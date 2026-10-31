# statsnzreleases

`statsnzreleases` discovers, downloads, caches, and standardises official data
files attached to major Stats NZ economic releases.

Version 0.3.1 supports:

- Consumers Price Index (`nz_stats_cpi`)
- Gross Domestic Product (`nz_stats_gdp`)
- Electronic Card Transactions (`nz_stats_electronic_cards`)
- Retail Trade Survey (`nz_stats_retail`)
- Balance of Payments and International Investment Position
  (`nz_stats_balance_payments`)
- Labour Market Statistics (`nz_stats_labour`), using a memory-aware curated
  set of quarterly HLFS, QES, and LCI headline series
- Overseas Merchandise Trade (`nz_stats_trade`), using historical headline
  and category tables from the official release workbook

## Usage

```r
library(statsnzreleases)

statsnz_releases()

cpi <- read_statsnz_release(
  "nz_stats_cpi",
  start_period = "2020.03"
)

head(cpi)
statsnz_provenance(cpi)
```

By default, the package queries the official Stats NZ release-calendar API to
find the latest published release. Pass a release URL for a reproducible
historical read:

```r
gdp <- read_statsnz_release(
  "nz_stats_gdp",
  release_url = paste0(
    "https://www.stats.govt.nz/information-releases/",
    "gross-domestic-product-march-2026-quarter/"
  )
)
```

Exact series references and period bounds can be applied while reading:

```r
headline_gdp <- read_statsnz_release(
  "nz_stats_gdp",
  series = "SNEA.SG00NAC00B15",
  start_period = "2020.03"
)
```

Downloaded files are cached under `statsnz_cache_dir()`. Provenance records the
release URL, every selected attachment URL, local cache path, byte size, and
SHA-256 hash.

## Data source

All network requests are restricted to official HTTPS URLs under
`stats.govt.nz`. Stats NZ owns and licenses the source data; users should check
the current Stats NZ terms before redistribution.


## Full histories

Version 0.3.0 adds Business Price Indexes, Building Consents Issued,
International Migration and Selected Price Indexes to the same release API.
Business prices and selected prices use the complete official CSV histories.
Building streams the reviewed national dwelling/house actual, adjusted and trend
series from its large official ZIP without extracting the archive.

```r
ppi <- read_statsnz_release("nz_stats_business_price_indexes")
migration <- read_statsnz_release("nz_stats_international_migration")
trade <- read_statsnz_release("nz_stats_trade", history = "full")
```

`history = "auto"` (the default) reads full histories for a latest-release query
and uses only release attachments for an explicit historical URL.
`history = "release"` always retains that exact release. Full migration and
qualified trade backfills use public Stats NZ Infoshare Export Direct requests,
with exact identifiers, all published periods, status flags and source hashes.
These live historical series are permitted only for the current release, because
Infoshare revisions cannot reconstruct an older vintage. An explicit older
`history = "full"` call fails with `statsnz_history_vintage_error` rather than
splicing current revisions into an old release.

Migration preserves the published Net series independently of displayed arrivals
and departures. Trade requests compatible time ranges in separate groups, so
series retain their actual starting periods and published missing observations.
Historical source magnitudes are converted explicitly to the release's units;
recent workbook observations retain their greater precision. Earlier quantities
and adjusted headlines retain Infoshare's integer serialization. All used source
hashes remain available through `statsnz_provenance()`.

The readers are bounded: at most 100 exact Infoshare identifiers and 5,000
server-listed periods per request, 25-second HTTP operations, 10 MiB CSV
responses, 64 MiB bulk ZIP inputs, 256 MiB reviewed ZIP members and 100,000
retained bulk observations. No credentials or additional dependencies are needed.
