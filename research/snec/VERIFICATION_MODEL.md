# Field verification and directory filters

Implemented November 7, 2026.

Each directory record now has `verification` entries for name, address, website, phone, conference, worship times and worship language. Each entry stores its own status and optional source URLs, source title/date/page/hash, and check date. The app distinguishes unknown, needs review, name clue, published-source and directly confirmed information. A published or confirmed status without evidence and a check date is displayed as needing review.

Existing researched website details were carried forward as published-source evidence using their original checked dates. Conference evidence points separately to the user-provided October 30 SNEC report, including page and hash. No website was newly checked by this migration, no church was contacted, no worship time or language was invented, and no record was promoted to directly confirmed status. Missing evidence decodes safely as unknown, including older saved records.

The migration is `python3 scripts/migrate_directory_verification.py`. It preserves existing per-field evidence and check dates and makes no network calls. Its legacy `checkedOn` input is used only to carry existing research forward; new research should update individual fields with their actual sources and dates. Mark conflicting information `needsReview` rather than silently replacing it. A church-confirmed status should be set only after direct confirmation and supporting evidence are recorded.

Address completeness is separate from address evidence. Address-based directions require a complete sourced address. Automatic map-name correction requires separate name and address evidence and retains existing shared-building protections. Published phone/website values can enrich a map record only when their own evidence is sourced. Per-field evidence is retained in directory attribution and survives saved-record encoding.

Directory filters combine state, conference, language and free-text search using AND. State/conference/language all have explicit unknown/not-listed options, so the 69 entries with unresolved locations remain discoverable. Name-based language clues remain labeled as clues. “Confirmed worship languages only” excludes them and requires a sourced, directly confirmed worship-language value. No current record meets that stronger status. Clear filters restores the complete 197-entry collection and clears text search.

The Sources and checks disclosure in directory details and enriched map details shows each field's status and sources separately. Conference labels also show the evidence status. Map positions remain supplied by Apple Maps; this change does not geocode the researched directory or verify every current listing.

Validation covers sparse unknown JSON, existing saved records, per-field isolation, conference PDF provenance, missing/incomplete evidence, combined filters, unknown values, language clues versus confirmation, bundled resources, and existing address/shared-building matching. UI coverage exercises directory search, combined state/conference/language filters, empty results, and reset.
