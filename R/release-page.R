snz_documents_from_payload <- function(payload, release_url) {
  blocks <- payload$PageBlocks %||% list()
  documents <- unlist(
    lapply(blocks, function(block) block$BlockDocuments %||% list()),
    recursive = FALSE
  )
  if (length(documents) == 0L) {
    return(data.frame())
  }
  rows <- lapply(documents, function(document) {
    link <- snz_scalar(document$DocumentLink)
    if (!nzchar(link)) {
      return(NULL)
    }
    data.frame(
      name = snz_scalar(document$Name %||% document$FileName),
      title = snz_scalar(document$Title),
      extension = tolower(snz_scalar(document$DocumentExtension)),
      stated_size = snz_scalar(document$DocumentSize),
      url = xml2::url_absolute(link, release_url),
      stringsAsFactors = FALSE
    )
  })
  snz_bind_rows(rows)
}

snz_documents_from_anchors <- function(document, release_url) {
  anchors <- xml2::xml_find_all(
    document,
    "//a[contains(@href,'.csv') or contains(@href,'.zip') or contains(@href,'.xlsx')]"
  )
  if (length(anchors) == 0L) {
    return(data.frame())
  }
  links <- xml2::xml_attr(anchors, "href")
  links <- links[!is.na(links) & nzchar(links)]
  if (length(links) == 0L) {
    return(data.frame())
  }
  urls <- vapply(
    links,
    function(link) xml2::url_absolute(link, release_url),
    FUN.VALUE = character(1)
  )
  data.frame(
    name = basename(urls),
    title = trimws(xml2::xml_text(anchors))[seq_along(urls)],
    extension = tolower(tools::file_ext(basename(urls))),
    stated_size = "",
    url = urls,
    stringsAsFactors = FALSE
  )
}

snz_parse_release_page <- function(raw, release_url) {
  release_url <- snz_assert_official_url(release_url, information_release = TRUE)
  document <- tryCatch(
    xml2::read_html(rawToChar(raw)),
    error = function(error) {
      snz_stop(
        sprintf("Stats NZ release page could not be parsed: %s", conditionMessage(error)),
        class = "statsnz_release_page_error",
        url = release_url
      )
    }
  )
  page_node <- xml2::xml_find_first(document, "//*[@id='pageViewData']")
  payload <- NULL
  if (!inherits(page_node, "xml_missing")) {
    encoded <- snz_scalar(xml2::xml_attr(page_node, "data-value"))
    if (nzchar(encoded)) {
      payload <- tryCatch(
        jsonlite::fromJSON(encoded, simplifyVector = FALSE),
        error = function(error) NULL
      )
    }
  }

  files <- if (!is.null(payload)) {
    snz_documents_from_payload(payload, release_url)
  } else {
    data.frame()
  }
  if (nrow(files) == 0L) {
    files <- snz_documents_from_anchors(document, release_url)
  }
  if (nrow(files) == 0L) {
    snz_stop(
      "No downloadable files were found on the Stats NZ release page.",
      class = "statsnz_attachments_not_found",
      url = release_url
    )
  }

  release_title <- snz_scalar(
    if (!is.null(payload)) payload$Title else xml2::xml_text(
      xml2::xml_find_first(document, "//h1")
    )
  )
  files$release_title <- release_title
  files$release_url <- release_url
  files <- files[!duplicated(files$url), , drop = FALSE]
  rownames(files) <- NULL
  files
}

#' List files attached to a Stats NZ information release
#'
#' @param release_url An official Stats NZ information-release URL.
#'
#' @return A tibble with attachment names, titles, sizes, and URLs.
#' @export
statsnz_release_files <- function(release_url) {
  release_url <- snz_assert_official_url(
    release_url,
    information_release = TRUE
  )
  result <- snz_parse_release_page(
    snz_fetch_memory(release_url),
    release_url
  )
  tibble::as_tibble(result)
}

snz_attachment_priority <- function(names, preference) {
  preference <- snz_scalar(preference)
  if (!nzchar(preference)) {
    return(seq_along(names))
  }
  tokens <- strsplit(preference, "|", fixed = TRUE)[[1L]]
  rank <- rep(length(tokens) + 1L, length(names))
  for (index in seq_along(tokens)) {
    rank[grepl(tokens[[index]], names, ignore.case = TRUE)] <- index
  }
  rank
}

snz_select_attachments <- function(files, release) {
  include <- snz_scalar(release$attachment_include)
  exclude <- snz_scalar(release$attachment_exclude)
  selected <- grepl(include, files$name, ignore.case = TRUE, perl = TRUE)
  if (nzchar(exclude)) {
    selected <- selected &
      !grepl(exclude, files$name, ignore.case = TRUE, perl = TRUE)
  }
  result <- files[selected, , drop = FALSE]
  if (nrow(result) == 0L) {
    snz_stop(
      sprintf(
        "No attachment on this page matched the %s package rule.",
        release$release_name[[1L]]
      ),
      class = "statsnz_attachment_mismatch",
      release_id = release$release_id[[1L]]
    )
  }
  if (identical(release$release_id[[1L]],"nz_stats_trade")) {
    primary <- grepl("^overseas-merchandise-trade-[a-z]+-[0-9]{4}([_-]v[0-9]+)?[.]xlsx$",result$name,ignore.case=TRUE)
    result <- result[primary,,drop=FALSE]
    if(nrow(result)!=1L)snz_stop("Trade release did not identify one primary workbook.",class="statsnz_attachment_mismatch")
  }
  rank <- snz_attachment_priority(
    result$name,
    release$attachment_preference[[1L]]
  )
  result <- result[order(rank, result$name), , drop = FALSE]
  rownames(result) <- NULL
  result
}
