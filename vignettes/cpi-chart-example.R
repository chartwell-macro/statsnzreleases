statsnz_example_cpi <- function() {
  fixture <- system.file(
    "extdata",
    "cpi-tradables-non-tradables-june-2026.csv",
    package = "statsnzreleases"
  )
  if (!nzchar(fixture)) {
    candidates <- c(
      file.path(
        "inst", "extdata", "cpi-tradables-non-tradables-june-2026.csv"
      ),
      file.path(
        "..", "inst", "extdata",
        "cpi-tradables-non-tradables-june-2026.csv"
      )
    )
    existing <- candidates[file.exists(candidates)]
    if (length(existing) > 0L) {
      fixture <- existing[[1L]]
    }
  }
  stopifnot(nzchar(fixture), file.exists(fixture))

  release_url <- paste0(
    "https://www.stats.govt.nz/information-releases/",
    "consumers-price-index-june-2026-quarter/"
  )
  attachment_name <- paste0(
    "consumers-price-index-june-2026-quarter-",
    "tradeables-and-non-tradeables.csv"
  )
  files <- tibble::tibble(
    name = attachment_name,
    title = paste0(
      "Consumers price index: June 2026 quarter – ",
      "tradeables and non-tradeables – CSV"
    ),
    extension = "csv",
    stated_size = "2.4 MB",
    url = paste0(
      "https://www.stats.govt.nz/assets/Uploads/Consumers-price-index/",
      "Consumers-price-index-June-2026-quarter/Download-data/",
      attachment_name
    ),
    release_title = "Consumers price index: June 2026 quarter",
    release_url = release_url
  )

  result <- testthat::with_mocked_bindings(
    statsnzreleases::read_statsnz_release(
      "nz_stats_cpi",
      release_url = release_url,
      series = c("CPIQ.SE9NS6000", "CPIQ.SE9NS6500"),
      start_period = "2016.03",
      end_period = "2026.06",
      cache_dir = tempfile("statsnzreleases-chart-cache-"),
      quiet = TRUE
    ),
    statsnz_release_files = function(release_url) files,
    snz_download = function(...) fixture,
    .package = "statsnzreleases"
  )

  stopifnot(
    inherits(result, "statsnz_release_data"),
    nrow(result) == 84L,
    identical(
      sort(unique(result$series_reference)),
      c("CPIQ.SE9NS6000", "CPIQ.SE9NS6500")
    )
  )
  result
}
