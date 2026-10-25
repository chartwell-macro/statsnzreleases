`%||%` <- function(x, y) {
  if (is.null(x) || length(x) == 0L) y else x
}

snz_scalar <- function(x, default = "") {
  if (is.null(x) || length(x) == 0L || is.na(x[[1L]])) {
    return(default)
  }
  value <- iconv(
    as.character(x[[1L]]),
    from = "",
    to = "UTF-8",
    sub = "\uFFFD"
  )
  trimws(value)
}

snz_stop <- function(message, class = "statsnz_error", ...) {
  condition <- structure(
    list(message = message, call = NULL, ...),
    class = c(class, "statsnz_error", "error", "condition")
  )
  stop(condition)
}

snz_assert_release_id <- function(release_id) {
  release_id <- snz_scalar(release_id)
  if (!grepl("^nz_stats_[a-z_]+$", release_id)) {
    snz_stop(
      "A valid Stats NZ release ID is required.",
      class = "statsnz_invalid_release"
    )
  }
  release_id
}

snz_assert_official_url <- function(url, information_release = FALSE) {
  url <- snz_scalar(url)
  pattern <- if (isTRUE(information_release)) {
    "^https://www\\.stats\\.govt\\.nz/information-releases/"
  } else {
    "^https://(www\\.)?stats\\.govt\\.nz/"
  }
  if (!grepl(pattern, url, ignore.case = TRUE)) {
    snz_stop(
      "Only official HTTPS Stats NZ URLs are accepted.",
      class = "statsnz_invalid_url",
      url = url
    )
  }
  url
}

snz_bind_rows <- function(frames) {
  frames <- Filter(function(x) is.data.frame(x) && nrow(x) > 0L, frames)
  if (length(frames) == 0L) {
    return(data.frame())
  }
  all_names <- unique(unlist(lapply(frames, names), use.names = FALSE))
  frames <- lapply(frames, function(frame) {
    missing <- setdiff(all_names, names(frame))
    for (name in missing) {
      frame[[name]] <- NA_character_
    }
    frame[all_names]
  })
  result <- do.call(rbind, frames)
  rownames(result) <- NULL
  result
}

snz_clean_names <- function(names) {
  names <- enc2utf8(names)
  names <- gsub("([a-z0-9])([A-Z])", "\\1_\\2", names)
  names <- tolower(gsub("[^A-Za-z0-9]+", "_", names))
  names <- gsub("^_+|_+$", "", names)
  names[names == "magntude"] <- "magnitude"
  make.unique(names, sep = "_")
}

snz_parse_period_date <- function(period) {
  period <- as.character(period)
  result <- rep(as.Date(NA), length(period))
  monthly <- which(
    !is.na(period) &
      grepl("^[0-9]{4}\\.(0[1-9]|1[0-2])$", period)
  )
  annual <- which(!is.na(period) & grepl("^[0-9]{4}$", period))
  if (length(monthly) > 0L) {
    result[monthly] <- as.Date(
      paste0(sub("\\.", "-", period[monthly]), "-01")
    )
  }
  if (length(annual) > 0L) {
    result[annual] <- as.Date(paste0(period[annual], "-01-01"))
  }
  result
}

snz_validate_period <- function(period, argument) {
  if (is.null(period)) {
    return(NULL)
  }
  period <- snz_scalar(period)
  if (!grepl("^[0-9]{4}(\\.(0[1-9]|1[0-2]))?$", period)) {
    snz_stop(
      sprintf("`%s` must use YYYY or YYYY.MM notation.", argument),
      class = "statsnz_invalid_period"
    )
  }
  period
}
