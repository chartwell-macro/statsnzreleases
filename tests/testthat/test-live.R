live_enabled <- identical(
  tolower(Sys.getenv("STATSNZRELEASES_LIVE", unset = "false")),
  "true"
)

live_releases <- data.frame(
  release_id = c(
    "nz_stats_cpi",
    "nz_stats_gdp",
    "nz_stats_electronic_cards",
    "nz_stats_retail",
    "nz_stats_balance_payments",
    "nz_stats_labour",
    "nz_stats_trade"
  ),
  release_url = c(
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "consumers-price-index-june-2026-quarter/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "gross-domestic-product-march-2026-quarter/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "electronic-card-transactions-june-2026/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "retail-trade-survey-march-2026-quarter/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "balance-of-payments-and-international-investment-position-march-2026-quarter/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "labour-market-statistics-march-2026-quarter/"
    ),
    paste0(
      "https://www.stats.govt.nz/information-releases/",
      "overseas-merchandise-trade-june-2026/"
    )
  ),
  minimum_rows = c(
    45000L, 90000L, 20000L, 25000L, 200000L, 25000L, 1500L
  ),
  attachment_count = c(4L, 1L, 1L, 1L, 1L, 1L, 1L),
  stringsAsFactors = FALSE
)

test_that("live calendar discovery resolves every supported release", {
  skip_if_not(live_enabled, "Live Stats NZ tests are opt-in.")

  for (release_id in live_releases$release_id) {
    latest <- statsnz_latest_release(
      release_id,
      as_of = as.Date("2026-07-27")
    )
    expect_equal(nrow(latest), 1L, info = release_id)
    expect_match(
      latest$url,
      "^https://www.stats.govt.nz/information-releases/",
      info = release_id
    )
  }
})

test_that("live current release files parse for every supported family", {
  skip_if_not(live_enabled, "Live Stats NZ tests are opt-in.")
  cache_dir <- Sys.getenv(
    "STATSNZRELEASES_LIVE_CACHE",
    unset = file.path(tempdir(), "statsnzreleases-live-cache")
  )

  for (index in seq_len(nrow(live_releases))) {
    specification <- live_releases[index, ]
    data <- read_statsnz_release(
      specification$release_id,
      release_url = specification$release_url,
      cache_dir = cache_dir,
      quiet = TRUE
    )
    provenance <- statsnz_provenance(data)

    expect_s3_class(
      data,
      "statsnz_release_data"
    )
    expect_gte(
      nrow(data),
      specification$minimum_rows
    )
    expect_gt(
      length(unique(data$series_reference)),
      20L
    )
    expect_true(
      any(!is.na(data$data_value))
    )
    expect_equal(
      nrow(provenance$attachments),
      specification$attachment_count
    )
    expect_true(
      all(file.exists(provenance$attachments$cache_path))
    )
  }
})
