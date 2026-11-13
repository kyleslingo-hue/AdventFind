# AdventFind

A native SwiftUI app for finding Seventh-day Adventist churches and viewing Sabbath sunset times for a selected place.

## Experience

- Today: illustrated sunset dashboard and nearby community discovery.
- Explore: location search, church filtering, interactive map, adaptive list/map layout, and a browsable Connecticut directory.
- Saved: locally persisted church records for future visits.
- You: discovery preferences and calculation information.
- Church details: directions, contact links, sharing, and local sunset times.
- Native static launch storyboard; no additional splash delay.

## Development

Open `SDA Church Finder.xcodeproj`, select the `AdventFind` scheme, and build with Xcode 27.2. Deployment target is iOS 18. The project resolves Solar 3.0.1 through Swift Package Manager.

Church discovery uses Apple Maps, enriched by a bundled collection of 46 Connecticut SDA congregations researched from church websites. Names are corrected only for clear address/name matches; shared buildings and conflicting names remain unresolved. Browse the collection from Explore → Browse Connecticut directory. Official eAdventist locator access is not connected. See [REDESIGN.md](REDESIGN.md) for implementation details, sunset fixes, validation results, and the directory integration plan.

Sunset tests: `AdventFindTests/SabbathTimeServiceTests`. These cover civil dates, time zones, DST, sunset interval boundaries, and polar day. Network-backed search tests require live services.

Connecticut database and sources: [research notes](research/connecticut/README.md), [source register](research/connecticut/SOURCES.md). Run `python3 scripts/check_connecticut_directory.py` for data validation. The initial collection is not a complete statewide census.

Directory verification now tracks sources, dates and status separately for names, meeting addresses, contact details, conference, worship times and worship languages. State, conference and language filters include unknown values and distinguish name-based language clues from confirmed worship languages. See [verification model](research/snec/VERIFICATION_MODEL.md). Existing source dates were preserved; this update does not represent a new verification of every listing.
