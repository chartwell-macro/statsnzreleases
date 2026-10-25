snz_user_agent <- function() {
  sprintf(
    "statsnzreleases/0.1.0 (R/%s; release-file importer)",
    getRversion()
  )
}

snz_handle <- function(timeout = 60) {
  curl::new_handle(
    useragent = snz_user_agent(),
    followlocation = TRUE,
    connecttimeout = min(15, timeout),
    timeout = timeout,
    accept_encoding = "gzip"
  )
}

snz_fetch_memory <- function(url, timeout = 60, max_bytes = 10 * 1024^2) {
  snz_assert_official_url(url)
  response <- tryCatch(
    curl::curl_fetch_memory(url, handle = snz_handle(timeout)),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ request failed: %s", conditionMessage(error)),
        class = "statsnz_request_error",
        url = url
      )
    }
  )
  status <- as.integer(response$status_code %||% 0L)
  if (status < 200L || status >= 300L) {
    snz_stop(
      sprintf("Stats NZ returned HTTP %s.", status),
      class = "statsnz_http_error",
      url = url,
      status = status
    )
  }
  if (length(response$content) > max_bytes) {
    snz_stop(
      "The Stats NZ response exceeded the in-memory safety limit.",
      class = "statsnz_response_too_large",
      url = url
    )
  }
  response$content
}

#' Return the default package cache directory
#'
#' `statsnz_cache_dir()` reports the user-level cache location used by
#' [read_statsnz_release()] when its `cache_dir` argument is omitted. The path
#' is supplied by `tools::R_user_dir()` and therefore follows the operating
#' system's R user-cache conventions rather than writing into the package
#' installation or the current project.
#'
#' @return A length-one character path. The directory may not exist yet: it is
#'   created lazily only when an attachment must be downloaded. Calling this
#'   function alone does not create files or directories.
#'
#' @section Cache behaviour:
#' Downloaded attachments are stored below this path in a release-specific
#' directory. Existing non-empty files are reused unless `refresh = TRUE` is
#' supplied to [read_statsnz_release()]. Attachment provenance records the
#' resulting cache path, byte count, and SHA-256 digest; this helper itself does
#' not perform network requests.
#'
#' @seealso [read_statsnz_release()] for the cache-writing operation and
#'   [statsnz_provenance()] for recorded cache metadata.
#'
#' @family release workflows
#'
#' @examples
#' cache <- statsnz_cache_dir()
#' stopifnot(is.character(cache), length(cache) == 1L, nzchar(cache))
#' basename(cache)
#' @export
statsnz_cache_dir <- function() {
  tools::R_user_dir("statsnzreleases", which = "cache")
}

snz_cache_path <- function(url, release_id, cache_dir) {
  basename <- basename(strsplit(url, "[?#]", perl = TRUE)[[1L]][[1L]])
  if (!nzchar(basename)) {
    basename <- "attachment"
  }
  fingerprint <- substr(
    digest::digest(url, algo = "sha256", serialize = FALSE),
    1L,
    16L
  )
  file.path(cache_dir, release_id, paste0(fingerprint, "-", basename))
}

snz_download <- function(
    url,
    release_id,
    cache_dir,
    refresh = FALSE,
    quiet = FALSE,
    timeout = 300) {
  snz_assert_official_url(url)
  target <- snz_cache_path(url, release_id, cache_dir)
  if (file.exists(target) && !isTRUE(refresh) && file.info(target)$size > 0) {
    return(target)
  }

  dir.create(dirname(target), recursive = TRUE, showWarnings = FALSE)
  temporary <- tempfile(
    pattern = paste0(".", basename(target), "-"),
    tmpdir = dirname(target)
  )
  on.exit(unlink(temporary, force = TRUE), add = TRUE)

  tryCatch(
    curl::curl_download(
      url,
      destfile = temporary,
      quiet = quiet,
      mode = "wb",
      handle = snz_handle(timeout)
    ),
    error = function(error) {
      snz_stop(
        sprintf(
          "Could not download Stats NZ attachment: %s",
          conditionMessage(error)
        ),
        class = "statsnz_download_error",
        url = url
      )
    }
  )
  if (!file.exists(temporary) || file.info(temporary)$size <= 0) {
    snz_stop(
      "Stats NZ returned an empty attachment.",
      class = "statsnz_download_error",
      url = url
    )
  }
  if (!file.rename(temporary, target)) {
    copied <- file.copy(temporary, target, overwrite = TRUE)
    if (!isTRUE(copied)) {
      snz_stop(
        "The downloaded attachment could not be placed in the cache.",
        class = "statsnz_cache_error",
        path = target
      )
    }
  }
  target
}
