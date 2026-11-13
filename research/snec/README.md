# SNEC directory research roster

Current integration audit: [verification findings and feature priorities](VERIFICATION_AUDIT.md). The app now loads a separate `snec-churches.json` containing all 182 roster entries, including entries explicitly awaiting location research. The checklist below describes the original research handoff and has not yet been reconciled with all subsequent app additions.

User-provided October 30, 2026 report: **182 congregations**. Extracted all congregation rows from pages 3–10 and checked the total against the report. **33 name-based candidates** correspond to existing Connecticut listings; **149 require location research**. A name match is a research lead, not an approved identity merge.

The app currently contains 48 researched Connecticut listings. Its additional listings are retained: this SNEC report is not a census of every conference serving Connecticut.

## Files

- `roster.json`: durable research records, source pages, source PDF hash, and explicitly excluded organizations.
- `roster.csv`: spreadsheet-friendly checklist of the same 182 names.
- The user-provided PDF is the roster source. Attendance figures, reporting classifications, and pastoral details are not imported.

## Publication requirements

1. Confirm each congregation’s current physical address, city, state, and public website from its own website or another approved primary source.
2. Preserve the source spelling and organization type. Review Church/Company/Group discrepancies before changing existing listings.
3. Record the source URL and verification date. Leave missing information unknown; do not infer location from a pastor’s district or congregation name.
4. Confirm shared-address and moved-congregation cases before enabling address-only matching.
5. Publish only verified records. The current app loader and matching logic are Connecticut-specific; expand them deliberately before publishing Massachusetts or Rhode Island listings.

Language words in names can support the existing “Language indicated” badge. Nationality alone does not establish worship language. The report’s “Not yet started” category means attendance reporting has not started; it does not mean the church is inactive. Only the four exclusions explicitly listed in the report footer are tracked as excluded.

## First research batch

Continue with Connecticut gaps: Canaan, Plainville, Ansonia Mount Zion Spanish, Bristol Betel Spanish, Greenwich, Norwich Cape Verdean, Shekinah II Haitian, Waterbury Lion of Judah Spanish, Waterbury Spanish, Willimantic Spanish, Naugatuck, and Quinebaug Spanish. Confirm the location of Covenant Spanish and Middleton Spanish before assigning either to a state. Orion and Wallingford were added to the app on November 7 from their public church websites.

## Checklist

