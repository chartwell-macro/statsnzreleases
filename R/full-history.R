# Full histories remain official-source data; this module owns their ingestion.
snz_history_stop <- function(message, call. = FALSE) {
  snz_stop(message, class = "statsnz_history_schema_error")
}
snz_history_text <- function(x) {
  x <- trimws(as.character(x)); x[is.na(x)] <- ""; x
}
snz_history_numeric <- function(x) {
  raw <- snz_history_text(x)
  missing <- raw %in% c("", "..")
  grouped <- grepl(",", raw, fixed = TRUE)
  valid_groups <- grepl("^[+-]?[0-9]{1,3}(,[0-9]{3})+(\\.[0-9]*)?([eE][+-]?[0-9]+)?$", raw)
  text <- gsub(",", "", raw, fixed = TRUE)
  numeric_token <- grepl("^[+-]?([0-9]+(\\.[0-9]*)?|\\.[0-9]+)([eE][+-]?[0-9]+)?$", text)
  value <- suppressWarnings(as.numeric(text))
  if (any(!missing & (!numeric_token | !is.finite(value) | (grouped & !valid_groups)))) {
    snz_history_stop("Stats NZ history contains an invalid or non-finite numeric value.")
  }
  value[missing] <- NA_real_
  value
}
snz_assert_history_keys <- function(reference, date, value) {
  if (anyNA(date) || any(!nzchar(reference))) snz_history_stop("Stats NZ history has an invalid identity or period.")
  if (any(is.nan(value) | is.infinite(value))) snz_history_stop("Stats NZ history contains a non-finite value.")
  key <- paste(reference, date, sep = "\r")
  if (anyDuplicated(key)) {
    snz_history_stop("Stats NZ history contains duplicate observations.")
  }
  invisible(TRUE)
}
snz_history_observations <- function(release_id,series_reference,series_label,period_date,data_value,units,subject,group,magnitude=0) {
  release <- snz_release_definition(release_id)
  raw_value <- snz_history_text(data_value)
  numeric_value <- snz_history_numeric(raw_value)
  tibble::tibble(release_id=release_id,release_name=release$release_name[[1L]],tier=release$tier[[1L]],
    frequency=release$frequency[[1L]],series_reference=series_reference,series_label=series_label,
    period=format(as.Date(period_date),"%Y.%m"),period_date=as.Date(period_date),
    data_value=numeric_value,data_value_raw=raw_value,
    status="",units=units,magnitude=as.numeric(magnitude),subject=subject,group=group,series_title_1=series_label)
}

SNZ_INFOSHARE_URL <- "https://infoshare.stats.govt.nz/infoshare/exportdirect.aspx"

snz_infoshare_fetch <- function(references) {
  references <- unique(as.character(references))
  if (!length(references) || length(references) > 100L ||
      any(!grepl("^[A-Z0-9]+\\.[A-Z0-9]+$", references))) {
    snz_history_stop("Stats NZ Infoshare requires 1\u2013100 exact official identifiers.", call. = FALSE)
  }
  session <- snz_handle(timeout = 25)
  curl::handle_setopt(session, cookiefile = "")
  page <- curl::curl_fetch_memory(SNZ_INFOSHARE_URL, handle = session)
  if (page$status_code != 200L || length(page$content) > 10 * 1024^2) {
    snz_history_stop("Stats NZ Infoshare returned an invalid export form.")
  }
  html <- xml2::read_html(page$content)
  hidden <- c("__VIEWSTATE", "__VIEWSTATEGENERATOR", "__EVENTVALIDATION")
  values <- vapply(hidden, function(name) {
    node <- xml2::xml_find_all(html, paste0("//input[@name='", name, "']"))
    if (length(node) != 1L) return("")
    xml2::xml_attr(node, "value")
  }, character(1))
  periods <- xml2::xml_attr(xml2::xml_find_all(html,
    "//select[@name='ctl00$MainContent$TimeVariableSelector$lbVariableOptions']/option"), "value")
  if (anyNA(values) || any(!nzchar(values)) || !length(periods) ||
      length(periods) > 5000L || anyNA(periods) || anyDuplicated(periods)) {
    snz_history_stop("Stats NZ Infoshare export form has an unsupported schema.", call. = FALSE)
  }
  search_file <- tempfile("stats-nz-infoshare-", fileext = ".sch")
  on.exit(unlink(search_file, force = TRUE), add = TRUE)
  writeLines(references, search_file, useBytes = TRUE)
  form <- c(list(`__EVENTTARGET` = "", `__EVENTARGUMENT` = ""), as.list(values))
  form[["ctl00$MainContent$fuSearchFile"]] <- curl::form_file(search_file, type = "text/plain")
  form[["ctl00$MainContent$tbMissingText"]] <- ".."
  form[["ctl00$MainContent$TimeVariableSelector$tbSelected"]] <- as.character(length(periods))
  form <- c(form, stats::setNames(as.list(periods), rep(
    "ctl00$MainContent$TimeVariableSelector$lbVariableOptions", length(periods))))
  form[["ctl00$MainContent$rblCSVFormat"]] <- "columns"
  form[["ctl00$MainContent$rblSeriesDescription"]] <- "description_at_top"
  form[["ctl00$MainContent$cbShowStatusCodes"]] <- "on"
  form[["ctl00$MainContent$btnGenerate.x"]] <- "1"
  form[["ctl00$MainContent$btnGenerate.y"]] <- "1"
  curl::handle_setform(session, .list = form)
  response <- curl::curl_fetch_memory(SNZ_INFOSHARE_URL, handle = session)
  bytes <- response$content
  if (response$status_code != 200L ||
      !grepl("^text/csv", response$type %||% "", ignore.case = TRUE) ||
      !length(bytes) || length(bytes) > 10 * 1024^2) {
    snz_history_stop("Stats NZ Infoshare returned an invalid or oversized CSV export.", call. = FALSE)
  }
  list(text = rawToChar(bytes), sha256 = digest::digest(bytes, algo = "sha256", serialize = FALSE),
       bytes = length(bytes), url = SNZ_INFOSHARE_URL)
}

