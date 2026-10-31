test_that("calendar parser identifies the matching published release", {
  payload <- list(items = list(published = list(
    list(
      Title = "Consumers price index: March 2026 quarter",
      PageLink = "/information-releases/consumers-price-index-march-2026-quarter/",
      DateTaxonomyTerm = list(PublicationDate = "2026-04-22 10:45:00")
    ),
    list(
      Title = "Electronic card transactions: March 2026",
      PageLink = "/information-releases/electronic-card-transactions-march-2026/",
      DateTaxonomyTerm = list(PublicationDate = "2026-04-15 10:45:00")
    )
  )))
  raw <- charToRaw(jsonlite::toJSON(payload, auto_unbox = TRUE))
  release <- statsnzreleases:::snz_release_definition("nz_stats_cpi")

  result <- statsnzreleases:::snz_parse_calendar_month(
    raw,
    release = release,
    as_of = as.Date("2026-04-30"),
    month = "2026-04"
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$release_id, "nz_stats_cpi")
  expect_equal(result$publication_date, as.Date("2026-04-22"))
  expect_match(result$url, "consumers-price-index-march-2026-quarter")
})

test_that("calendar parser respects the as-of date", {
  payload <- list(items = list(published = list(list(
    Title = "Gross domestic product: March 2026 quarter",
    PageLink = "/information-releases/gross-domestic-product-march-2026-quarter/",
    DateTaxonomyTerm = list(PublicationDate = "2026-06-18 10:45:00")
  ))))
  release <- statsnzreleases:::snz_release_definition("nz_stats_gdp")
  result <- statsnzreleases:::snz_parse_calendar_month(
    charToRaw(jsonlite::toJSON(payload, auto_unbox = TRUE)),
    release,
    as_of = as.Date("2026-06-17"),
    month = "2026-06"
  )

  expect_equal(nrow(result), 0L)
})

test_that("calendar month sequence is bounded and deterministic", {
  expect_equal(
    statsnzreleases:::snz_calendar_months(as.Date("2026-01-31"), 3L),
    c("2026-01", "2025-12", "2025-11")
  )
  expect_error(
    statsnzreleases:::snz_calendar_months(Sys.Date(), 0L),
    class = "statsnz_invalid_argument"
  )
})

test_that("quarterly BOP discovery cannot select a newer annual workbook", {
  entries <- list(
    list(Title = "Balance of payments and international investment position: Year ended 31 March 2026",
         PageLink = "/information-releases/bop-year-ended-31-march-2026/",
         DateTaxonomyTerm = list(PublicationDate = "2026-09-30 10:45:00")),
    list(Title = "Balance of payments and international investment position: June 2026 quarter",
         PageLink = "/information-releases/balance-of-payments-and-international-investment-position-june-2026-quarter/",
         DateTaxonomyTerm = list(PublicationDate = "2026-09-16 10:45:00")))
  raw <- charToRaw(jsonlite::toJSON(list(items=list(published=entries)),auto_unbox=TRUE))
  result <- statsnzreleases:::snz_latest_release(
    statsnzreleases:::snz_release_definition("nz_stats_balance_payments"),
    as.Date("2026-10-25"), 2L, fetch_fun=function(url)raw)
  expect_equal(nrow(result),1L)
  expect_match(result$url,"june-2026-quarter/")
  expect_identical(result$publication_date,as.Date("2026-09-16"))
})
