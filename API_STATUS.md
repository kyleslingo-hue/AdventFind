# Church data integration status

Discovery uses Apple Maps, with names and websites enriched by AdventFind’s Connecticut research directory when a specific address and congregation match is clear. The historically named `EAdventistService` remains a cache/wrapper around Apple Maps; no eAdventist account, feed or scraped eAdventist records are used.

The app bundles 46 Connecticut SDA congregation records researched from public church websites, with physical addresses, published church phones when available, source URLs and checked dates. Explore → Browse Connecticut directory works independently of Maps search coverage. No coordinates are guessed. Shared-address generic listings and old addresses are not automatically renamed. Map result IDs and coordinates are preserved.

See [Connecticut research notes](research/connecticut/README.md) and [source register](research/connecticut/SOURCES.md). The collection is incomplete and needs periodic source review. See [REDESIGN.md](REDESIGN.md) for the future authorized official-feed integration path.
