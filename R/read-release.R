#' Read a major Stats NZ economic release
#'
#' Read the selected official data attachments for a supported Stats NZ
#' information release and return one standardised time-series table. By
#' default, the package searches the official release calendar for the latest
#' publication. Supplying `release_url` selects a specific historical page and
#' avoids that moving target.
#'
#' @param release_id A supported release ID returned by
#'   [statsnz_releases()]. The current supported IDs are
#'   `nz_stats_cpi`, `nz_stats_gdp`, `nz_stats_electronic_cards`,
#'   `nz_stats_retail`, `nz_stats_balance_payments`, `nz_stats_labour`, and
#'   `nz_stats_trade`.
#' @param release_url Optional official Stats NZ information-release URL. It
#'   must use HTTPS and the `/information-releases/` path. When supplied, the
#'   page is read directly; otherwise the calendar is searched using `as_of`
#'   and `lookback_months`.
#' @param as_of A single date, or a value coercible to one, used only when
#'   `release_url` is `NULL`. Publications after this date are ignored. The
#'   default is `Sys.Date()`.
#' @param lookback_months Number of calendar months to inspect when discovering
#'   a release. The default is `18L`; values must be between 1 and 120.
#' @param series Optional character vector of exact Stats NZ
#'   `series_reference` values. If supplied, only matching observations are
#'   returned; duplicates in this vector have no effect.
#' @param start_period Optional inclusive lower period bound in `YYYY` or
#'   `YYYY.MM` notation. `NULL` (the default) leaves the lower bound open.
#' @param end_period Optional inclusive upper period bound in `YYYY` or
#'   `YYYY.MM` notation. `NULL` (the default) leaves the upper bound open.
#' @param cache_dir Directory used for downloaded official attachments. The
#'   default is [statsnz_cache_dir()]. A release-specific subdirectory is
#'   created when a download is needed.
#' @param refresh Logical flag. If `TRUE`, download selected attachments again
#'   even when a non-empty cached file already exists. The default is `FALSE`.
#' @param quiet Logical flag passed to the download operation. The default is
#'   `FALSE`; set it to `TRUE` to suppress download progress.
#'
#' @details
#' The reader first validates the release ID and page URL, discovers the page
#' when necessary, and selects the attachment files configured for that release
#' family. CSV, ZIP, and (for overseas merchandise trade) XLSX attachments are
#' parsed into a common table. Standardisation preserves the source value in
#' `data_value_raw`, converts `data_value` and `magnitude` to numeric values,
#' derives `period_date`, and adds release and attachment metadata. Rows with
#' the same non-empty `series_reference` and `period` are de-duplicated while
#' retaining the first selected attachment's row.
#'
#' `start_period` and `end_period` are inclusive string comparisons on the
#' source `period` field. Monthly periods use `YYYY.MM`; annual periods use
#' `YYYY`. A filtered result retains the `statsnz_release_data` class and its
#' `statsnz_provenance` attribute.
#'
#' @section Network and cache:
#' Calendar, release-page, and attachment requests are made only to official
#' HTTPS Stats NZ URLs. The default cache is the platform-specific
#' [tools::R_user_dir()] cache for this package; downloads use temporary files
#' before being placed in the cache. The release page has a bounded request
#' size, and attachment downloads have a bounded timeout. A public read still
#' fetches and validates the release page when a non-empty attachment is already
#' cached; the cache avoids only the attachment download. No credentials are
#' requested or stored. Use an explicit `release_url` and retain the
#' provenance returned by [statsnz_provenance()] when a run must be audited;
#' the provenance includes the bytes and SHA-256 hash of each selected local
#' attachment.
#'
#' @section Errors and limitations:
#' Invalid IDs, URLs, dates, periods, unsupported families, mismatched release
#' pages, missing or changed attachments, HTTP failures, parser failures, and
#' schema or empty-data failures are reported as `statsnz_error` conditions
#' with more specific classes such as `statsnz_invalid_url`,
#' `statsnz_release_mismatch`, `statsnz_request_error`,
#' `statsnz_download_error`, `statsnz_csv_error`, and
#' `statsnz_schema_error`. The package supports the release families listed in
#' `release_id`; it does not promise to import every file published by Stats
#' NZ, and a future change to an official page or attachment format can make a
#' previously valid request fail.
#'
#' @return A tibble with class `c("statsnz_release_data", "tbl_df", "tbl",
#'   "data.frame")`. The leading standardised columns, in order when present,
#'   are `release_id`, `release_name`, `tier`, `frequency`,
#'   `series_reference`, `series_label`, `period`, `period_date`,
#'   `data_value`, `data_value_raw`, `status`, `units`, `magnitude`,
#'   `subject`, `group`, `series_title_1` through `series_title_5`, `type`,
#'   `description`, `suppressed`, `source_file`, and
#'   `source_attachment_url`; source-specific columns may follow. `tier` is
#'   integer; `data_value` and `magnitude` are numeric; `period_date` is a
#'   `Date`; and source text columns are character vectors. The object has a
#'   `statsnz_provenance` attribute; see [statsnz_provenance()] for its
#'   structure.
#'
#' @seealso [statsnz_releases()] to discover IDs, [statsnz_latest_release()]
#'   to inspect the calendar result, [statsnz_release_files()] to inspect a
#'   page before reading it, and [statsnz_provenance()] for audit metadata.
#'
#' @family release workflows
#'
#' @examples
#' # The registry is packaged with the release manifest, so this is offline.
#' statsnz_releases(include_unsupported = FALSE)
#'
#' # A deterministic small read using the same public reader and a mocked
#' # transport. The mock keeps examples independent of network availability.
#' if (requireNamespace("testthat", quietly = TRUE)) {
#'   fixture <- system.file(
#'     "extdata", "example-release.csv", package = "statsnzreleases"
#'   )
#'   page <- tibble::tibble(
#'     name = "gross-domestic-product-test-quarter.csv",
#'     title = "TEST schema fixture",
#'     extension = "csv",
#'     stated_size = "1 KB",
#'     url = paste0(
#'       "https://www.stats.govt.nz/assets/",
#'       "gross-domestic-product-test-quarter.csv"
#'     ),
#'     release_title = "Gross domestic product: TEST schema fixture",
#'     release_url = paste0(
#'       "https://www.stats.govt.nz/information-releases/",
#'       "gross-domestic-product-test-quarter/"
#'     )
#'   )
#'   testthat::local_mocked_bindings(
#'     statsnz_release_files = function(release_url) page,
#'     snz_download = function(...) fixture,
#'     .package = "statsnzreleases"
#'   )
#'   example_data <- read_statsnz_release(
#'     "nz_stats_gdp",
#'     release_url = page$release_url[[1L]],
#'     series = "TEST.S1",
#'     start_period = "2025.06",
#'     cache_dir = tempdir(),
#'     quiet = TRUE
#'   )
#'   example_data[, c("series_reference", "period", "data_value")]
#' }
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
#' Extract the attachment-level audit record stored on an object returned by
#' [read_statsnz_release()]. Filtering a release table does not remove this
#' attribute, so the same function can be used after selecting series or
#' periods.
#'
#' @param x A `statsnz_release_data` object returned by
#'   [read_statsnz_release()], or a filtered object that retains its
#'   `statsnz_provenance` attribute.
#'
#' @details
#' The returned record describes the release page and every selected local
#' attachment at the time of the read. It records the retrieval timestamp,
#' cache path, byte count, and SHA-256 digest; it does not fetch the network or
#' recompute a digest.
#'
#' @return A named list with `release_id`, `release_name`, `release_title`,
#'   `release_url`, `retrieved_at`, and `attachments`. `retrieved_at` is a
#'   `POSIXct` timestamp. `attachments` is a tibble with `name`, `title`,
#'   `url`, `cache_path`, numeric `bytes`, and character `sha256` columns.
#'
#' @section Errors:
#' If `x` has no exact `statsnz_provenance` attribute, the function signals a
#' `statsnz_provenance_error` condition.
#'
#' @seealso [read_statsnz_release()] to create the object and
#'   [statsnz_cache_dir()] for the default cache location.
#'
#' @family release workflows
#'
#' @examples
#' example_data <- tibble::tibble(
#'   series_reference = "DEMO.S1",
#'   period = "2025.03",
#'   data_value = 10.5
#' )
#' class(example_data) <- c("statsnz_release_data", class(example_data))
#' attr(example_data, "statsnz_provenance") <- list(
#'   release_id = "nz_stats_gdp",
#'   release_name = "Gross Domestic Product",
#'   release_title = "Gross domestic product: demo quarter",
#'   release_url = paste0(
#'     "https://www.stats.govt.nz/information-releases/",
#'     "gross-domestic-product-demo-quarter/"
#'   ),
#'   retrieved_at = as.POSIXct("2026-01-01", tz = "UTC"),
#'   attachments = tibble::tibble(
#'     name = "demo.csv",
#'     title = "Demo CSV",
#'     url = "https://www.stats.govt.nz/assets/demo.csv",
#'     cache_path = "demo.csv",
#'     bytes = 42,
#'     sha256 = "demo-sha256"
#'   )
#' )
#' statsnz_provenance(example_data)
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