| Congregation | PDF page | Research status | Existing listing candidate |
|---|---|---|---|
| Amesbury SDA Church | 3 | Verify location and website | — |
| Ansonia Mount Zion Spanish SDA Group | 7 | Verify location and website | — |
| Athol SDA Church | 7 | Verify location and website | — |
| Attleboro SDA Church | 6 | Verify location and website | — |
| Attleboro Spanish SDA Church | 3 | Verify location and website | — |
| Beraca Franco-Haitian Mission Group | 8 | Verify location and website | — |
| Berkshire Hills SDA Church | 6 | Verify location and website | — |
| Beth-Union Haitian SDA Church | 3 | Verify location and website | — |
| Bethany Haitian SDA Company | 6 | Verify location and website | — |
| Bethel Haitian SDA Church | 3 | Verify location and website | — |
| Bethesda Haitian SDA Church | 3 | Verify location and website | — |
| Beverly SDA Church | 3 | Verify location and website | — |
| Billerica SDA Church | 8 | Verify location and website | — |
| Boston Cape Verdean SDA Group | 8 | Verify location and website | — |
| Boston Korean SDA Church | 8 | Verify location and website | — |
| Boston Portuguese SDA Church | 3 | Verify location and website | — |
| Boston Slavic SDA of Framingham Group | 8 | Verify location and website | — |
| Boston Spanish SDA Church | 3 | Verify location and website | — |
| Boston Temple SDA Church | 8 | Verify location and website | — |
| Braintree SDA Church | 3 | Verify location and website | — |
| Bridgeport Portuguese SDA Church | 3 | Review existing match | ct-bridgeport-portuguese |
| Bridgeport Spanish SDA Church | 3 | Review existing match | ct-bridgeport-spanish |
| Bristol Betel Spanish SDA Group | 6 | Verify location and website | — |
| Bristol SDA Group | 9 | Review existing match | ct-bristol |
| Brockton Cape Verdean SDA Church | 9 | Verify location and website | — |
| Brockton SDA Church | 9 | Verify location and website | — |
| Brooklawn SDA Church | 3 | Review existing match | ct-brooklawn |
| Burrillville SDA Church | 3 | Verify location and website | — |
| Canaan SDA Church | 9 | Verify location and website | — |
| Cape Cod Brazilian SDA Company | 3 | Verify location and website | — |
| Cape Cod SDA Church | 6 | Verify location and website | — |
| Central Falls Spanish SDA Church | 3 | Verify location and website | — |
| Chosen Cape Verdean SDA Group | 9 | Verify location and website | — |
| Clinton Spanish SDA Church | 3 | Verify location and website | — |
| College SDA Church | 6 | Verify location and website | — |
| Connecticut Valley SDA Church | 8 | Review existing match | ct-connecticut-valley |
| Covenant Spanish SDA Group | 8 | Verify location and website | — |
| Cranston Spanish SDA Company | 3 | Verify location and website | — |
| Crosswalk Boston SDA Group | 6 | Verify location and website | — |
| Crosswalk Hartford SDA Company | 8 | Review existing match | ct-crosswalk-hartford |
| Crosswalk New England SDA Church | 6 | Verify location and website | — |
| Danbury Nuevo Horizonte Spanish SDA Church | 3 | Review existing match | ct-danbury-nuevo-horizonte |
| Danbury-Bethel SDA Church | 3 | Review existing match | ct-danbury-bethel |
| Dedham Temple SDA Church | 8 | Verify location and website | — |
| Dorchester Cape Verdean SDA Church | 6 | Verify location and website | — |
| Ebenezer KinYarwanda SDA Group | 9 | Verify location and website | — |
| Ebenezer Spanish SDA Group | 9 | Verify location and website | — |
| Eden Haitian SDA Company | 9 | Verify location and website | — |
| El Faro Spanish SDA Church | 3 | Verify location and website | — |
| Ephesus Haitian SDA Church | 9 | Verify location and website | — |
| Espaço Novo Tempo Leominster Company | 9 | Verify location and website | — |
| Esperanza SDA Church | 3 | Verify location and website | — |
| Everett Portuguese SDA Church | 3 | Verify location and website | — |
| Fall River Cape Verdean SDA Church | 8 | Verify location and website | — |
| Fall River Portuguese SDA Church | 4 | Verify location and website | — |
| Fall River SDA Church | 9 | Verify location and website | — |
| Fall River Spanish SDA Company | 4 | Verify location and website | — |
| First Springfield SDA Church | 4 | Verify location and website | — |
| Fitchburg SDA Church | 6 | Verify location and website | — |
| Foxboro SDA Church | 6 | Verify location and website | — |
| Framingham Centre SDA Church | 4 | Verify location and website | — |
| Framingham Portuguese SDA Church | 9 | Verify location and website | — |
| Framingham Spanish SDA Church | 6 | Verify location and website | — |
| Framingham Temple Haitian SDA Church | 9 | Verify location and website | — |
| Freetown SDA Company | 4 | Verify location and website | — |
| Gardner SDA Church | 6 | Verify location and website | — |
| Gethsemane Haitian SDA Church | 4 | Verify location and website | — |
| Gloucester Spanish SDA Company | 9 | Verify location and website | — |
| Grace and Glory SDA Church | 9 | Verify location and website | — |
| Greater Boston Brazilian SDA Church | 4 | Verify location and website | — |
| Greater Boston Chinese SDA Church | 4 | Verify location and website | — |
| Greater Boston Ghanaian SDA Church | 6 | Verify location and website | — |
| Greater Bridgeport Ghanaian SDA Church | 4 | Review existing match | ct-greater-bridgeport-ghanaian |
| Greater Hartford Ghanaian SDA Church | 4 | Review existing match | ct-greater-hartford-ghanaian |
| Greenwich SDA Company | 4 | Verify location and website | — |
| Harmony SDA Church | 4 | Verify location and website | — |
| Hartford Bethel Haitian SDA Company | 4 | Review existing match | ct-hartford-bethel-haitian |
| Hartford Portuguese SDA Company | 4 | Review existing match | ct-hartford-portuguese |
| Hartford Spanish SDA Church | 4 | Review existing match | ct-hartford-spanish |
| Haverhill SDA Church | 9 | Verify location and website | — |
| Holyoke Spanish SDA Church | 7 | Verify location and website | — |
| Hope Northampton SDA Church | 4 | Verify location and website | — |
| Hudson SDA Church | 4 | Verify location and website | — |
| Jamaica Plain Spanish SDA Church | 9 | Verify location and website | — |
| Jerusalem Haitian SDA Church | 7 | Verify location and website | — |
| Johnston SDA Church | 7 | Verify location and website | — |
| Lakeview Ghanaian SDA Church | 4 | Verify location and website | — |
| Lancaster Brazilian SDA Church | 4 | Verify location and website | — |
| Lawrence Spanish SDA Church | 7 | Verify location and website | — |
| Leominster All Nations SDA Church | 9 | Verify location and website | — |
| Leominster SDA Church | 7 | Verify location and website | — |
| Leominster Spanish SDA Church | 9 | Verify location and website | — |
| Lighthouse SDA Church | 4 | Verify location and website | — |
| Lincoln SDA Church | 4 | Verify location and website | — |
| Lowell All Nations SDA Church | 9 | Verify location and website | — |
| Lowell Portuguese SDA Church | 4 | Verify location and website | — |
| Lowell Spanish SDA Church | 9 | Verify location and website | — |
| Lynn Spanish SDA Church | 9 | Verify location and website | — |
| Malden Spanish SDA Church | 8 | Verify location and website | — |
| Marlboro Spanish SDA Church | 4 | Verify location and website | — |
| Meriden SDA Church | 7 | Review existing match | ct-meriden |
| Meriden Spanish SDA Church | 4 | Review existing match | ct-meriden-spanish |
| Merrimack Valley SDA Church | 7 | Verify location and website | — |
| Middleton Spanish SDA Group | 9 | Verify location and website | — |
| Middletown-Portland SDA Church | 4 | Review existing match | ct-middletown-portland |
| Monte de Sion Spanish SDA Company | 4 | Verify location and website | — |
| Mount Horeb SDA Church | 9 | Verify location and website | — |
| Nantucket SDA Company | 9 | Verify location and website | — |
| Naugatuck SDA Company | 9 | Verify location and website | — |
| New Bedford Cape Verdean SDA Church | 10 | Verify location and website | — |
| New Bedford Portuguese SDA Church | 5 | Verify location and website | — |
| New Bedford SDA Church | 7 | Verify location and website | — |
| New Bedford Spanish SDA Church | 5 | Verify location and website | — |
| New Britain Spanish SDA Church | 8 | Review existing match | ct-new-britain-spanish |
| New England Ghanaian SDA Church | 7 | Verify location and website | — |
| New England Luganda SDA Company | 8 | Verify location and website | — |
| New Haven SDA Church | 5 | Review existing match | ct-new-haven |
| New Haven Spanish SDA Church | 7 | Review existing match | ct-new-haven-spanish |
| North Stamford SDA Church | 5 | Review existing match | ct-north-stamford |
| Northboro SDA Church | 8 | Verify location and website | — |
| Norwalk Spanish SDA Church | 5 | Review existing match | ct-norwalk-spanish |
| Norwich Cape Verdean SDA Group | 5 | Verify location and website | — |
| Norwich SDA Church | 10 | Review existing match | ct-norwich |
| Norwood SDA Company | 10 | Verify location and website | — |
| Nouvelle Arche Haitian SDA Church | 7 | Verify location and website | — |
| Nuevo Amanecer Spanish SDA Church | 5 | Verify location and website | — |
| One Connection Boston SDA Group | 5 | Verify location and website | — |
| One Connection Haverhill SDA Company | 8 | Verify location and website | — |
| Orion Spanish SDA Company | 5 | Review existing match | ct-orion-spanish |
| Pawtucket Cape Verdean SDA Church | 7 | Verify location and website | — |
| Pawtucket Portuguese SDA Church | 10 | Verify location and website | — |
| Peniel Haitian SDA Church | 5 | Verify location and website | — |
| Plainville SDA Church | 10 | Verify location and website | — |
| Pleasant Street SDA Church | 5 | Verify location and website | — |
| Prospect Avenue SDA Church | 7 | Review existing match | ct-prospect-avenue |
| Providence Ghanaian SDA Company | 5 | Verify location and website | — |
| Providence Spanish SDA Church | 5 | Verify location and website | — |
| Quinebaug SDA Church | 7 | Review existing match | ct-quinebaug |
| Quinebaug Spanish SDA Group | 10 | Verify location and website | — |
| Randolph Cape Verdean SDA Company | 10 | Verify location and website | — |
| Redemption Community SDA Company | 8 | Verify location and website | — |
| Renacer Massachusetts Spanish SDA Church | 5 | Verify location and website | — |
| Renacer Stratford Spanish SDA Church | 5 | Review existing match | ct-renacer-stratford |
| Revelation Lynnfield Spanish SDA Company | 5 | Verify location and website | — |
| Revere Spanish SDA Company | 8 | Verify location and website | — |
| Rockville-Tolland SDA Church | 5 | Review existing match | ct-rockville-tolland |
| Salem Mass Esperanza Spanish Group | 10 | Verify location and website | — |
| Salem SDA Church | 7 | Verify location and website | — |
| Salem Spanish SDA Company | 10 | Verify location and website | — |
| Seekonk Portuguese SDA Church | 10 | Verify location and website | — |
| Senderos de Vida SDA Company | 10 | Verify location and website | — |
| Shaddai Spanish SDA Church | 8 | Verify location and website | — |
| Shekinah Haitian SDA Church | 5 | Review existing match | ct-shekinah-haitian |
| Shekinah II Haitian SDA Church | 5 | Verify location and website | — |
| Shelburne Falls SDA Church | 7 | Verify location and website | — |
| Shrewsbury SDA Church | 8 | Verify location and website | — |
| Sinai Haitian SDA Church | 5 | Verify location and website | — |
| Springfield Congolese SDA Group | 10 | Verify location and website | — |
| Springfield Nouvelle Jerusalem Haitian SDA Company | 5 | Verify location and website | — |
| Stamford Spanish SDA Church | 5 | Review existing match | ct-stamford-spanish |
| Sterling SDA Church | 8 | Verify location and website | — |
| Stoneham Memorial SDA Church | 5 | Verify location and website | — |
| Sychar Haitian SDA Church | 5 | Verify location and website | — |
| Taunton Cape Verdean SDA Church | 5 | Verify location and website | — |
| Taunton Haitian SDA Church | 5 | Verify location and website | — |
| Taunton SDA Church | 7 | Verify location and website | — |
| Three Angels SDA Church | 7 | Verify location and website | — |
| Village SDA Church | 6 | Verify location and website | — |
| Wallingford Spanish SDA Church | 6 | Review existing match | ct-wallingford-spanish |
| Waltham SDA Church | 8 | Verify location and website | — |
| Waltham Spanish SDA Group | 10 | Verify location and website | — |
| Warren SDA Church | 10 | Verify location and website | — |
| Waterbury Lion of Judah Spanish SDA Church | 6 | Verify location and website | — |
| Waterbury SDA Church | 7 | Review existing match | ct-waterbury |
| Waterbury Spanish SDA Church | 6 | Verify location and website | — |
| Waterford SDA Church | 6 | Review existing match | ct-waterford |
| Wickford SDA Church | 7 | Verify location and website | — |
| Willimantic SDA Church | 8 | Review existing match | ct-willimantic |
| Willimantic Spanish SDA Church | 6 | Verify location and website | — |
| Worcester Central Spanish SDA Church | 6 | Verify location and website | — |
| Worcester Portuguese SDA Church | 6 | Verify location and website | — |
| Worcester SDA Church | 6 | Verify location and website | — |
