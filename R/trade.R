snz_fill_down <- function(value) {
  value <- as.character(value)
  last <- NA_character_
  for (index in seq_along(value)) {
    if (!is.na(value[[index]]) && nzchar(trimws(value[[index]]))) {
      last <- value[[index]]
    } else {
      value[[index]] <- last
    }
  }
  value
}

snz_fill_right <- function(value) {
  snz_fill_down(value)
}

snz_trade_period <- function(sheet, start_row, year_column = 1L, month_column = 2L) {
  year <- suppressWarnings(as.integer(snz_fill_down(sheet[[year_column]])))
  month_text <- trimws(as.character(sheet[[month_column]]))
  month <- match(
    tolower(substr(month_text, 1L, 3L)),
    tolower(month.abb)
  )
  period <- ifelse(
    !is.na(year) & !is.na(month),
    sprintf("%04d.%02d", year, month),
    NA_character_
  )
  period[seq_len(min(start_row - 1L, length(period)))] <- NA_character_
  section_end <- which(grepl(
    "^Percentage change",
    trimws(as.character(sheet[[year_column]])),
    ignore.case = TRUE
  ))
  if (length(section_end) > 0L) {
    period[seq.int(section_end[[1L]], length(period))] <- NA_character_
  }
  period
}

snz_trade_series_reference <- function(value, prefix = "", fallback) {
  value <- gsub("\\s+", "", snz_scalar(value))
  prefix <- snz_scalar(prefix)
  if (nzchar(value) && !grepl("\\.", value, fixed = FALSE) && nzchar(prefix)) {
    value <- paste0(prefix, value)
  }
  if (!nzchar(value)) fallback else value
}

snz_trade_reference_prefix <- function(value) {
  value <- snz_scalar(value)
  match <- regexec(
    "Infoshare series\\s+([A-Za-z0-9]+\\.)",
    value,
    ignore.case = TRUE
  )
  pieces <- regmatches(value, match)[[1L]]
  if (length(pieces) < 2L) "" else pieces[[2L]]
}

snz_trade_frame <- function(
    sheet,
    columns,
    start_row,
    references,
    labels,
    adjustment,
    measure,
    frequency,
    source_name,
    source_url,
    units = NULL,
    magnitude = NULL,
    title_2 = NULL,
    title_3 = NULL) {
  period <- snz_trade_period(sheet, start_row)
  keep_rows <- which(!is.na(period))
  if (length(keep_rows) == 0L) {
    return(data.frame())
  }
  if (is.null(units)) {
    units <- rep("", length(columns))
  }
  if (is.null(magnitude)) {
    magnitude <- rep("", length(columns))
  }
  if (is.null(title_2)) {
    title_2 <- rep("", length(columns))
  }
  if (is.null(title_3)) {
    title_3 <- rep("", length(columns))
  }

  frames <- lapply(seq_along(columns), function(index) {
    column <- columns[[index]]
    data.frame(
      frequency = tolower(frequency),
      series_reference = references[[index]],
      period = period[keep_rows],
      data_value = as.character(sheet[[column]][keep_rows]),
      status = "",
      units = units[[index]],
      magnitude = magnitude[[index]],
      subject = "Overseas Merchandise Trade",
      group = paste(
        "Overseas Merchandise Trade",
        frequency,
        adjustment,
        measure,
        sep = " | "
      ),
      series_title_1 = labels[[index]],
      series_title_2 = title_2[[index]],
      series_title_3 = title_3[[index]],
      source_file = source_name,
      source_attachment_url = source_url,
      stringsAsFactors = FALSE
    )
  })
  snz_bind_rows(frames)
}

snz_trade_headline_sheet <- function(
    sheet,
    columns,
    start_row,
    references,
    labels,
    adjustments,
    frequency,
    source_name,
    source_url) {
  frames <- lapply(unique(adjustments), function(adjustment) {
    use <- which(adjustments == adjustment)
    snz_trade_frame(
      sheet = sheet,
      columns = columns[use],
      start_row = start_row,
      references = references[use],
      labels = labels[use],
      adjustment = adjustment,
      measure = "Value",
      frequency = frequency,
      source_name = source_name,
      source_url = source_url,
      units = rep("Dollars (millions)", length(use)),
      magnitude = rep("6", length(use))
    )
  })
  snz_bind_rows(frames)
}

