# AdventFind redesign

## Rebuilt experience

The former screen system has been replaced. The app opens directly into a midnight-blue dashboard with an adaptive vector sunset landscape, warm ivory typography and sunset-orange controls. Today, Explore, Saved and You use native system tab navigation. Explore uses list/map selection on compact windows and simultaneous results/map when space allows. Church details and settings share the same new design system. A static LaunchScreen.storyboard matches the opening background without adding a timed splash or extra landing page.

Saved church records now persist locally as well as their IDs. Discovery uses Apple Maps with researched Connecticut name corrections where a precise address/congregation match is clear. A separate Connecticut directory is browsable from Explore. The UI does not represent it as a live official directory feed. See research/connecticut/README.md.

## Sunset correctness

The selected place is reverse-geocoded to resolve its time zone. If resolution fails, the UI asks for a place again instead of silently using the phone's zone. Calendar arithmetic uses Gregorian local civil dates. Solar's UTC calculation is seeded from those civil dates and normalized to the requested local date. Every displayed event uses the place's time zone and event-date DST offset. The old hour-long cache was removed, and visible sunset intervals refresh periodically. Sabbath intervals include Friday sunset and exclude Saturday sunset. Polar locations with no sunset receive an unavailable state, not an invented time.

Six deterministic sunset tests passed on iOS 27.2: New York November clock time, Los Angeles UTC day rollover, Sydney/Auckland local Friday, DST offsets, exact sunset boundaries, and polar day. App builds with Xcode 27.2. The dashboard was visually checked on a standard iPhone and the Duo cover display. Inner-display visual validation remains outstanding because the simulator returned a black display during the attempt. Live directory search and geocoder behavior depend on network services and were not covered by these deterministic tests.

Apple's Duo preparation guidance: https://developer.apple.com/iphone-duo/prepare/

## Official directory integration

Current runtime provider: AppleMapsService, wrapped by the historically named EAdventistService. Results are not official directory records. Earlier README endpoint examples are placeholders and must not be used as an integration contract.

Verified documentation: https://help.eadventist.net/article/16-web-services

The locator-specific endpoint is:
https://www.eadventist.net/web_services/locator_organizations

It supports JSON with `format=json`, requires a `from` update cursor/date, and returns changed or authorized organizations including coordinates, contact details, pastor, and service times. All web services require an eAdventist account with appropriate roles. The documentation describes an account request limit of four requests per hour; confirm the locator feed's scope, quotas, initial sync, deletion semantics, and cursor format directly with eAdventist before implementation. Its example cursor is ambiguous, so do not infer its encoding.

Recommended architecture:
1. Obtain authorized locator access and a representative JSON response from eAdventist. Confirm coverage and redistribution permission for AdventFind.
2. A backend keeps credentials, syncs authorized public organization records, stores the last successful cursor, and caches data. Never ship directory account credentials in the iOS app.
3. Validate the actual response schema, stable IDs, updates and removals. Map records to Church only after inspecting that schema.
4. The app queries the backend by location and radius. Preserve source provenance and distinguish official records from any Apple Maps fallback.

No official endpoint has been connected in this pass: access and the response contract are still required. Do not scrape the public locator or assume a public proximity-search API exists.
