#' statsnzreleases: reproducible Stats NZ release-file imports
#'
#' `statsnzreleases` imports selected official data attachments from major New
#' Zealand economic information releases and standardises them as tidy
#' time-series tables. It is intended for analysts who need release-file data,
#' attachment-level provenance, and a reproducible alternative to manually
#' downloading files from Stats NZ information-release pages.
#'
#' @details
#' The package uses the official Stats NZ release calendar and
#' `/information-releases/` pages. It complements, rather than replaces, the
#' Aotearoa Data Explorer API: some release families continue to publish their
#' historical or specialised files through release pages, Infoshare-style CSV
#' exports, ZIP archives, or XLSX workbooks.
#'
#' This package does not query the Aotearoa Data Explorer catalogue or data
#' endpoints and does not accept an API subscription key. The
#' [statsnz_latest_release()] discovery helper instead uses the separate,
#' credential-free Stats NZ website release-calendar endpoint. Reads then fetch
#' the selected information-release page and its official attachments. See the
#' Stats NZ [API guide](https://portal.apis.stats.govt.nz/api-guide) for the
#' Data Explorer's dataset-query workflow.
#'
#' Start with [statsnz_releases()] to inspect the release registry, use
#' [read_statsnz_release()] to import a family, and inspect
#' [statsnz_provenance()] when a result must be audited. [statsnz_latest_release()]
#' helps discover a current page and [statsnz_release_files()] lets users
#' inspect a page's attachments before downloading them.
#'
#' @section Supported release families:
#' The current registry supports Consumers Price Index (`nz_stats_cpi`), Gross
#' Domestic Product (`nz_stats_gdp`), Electronic Card Transactions
#' (`nz_stats_electronic_cards`), Retail Trade Survey (`nz_stats_retail`),
#' Balance of Payments and International Investment Position
#' (`nz_stats_balance_payments`), Labour Market Statistics (`nz_stats_labour`,
#' a curated quarterly HLFS/QES/LCI headline set), and Overseas Merchandise
#' Trade (`nz_stats_trade`, curated monthly and quarterly workbook tables).
#' The registry is the source of truth for support status and attachment rules;
#' publication of a file by Stats NZ does not imply that every file is imported.
#'
#' @section Network, cache, and provenance:
#' Requests use official HTTPS Stats NZ URLs and do not require credentials.
#' Downloaded attachments are cached in the platform-specific
#' [statsnz_cache_dir()] location. Results carry release-page and
#' attachment-level provenance, including local cache paths, byte counts, and
#' SHA-256 hashes. For a stable target, pass an explicit historical
#' `release_url`; the URL identifies the page, while the provenance hash records
#' the bytes actually read.
#'
#' @section Scope and limitations:
#' The package is a focused release-file importer, not a general Stats NZ API
#' client or a guarantee that every historical release format will remain
#' unchanged. Network access is required to discover or fetch the release page;
#' after that page is fetched, non-empty cached attachments can be reused. A
#' changed official URL, attachment name, schema, or file format can require a
#' package update. The package does not silently fall back to Data Explorer:
#' changing from a published attachment to an API query could change the output
#' schema, revision state, and provenance.
#'
#' @section Licensing and source rights:
#' Package code is released under the MIT license, copyright Chartwell Macro. Data and
#' publications obtained from Stats NZ retain their own copyright, attribution,
#' and source-specific terms. The package preserves official release and
#' attachment URLs so users can cite the source and check the applicable terms
#' before redistribution.
#'
#' @seealso [statsnz_releases()], [read_statsnz_release()],
#'   [statsnz_latest_release()], [statsnz_release_files()],
#'   [statsnz_provenance()], and [statsnz_cache_dir()].
#'
#' @author Chartwell Macro
#'
#' @keywords package
#' @docType package
"_PACKAGE"
