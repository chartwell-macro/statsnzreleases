test_that("release page parser extracts structured attachments", {
  raw <- fixture_release_page(
    "Gross domestic product: March 2026 quarter",
    list(
      fixture_document("gross-domestic-product-march-2026-quarter.csv"),
      fixture_document("gross-domestic-product-march-2026-quarter-visualisation.csv"),
      fixture_document("gross-domestic-product-march-2026-quarter.xlsx")
    )
  )
  url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "gross-domestic-product-march-2026-quarter/"
  )

  files <- statsnzreleases:::snz_parse_release_page(raw, url)

  expect_equal(nrow(files), 3L)
  expect_equal(unique(files$release_title), "Gross domestic product: March 2026 quarter")
  expect_true(all(grepl("^https://www.stats.govt.nz/", files$url)))
})

test_that("GDP selection excludes the visualisation extract", {
  raw <- fixture_release_page(
    "Gross domestic product: March 2026 quarter",
    list(
      fixture_document("gross-domestic-product-march-2026-quarter.csv"),
      fixture_document("gross-domestic-product-march-2026-quarter-visualisation.csv")
    )
  )
  url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "gross-domestic-product-march-2026-quarter/"
  )
  files <- statsnzreleases:::snz_parse_release_page(raw, url)
  release <- statsnzreleases:::snz_release_definition("nz_stats_gdp")

  selected <- statsnzreleases:::snz_select_attachments(files, release)

  expect_equal(nrow(selected), 1L)
  expect_false(grepl("visualisation", selected$name))
})

test_that("CPI files use deterministic de-duplication precedence", {
  names <- c(
    "consumers-price-index-june-2026-quarter-infoshare-data.csv",
    "consumers-price-index-june-2026-quarter-index-numbers.csv",
    "consumers-price-index-june-2026-quarter-tradeables-and-non-tradeables.csv",
    "consumers-price-index-june-2026-quarter-seasonally-adjusted.csv"
  )
  raw <- fixture_release_page(
    "Consumers price index: June 2026 quarter",
    lapply(names, fixture_document)
  )
  url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "consumers-price-index-june-2026-quarter/"
  )
  files <- statsnzreleases:::snz_parse_release_page(raw, url)
  release <- statsnzreleases:::snz_release_definition("nz_stats_cpi")

  selected <- statsnzreleases:::snz_select_attachments(files, release)

  expect_match(selected$name[[1L]], "seasonally-adjusted")
  expect_match(selected$name[[2L]], "index-numbers")
  expect_match(selected$name[[3L]], "tradeables-and-non-tradeables")
  expect_match(selected$name[[4L]], "infoshare-data")
})

test_that("non-official release URLs are rejected", {
  expect_error(
    statsnz_release_files("https://example.com/information-releases/test/"),
    class = "statsnz_invalid_url"
  )
})