snz_infoshare_parse <- function(export, references, release_id) {
  lines <- strsplit(export$text, "\r?\n", perl = TRUE)[[1L]]
  starts <- which(startsWith(lines, "Series is "))
  headers <- which(startsWith(lines, ","))
  if (length(starts) != length(references) || length(headers) != 1L) {
    snz_history_stop("Stats NZ Infoshare CSV omitted exact series descriptions or data header.", call. = FALSE)
  }
  ids <- sub("^Series is ", "", lines[starts])
  if (!setequal(ids, references) || anyDuplicated(ids)) {
    snz_history_stop("Stats NZ Infoshare CSV returned conflicting series identity.", call. = FALSE)
  }
  data_rows <- which(grepl("^[A-Za-z]{3}-[0-9]{4},", lines))
  if (!length(data_rows) || !identical(data_rows, seq.int(headers + 1L, max(data_rows))) ||
      (max(data_rows) < length(lines) &&
       any(!lines[seq.int(max(data_rows) + 1L, length(lines))] %in%
         c("", "Source: Statistics New Zealand")))) {
    snz_history_stop("Stats NZ Infoshare CSV has an unsupported data block or footer.", call. = FALSE)
  }
  table <- readr::read_csv(I(paste(lines[headers:max(data_rows)], collapse = "\n")),
    col_names = FALSE, col_types = readr::cols(.default = readr::col_character()),
    na = character(), show_col_types = FALSE, progress = FALSE)
  if (nrow(readr::problems(table)) || ncol(table) != 2L * length(ids) + 2L || nrow(table) < 3L) {
    snz_history_stop("Stats NZ Infoshare CSV has an unsupported value/status table.", call. = FALSE)
  }
  months <- snz_history_text(table[[1L]][-1L])
  month_number <- match(substr(months, 1L, 3L), month.abb)
  years <- suppressWarnings(as.integer(substr(months, 5L, 8L)))
  dates <- as.Date(sprintf("%04d-%02d-01", years, month_number))
  if (anyNA(dates) || any(!grepl("^[A-Z][a-z]{2}-[0-9]{4}$", months)) || anyDuplicated(dates)) {
    snz_history_stop("Stats NZ Infoshare CSV contains invalid or duplicate monthly periods.", call. = FALSE)
  }
  frames <- lapply(seq_along(ids), function(index) {
    block_end <- if (index < length(ids)) starts[[index + 1L]] - 1L else headers - 1L
    block <- lines[starts[[index]]:block_end]
    metadata_row <- which(startsWith(block, "Units = "))
    if (length(metadata_row) != 1L || metadata_row < 5L ||
        !identical(snz_scalar(table[[2L * index]][[1L]]), ids[[index]])) {
      snz_history_stop("Stats NZ Infoshare CSV contains conflicting metadata/header identity.", call. = FALSE)
    }
    meta <- block[[metadata_row]]
    units <- sub("^.*Units = ([^;]+);.*$", "\\1", meta)
    magnitude_text <- sub("^.*Magnitude = ([^;]+);.*$", "\\1", meta)
    magnitude <- switch(gsub(",", "", magnitude_text, fixed = TRUE),
      Units = 0, `1000s` = 3, `1000000s` = 6, Millions = 6, NA_real_)
    if (!is.finite(magnitude) || !grepl("Frequency = Monthly;", meta, fixed = TRUE)) {
      snz_history_stop("Stats NZ Infoshare CSV has unsupported frequency or magnitude.", call. = FALSE)
    }
    result <- snz_history_observations(release_id, ids[[index]],
      paste(block[4L:(metadata_row - 1L)], collapse = " \u2014 "), dates,
      table[[2L * index]][-1L], units, block[[2L]], block[[3L]], magnitude)
    result$status <- snz_history_text(table[[2L * index + 1L]][-1L])
    if (any(!grepl("^[A-Z]?$", result$status))) {
      snz_history_stop("Stats NZ Infoshare CSV contains unsupported status flags.", call. = FALSE)
    }
    result$source_file <- "Infoshare Export Direct.csv"
    result$source_attachment_url <- export$url
    result
  })
  data <- snz_bind_rows(frames)
  snz_assert_history_keys(data$series_reference, data$period_date, data$data_value)
  attr(data, "statsnz_provenance") <- list(
    release_url = export$url, release_title = snz_release_definition(release_id)$release_name[[1L]],
    retrieved_at = Sys.time(), adapter_version = "infoshare-export-direct-v1",
    attachments = tibble::tibble(name = "Infoshare Export Direct.csv", url = export$url,
      bytes = export$bytes, sha256 = export$sha256))
  data
}

