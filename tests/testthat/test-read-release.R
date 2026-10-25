test_that("public reader composes selection, parsing, filtering, and provenance", {
  directory <- withr::local_tempdir()
  path <- fixture_csv(directory, "gross-domestic-product-test-quarter.csv")
  release_url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "gross-domestic-product-test-quarter/"
  )
  attachment_url <- paste0(
    "https://www.stats.govt.nz/assets/",
    "gross-domestic-product-test-quarter.csv"
  )
  files <- tibble::tibble(
    name = "gross-domestic-product-test-quarter.csv",
    title = "GDP CSV",
    extension = "csv",
    stated_size = "1 KB",
    url = attachment_url,
    release_title = "Gross domestic product: test quarter",
    release_url = release_url
  )
  testthat::local_mocked_bindings(
    statsnz_release_files = function(release_url) files,
    snz_download = function(...) path,
    .package = "statsnzreleases"
  )

  result <- read_statsnz_release(
    "nz_stats_gdp",
    release_url = release_url,
    series = "TEST.S1",
    start_period = "2025.06",
    cache_dir = directory,
    quiet = TRUE
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$series_reference, "TEST.S1")
  expect_equal(result$period, "2025.06")
  expect_equal(statsnz_provenance(result)$attachments$sha256[[1L]], {
    digest::digest(path, algo = "sha256", file = TRUE)
  })
})

test_that("public reader rejects a mismatched release page", {
  release_url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "electronic-card-transactions-test/"
  )
  files <- tibble::tibble(
    name = "electronic-card-transactions-test.zip",
    title = "ECT CSV",
    extension = "zip",
    stated_size = "1 KB",
    url = "https://www.stats.govt.nz/assets/electronic-card-transactions-test.zip",
    release_title = "Electronic card transactions: test",
    release_url = release_url
  )
  testthat::local_mocked_bindings(
    statsnz_release_files = function(release_url) files,
    .package = "statsnzreleases"
  )

  expect_error(
    read_statsnz_release("nz_stats_gdp", release_url = release_url),
    class = "statsnz_release_mismatch"
  )
})
