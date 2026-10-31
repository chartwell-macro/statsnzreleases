test_that("full business-price CSV keeps original periods, units, NA and status", {
  input <- data.frame(Series_reference=rep("PPIQ.SQN900000",3),
    Period=c("1977.12","2026.03","2026.06"),Data_value=c("165.782493","..","1234.5"),
    STATUS=c("FINAL","FINAL","PROVISIONAL"),UNITS="Index",Subject="PPI",
    Group="Inputs, December 2010 quarter (=1000)",Series_title_1="All industries")
  got<-statsnzreleases:::snz_parse_bulk_csv(input,"nz_stats_business_price_indexes")
  expect_identical(got$period_date,as.Date(c("1977-12-01","2026-03-01","2026-06-01")))
  expect_equal(got$data_value,c(165.782493,NA,1234.5))
  expect_identical(got$status,input$STATUS)
  bad<-input;bad$Period[[1]]<-"1977.11"
  expect_error(statsnzreleases:::snz_parse_bulk_csv(bad,"nz_stats_business_price_indexes"),class="statsnz_history_schema_error")
  bad<-rbind(input,input[1,])
  expect_error(statsnzreleases:::snz_parse_bulk_csv(bad,"nz_stats_business_price_indexes"),"duplicate observations")
  bad$Data_value[[4]]<-"999"
  expect_error(statsnzreleases:::snz_parse_bulk_csv(bad,"nz_stats_business_price_indexes"),"duplicate observations")
})

infoshare_export_fixture <- function() {
  list(text=paste(c(
    "Series is ITMM.SEMAAE","International Travel and Migration - ITM",
    "Estimated migration by direction, 12/16-month rule (Monthly)","Arrivals","Estimate",
    "Units = Number;,Magnitude = Units;,Frequency = Monthly;","",
    "Series is ITMM.SEMANE","International Travel and Migration - ITM",
    "Estimated migration by direction, 12/16-month rule (Monthly)","Net","Estimate",
    "Units = Number;,Magnitude = Units;,Frequency = Monthly;","",
    ",ITMM.SEMAAE,,ITMM.SEMANE,,","Jan-2001,10541,,729,,",
    "Jul-2025,11669,P,2225,P,","Aug-2025,..,N,1618,E,","","Source: Statistics New Zealand"
  ),collapse="\n"),sha256=paste(rep("a",64),collapse=""),bytes=1000,
  url="https://infoshare.stats.govt.nz/infoshare/exportdirect.aspx")
}

test_that("Infoshare retains native net and missing values with all single-letter statuses", {
  export<-infoshare_export_fixture()
  got<-statsnzreleases:::snz_infoshare_parse(export,c("ITMM.SEMAAE","ITMM.SEMANE"),"nz_stats_international_migration")
  net<-got[got$series_reference=="ITMM.SEMANE",]
  expect_equal(net$data_value,c(729,2225,1618))
  expect_identical(net$status,c("","P","E"))
  expect_true(is.na(got$data_value[[3]]))
  expect_identical(got$status[[3]],"N")
  expect_identical(statsnz_provenance(got)$attachments$sha256,export$sha256)
  expect_error(statsnzreleases:::snz_infoshare_parse(export,c("ITM.SEMAAE","ITM.SEMANE"),"nz_stats_international_migration"),"conflicting series identity")
  bad<-export;bad$text<-paste0(bad$text,"\nUnexpected trailer")
  expect_error(statsnzreleases:::snz_infoshare_parse(bad,c("ITMM.SEMAAE","ITMM.SEMANE"),"nz_stats_international_migration"),"unsupported data block or footer")
  expect_error(statsnzreleases:::snz_infoshare_fetch("ITMM.*"),class="statsnz_history_schema_error")
})

test_that("trade backfill preserves current precision, statuses, and source scales", {
  make<-statsnzreleases:::snz_history_observations
  current<-make("nz_stats_trade","EXPM.SH4AFS","Dairy exports",as.Date(c("2026-01-01","2026-02-01")),c(1000.25,1001.75),"$(million)","Exports","Seasonally adjusted",6)
  current$source_file<-"official.xlsx";current$source_attachment_url<-"https://www.stats.govt.nz/current.xlsx"
  full<-make("nz_stats_trade","EXPM.SH4AFS","Dairy exports",as.Date(c("1988-01-01","2026-01-01","2026-02-01")),c(112203016,1000250000,1001750000),"$","Exports","Seasonally adjusted",0)
  full$status<-c("R","R","P");full$source_file<-"full.csv";full$source_attachment_url<-"https://infoshare.stats.govt.nz/"
  got<-statsnzreleases:::snz_trade_backfill(current,full)
  expect_identical(got$period_date,as.Date(c("1988-01-01","2026-01-01","2026-02-01")))
  expect_equal(got$data_value,c(112.203016,1000.25,1001.75))
  expect_identical(got$status,c("R","R","P"))
  expect_identical(got$source_file,c("full.csv","official.xlsx","official.xlsx"))
  full$data_value[[2]]<-900000000
  expect_error(statsnzreleases:::snz_trade_backfill(current,full),"conflicts")
})


