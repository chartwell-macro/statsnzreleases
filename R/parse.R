snz_read_csv <- function(path, source_name, source_url) {
  # readr::guess_encoding() delegates to stringi. Read the sample explicitly so
  # stringi is a declared runtime dependency even in dependency-restricted
  # checks, while retaining readr's detector for non-ASCII input.
  sample <- tryCatch(
    unlist(readr::read_lines_raw(path, n_max = 10000L), use.names = FALSE),
    error = function(error) raw()
  )
  guessed <- tryCatch(
    if (isTRUE(stringi::stri_enc_isascii(sample))) {
      data.frame(encoding = "ASCII", confidence = 1)
    } else {
      suppressWarnings(readr::guess_encoding(sample))
    },
    error = function(error) data.frame()
  )
  encoding <- if (nrow(guessed) > 0L) {
    snz_scalar(guessed$encoding[[1L]], "UTF-8")
  } else {
    "UTF-8"
  }
  if (identical(toupper(encoding), "ASCII")) {
    encoding <- "UTF-8"
  }
  data <- tryCatch(
    readr::read_csv(
      path,
      col_types = readr::cols(.default = readr::col_character()),
      name_repair = "minimal",
      progress = FALSE,
      show_col_types = FALSE,
      na = c("", "NA"),
      locale = readr::locale(encoding = encoding)
    ),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ CSV could not be parsed: %s", conditionMessage(error)),
        class = "statsnz_csv_error",
        path = path
      )
    }
  )
  data <- as.data.frame(data, stringsAsFactors = FALSE, check.names = FALSE)
  names(data) <- snz_clean_names(names(data))
  if ("status_code" %in% names(data) && !"status" %in% names(data)) {
    names(data)[names(data) == "status_code"] <- "status"
  }
  if (!"series_reference" %in% names(data) ||
      !"period" %in% names(data) ||
      !"data_value" %in% names(data)) {
    snz_stop(
      sprintf("Stats NZ CSV `%s` does not contain the expected time-series columns.", source_name),
      class = "statsnz_schema_error",
      path = path
    )
  }
  for (name in names(data)) {
    # readr returns character columns in UTF-8 after applying the detected
    # input encoding. An empty `from` follows the native encoding and can
    # reinterpret those UTF-8 bytes on non-UTF-8 locales.
    data[[name]] <- iconv(
      as.character(data[[name]]),
      from = "UTF-8",
      to = "UTF-8",
      sub = "\uFFFD"
    )
  }
  data$source_file <- source_name
  data$source_attachment_url <- source_url
  data
}

snz_read_zip <- function(path, source_url) {
  contents <- tryCatch(
    utils::unzip(path, list = TRUE),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ ZIP could not be inspected: %s", conditionMessage(error)),
        class = "statsnz_zip_error",
        path = path
      )
    }
  )
  csv_names <- contents$Name[grepl("\\.csv$", contents$Name, ignore.case = TRUE)]
  unsafe <- grepl("(^/|^[A-Za-z]:|(^|/)\\.\\.(/|$))", csv_names)
  if (length(csv_names) == 0L || any(unsafe)) {
    snz_stop(
      "The Stats NZ ZIP does not contain a safe CSV member.",
      class = "statsnz_zip_error",
      path = path
    )
  }

  extraction_dir <- tempfile("statsnzreleases-unzip-")
  dir.create(extraction_dir, recursive = TRUE)
  on.exit(unlink(extraction_dir, recursive = TRUE, force = TRUE), add = TRUE)
  extracted <- tryCatch(
    utils::unzip(path, files = csv_names, exdir = extraction_dir),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ ZIP could not be extracted: %s", conditionMessage(error)),
        class = "statsnz_zip_error",
        path = path
      )
    }
  )
  Map(
    function(file, name) snz_read_csv(file, name, source_url),
    extracted,
    csv_names
  )
}

snz_read_attachment <- function(
    path,
    source_name,
    source_url,
    release_id = "") {
  extension <- tolower(tools::file_ext(source_name))
  if (identical(release_id, "nz_stats_labour") && extension == "zip") {
    return(snz_read_labour_zip(path, source_url))
  }
  if (identical(release_id, "nz_stats_trade") && extension == "xlsx") {
    return(list(snz_read_trade_workbook(path, source_name, source_url)))
  }
  if (extension == "csv") {
    return(list(snz_read_csv(path, source_name, source_url)))
  }
  if (extension == "zip") {
    return(snz_read_zip(path, source_url))
  }
  snz_stop(
    sprintf("Unsupported Stats NZ attachment type: %s", extension),
    class = "statsnz_attachment_type_error",
    path = path
  )
}

