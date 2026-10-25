# statsnzreleases

`statsnzreleases` discovers, downloads, caches, and standardises official data
files attached to major Stats NZ economic releases.

Version 0.2.0 supports:

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
