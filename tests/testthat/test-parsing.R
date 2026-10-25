test_that("CSV variants are normalised without discarding raw values", {
  directory <- withr::local_tempdir()
  path <- fixture_csv(directory)
  frame <- statsnzreleases:::snz_read_csv(
    path,
    "sample.csv",
    "https://www.stats.govt.nz/assets/sample.csv"
  )
  release <- statsnzreleases:::snz_release_definition("nz_stats_gdp")

  result <- statsnzreleases:::snz_standardise(
    list(frame),
    release,
    "https://www.stats.govt.nz/information-releases/gross-domestic-product-test/",
    "Gross domestic product: test",
    data.frame(name = "sample.csv", stringsAsFactors = FALSE),
    as.POSIXct("2026-01-01", tz = "UTC")
  )

  expect_s3_class(result, "statsnz_release_data")
  expect_equal(result$data_value, c(10.5, 11, 1200))
  expect_equal(result$data_value_raw[[3L]], "1,200")
  expect_equal(result$magnitude, c(0, 0, 6))
  expect_equal(result$period_date[[1L]], as.Date("2025-03-01"))
  expect_equal(result$series_label[[1L]], "Series one")
})

test_that("series labels are reused without changing row-level metadata", {
  frame <- data.frame(
    series_reference = c("TEST.S1", "TEST.S1", "TEST.S2", "TEST.S3"),
    period = rep("2025.03", 4L),
    data_value = rep("1", 4L),
    description = c(NA, NA, "Published label", NA),
    series_title_1 = c("Group", "Group", "Ignored", NA),
    series_title_2 = c("Item", "Item", NA, NA),
    stringsAsFactors = FALSE
  )
  title_columns <- paste0("series_title_", 1:5)
  for (name in setdiff(title_columns, names(frame))) {
    frame[[name]] <- NA_character_
  }
  labels <- statsnzreleases:::snz_series_labels(frame, title_columns)

  expect_equal(
    labels,
    c("Group \u2014 Item", "Group \u2014 Item", "Published label", "TEST.S3")
  )
})

test_that("Windows-1252 release labels are converted to valid UTF-8", {
  directory <- withr::local_tempdir()
  path <- file.path(directory, "windows.csv")
  text <- paste(
    "Series_reference,Period,Data_value,Description",
    "TEST.S1,2025.03,10,Men\u2019s clothing",
    sep = "\n"
  )
  writeLines(
    iconv(text, from = "UTF-8", to = "windows-1252"),
    path,
    useBytes = TRUE
  )

  frame <- statsnzreleases:::snz_read_csv(
    path,
    "windows.csv",
    "https://www.stats.govt.nz/assets/windows.csv"
  )

  expect_true(validUTF8(frame$description))
  expect_equal(frame$description, "Men\u2019s clothing")
})

test_that("duplicate series-period rows keep the first attachment", {
  frame_one <- data.frame(
    series_reference = "TEST.S1",
    period = "2025.03",
    data_value = "10",
    source_file = "preferred.csv",
    source_attachment_url = "https://www.stats.govt.nz/assets/preferred.csv"
  )
  frame_two <- frame_one
  frame_two$data_value <- "99"
  frame_two$source_file <- "fallback.csv"
  release <- statsnzreleases:::snz_release_definition("nz_stats_cpi")

  result <- statsnzreleases:::snz_standardise(
    list(frame_one, frame_two),
    release,
    "https://www.stats.govt.nz/information-releases/consumers-price-index-test/",
    "Consumers price index: test",
    data.frame(name = c("preferred.csv", "fallback.csv")),
    Sys.time()
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$data_value, 10)
  expect_equal(result$source_file, "preferred.csv")
})

test_that("series and period filters preserve provenance", {
  frame <- data.frame(
    series_reference = c("TEST.S1", "TEST.S1", "TEST.S2"),
    period = c("2024.12", "2025.03", "2025.03"),
    data_value = c("9", "10", "20"),
    source_file = "sample.csv",
    source_attachment_url = "https://www.stats.govt.nz/assets/sample.csv"
  )
  release <- statsnzreleases:::snz_release_definition("nz_stats_gdp")
  data <- statsnzreleases:::snz_standardise(
    list(frame),
    release,
    "https://www.stats.govt.nz/information-releases/gross-domestic-product-test/",
    "Gross domestic product: test",
    data.frame(name = "sample.csv"),
    Sys.time()
  )

  result <- statsnzreleases:::snz_filter_observations(
    data,
    series = "TEST.S1",
    start_period = "2025.03",
    end_period = NULL
  )

  expect_equal(nrow(result), 1L)
  expect_equal(result$data_value, 10)
  expect_s3_class(result, "statsnz_release_data")
  expect_equal(statsnz_provenance(result)$release_id, "nz_stats_gdp")
})

test_that("ZIP reader loads safe CSV members", {
  directory <- withr::local_tempdir()
  csv <- fixture_csv(directory, "inside.csv")
  archive <- file.path(directory, "release.zip")
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  utils::zip(archive, basename(csv), flags = "-q")

  frames <- statsnzreleases:::snz_read_attachment(
    archive,
    "release.zip",
    "https://www.stats.govt.nz/assets/release.zip"
  )

  expect_length(frames, 1L)
  expect_equal(nrow(frames[[1L]]), 3L)
  expect_equal(unique(frames[[1L]]$source_file), "inside.csv")
})

