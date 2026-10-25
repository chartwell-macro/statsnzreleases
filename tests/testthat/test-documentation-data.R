test_that("installed CPI chart snapshot matches its documented extract", {
  fixture <- system.file(
    "extdata",
    "cpi-tradables-non-tradables-june-2026.csv",
    package = "statsnzreleases"
  )
  expect_true(nzchar(fixture))
  expect_true(file.exists(fixture))
  expect_equal(
    digest::digest(fixture, algo = "sha256", file = TRUE),
    "455c6c4bbad4345bae69da6d91db3a0455e54a025c77ce4bc844e35593e00c0e"
  )

  snapshot <- readr::read_csv(
    fixture,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    show_col_types = FALSE,
    progress = FALSE
  )
  expect_equal(nrow(snapshot), 84L)
  expect_equal(
    sort(unique(snapshot$Series_reference)),
    c("CPIQ.SE9NS6000", "CPIQ.SE9NS6500")
  )
  expect_equal(range(snapshot$Period), c("2016.03", "2026.06"))
  expect_equal(unique(snapshot$UNITS), "Index")
})

test_that("documentation snapshot exercises the public CPI reader", {
  fixture <- system.file(
    "extdata",
    "cpi-tradables-non-tradables-june-2026.csv",
    package = "statsnzreleases"
  )
  release_url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "consumers-price-index-june-2026-quarter/"
  )
  attachment_name <- paste0(
    "consumers-price-index-june-2026-quarter-",
    "tradeables-and-non-tradeables.csv"
  )
  files <- tibble::tibble(
    name = attachment_name,
    title = "Consumers price index: June 2026 quarter – tradeables and non-tradeables – CSV",
    extension = "csv",
    stated_size = "2.4 MB",
    url = paste0(
      "https://www.stats.govt.nz/assets/Uploads/Consumers-price-index/",
      "Consumers-price-index-June-2026-quarter/Download-data/",
      attachment_name
    ),
    release_title = "Consumers price index: June 2026 quarter",
    release_url = release_url
  )
  testthat::local_mocked_bindings(
    statsnz_release_files = function(release_url) files,
    snz_download = function(...) fixture,
    .package = "statsnzreleases"
  )

  result <- read_statsnz_release(
    "nz_stats_cpi",
    release_url = release_url,
    series = c("CPIQ.SE9NS6000", "CPIQ.SE9NS6500"),
    start_period = "2016.03",
    end_period = "2026.06",
    cache_dir = withr::local_tempdir(),
    quiet = TRUE
  )

  expect_s3_class(result, "statsnz_release_data")
  expect_equal(nrow(result), 84L)
  expect_equal(range(result$period_date), as.Date(c("2016-03-01", "2026-06-01")))
  expect_equal(
    sort(unique(result$series_label)),
    c("Non-Tradable All Groups", "Tradable All Groups")
  )
  expect_equal(unique(result$units), "Index")
  expect_equal(
    statsnz_provenance(result)$attachments$sha256[[1L]],
    "455c6c4bbad4345bae69da6d91db3a0455e54a025c77ce4bc844e35593e00c0e"
  )
})