snz_trade_grid_sheet <- function(
    sheet,
    columns,
    start_row,
    reference_row,
    title_row,
    units_row,
    flow,
    adjustment,
    measure,
    frequency,
    source_name,
    source_url,
    parent_title_row = NULL,
    prefix_cell = NULL) {
  prefix <- if (is.null(prefix_cell)) "" else
    snz_trade_reference_prefix(sheet[[prefix_cell[[2L]]]][[prefix_cell[[1L]]]])
  references <- vapply(columns, function(column) {
    snz_trade_series_reference(
      sheet[[column]][[reference_row]],
      prefix = prefix,
      fallback = sprintf(
        "OMT%s.%s.%s.%02d",
        if (frequency == "Monthly") "M" else "Q",
        toupper(flow),
        toupper(gsub("[^A-Za-z]", "", adjustment)),
        column
      )
    )
  }, character(1))
  labels <- rep(flow, length(columns))
  children <- vapply(
    columns,
    function(column) snz_scalar(sheet[[column]][[title_row]]),
    character(1)
  )
  parents <- if (is.null(parent_title_row)) {
    children
  } else {
    row <- vapply(
      columns,
      function(column) snz_scalar(sheet[[column]][[parent_title_row]]),
      character(1)
    )
    snz_fill_right(row)
  }
  title_2 <- if (is.null(parent_title_row)) children else parents
  title_3 <- if (is.null(parent_title_row)) rep("", length(columns)) else children
  units <- vapply(
    columns,
    function(column) snz_scalar(sheet[[column]][[units_row]]),
    character(1)
  )
  magnitude <- ifelse(grepl("million", units, ignore.case = TRUE), "6", "")

  snz_trade_frame(
    sheet = sheet,
    columns = columns,
    start_row = start_row,
    references = references,
    labels = labels,
    adjustment = adjustment,
    measure = measure,
    frequency = frequency,
    source_name = source_name,
    source_url = source_url,
    units = units,
    magnitude = magnitude,
    title_2 = title_2,
    title_3 = title_3
  )
}

