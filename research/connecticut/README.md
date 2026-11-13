# Connecticut directory pilot

The app bundles 48 researched Seventh-day Adventist congregations from their public church websites. No eAdventist feed or scraped eAdventist records are used. The source register is [SOURCES.md](SOURCES.md); the database is `SDA Church Finder/Resources/connecticut-churches.json`.

## How it works

Explore → Browse Connecticut directory exposes the whole researched collection, independently of Apple Maps search coverage. Search by congregation, town or street. Listings offer their source, website, published public phone when available, and address-based Apple Maps directions. No coordinates are guessed.

Apple Maps search results are enriched only when street number, normalized full street, Connecticut state and city (or an exact five-digit ZIP) match. Street suffixes and cardinal directions normalize. Map IDs and coordinates remain unchanged, preserving saved places and map positioning. Saved records also receive enrichment. Unmatched results remain Apple Maps records.

Generic map names can resolve only to one unambiguous address. At known shared buildings or cohosted congregations a congregation-specific name must match; ambiguous generic listings remain unchanged. Moved churches are not matched by their old addresses. Sources and original map names are retained in attribution. Directory data has a static reviewed date and is not presented as a live official feed.

## Coverage and review queue

This is an initial collection, not a complete statewide census. Church-published information can itself be stale. In particular Stamford Spanish describes its address as provisional. Norwalk Spanish and Mont des Oliviers share a physical address; New Britain Spanish also hosts an English mission. Those records explicitly disable address-only matching.

Further research candidates include Canaan, Plainville, Hope (Bloomfield), Willimantic Spanish, Ansonia, and additional congregations without a clearly verifiable public address. Peniel Haitian was excluded after research located it in Massachusetts, not Connecticut. Do not add addresses, names or service times from unverified search snippets. Canaan and Hope sites were unavailable through the research tool; no records were invented. A search for Rockville also surfaced an SDA church in Maryland, which was excluded.

## Maintaining the collection

Run `python3 scripts/check_connecticut_directory.py` to validate schema, source URLs, unique IDs and shared-address protections. The optional `--check-sources [--limit N]` mode fetches only the approved source pages, respects robots rules, records hashes and checks whether the approved physical address is still present. It does not approve changed names or overwrite the bundled database. Review changes manually against primary sources, update the source register and checked date, then run the Swift matching tests before release.

Only public organizational facts are retained. No member details, copied descriptions, photos, prayer lists, personal pastoral contacts or service schedules were imported.

## Validation

- 46 bundled records validated with unique IDs, public HTTPS sources, explicit SDA affiliation and safeguards at shared addresses.
- Nine directory unit tests passed on iOS 27.2, covering resource loading, exact-address correction, normalization, aliases, wrong states and addresses, moved churches, shared congregations and legacy saved-record decoding.
- The six sunset regression tests also passed during integration.
- An iPhone UI test passed through Explore → Browse Connecticut directory → search Schilo → listing details, checking the published church name, physical address and website control without requiring location permission.
- The optional source checker fetched three source pages successfully and found their approved physical addresses; it did not overwrite reviewed data.

## November 7, 2026 additions

Added Orion Spanish SDA Company (New Milford) and Wallingford Spanish SDA Church from their own public websites. The original 46 records retain their November 6 check dates. Orion publishes no public phone on the reviewed page, so none was added. Wallingford’s phone is the number published under its public call link. Spanish is indicated by both listing names; service languages have not been independently confirmed. Canaan, Plainville, Hope and Willimantic Spanish remain unapproved because their church pages could not be accessed during this pass.
