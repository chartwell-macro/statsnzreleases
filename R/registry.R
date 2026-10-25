#' List Stats NZ release families known to the package
#'
#' `statsnz_releases()` is the package's registry and the starting point for
#' choosing a `release_id`. The registry is read from the installed
#' `inst/extdata/release_manifest.csv`; it does not contact Stats NZ and does
#' not create files. Rows are kept in manifest order so that the result is
#' stable across calls.
#'
#' @param include_unsupported If exactly `TRUE` (the default), include release
#'   families that are known to the package but intentionally deferred. Any
#'   other value returns only rows whose `supported` value is `TRUE`.
#'
#' @return A tibble with one row per known release family and these columns:
#'   \describe{
#'     \item{`release_id`}{Stable identifier accepted by
#'       [read_statsnz_release()] and [statsnz_latest_release()].}
#'     \item{`release_name`}{Human-readable Stats NZ release-family name.}
#'     \item{`tier`}{Integer package priority tier.}
#'     \item{`frequency`}{Nominal release frequency, such as `monthly` or
#'       `quarterly`.}
#'     \item{`title_pattern`}{Case-insensitive regular expression used to
#'       identify the release page.}
#'     \item{`supported`}{Logical support flag used by the public reader.}
#'     \item{`attachment_include`, `attachment_exclude`}{Regular-expression
#'       rules used to select official attachments.}
#'     \item{`attachment_preference`}{Pipe-separated preference tokens used
#'       to order selected attachments.}
#'     \item{`note`}{Package-facing description of the selection or parsing
#'       rule.}
#'   }
#'   `tier` is integer, `supported` is logical, and the remaining columns are
#'   character vectors. The result has classes `tbl_df`, `tbl`, and
#'   `data.frame`.
#'
#' @section Errors:
#' If the installed manifest cannot be located, the function throws a
#' `statsnz_manifest_error` condition (which also inherits from
#' `statsnz_error`). Errors raised while reading a malformed installed CSV are
#' propagated by `readr`.
#'
#' @seealso [read_statsnz_release()] for importing a selected family and
#'   [statsnz_release_files()] for inspecting a release page's attachments.
#'
#' @family release workflows
#'
#' @examples
#' releases <- statsnz_releases()
#' releases[, c("release_id", "frequency", "supported")]
#' statsnz_releases(include_unsupported = FALSE)
#' @export
statsnz_releases <- function(include_unsupported = TRUE) {
  path <- system.file(
    "extdata",
    "release_manifest.csv",
    package = "statsnzreleases"
  )
  if (!nzchar(path)) {
    snz_stop(
      "The installed release manifest could not be found.",
      class = "statsnz_manifest_error"
    )
  }
  result <- readr::read_csv(
    path,
    col_types = readr::cols(.default = readr::col_character()),
    na = character(),
    name_repair = "minimal",
    progress = FALSE,
    show_col_types = FALSE
  )
  result$supported <- tolower(result$supported) == "true"
  result$tier <- as.integer(result$tier)
  if (!isTRUE(include_unsupported)) {
    result <- result[result$supported, , drop = FALSE]
  }
  tibble::as_tibble(result)
}

snz_release_definition <- function(release_id, require_supported = TRUE) {
  release_id <- snz_assert_release_id(release_id)
  registry <- statsnz_releases(include_unsupported = TRUE)
  match <- registry[registry$release_id == release_id, , drop = FALSE]
  if (nrow(match) != 1L) {
    snz_stop(
      sprintf("Unknown Stats NZ release ID: %s", release_id),
      class = "statsnz_unknown_release",
      release_id = release_id
    )
  }
  if (isTRUE(require_supported) && !isTRUE(match$supported[[1L]])) {
    snz_stop(
      sprintf(
        "%s is not supported in this package version. %s",
        match$release_name[[1L]],
        match$note[[1L]]
      ),
      class = "statsnz_unsupported_release",
      release_id = release_id
    )
  }
  match
}
