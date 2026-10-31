test_that("registry contains all eleven supported releases", {
  registry <- statsnz_releases()

  expect_equal(nrow(registry), 11L)
  expect_equal(sum(registry$supported), 11L)
  expect_setequal(
    registry$release_id[registry$supported],
    c(
      "nz_stats_cpi",
      "nz_stats_gdp",
      "nz_stats_electronic_cards",
      "nz_stats_retail",
      "nz_stats_balance_payments",
      "nz_stats_labour",
      "nz_stats_trade",
      "nz_stats_building_consents", "nz_stats_international_migration",
      "nz_stats_business_price_indexes", "nz_stats_selected_price_indexes"
    )
  )
})

test_that("unknown releases fail clearly", {
  expect_error(
    statsnzreleases:::snz_release_definition("nz_stats_not_real"),
    class = "statsnz_unknown_release"
  )
})
