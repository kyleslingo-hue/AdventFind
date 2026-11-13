#!/usr/bin/env python3
"""Carry existing research evidence into per-field records; never claim new verification.
Idempotent: existing per-field evidence is preserved. No network requests are made.
"""
import json
from pathlib import Path
ROOT = Path(__file__).resolve().parents[1]
roster = json.loads((ROOT / 'research/snec/roster.json').read_text())['source']
for filename in ('connecticut-churches.json', 'snec-churches.json'):
    path = ROOT / 'SDA Church Finder/Resources' / filename
    doc = json.loads(path.read_text())
    for record in doc['records']:
        sources = record['sourceURLs']
        checked = record['checkedOn']
        def published(present):
            if not present: return {'status':'unknown'}
            if not sources: return {'status':'needsReview'}
            return {'status':'published', 'sourceURLs':sources, 'checkedOn':checked}
        located = all(record[k] for k in ('street','city','state'))
        conference = {'status':'unknown'}
        if record.get('conference') and record.get('conferenceSourcePage'):
            conference = dict(status='published',sourceURLs=[],sourceTitle=roster['title'],sourceDate=roster['reportDate'],
                sourcePage=record['conferenceSourcePage'],sourceSHA256=roster['sha256'],checkedOn=checked)
        name = published(bool(record['name']) and located)
        if not located and record.get('conferenceSourcePage'): name = conference.copy()
        evidence = dict(name=name,address=published(located),website=published(bool(record['website'])),
                        phone=published(bool(record.get('phone'))),conference=conference,
                        worshipTimes={'status':'unknown'},
                        languages={'status':'unknown'})
        # No worship-language values are invented by this migration.
        record.setdefault('verification', {})
        for field, value in evidence.items(): record['verification'].setdefault(field,value)
    path.write_text(json.dumps(doc,ensure_ascii=False,indent=2)+'\n')
    print(filename, len(doc['records']), 'records; existing check dates retained')