#' Print a Stats NZ release-data object
#'
#' Print the release title and source page before delegating to the standard
#' tibble method. This method is registered for objects with class
#' `statsnz_release_data` returned by [read_statsnz_release()].
#'
#' @param x A `statsnz_release_data` object with a `statsnz_provenance`
#'   attribute.
#' @param ... Additional arguments passed to the next `print()` method.
#'
#' @return The object `x`, invisibly, as returned by the delegated print
#'   method.
#'
#' @section Output:
#' Two header lines are written before the usual tibble display: the release
#' title and the information-release URL. The data itself is not modified.
#'
#' @seealso [read_statsnz_release()] and [statsnz_provenance()].
#'
#' @family release workflows
#'
#' @examples
#' printed_data <- tibble::tibble(
#'   series_reference = "DEMO.S1",
#'   period = "2025.03",
#'   data_value = 10.5
#' )
#' class(printed_data) <- c("statsnz_release_data", class(printed_data))
#' attr(printed_data, "statsnz_provenance") <- list(
#'   release_title = "Gross domestic product: demo quarter",
#'   release_url = paste0(
#'     "https://www.stats.govt.nz/information-releases/",
#'     "gross-domestic-product-demo-quarter/"
#'   )
#' )
#' print(printed_data)
#' @method print statsnz_release_data
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
