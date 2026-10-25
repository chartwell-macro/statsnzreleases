# statsnzreleases 0.2.1

- Adds complete reference documentation, deterministic examples, task-oriented
  vignettes, a generated README, and a grouped pkgdown site for the supported
  Stats NZ release families.
- Adds CRAN-ready package metadata, citation and licensing guidance, community
  support files, and multi-platform check, coverage, and pkgdown workflows.
- Preserves smart punctuation and other non-ASCII labels when CSV input is
  decoded on systems whose native locale is not UTF-8.
- Adds an end-to-end CPI retrieval and chart workflow to the README and Getting
  Started guide, rendered offline from an attributed official Stats NZ
  snapshot through the public reader.
- Standardises the package author, maintainer, and copyright-holder display as
  Chartwell Macro while retaining source-data attribution.
- Explains the package's release-calendar, information-page, and attachment
  access path; distinguishes it from the subscription-key Aotearoa Data
  Explorer API; and documents when to use each route.

# statsnzreleases 0.2.0

- Adds a memory-aware Labour Market Statistics adapter that streams the
  standard LMS table and retains curated quarterly HLFS, QES, and LCI
  headline series.
- Adds an Overseas Merchandise Trade workbook adapter covering actual,
  seasonally adjusted, and trend series across monthly and quarterly
  headline, value, and quantity tables.

# statsnzreleases 0.1.0

- Initial release-file importer.
- Supports CPI, GDP, electronic card transactions, retail trade, and balance
  of payments/international investment position.
- Adds automatic latest-release discovery, official attachment selection,
  standardised time-series output, caching, filtering, and SHA-256 provenance.
- Records labour market statistics and overseas merchandise trade as deferred
  release families.
