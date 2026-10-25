#' Read a major Stats NZ economic release
#'
#' Discovers the latest published release by default, downloads the package's
#' selected official attachments, and returns a standardised time-series table.
#' Supply `release_url` to make a historical release fully reproducible.
#'
#' @param release_id A supported release ID returned by [statsnz_releases()].
#' @param release_url Optional explicit Stats NZ information-release URL.
#' @param as_of When `release_url` is `NULL`, only consider releases published
#'   on or before this date.
#' @param lookback_months Number of release-calendar months to inspect.
#' @param series Optional vector of exact Stats NZ series references.
#' @param start_period,end_period Optional inclusive bounds using `YYYY` or
#'   `YYYY.MM` notation.
#' @param cache_dir Directory for downloaded official attachments.
#' @param refresh Download attachments again even when cached.
#' @param quiet Suppress download progress.
#'
#' @return A `statsnz_release_data` tibble with standardised columns and
#'   attachment provenance.
#' @export
read_statsnz_release <- function(
    release_id,
    release_url = NULL,
    as_of = Sys.Date(),
    lookback_months = 18L,
    series = NULL,
    start_period = NULL,
    end_period = NULL,
    cache_dir = statsnz_cache_dir(),
    refresh = FALSE,
    quiet = FALSE) {
  release <- snz_release_definition(release_id)
  if (is.null(release_url)) {
    latest <- snz_latest_release(release, as_of, lookback_months)
    release_url <- latest$url[[1L]]
  }
  release_url <- snz_assert_official_url(
    release_url,
    information_release = TRUE
  )

  files <- statsnz_release_files(release_url)
  release_title <- snz_scalar(files$release_title)
  if (!grepl(
    release$title_pattern[[1L]],
    release_title,
    ignore.case = TRUE
  )) {
    snz_stop(
      sprintf(
        "The supplied page is `%s`, not a %s release.",
        release_title,
        release$release_name[[1L]]
      ),
      class = "statsnz_release_mismatch",
      release_id = release$release_id[[1L]],
      url = release_url
    )
  }
  selected <- snz_select_attachments(files, release)
  retrieved_at <- Sys.time()
  paths <- vapply(seq_len(nrow(selected)), function(index) {
    snz_download(
      selected$url[[index]],
      release_id = release$release_id[[1L]],
      cache_dir = cache_dir,
      refresh = refresh,
      quiet = quiet
    )
  }, character(1))

  frames <- unlist(Map(
    function(path, name, url) snz_read_attachment(
      path,
      name,
      url,
      release_id = release$release_id[[1L]]
    ),
    paths,
    selected$name,
    selected$url
  ), recursive = FALSE)
  attachment_provenance <- data.frame(
    name = selected$name,
    title = selected$title,
    url = selected$url,
    cache_path = paths,
    bytes = as.numeric(file.info(paths)$size),
    sha256 = vapply(
      paths,
      digest::digest,
      algo = "sha256",
      file = TRUE,
      FUN.VALUE = character(1)
    ),
    stringsAsFactors = FALSE
  )

  result <- snz_standardise(
    frames,
    release = release,
    release_url = release_url,
    release_title = release_title,
    attachment_provenance = attachment_provenance,
    retrieved_at = retrieved_at
  )
  snz_filter_observations(result, series, start_period, end_period)
}

#' Return provenance for imported Stats NZ data
#'
#' @param x An object returned by [read_statsnz_release()].
#'
#' @return A list containing the release URL, retrieval time, and attachment
#'   URLs, cache paths, sizes, and SHA-256 hashes.
#' @export
statsnz_provenance <- function(x) {
  provenance <- attr(x, "statsnz_provenance", exact = TRUE)
  if (is.null(provenance)) {
    snz_stop(
      "`x` does not contain Stats NZ release provenance.",
      class = "statsnz_provenance_error"
    )
  }
  provenance
}

#' @export
print.statsnz_release_data <- function(x, ...) {
  provenance <- attr(x, "statsnz_provenance", exact = TRUE)
  cat(
    sprintf(
      "# Stats NZ release: %s\n# Release page: %s\n",
      provenance$release_title %||% "",
      provenance$release_url %||% ""
    )
  )
  NextMethod()
}
