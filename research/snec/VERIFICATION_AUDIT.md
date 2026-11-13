# Directory verification audit and feature priorities

Implementation update: per-field evidence and directory filters are now implemented. See [the verification model](VERIFICATION_MODEL.md). Findings below describe the pre-change audit; the 69 location-research gaps remain.

Reviewed November 7, 2026. This is an audit of the current data and implementation, with a four-site primary-source spot check. It is not a completed re-verification of every congregation.

## Current state

| Measure | Count |
|---|---:|
| SNEC roster entries | 182 |
| SNEC entries with populated street, city and state | 113 |
| SNEC entries awaiting location research | 69 |
| Populated locations by state | MA 71; CT 33; RI 9 |
| SNEC records with a website | 114 |
| SNEC records with a phone | 78 |
| Connecticut source records | 48 |
| Shared record IDs between Connecticut and SNEC files | 33 |
| Unique entries after loader merge | 197 |
| Total unique entries with populated location fields | 128 |

All 182 SNEC records have a conference label and source-page reference. Fifteen additional Connecticut entries remain outside that roster; a missing conference label must remain unknown until sourced. Connecticut geography alone does not establish SNEC membership.

## Spot checks against church-owned sites

- [Amesbury](https://amesburyma.adventistchurch.org/): source confirms 171 Main Street, Amesbury, MA. The website uses the full Seventh-day Adventist name while the roster uses SDA.
- [Beth-Union Haitian](https://bethunionhaitianma.adventistchurch.org/): source confirms the stored `15 Lowell Bvd, Methuen, MA 01844` and published phone. `Bvd` is the site's spelling; keep the source evidence, then independently check the canonical street spelling before adding an address-normalization alias.
- [Orion Spanish](https://orionct.adventistchurch.org/): source confirms Company and 68 Danbury Rd, New Milford, CT 06776-3412. No public phone is supplied on this page; leave it unknown.
- [Wallingford Spanish](https://wallingfordspanishct.adventistchurch.org/): source confirms 941 Old Rock Hill Rd, Wallingford, CT 06492-3950 and 978-902-4437. An out-of-state phone area code alone is not evidence of an error.

These checks confirm what the websites publish, not that a church was contacted or its current meeting arrangements independently confirmed. No app records were changed by this audit.

## Findings to address before broadening claims

1. `hasVerifiedLocation` currently checks only whether street, city and state are nonempty. UI labels such as “Location verified from church source” therefore rely entirely on the importer having done the research. Add explicit address evidence/status rather than equating completeness with verification.
2. A single `checkedOn` cannot describe the freshness of every field. Address, phone, website, worship times, languages and conference should each carry status, source and checked date. Distinguish website-published from directly confirmed information.
3. Conference evidence comes from the user-provided October 30 report; address evidence comes from church sites. Preserve these as separate provenance. A PDF page is useful, but the report title/date/hash should be carried by a shared source record rather than repeated display text alone.
4. The research roster still describes all 182 entries as a pre-publication research collection, despite a separate SNEC file now being loaded in the app. Reconcile research statuses to the actual app collection to avoid duplicate work or incorrectly promoting a candidate identity match.
5. Shared-address records exist at 26 Burncoat St, Worcester (three congregations), and 2695 N Main St, Fall River (two). Address-only matching is disabled for these SNEC records. Preserve that protection and review organization-specific names before merging.
6. Eighty-three located SNEC records disable address-only matching. That is conservative, but generic Apple Maps names will often remain unchanged even when a researched address exists. Approve address-only matching per location after checking cohosted congregations; do not enable it globally.
7. The web-only Peniel Haitian entry still lacks a verified address. Do not enable directions based on its name or a pastor's district.
8. “Language indicated” is appropriately separate from confirmed worship language. Keep that distinction; website translation or a congregation's nationality does not establish its service language.

## Recommended verification workflow

- Prioritize the 69 location gaps, temporary/moved addresses and shared buildings; do not start by rechecking every already sourced field indiscriminately.
- Record a congregation's official/published name, organization type, meeting address versus mailing address, public contact, conference evidence and source dates.
- Verify worship service and Sabbath School times separately, including local time zone and whether information is current. Online prayer meetings must not become in-person worship times.
- Geocode the confirmed physical address and review the map pin before making the researched directory a map-search source independent of Apple Maps coverage.
- Review conflicts explicitly; retain the old value/source in a research history. Website unavailability alone should not mark a congregation inactive.
- Run matching, shared-address, source-loading and legacy-saved-record tests for data/schema changes. Do not treat a successful HTTP request as confirmation that every field is correct.

## Feature order

### First: reliable discovery

- State, conference and confirmed/indicated language filters, including unknown values.
- A “visit details ready” state based on confirmed physical address and current worship information.
- Directory-backed map pins and nearby search after address geocoding, so results no longer depend on Apple Maps identifying an SDA church.
- Clear “address pending”, “time not listed” and source-date information.

### Next: plan a Sabbath visit

- Worship time and Sabbath School time, route/arrival estimate, a calendar action and local sunset together.
- Saved churches from both researched listings and Apple Maps, preserving stable identity across name changes. The current directory-only detail sheet does not yet expose the same save action as map-backed details.
- Confirmed visitor information: parking/entrance, accessibility, children's programs and worship language. Unknown is a valid value.

### Then: keep the directory useful

- Suggest a correction with the affected field, supporting link and a review queue; submissions must not immediately overwrite public records.
- Church-confirmed updates, with an ownership-verification process and field history before introducing a public “church confirmed” badge.
- Verified livestream and event links, with expiry dates for temporary events.

Recommended next implementation: explicit verification/provenance fields plus state/conference filters. This improves trust and makes the remaining research manageable before adding broader social or event features.
