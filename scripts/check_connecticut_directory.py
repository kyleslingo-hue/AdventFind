#!/usr/bin/env python3
"""Validate the reviewed seed; optionally fetch its public sources for change review.

Never overwrites approved data or treats a changed page as an approved new listing.
Usage: python3 scripts/check_connecticut_directory.py [--check-sources] [--limit N]
"""
import argparse
import hashlib
import json
import re
import time
import unicodedata
import urllib.error
import urllib.parse
import urllib.request
import urllib.robotparser
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
SEED = ROOT / 'SDA Church Finder/Resources/connecticut-churches.json'
REPORT = ROOT / 'research/connecticut/source-check.json'
AGENT = 'AdventFindDirectoryResearch/1.0'

class TextOnly(HTMLParser):
    def __init__(self):
        super().__init__(); self.hidden = 0; self.text = []
    def handle_starttag(self, tag, attrs):
        if tag in ('script', 'style'): self.hidden += 1
    def handle_endtag(self, tag):
        if tag in ('script', 'style'): self.hidden = max(0, self.hidden - 1)
    def handle_data(self, value):
        if not self.hidden: self.text.append(value)

def normalize(value):
    value = ''.join(c for c in unicodedata.normalize('NFKD', value.lower()) if not unicodedata.combining(c))
    replacements = {'avenue':'ave','street':'st','road':'rd','north':'n','south':'s','east':'e','west':'w','turnpike':'tpke'}
    return ' '.join(replacements.get(w, w) for w in re.findall(r'[a-z0-9]+', value))

class PublicSourcesOnly(urllib.request.HTTPRedirectHandler):
    def redirect_request(self, req, fp, code, msg, headers, newurl):
        if 'eadventist' in urllib.parse.urlsplit(newurl).hostname.lower():
            raise ValueError('Redirect to excluded directory; manual review needed')
        return super().redirect_request(req, fp, code, msg, headers, newurl)

opener = urllib.request.build_opener(PublicSourcesOnly())
def fetch(url):
    request = urllib.request.Request(url, headers={'User-Agent': AGENT})
    with opener.open(request, timeout=20) as response:
        return response.read(3_000_000), response.geturl()

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--check-sources', action='store_true')
    parser.add_argument('--limit', type=int)
    args = parser.parse_args()
    data = json.loads(SEED.read_text())
    records = data['records']
    assert data['schemaVersion'] == 1
    assert len({r['id'] for r in records}) == len(records), 'Duplicate IDs'
    addresses = {}
    for r in records:
        assert r['state'] == 'CT' and r['denomination'] == 'Seventh-day Adventist'
        assert r['street'] and r['street'][0].isdigit() and r['city'] and r['name']
        assert r['sourceURLs'] and r['website']
        for source in r['sourceURLs']:
            url = urllib.parse.urlsplit(source)
            assert url.scheme == 'https' and url.hostname and 'eadventist' not in url.hostname
        key = (normalize(r['street']), normalize(r['city']))
        addresses.setdefault(key, []).append(r)
    shared = [group for group in addresses.values() if len(group) > 1]
    for group in shared:
        assert all(not r['allowsAddressOnlyMatch'] for r in group), 'Shared building permits ambiguous match'
    print(f'Validated {len(records)} sourced SDA records; {len(shared)} shared-address group(s) safely flagged.')
    if not args.check_sources: return
    results = []
    robots_cache = {}
    for r in records[:args.limit]:
        source = r['sourceURLs'][0]
        origin = '{uri.scheme}://{uri.netloc}'.format(uri=urllib.parse.urlsplit(source))
        result = {'id':r['id'], 'sourceURL':source, 'approvedCheckedOn':r['checkedOn']}
        try:
            if origin not in robots_cache:
                robots = urllib.robotparser.RobotFileParser()
                try:
                    content, _ = fetch(origin + '/robots.txt')
                    robots.parse(content.decode('utf-8', errors='replace').splitlines())
                except urllib.error.HTTPError as error:
                    if error.code == 404: robots.parse([])
                    else: raise
                robots_cache[origin] = robots
            robots = robots_cache[origin]
            if not robots.can_fetch(AGENT, source):
                result['status'] = 'robots-disallowed'
            else:
                time.sleep(max(1, robots.crawl_delay(AGENT) or 0))
                body, final_url = fetch(source)
                html = TextOnly(); html.feed(body.decode('utf-8', errors='replace'))
                text = normalize(' '.join(html.text))
                required = normalize(r['street'])
                result.update(finalURL=final_url, contentSHA256=hashlib.sha256(body).hexdigest(),
                              addressStillPresent=required in text,
                              status='address-found-review-name' if required in text else 'needs-review')
        except Exception as error:
            result.update(status='fetch-unavailable', error=str(error))
        results.append(result)
        print(r['id'] + ': ' + result['status'], flush=True)
    REPORT.write_text(json.dumps({'checkedAtUTC':time.strftime('%Y-%m-%dT%H:%M:%SZ',time.gmtime()),
                                 'results':results}, indent=2)+'\n')
    print('Source checks are review aids; approved records were not changed.')

if __name__ == '__main__': main()
