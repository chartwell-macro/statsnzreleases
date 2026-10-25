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
#' `statsnz_latest_release()` walks the official Stats NZ release-calendar API
#' backwards from the month containing `as_of`. It returns the newest matching
#' page whose publication date is not later than `as_of`. Use the returned `url`
#' with [read_statsnz_release()] when you want to inspect or import exactly that
#' release.
#'
#' @param release_id A supported release ID returned by
#'   [statsnz_releases()]. The ID is matched against the installed registry.
#' @param as_of A single value coercible to `Date`; only releases published on
#'   or before this date are considered. The default is `Sys.Date()`.
#' @param lookback_months A value coercible to an integer number of
#'   release-calendar months from 1 through 120. The default is `18L`.
#'   Calendar requests are made in reverse chronological order until a
#'   matching release is found.
#'
#' @return A one-row tibble with classes `tbl_df`, `tbl`, and `data.frame`, and
#'   these columns: `release_id` (character), `title` (character),
#'   `publication_date` (`Date`), `publication_time` (character as supplied by
#'   Stats NZ), `url` (absolute official HTTPS release-page URL), and
#'   `calendar_month` (character `YYYY-MM`). The result is deterministic for a
#'   fixed calendar response and `as_of` date.
#'
#' @section Network and side effects:
#' The function makes one HTTPS GET request per inspected calendar month to
#' `https://www.stats.govt.nz/api/v1/releaseCalendarMonth/YYYY-MM`. It does not
#' use or populate the attachment cache and does not write files. Requests use
#' the package's bounded curl timeouts. A failed request is skipped so that an
#' earlier month can still be examined; a malformed successful response is a
#' parse failure.
#'
#' @section Errors:
#' Invalid `as_of` values throw `statsnz_invalid_date`; an out-of-range
#' `lookback_months` throws `statsnz_invalid_argument`; malformed calendar JSON
#' throws `statsnz_calendar_parse_error`; an unknown or unsupported ID throws
#' `statsnz_unknown_release` or `statsnz_unsupported_release`, respectively.
#' If no matching release is found, the function throws
#' `statsnz_release_not_found` and includes the release ID (and, when
#' applicable, the first request failure) in the condition.
#'
#' @seealso [statsnz_releases()] for supported IDs and
#'   [statsnz_release_files()] for the selected page's attachments.
#'
#' @family release workflows
#'
#' @examples
#' # The registry lookup is fully offline.
#' statsnz_releases()[1, c("release_id", "release_name")]
#'
#' # A deterministic calendar response can be used in examples and tests.
#' if (requireNamespace("testthat", quietly = TRUE)) {
#'   payload <- list(items = list(published = list(list(
#'     Title = "Consumers price index: June 2026 quarter",
#'     PageLink = "/information-releases/consumers-price-index-june-2026-quarter/",
#'     DateTaxonomyTerm = list(PublicationDate = "2026-07-21 10:45:00")
#'   ))))
#'   testthat::local_mocked_bindings(
#'     snz_fetch_memory = function(url) {
#'       charToRaw(jsonlite::toJSON(payload, auto_unbox = TRUE))
#'     },
#'     .package = "statsnzreleases"
#'   )
#'   statsnz_latest_release(
#'     "nz_stats_cpi",
#'     as_of = as.Date("2026-07-31"),
#'     lookback_months = 1L
#'   )
#' }
#' @export
statsnz_latest_release <- function(
    release_id,
    as_of = Sys.Date(),
    lookback_months = 18L) {
  release <- snz_release_definition(release_id)
  result <- snz_latest_release(release, as_of, lookback_months)
  tibble::as_tibble(result)
}