snz_read_infoshare <- function(references, release_id, fetcher = snz_infoshare_fetch) {
  snz_infoshare_parse(fetcher(references), references, release_id)
}

snz_trade_full_history_groups <- function() {
  list(c("OTTM.SSEF", "OTTM.SSIC", "EXPM.SH4AFS", "EXPM.SH4AQS", "EXPM.SH1DQS", "EXPM.SH03QS", "EXPM.SH44Q"),
    "EXPM.SCT99F", "IMPM.SCT99C")
}

snz_trade_backfill <- function(data, history) {
  historical <- list()
  for (reference in unique(history$series_reference)) {
    full <- history[history$series_reference == reference, , drop = FALSE]
    current <- data[data$series_reference == reference, , drop = FALSE]
    if (!nrow(current)) snz_history_stop("Stats NZ trade backfill series is absent from the release workbook.", call. = FALSE)
    quantity <- reference %in% c("EXPM.SH4AQS", "EXPM.SH1DQS", "EXPM.SH03QS", "EXPM.SH44Q")
    target_magnitude <- if (quantity) 3 else 6
    expected_units <- if (reference == "EXPM.SH44Q") "m3" else if (quantity) "Tonnes" else "$"
    if (any(full$units != expected_units) || anyNA(full$magnitude) ||
        length(unique(full$magnitude)) != 1L) {
      snz_history_stop("Stats NZ trade full-history units have changed.", call. = FALSE)
    }
    scaled <- full$data_value * 10^(full$magnitude - target_magnitude)
    overlap <- match(current$period_date, full$period_date)
    compare <- !is.na(overlap) & is.finite(current$data_value)
    if (any(!is.finite(scaled[overlap[compare]]))) {
      snz_history_stop("Stats NZ trade full history omitted a current published value.", call. = FALSE)
    }
    current_rows <- which(data$series_reference == reference)
    data$status[current_rows[!is.na(overlap)]] <- full$status[overlap[!is.na(overlap)]]
    # Infoshare serializes quantities and adjusted headlines at integer precision.
    # Check that precision explicitly; retain the workbook's more precise values.
    scale <- 10^(unique(full$magnitude) - target_magnitude)
    if (any(abs(scaled[overlap[compare]] - current$data_value[compare]) > scale * 0.500001)) {
      snz_history_stop("Stats NZ trade full history conflicts with its current release workbook.", call. = FALSE)
    }
    earlier <- !full$period_date %in% current$period_date
    backfill <- current[rep(1L, sum(earlier)), , drop = FALSE]
    backfill$period_date <- full$period_date[earlier]
    backfill$period <- full$period[earlier]
    backfill$data_value <- scaled[earlier]
    backfill$data_value_raw <- full$data_value_raw[earlier]
    backfill$status <- full$status[earlier]
    backfill$source_file <- full$source_file[earlier]
    backfill$source_attachment_url <- full$source_attachment_url[earlier]
    historical[[length(historical) + 1L]] <- backfill
  }
  result <- snz_bind_rows(c(list(data),historical))
  result <- result[order(result$series_reference, result$period_date), , drop = FALSE]
  snz_assert_history_keys(result$series_reference, result$period_date, result$data_value)
  result
}

