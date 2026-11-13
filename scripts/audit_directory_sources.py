#!/usr/bin/env python3
"""Recheck published public church sources; save factual matches for review, never infer new addresses."""
import concurrent.futures, hashlib, json, re, threading, time, unicodedata
import urllib.request, urllib.error, urllib.parse, urllib.robotparser
from html.parser import HTMLParser
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
AGENT='AdventFindDirectoryResearch/1.0'
class VisibleText(HTMLParser):
    def __init__(self): super().__init__();self.skip=0;self.parts=[]
    def handle_starttag(self,tag,attrs):
        if tag in ('script','style'):self.skip+=1
    def handle_endtag(self,tag):
        if tag in ('script','style'):self.skip=max(0,self.skip-1)
    def handle_data(self,value):
        if not self.skip:self.parts.append(value)
def normalize(text):
    text=''.join(c for c in unicodedata.normalize('NFKD',text.lower()) if not unicodedata.combining(c))
    text=re.sub(r'seventh[\s-]*day\s+adventist','sda',text)
    replacements={'street':'st','avenue':'ave','road':'rd','drive':'dr','boulevard':'blvd','turnpike':'tpke','north':'n','south':'s','east':'e','west':'w','massachusetts':'ma','connecticut':'ct','island':'island'}
    return ' '.join(replacements.get(w,w) for w in re.findall(r'[a-z0-9]+',text))
class NoExcludedRedirect(urllib.request.HTTPRedirectHandler):
    def redirect_request(self,req,fp,code,msg,headers,newurl):
        if 'eadventist' in (urllib.parse.urlsplit(newurl).hostname or ''):raise ValueError('Excluded directory redirect')
        return super().redirect_request(req,fp,code,msg,headers,newurl)
def fetch(url):
    opener=urllib.request.build_opener(NoExcludedRedirect())
    with opener.open(urllib.request.Request(url,headers={'User-Agent':AGENT}),timeout=15) as response:
        return response.read(3_000_000),response.geturl()
locks={};lock=threading.Lock()
def audit(record):
    sources=record['sourceURLs']
    if not sources:return {'id':record['id'],'name':record['name'],'status':'no_source_yet'}
    source=sources[0];origin='{u.scheme}://{u.netloc}'.format(u=urllib.parse.urlsplit(source))
    with lock: hostlock=locks.setdefault(origin,threading.Lock())
    result={'id':record['id'],'name':record['name'],'sourceURL':source}
    try:
        with hostlock:
            robots=urllib.robotparser.RobotFileParser()
            try:
                body,_=fetch(origin+'/robots.txt');robots.parse(body.decode('utf-8',errors='replace').splitlines())
            except urllib.error.HTTPError as error:
                if error.code==404:robots.parse([])
                else:raise
            if not robots.can_fetch(AGENT,source):result['status']='robots_disallowed';return result
            time.sleep(min(30,max(0.5,robots.crawl_delay(AGENT) or 0)))
            body,final=fetch(source)
        parser=VisibleText();parser.feed(body.decode('utf-8',errors='replace'));visible=' '.join(parser.parts);text=normalize(visible)
        street=normalize(record['street']);city=normalize(record['city'])
        address=bool(street and city and street in text and city in text)
        names=[record['name']]+record['aliases']
        name=any(normalize(n) in text for n in names)
        phone=record.get('phone');phone_match=bool(phone and re.sub(r'\D','',phone) in re.sub(r'\D','',visible))
        review=any(phrase in visible.lower() for phrase in ['temporary location','temporarily meeting','have moved','new worship location','mailing address'])
        result.update(status='matched_published_address' if address else 'manual_review',nameMatched=name,addressMatched=address,
            phoneMatched=phone_match,reviewLocationContext=review,finalURL=final,contentSHA256=hashlib.sha256(body).hexdigest())
    except Exception as error:result.update(status='source_unavailable',error=str(error))
    return result
if __name__=='__main__':
    combined={}
    for filename in ('connecticut-churches.json','snec-churches.json'):
        for record in json.loads((ROOT/'SDA Church Finder/Resources'/filename).read_text())['records']:combined[record['id']]=record
    results=[]
    with concurrent.futures.ThreadPoolExecutor(max_workers=4) as pool:
        for result in pool.map(audit,combined.values()):
            results.append(result)
            if result['status']!='no_source_yet':print(result['id']+': '+result['status'],flush=True)
    path=ROOT/'research/verification/source-audit-2026-11-07.json'
    path.write_text(json.dumps({'checkedOn':'2026-11-07','method':'Public-source check; not direct contact with congregations','records':results},indent=2)+'\n')
    from collections import Counter
    print(dict(Counter(r['status'] for r in results)),flush=True)