test_that("labour ZIP reader streams only curated quarterly headline series", {
  directory <- withr::local_tempdir()
  csv <- file.path(directory, "lms-test-tables.csv")
  utils::write.csv(
    data.frame(
      Series_reference = c(
        "HLFQ.S1A3S",
        "QEMQ.SHAZS",
        "LCIQ.SD53Z9",
        "HLFQ.DETAIL"
      ),
      Period = rep("2026.03", 4L),
      Data_value = c("100", "200", "300", "400"),
      Subject = c(
        "Household Labour Force Survey - HLF",
        "Quarterly Employment Survey - QEM",
        "Labour Cost Index - LCI",
        "Household Labour Force Survey - HLF"
      ),
      Group = c(
        "Labour Force Status by Sex: Seasonally Adjusted",
        "Total Gross Earnings Seasonally Adjusted and Trend Series",
        "All Sectors Combined, All Salary and Wage Rates (Base: June 2017 qtr (=1000))",
        "Labour Force Status by Ethnic Group by Regional Council"
      ),
      Series_title_1 = c(
        "Persons Employed in Labour Force",
        "Total Gross Earnings",
        "All Sectors Combined",
        "Persons Employed in Labour Force"
      ),
      Series_title_2 = c(
        "Total Both Sexes",
        "Seasonally Adjusted",
        "All Salary and Wage Rates",
        "Total Both Sexes"
      ),
      Series_title_3 = c("", "", "All Industries/Occupations Combined", ""),
      check.names = FALSE
    ),
    csv,
    row.names = FALSE,
    na = ""
  )
  archive <- file.path(directory, "labour.zip")
  old <- setwd(directory)
  on.exit(setwd(old), add = TRUE)
  utils::zip(archive, basename(csv), flags = "-q")

  frames <- statsnzreleases:::snz_read_attachment(
    archive,
    "labour-market-statistics-test-quarter.zip",
    "https://www.stats.govt.nz/assets/labour.zip",
    release_id = "nz_stats_labour"
  )

  expect_length(frames, 1L)
  expect_setequal(
    frames[[1L]]$series_reference,
    c("HLFQ.S1A3S", "QEMQ.SHAZS", "LCIQ.SD53Z9")
  )
})

test_that("trade grid parser builds periods and stops before change tables", {
  sheet <- as.data.frame(
    matrix(NA_character_, nrow = 12L, ncol = 4L),
    stringsAsFactors = FALSE
  )
  sheet[[1L]][[6L]] <- "Infoshare series TESTQ."
  sheet[[3L]][[4L]] <- "Food"
  sheet[[4L]][[4L]] <- "Machinery"
  sheet[[3L]][[6L]] <- "S1"
  sheet[[4L]][[6L]] <- "S2"
  sheet[[3L]][[7L]] <- "Dollars (millions)"
  sheet[[4L]][[7L]] <- "Dollars (millions)"
  sheet[[1L]][[9L]] <- "2025"
  sheet[[2L]][[9L]] <- "Mar"
  sheet[[3L]][[9L]] <- "10"
  sheet[[4L]][[9L]] <- "20"
  sheet[[2L]][[10L]] <- "Jun"
  sheet[[3L]][[10L]] <- "11"
  sheet[[4L]][[10L]] <- "21"
  sheet[[1L]][[11L]] <- "Percentage change from previous period"
  sheet[[1L]][[12L]] <- "2025"
  sheet[[2L]][[12L]] <- "Sep"
  sheet[[3L]][[12L]] <- "1"
  sheet[[4L]][[12L]] <- "2"

  result <- statsnzreleases:::snz_trade_grid_sheet(
    sheet = sheet,
    columns = 3:4,
    start_row = 9L,
    reference_row = 6L,
    title_row = 4L,
    units_row = 7L,
    flow = "Exports",
    adjustment = "Seasonally adjusted",
    measure = "Value",
    frequency = "Quarterly",
    source_name = "trade.xlsx",
    source_url = "https://www.stats.govt.nz/assets/trade.xlsx",
    prefix_cell = c(6L, 1L)
  )

  expect_equal(nrow(result), 4L)
  expect_setequal(result$series_reference, c("TESTQ.S1", "TESTQ.S2"))
  expect_setequal(result$period, c("2025.03", "2025.06"))
  expect_false("2025.09" %in% result$period)
})

test_that("trade grid parser inherits the sheet frequency prefix", {
  sheet <- as.data.frame(
    matrix(NA_character_, nrow = 10L, ncol = 3L),
    stringsAsFactors = FALSE
  )
  sheet[[1L]][[6L]] <- "Infoshare series EXPQ."
  sheet[[3L]][[4L]] <- "Milk powder"
  sheet[[3L]][[6L]] <- "SH04FS"
  sheet[[3L]][[7L]] <- "Dollars (millions)"
  sheet[[1L]][[9L]] <- "2026"
  sheet[[2L]][[9L]] <- "Jun"
  sheet[[3L]][[9L]] <- "100"

  result <- statsnzreleases:::snz_trade_grid_sheet(
    sheet = sheet,
    columns = 3L,
    start_row = 9L,
    reference_row = 6L,
    title_row = 4L,
    units_row = 7L,
    flow = "Exports",
    adjustment = "Seasonally adjusted",
    measure = "Value",
    frequency = "Quarterly",
    source_name = "trade.xlsx",
    source_url = "https://www.stats.govt.nz/assets/trade.xlsx",
    prefix_cell = c(6L, 1L)
  )

  expect_equal(result$series_reference, "EXPQ.SH04FS")
})
