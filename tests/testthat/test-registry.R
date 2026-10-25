test_that("registry contains all seven supported releases", {
  registry <- statsnz_releases()

  expect_equal(nrow(registry), 7L)
  expect_equal(sum(registry$supported), 7L)
  expect_setequal(
    registry$release_id[registry$supported],
    c(
      "nz_stats_cpi",
      "nz_stats_gdp",
      "nz_stats_electronic_cards",
      "nz_stats_retail",
      "nz_stats_balance_payments",
      "nz_stats_labour",
      "nz_stats_trade"
    )
  )
})

test_that("unknown releases fail clearly", {
  expect_error(
    statsnzreleases:::snz_release_definition("nz_stats_not_real"),
    class = "statsnz_unknown_release"
  )
})