snz_read_bulk_csv <- function(
    path, member, release_id, references = NULL, prefix = NULL) {
  if (file.info(path)$size > 64 * 1024^2) snz_history_stop("Stats NZ bulk archive exceeds the input limit.")
  members <- utils::unzip(path, list = TRUE)
  selected <- members[members$Name == member, , drop = FALSE]
  if (nrow(selected) != 1L || selected$Length[[1L]] > 256 * 1024^2) {
    snz_history_stop("Stats NZ bulk archive omitted its bounded reviewed CSV member.", call. = FALSE)
  }
  connection <- unz(path, member, open = "r")
  on.exit(close(connection), add = TRUE)
  header <- readLines(connection, n = 1L, warn = FALSE)
  if (length(header) != 1L) {
    snz_history_stop("Stats NZ bulk CSV omitted its header.", call. = FALSE)
  }
  pieces <- list(header)
  retained <- 0L
  repeat {
    lines <- readLines(connection, n = 50000L, warn = FALSE)
    if (!length(lines)) break
    reference <- gsub('^"|"$', "", sub(",.*$", "", lines))
    keep <- if (length(references)) reference %in% references else {
      startsWith(reference, prefix)
    }
    retained <- retained + sum(keep)
    if (retained > 100000L) {
      snz_history_stop("Stats NZ bulk CSV exceeded the retained-observation limit.", call. = FALSE)
    }
    if (any(keep)) pieces[[length(pieces) + 1L]] <- lines[keep]
  }
  if (!retained) {
    snz_history_stop("Stats NZ bulk CSV omitted the requested exact series.", call. = FALSE)
  }
  data <- readr::read_csv(
    I(paste(unlist(pieces, use.names = FALSE), collapse = "\n")),
    col_types = readr::cols(.default = readr::col_character()),
    show_col_types = FALSE, progress = FALSE, name_repair = "minimal"
  )
  if (nrow(readr::problems(data))) {
    snz_history_stop("Stats NZ bulk CSV could not be parsed without schema errors.", call. = FALSE)
  }
  result <- snz_parse_bulk_csv(data, release_id)
  if (length(references) && !setequal(unique(result$series_reference), references)) {
    snz_history_stop("Stats NZ bulk CSV did not contain every reviewed exact series.", call. = FALSE)
  }
  result
}

snz_parse_bulk_csv <- function(data, release_id) {
  names(data) <- tolower(names(data))
  required <- c("series_reference", "period", "data_value", "units", "subject", "group", "series_title_1", "status")
  if (anyDuplicated(names(data)) || length(setdiff(required, names(data)))) {
    snz_history_stop("Stats NZ bulk CSV has an unsupported schema.", call. = FALSE)
  }
  periods <- snz_history_text(data$period)
  year <- suppressWarnings(as.integer(substr(periods, 1L, 4L)))
  month <- suppressWarnings(as.integer(substr(periods, 6L, 7L)))
  dates <- suppressWarnings(as.Date(sprintf("%04d-%02d-01", year, month)))
  quarterly <- identical(tolower(snz_release_definition(release_id)$frequency[[1L]]), "quarterly")
  if (any(!grepl("^[0-9]{4}\\.[0-9]{2}$", periods)) || anyNA(dates) ||
      (quarterly && any(!month %in% c(3L, 6L, 9L, 12L)))) {
    snz_history_stop("Stats NZ bulk CSV contained an invalid observation period.", call. = FALSE)
  }
  title_columns <- intersect(paste0("series_title_", 1:5), names(data))
  labels <- rep("", nrow(data))
  for (column in title_columns) {
    part <- snz_history_text(data[[column]])
    labels <- ifelse(nzchar(part), ifelse(
      nzchar(labels), paste(labels, part, sep = " \u2014 "), part
    ), labels)
  }
  result <- snz_history_observations(
    release_id, data$series_reference, labels, dates, data$data_value,
    data$units, data$subject, data$group,
    magnitude = if ("magnitude" %in% names(data)) data$magnitude else 0
  )
  result$status <- snz_history_text(data$status)
  for (column in title_columns) result[[column]] <- snz_history_text(data[[column]])
  snz_assert_history_keys(result$series_reference, result$period_date, result$data_value)
  result
}