test_that("older explicit Infoshare vintages fail before acquisition", {
  testthat::local_mocked_bindings(
    snz_latest_release=function(...)data.frame(url="https://www.stats.govt.nz/information-releases/overseas-merchandise-trade-september-2026/"),
    statsnz_release_files=function(...)stop("must not fetch the old release"),
    .package="statsnzreleases")
  expect_error(read_statsnz_release("nz_stats_trade",
    release_url="https://www.stats.govt.nz/information-releases/overseas-merchandise-trade-june-2026/",history="full"),
    class="statsnz_history_vintage_error")
})

test_that("full-history values preserve published missing tokens and reject corruption", {
  parse <- statsnzreleases:::snz_history_numeric
  expect_equal(parse(c("1,234.5", "-2", "..", "", NA_character_)), c(1234.5, -2, NA, NA, NA))
  for (token in c("not-a-number", "Inf", "-Inf", "NaN", "1,2", "1e999")) {
    expect_error(parse(token), class = "statsnz_history_schema_error")
  }
  got <- statsnzreleases:::snz_history_observations("nz_stats_international_migration",
    "ITMM.SEMANE", "Net", as.Date(c("2001-01-01", "2001-02-01")),
    c("..", "1,234"), "Number", "Migration", "Estimate")
  expect_identical(got$data_value_raw, c("..", "1,234"))
  expect_equal(got$data_value, c(NA, 1234))
})

migration_history_fixture <- function() {
  refs <- c("ITMM.SEMAAE", "ITMM.SEMADE", "ITMM.SEMANE")
  full <- statsnzreleases:::snz_history_observations("nz_stats_international_migration",
    rep(refs, each = 3), "Migration", rep(as.Date(c("2001-01-01", "2001-02-01", "2001-03-01")), 3),
    rep(c("100", "101", "102"), 3), "Number", "Migration", "Estimate")
  full$source_file <- "Infoshare.csv"; full$source_attachment_url <- "https://infoshare.stats.govt.nz/"
  provenance <- list(attachments = tibble::tibble(name = "Infoshare.csv", url = "https://infoshare.stats.govt.nz/", bytes = 100, sha256 = paste(rep("a", 64), collapse = "")))
  attr(full, "statsnz_provenance") <- provenance
  current <- full[full$period_date >= as.Date("2001-02-01"), ]
  current$status <- rep(c("F", "P"), 3)
  current$source_file <- "current.xlsx"; current$source_attachment_url <- "https://www.stats.govt.nz/current.xlsx"
  attr(current, "statsnz_provenance") <- list(attachments = tibble::tibble(name = "current.xlsx", url = "https://www.stats.govt.nz/current.xlsx", bytes = 200, sha256 = paste(rep("b", 64), collapse = "")))
  class(current) <- c("statsnz_release_data", class(current))
  list(full = full, current = current)
}

test_that("migration backfill retains current raw values, metadata and exact history", {
  fixture <- migration_history_fixture()
  testthat::local_mocked_bindings(snz_read_infoshare = function(...) fixture$full, .package = "statsnzreleases")
  got <- statsnzreleases:::snz_add_full_history(fixture$current,
    statsnzreleases:::snz_release_definition("nz_stats_international_migration"))
  expect_equal(nrow(got), 9L)
  current <- got[got$period_date >= as.Date("2001-02-01"), ]
  expect_identical(current$status, fixture$current$status)
  expect_identical(current$data_value_raw, fixture$current$data_value_raw)
  expect_identical(current$source_file, rep("current.xlsx", 6L))
  expect_identical(got$source_file[got$period_date == as.Date("2001-01-01")], rep("Infoshare.csv", 3L))
  expect_equal(nrow(statsnz_provenance(got)$attachments), 2L)
})

test_that("migration rejects partial, stale, missing-series and conflicting histories", {
  fixture <- migration_history_fixture()
  bad <- list(
    stale = fixture$full[fixture$full$period_date < as.Date("2001-03-01"), ],
    missing_series = fixture$full[fixture$full$series_reference != "ITMM.SEMANE", ],
    missing_period = fixture$full[fixture$full$period_date != as.Date("2001-02-01"), ],
    missing_early = fixture$full[fixture$full$period_date != as.Date("2001-01-01"), ],
    conflict = fixture$full,
    missing_value = fixture$full
  )
  bad$conflict$data_value[[2]] <- 999
  bad$missing_value$data_value[[2]] <- NA_real_
  for (candidate in bad) {
    local({
      history <- candidate
      testthat::local_mocked_bindings(snz_read_infoshare = function(...) history, .package = "statsnzreleases")
      expect_error(statsnzreleases:::snz_add_full_history(fixture$current,
        statsnzreleases:::snz_release_definition("nz_stats_international_migration")),
        class = "statsnz_history_schema_error")
    })
  }
})
