#' List Stats NZ release families known to the package
#'
#' @param include_unsupported Include release families that are intentionally
#'   deferred.
#'
#' @return A tibble containing release IDs, matching rules, and support status.
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
