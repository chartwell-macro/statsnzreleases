snz_text_column <- function(data, name) {
  if (!name %in% names(data)) {
    return(rep("", nrow(data)))
  }
  value <- as.character(data[[name]])
  value[is.na(value)] <- ""
  trimws(value)
}

snz_labour_series_is_headline <- function(data) {
  reference <- snz_text_column(data, "series_reference")
  subject <- snz_text_column(data, "subject")
  group <- snz_text_column(data, "group")
  title_1 <- snz_text_column(data, "series_title_1")
  title_2 <- snz_text_column(data, "series_title_2")
  title_3 <- snz_text_column(data, "series_title_3")

  hlfs_primary_groups <- c(
    "Labour Force Status by Sex: Seasonally Adjusted",
    "Labour Force Status by Sex: Trend Series",
    "Employed Full & Part-Time: Seas Adj & Trend Series",
    "Underutilisation by Sex: Seasonally Adjusted"
  )
  hlfs_actual <- (
    group == "Labour Force Status by Sex by Age Group" &
      title_3 == "Total All Ages"
  ) |
    group == "Employed Persons, Full & Part-Time Status by Sex" |
    group == "Underutilisation by Sex"
  hlfs <- startsWith(reference, "HLFQ.") &
    (group %in% hlfs_primary_groups | hlfs_actual)

  qes_actual_groups <- c(
    "Average Hourly Earnings by Industry (ANZSIC06) and Sex",
    "Average Weekly Earnings (Employees) by Industry (ANZSIC06) and Sex",
    "Average Weekly Earnings (FTES) by Industry (ANZSIC06) and Sex",
    "Average Weekly Paid Hours (Employees) by Industry (ANZIC06) and Sex",
    "Average Weekly Paid Hours FTES by Industry (ANZIC06) and Sex",
    "Filled Jobs by Industry (ANZSIC06) by Sex and Status in Employment",
    "Full-Time Equivalent Employees by Industry (ANZSIC06) and Sex"
  )
  qes_adjusted_groups <- c(
    "Average Weekly Earnings (Employees) Total All Ind. & Both Sexes - Seasonally Adj",
    "Average Weekly Earnings (Employees) Total All Ind. & Both Sexes - Trend Series",
    "Average Weekly Earnings (FTES) Total All Ind. & Both Sexes - Seasonally Adj",
    "Average Weekly Earnings (FTES) Total All Ind. & Both Sexes - Trend Series",
    "Average Weekly Paid Hours (Employees) Total All Ind & Both Sexes - Seasonal Adj",
    "Average Weekly Paid Hours (Employees) Total All Ind & Both Sexes - Trend",
    "Average Weekly Paid Hours FTES Total All industries & both sexes - Seasonal adj",
    "Average Weekly Paid Hours FTES Total All industries & both sexes - Trend Series",
    "Filled Jobs by Total All Ind.&Both Sexes and Status in Employment- Seasonal/Tren",
    "Full-Time Equivalent Employees by Total All Ind.&Both Sexes- Seasonal/Trend",
    "Total Gross Earnings Seasonally Adjusted and Trend Series",
    "Total Paid Hours  Seasonally Adjusted and Trend Series"
  )
  qes_actual <- group %in% qes_actual_groups &
    title_1 == "Total All Industries" &
    title_2 == "Total Both Sexes"
  qes <- startsWith(reference, "QEMQ.") &
    (qes_actual | group %in% qes_adjusted_groups)

  lci_overall <- group ==
    "All Sectors Combined, All Salary and Wage Rates (Base: June 2017 qtr (=1000))"
  lci_historical <- grepl(
    "^All Sectors Combined and Industry Group",
    group
  ) &
    title_1 == "All Salary and Wage Rates" &
    title_2 == "All Industries Combined"
  lci <- startsWith(reference, "LCIQ.") & (lci_overall | lci_historical)

  expected_subject <- subject %in% c(
    "Household Labour Force Survey - HLF",
    "Quarterly Employment Survey - QEM",
    "Labour Cost Index - LCI"
  )
  expected_subject & (hlfs | qes | lci)
}

snz_read_labour_csv <- function(path, source_name, source_url) {
  frames <- list()
  callback <- readr::SideEffectChunkCallback$new(function(data, position) {
    data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
    names(data) <- snz_clean_names(names(data))
    keep <- snz_labour_series_is_headline(data)
    if (any(keep)) {
      frames[[length(frames) + 1L]] <<- data[keep, , drop = FALSE]
    }
    invisible(NULL)
  })

  tryCatch(
    suppressWarnings(readr::read_csv_chunked(
      path,
      callback = callback,
      chunk_size = 100000L,
      col_types = readr::cols(.default = readr::col_character()),
      progress = FALSE,
      show_col_types = FALSE,
      na = c("", "NA"),
      locale = readr::locale(encoding = "UTF-8")
    )),
    error = function(error) {
      snz_stop(
        sprintf(
          "Stats NZ labour-market CSV could not be parsed: %s",
          conditionMessage(error)
        ),
        class = "statsnz_csv_error",
        path = path
      )
    }
  )

  data <- snz_bind_rows(frames)
  if (nrow(data) == 0L) {
    snz_stop(
      "The labour-market archive contained no curated quarterly headline series.",
      class = "statsnz_empty_data",
      path = path
    )
  }
  for (name in names(data)) {
    data[[name]] <- iconv(
      as.character(data[[name]]),
      from = "",
      to = "UTF-8",
      sub = "\uFFFD"
    )
  }
  data$source_file <- source_name
  data$source_attachment_url <- source_url
  data
}

snz_read_labour_zip <- function(path, source_url) {
  contents <- tryCatch(
    utils::unzip(path, list = TRUE),
    error = function(error) {
      snz_stop(
        sprintf(
          "Stats NZ labour-market ZIP could not be inspected: %s",
          conditionMessage(error)
        ),
        class = "statsnz_zip_error",
        path = path
      )
    }
  )
  members <- contents$Name[
    grepl("(^|/)lms-.*-tables\\.csv$", contents$Name, ignore.case = TRUE)
  ]
  unsafe <- grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", members)
  if (length(members) != 1L || any(unsafe)) {
    snz_stop(
      "The labour-market ZIP must contain one safe standard LMS table.",
      class = "statsnz_zip_error",
      path = path
    )
  }

  extraction_dir <- tempfile("statsnzreleases-labour-")
  dir.create(extraction_dir, recursive = TRUE)
  on.exit(unlink(extraction_dir, recursive = TRUE, force = TRUE), add = TRUE)
  extracted <- tryCatch(
    utils::unzip(path, files = members, exdir = extraction_dir),
    error = function(error) {
      snz_stop(
        sprintf(
          "Stats NZ labour-market ZIP could not be extracted: %s",
          conditionMessage(error)
        ),
        class = "statsnz_zip_error",
        path = path
      )
    }
  )
  list(snz_read_labour_csv(extracted[[1L]], members[[1L]], source_url))
}
