snz_calendar_months <- function(as_of, lookback_months) {
  as_of <- as.Date(as_of)
  if (length(as_of) != 1L || is.na(as_of)) {
    snz_stop("`as_of` must be a valid date.", class = "statsnz_invalid_date")
  }
  lookback_months <- as.integer(lookback_months)
  if (is.na(lookback_months) || lookback_months < 1L ||
      lookback_months > 120L) {
    snz_stop(
      "`lookback_months` must be between 1 and 120.",
      class = "statsnz_invalid_argument"
    )
  }
  start <- as.Date(format(as_of, "%Y-%m-01"))
  format(seq(start, by = "-1 month", length.out = lookback_months), "%Y-%m")
}

snz_parse_calendar_month <- function(raw, release, as_of, month) {
  payload <- tryCatch(
    jsonlite::fromJSON(rawToChar(raw), simplifyVector = FALSE),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ calendar JSON could not be parsed: %s", conditionMessage(error)),
        class = "statsnz_calendar_parse_error"
      )
    }
  )
  published <- payload$items$published %||% list()
  if (!is.list(published) || length(published) == 0L) {
    return(data.frame())
  }

  rows <- lapply(published, function(item) {
    title <- snz_scalar(item$Title %||% item$DateTaxonomyTerm$DisplayName)
    publication <- snz_scalar(
      item$DateTaxonomyTerm$PublicationDate %||% item$PageDate
    )
    link <- snz_scalar(item$PageLink)
    if (!grepl(release$title_pattern[[1L]], title, ignore.case = TRUE) ||
        !nzchar(publication) || !nzchar(link)) {
      return(NULL)
    }
    publication_date <- suppressWarnings(as.Date(substr(publication, 1L, 10L)))
    if (is.na(publication_date) || publication_date > as.Date(as_of)) {
      return(NULL)
    }
    data.frame(
      release_id = release$release_id[[1L]],
      title = title,
      publication_date = publication_date,
      publication_time = publication,
      url = xml2::url_absolute(link, "https://www.stats.govt.nz/"),
      calendar_month = month,
      stringsAsFactors = FALSE
    )
  })
  snz_bind_rows(rows)
}

snz_latest_release <- function(
    release,
    as_of,
    lookback_months,
    fetch_fun = snz_fetch_memory) {
  months <- snz_calendar_months(as_of, lookback_months)
  failures <- character()

  for (index in seq_along(months)) {
    url <- paste0(
      "https://www.stats.govt.nz/api/v1/releaseCalendarMonth/",
      months[[index]]
    )
    raw <- tryCatch(
      fetch_fun(url),
      error = function(error) {
        failures <<- c(failures, conditionMessage(error))
        NULL
      }
    )
    if (!is.null(raw)) {
      results <- snz_parse_calendar_month(
        raw,
        release = release,
        as_of = as_of,
        month = months[[index]]
      )
      if (nrow(results) > 0L) {
        results <- results[
          order(results$publication_date, decreasing = TRUE),
          ,
          drop = FALSE
        ]
        return(results[1L, , drop = FALSE])
      }
    }
  }

  detail <- if (length(failures) > 0L) {
    paste0(" Calendar requests also reported: ", failures[[1L]])
  } else {
    ""
  }
  snz_stop(
    paste0(
      "No published Stats NZ release was found in the requested lookback window.",
      detail
    ),
    class = "statsnz_release_not_found",
    release_id = release$release_id[[1L]]
  )
}

#' Find the latest published information release
#'
#' @param release_id A release ID returned by [statsnz_releases()].
#' @param as_of Only consider releases published on or before this date.
#' @param lookback_months Number of release-calendar months to inspect.
#'
#' @return A one-row tibble describing the latest published release.
#' @export
statsnz_latest_release <- function(
    release_id,
    as_of = Sys.Date(),
    lookback_months = 18L) {
  release <- snz_release_definition(release_id)
  result <- snz_latest_release(release, as_of, lookback_months)
  tibble::as_tibble(result)
}