snz_add_full_history <- function(data, release) {
  release_id <- release$release_id[[1L]]
  if (!release_id %in% c("nz_stats_international_migration", "nz_stats_trade")) return(data)
  provenance <- statsnz_provenance(data)
  groups <- if (release_id == "nz_stats_international_migration") {
    list(c("ITMM.SEMAAE", "ITMM.SEMADE", "ITMM.SEMANE"))
  } else snz_trade_full_history_groups()
  histories <- lapply(groups, function(references) snz_read_infoshare(references,release_id))
  cutoff <- max(data$period_date,na.rm=TRUE)
  full <- snz_bind_rows(lapply(histories,function(x)x[x$period_date<=cutoff,,drop=FALSE]))
  if (release_id == "nz_stats_international_migration") {
    if (any(full$units != "Number") || any(full$magnitude != 0)) snz_history_stop("Stats NZ migration units have changed.")
    if (!setequal(unique(full$series_reference), unique(data$series_reference))) {
      snz_history_stop("Stats NZ migration full history omitted an exact release series.")
    }
    snz_assert_history_keys(full$series_reference, full$period_date, full$data_value)
    for (reference in unique(data$series_reference)) {
      dates <- sort(full$period_date[full$series_reference == reference])
      if (min(dates) > as.Date("2001-01-01") ||
          !identical(dates, seq(min(dates), cutoff, by = "month"))) {
        snz_history_stop("Stats NZ migration full history has incomplete monthly coverage.")
      }
    }
    current_key <- paste(data$series_reference, data$period_date, sep = "\r")
    full_key <- paste(full$series_reference, full$period_date, sep = "\r")
    overlap <- match(current_key, full_key)
    if (anyNA(overlap)) {
      snz_history_stop("Stats NZ migration full history omitted a current release period.")
    }
    values <- full$data_value[overlap]
    if (any(is.na(values) != is.na(data$data_value)) ||
        any(values != data$data_value, na.rm = TRUE)) {
      snz_history_stop("Stats NZ migration full history conflicts with the current release values.")
    }
    # The selected release owns current precision, raw tokens and status flags.
    # Infoshare supplies earlier observations and its own historical metadata.
    result <- snz_bind_rows(list(full[!full_key %in% current_key, , drop = FALSE], data))
    result <- result[order(result$series_reference, result$period_date), , drop = FALSE]
  } else result <- snz_trade_backfill(data,full)
  attachments <- c(list(provenance$attachments),lapply(histories,function(x)statsnz_provenance(x)$attachments))
  provenance$attachments <- tibble::as_tibble(snz_bind_rows(attachments))
  provenance$history_policy <- "Latest official historical series through the selected release endpoint"
  provenance$history_precision <- "Recent trade workbook precision retained; earlier Infoshare quantity and adjusted headline values retain integer serialization."
  result <- tibble::as_tibble(result)
  attr(result,"statsnz_provenance") <- provenance
  class(result) <- unique(c("statsnz_release_data",class(result)))
  result
}

snz_read_migration_workbook <- function(path,source_name,source_url) {
  table <- suppressMessages(readxl::read_excel(path,sheet="Table 3",col_names=FALSE,.name_repair="minimal"))
  codes <- snz_history_text(unlist(table[6L,],use.names=FALSE))
  columns <- which(codes %in% c("SEMAAE","SEMADE","SEMANE"))
  end <- which(snz_history_text(table[[1L]])=="Year ended")
  last <- if(length(end))end[[1L]]-1L else nrow(table)
  if(length(columns)!=3L || last<9L)snz_history_stop("Migration workbook omitted its three exact monthly estimate series.")
  rows<-8:last
  years<-snz_fill_down(snz_history_text(table[[1L]][rows]))
  months<-match(tolower(substr(snz_history_text(table[[2L]][rows]),1L,3L)),tolower(month.abb))
  dates<-snz_parse_period_date(sprintf("%s.%02d",years,months))
  keep<-!is.na(dates)
  frames<-lapply(columns,function(column){
    titles<-snz_history_text(unlist(table[4:5,column,drop=FALSE],use.names=FALSE))
    data<-snz_history_observations("nz_stats_international_migration",paste0("ITMM.",codes[[column]]),
      paste(titles[nzchar(titles)],collapse=" \u2014 "),dates[keep],table[[column]][rows][keep],"Number",
      "International Travel and Migration - ITM","Estimated migration by direction, 12/16-month rule (Monthly)")
    data$status<-snz_history_text(table[[3L]][rows][keep])
    data$source_file<-source_name;data$source_attachment_url<-source_url;data
  })
  snz_bind_rows(frames)
}