snz_series_labels <- function(data, title_columns) {
  label_columns <- c("description", title_columns)
  key_parts <- lapply(label_columns, function(name) {
    value <- as.character(data[[name]])
    value[is.na(value)] <- "\u001d"
    paste0("\u001e", value)
  })
  label_key <- do.call(paste, c(key_parts, sep = "\u001f"))
  unique_index <- !duplicated(label_key)
  unique_rows <- data[unique_index, label_columns, drop = FALSE]
  unique_labels <- vapply(seq_len(nrow(unique_rows)), function(index) {
    description <- snz_scalar(unique_rows$description[[index]])
    if (nzchar(description)) {
      return(description)
    }
    titles <- trimws(unlist(
      unique_rows[index, title_columns, drop = FALSE],
      use.names = FALSE
    ))
    titles <- titles[!is.na(titles) & nzchar(titles)]
    if (length(titles) == 0L) "" else paste(titles, collapse = " \u2014 ")
  }, character(1))
  labels <- unique_labels[match(label_key, label_key[unique_index])]
  missing <- !nzchar(labels)
  labels[missing] <- data$series_reference[missing]
  unname(labels)
}

snz_standardise <- function(
    frames,
    release,
    release_url,
    release_title,
    attachment_provenance,
    retrieved_at) {
  data <- snz_bind_rows(frames)
  if (nrow(data) == 0L) {
    snz_stop(
      "The selected Stats NZ attachments contained no observations.",
      class = "statsnz_empty_data"
    )
  }

  core <- c(
    "status", "units", "magnitude", "subject", "group",
    paste0("series_title_", 1:5), "type", "description", "suppressed"
  )
  for (name in core) {
    if (!name %in% names(data)) {
      data[[name]] <- NA_character_
    }
  }

  data$data_value_raw <- data$data_value
  data$data_value <- suppressWarnings(
    as.numeric(gsub(",", "", data$data_value_raw, fixed = TRUE))
  )
  data$magnitude <- suppressWarnings(as.numeric(data$magnitude))
  data$period_date <- snz_parse_period_date(data$period)

  title_columns <- paste0("series_title_", 1:5)
  data$series_label <- snz_series_labels(data, title_columns)

  key <- paste(data$series_reference, data$period, sep = "\r")
  usable_key <- nzchar(data$series_reference) & nzchar(data$period)
  keep <- !usable_key | !duplicated(key)
  data <- data[keep, , drop = FALSE]

  data$release_id <- release$release_id[[1L]]
  data$release_name <- release$release_name[[1L]]
  data$tier <- as.integer(release$tier[[1L]])
  data$frequency <- release$frequency[[1L]]

  leading <- c(
    "release_id", "release_name", "tier", "frequency",
    "series_reference", "series_label", "period", "period_date",
    "data_value", "data_value_raw", "status", "units", "magnitude",
    "subject", "group", title_columns, "type", "description", "suppressed",
    "source_file", "source_attachment_url"
  )
  leading <- leading[leading %in% names(data)]
  data <- data[c(leading, setdiff(names(data), leading))]
  data <- tibble::as_tibble(data)

  provenance <- list(
    release_id = release$release_id[[1L]],
    release_name = release$release_name[[1L]],
    release_title = release_title,
    release_url = release_url,
    retrieved_at = retrieved_at,
    attachments = tibble::as_tibble(attachment_provenance)
  )
  attr(data, "statsnz_provenance") <- provenance
  class(data) <- unique(c("statsnz_release_data", class(data)))
  data
}

snz_filter_observations <- function(data, series, start_period, end_period) {
  start_period <- snz_validate_period(start_period, "start_period")
  end_period <- snz_validate_period(end_period, "end_period")
  if (!is.null(start_period) && !is.null(end_period) &&
      start_period > end_period) {
    snz_stop(
      "`start_period` must not be later than `end_period`.",
      class = "statsnz_invalid_period"
    )
  }

  keep <- rep(TRUE, nrow(data))
  if (!is.null(series)) {
    series <- unique(as.character(series))
    keep <- keep & data$series_reference %in% series
  }
  if (!is.null(start_period)) {
    keep <- keep & data$period >= start_period
  }
  if (!is.null(end_period)) {
    keep <- keep & data$period <= end_period
  }
  provenance <- attr(data, "statsnz_provenance", exact = TRUE)
  result <- data[keep, , drop = FALSE]
  attr(result, "statsnz_provenance") <- provenance
  class(result) <- unique(c("statsnz_release_data", class(result)))
  result
}
