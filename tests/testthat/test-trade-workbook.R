package_trade_fixture_grid <- function(
    sheet_name,
    columns,
    start_row = 9L,
    reference_row = 6L,
    title_row = 4L,
    units_row = 7L,
    prefix = "EXPM.",
    parent_title_row = NULL) {
  sheet <- as.data.frame(
    matrix("", nrow = start_row + 1L, ncol = max(columns)),
    stringsAsFactors = FALSE
  )
  sheet[[1L]][[1L]] <- sheet_name
  sheet[[1L]][[reference_row]] <- paste("Infoshare series", prefix)
  for (column in columns) {
    sheet[[column]][[reference_row]] <- sprintf("S%02d", column)
    sheet[[column]][[title_row]] <- paste("Series", column)
    sheet[[column]][[units_row]] <- "$(million)"
    sheet[[column]][start_row:(start_row + 1L)] <- c("100", "101")
  }
  if (!is.null(parent_title_row)) {
    sheet[[columns[[1L]]]][[parent_title_row]] <- "Parent group"
  }
  sheet[[1L]][start_row:(start_row + 1L)] <- c("2025", "")
  sheet[[2L]][start_row:(start_row + 1L)] <- c("Jun", "Jul")
  sheet
}

package_trade_fixture_sheets <- function(include_quarterly = FALSE) {
  actual <- package_trade_fixture_grid(
    "Table 1.02",
    4:6,
    start_row = 8L
  )
  monthly <- package_trade_fixture_grid(
    "Table 2",
    c(4L, 6L, 8L, 9L, 11L, 13L),
    start_row = 9L
  )
  monthly[[4L]][[6L]] <- "OTTM.SSEF"
  monthly[[6L]][[6L]] <- "OTTM.SSIC"
  monthly[[9L]][[6L]] <- "OTTM.STEF"
  monthly[[11L]][[6L]] <- "OTTM.STIC"
  result <- list(
    "Table 1.02" = actual,
    "Table 2" = monthly,
    "Table 11" = package_trade_fixture_grid("Table 11", 3:13),
    "Table 12" = package_trade_fixture_grid("Table 12", 3:13),
    "Table 13" = package_trade_fixture_grid(
      "Table 13",
      3:10,
      prefix = "IMPM."
    ),
    "Table 14" = package_trade_fixture_grid("Table 14", 3:13),
    "Table 15" = package_trade_fixture_grid("Table 15", 3:13),
    "Table 16" = package_trade_fixture_grid(
      "Table 16",
      3:10,
      prefix = "IMPM."
    )
  )
  if (!isTRUE(include_quarterly)) {
    return(result)
  }
  quarter <- package_trade_fixture_grid(
    "Table 17",
    c(3L, 5L, 7L, 8L, 10L, 12L),
    start_row = 9L,
    prefix = "EXPQ."
  )
  quarter[[3L]][[6L]] <- "EXPQ.SH99FS"
  quarter[[5L]][[6L]] <- "IMPQ.SOX1SCS"
  quarter[[8L]][[6L]] <- "EXPQ.SH99FT"
  quarter[[10L]][[6L]] <- "IMPQ.SOX1SCT"
  result[c("Table 17", "Table 18", "Table 19", "Table 20")] <- list(
    quarter,
    package_trade_fixture_grid(
      "Table 18",
      3:13,
      prefix = "EXPQ."
    ),
    package_trade_fixture_grid(
      "Table 19",
      3:13,
      prefix = "EXPQ."
    ),
    package_trade_fixture_grid(
      "Table 20",
      3:10,
      start_row = 10L,
      reference_row = 7L,
      title_row = 5L,
      units_row = 8L,
      prefix = "BECQ.",
      parent_title_row = 4L
    )
  )
  result
}

test_that("trade preserves monthly-only workbooks and complete quarterly blocks", {
  sheets<-package_trade_fixture_sheets(FALSE)
  testthat::local_mocked_bindings(read_excel=function(path,sheet,...)sheets[[sheet]],
    excel_sheets=function(path)names(sheets),.package="readxl")
  monthly<-statsnzreleases:::snz_read_trade_workbook("fixture.xlsx","official.xlsx","https://www.stats.govt.nz/official.xlsx")
  expect_true(all(monthly$frequency=="monthly"))
  expect_true(all(c("EXPM.SCT99F","IMPM.SCT99C","OTTM.SSEF","OTTM.SSIC")%in%monthly$series_reference))
  sheets<-package_trade_fixture_sheets(TRUE)
  combined<-statsnzreleases:::snz_read_trade_workbook("fixture.xlsx","official.xlsx","https://www.stats.govt.nz/official.xlsx")
  expect_setequal(unique(combined$frequency),c("monthly","quarterly"))
  expect_true(any(grepl("Q[.]",combined$series_reference)))
  sheets[["Table 20"]]<-NULL
  expect_error(statsnzreleases:::snz_read_trade_workbook("fixture.xlsx","official.xlsx","https://www.stats.govt.nz/official.xlsx"),"incomplete quarterly block")
})