snz_read_trade_workbook <- function(path, source_name, source_url) {
  read_sheet <- function(name) {
    tryCatch(
      as.data.frame(
        readxl::read_excel(
          path,
          sheet = name,
          col_names = FALSE,
          .name_repair = "minimal"
        ),
        stringsAsFactors = FALSE,
        check.names = FALSE
      ),
      error = function(error) {
        snz_stop(
          sprintf(
            "Stats NZ trade workbook sheet `%s` could not be parsed: %s",
            name,
            conditionMessage(error)
          ),
          class = "statsnz_workbook_error",
          path = path
        )
      }
    )
  }

  available <- readxl::excel_sheets(path)
  required <- c("Table 1.02", "Table 2", paste("Table",11:16))
  quarterly_sheets <- paste("Table",17:20)
  if (length(setdiff(required,available)) ||
      (any(quarterly_sheets %in% available) && !all(quarterly_sheets %in% available))) {
    snz_stop("Trade workbook omitted required monthly sheets or has an incomplete quarterly block.",class="statsnz_workbook_error")
  }
  actual <- read_sheet("Table 1.02")
  frames <- list(snz_trade_headline_sheet(
    sheet = actual,
    columns = 4:6,
    start_row = 8L,
    references = c(
      "EXPM.SCT99F",
      "IMPM.SCT99C",
      "OMTM.HEADLINE.BALANCE.ACTUAL"
    ),
    labels = c("Exports", "Imports", "Trade balance"),
    adjustments = rep("Actual", 3L),
    frequency = "Monthly",
    source_name = source_name,
    source_url = source_url
  ))

  monthly <- read_sheet("Table 2")
  frames[[length(frames) + 1L]] <- snz_trade_headline_sheet(
    sheet = monthly,
    columns = c(4L, 6L, 8L, 9L, 11L, 13L),
    start_row = 9L,
    references = c(
      snz_trade_series_reference(monthly[[4L]][[6L]], fallback = "OMTM.HEADLINE.EXPORTS.SA"),
      snz_trade_series_reference(monthly[[6L]][[6L]], fallback = "OMTM.HEADLINE.IMPORTS.SA"),
      "OMTM.HEADLINE.BALANCE.SA",
      snz_trade_series_reference(monthly[[9L]][[6L]], fallback = "OMTM.HEADLINE.EXPORTS.TREND"),
      snz_trade_series_reference(monthly[[11L]][[6L]], fallback = "OMTM.HEADLINE.IMPORTS.TREND"),
      "OMTM.HEADLINE.BALANCE.TREND"
    ),
    labels = rep(c("Exports", "Imports", "Trade balance"), 2L),
    adjustments = rep(c("Seasonally adjusted", "Trend"), each = 3L),
    frequency = "Monthly",
    source_name = source_name,
    source_url = source_url
  )

  grid_specs <- list(
    list("Table 11", 3:13, 9L, 6L, 4L, 7L, "Exports", "Seasonally adjusted", "Value", "Monthly"),
    list("Table 12", 3:13, 9L, 6L, 4L, 7L, "Exports", "Seasonally adjusted", "Quantity", "Monthly"),
    list("Table 13", 3:10, 9L, 6L, 4L, 7L, "Imports", "Seasonally adjusted", "Value", "Monthly"),
    list("Table 14", 3:13, 9L, 6L, 4L, 7L, "Exports", "Trend", "Value", "Monthly"),
    list("Table 15", 3:13, 9L, 6L, 4L, 7L, "Exports", "Trend", "Quantity", "Monthly"),
    list("Table 16", 3:10, 9L, 6L, 4L, 7L, "Imports", "Trend", "Value", "Monthly"),
    list("Table 18", 3:13, 9L, 6L, 4L, 7L, "Exports", "Seasonally adjusted", "Value", "Quarterly"),
    list("Table 19", 3:13, 9L, 6L, 4L, 7L, "Exports", "Seasonally adjusted", "Quantity", "Quarterly")
  )
  for (specification in grid_specs) {
    if (!specification[[1L]] %in% available) next
    sheet <- read_sheet(specification[[1L]])
    frames[[length(frames) + 1L]] <- snz_trade_grid_sheet(
      sheet = sheet,
      columns = specification[[2L]],
      start_row = specification[[3L]],
      reference_row = specification[[4L]],
      title_row = specification[[5L]],
      units_row = specification[[6L]],
      flow = specification[[7L]],
      adjustment = specification[[8L]],
      measure = specification[[9L]],
      frequency = specification[[10L]],
      source_name = source_name,
      source_url = source_url,
      prefix_cell = c(specification[[4L]], 1L)
    )
  }

  if (all(quarterly_sheets %in% available)) {
  quarterly <- read_sheet("Table 17")
  frames[[length(frames) + 1L]] <- snz_trade_headline_sheet(
    sheet = quarterly,
    columns = c(3L, 5L, 7L, 8L, 10L, 12L),
    start_row = 9L,
    references = c(
      snz_trade_series_reference(quarterly[[3L]][[6L]], fallback = "OMTQ.HEADLINE.EXPORTS.SA"),
      snz_trade_series_reference(quarterly[[5L]][[6L]], fallback = "OMTQ.HEADLINE.IMPORTS.SA"),
      "OMTQ.HEADLINE.BALANCE.SA",
      snz_trade_series_reference(quarterly[[8L]][[6L]], fallback = "OMTQ.HEADLINE.EXPORTS.TREND"),
      snz_trade_series_reference(quarterly[[10L]][[6L]], fallback = "OMTQ.HEADLINE.IMPORTS.TREND"),
      "OMTQ.HEADLINE.BALANCE.TREND"
    ),
    labels = rep(c("Exports", "Imports", "Trade balance"), 2L),
    adjustments = rep(c("Seasonally adjusted", "Trend"), each = 3L),
    frequency = "Quarterly",
    source_name = source_name,
    source_url = source_url
  )

  quarterly_imports <- read_sheet("Table 20")
  frames[[length(frames) + 1L]] <- snz_trade_grid_sheet(
    sheet = quarterly_imports,
    columns = 3:10,
    start_row = 10L,
    reference_row = 7L,
    title_row = 5L,
    units_row = 8L,
    flow = "Imports",
    adjustment = "Seasonally adjusted",
    measure = "Value",
    frequency = "Quarterly",
    source_name = source_name,
    source_url = source_url,
    parent_title_row = 4L,
    prefix_cell = c(7L, 1L)
  )

  }
  snz_bind_rows(frames)
}
