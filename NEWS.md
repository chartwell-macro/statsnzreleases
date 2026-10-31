# statsnzreleases 0.3.1

- Rejects incomplete or conflicting migration backfills and invalid numeric tokens.
- Preserves published missing tokens and current release status metadata.

# statsnzreleases 0.3.0

- Adds official full-history building, migration, business-price and selected-price routes.
- Retains attachment hashes and explicit full-history vintage rules.

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
