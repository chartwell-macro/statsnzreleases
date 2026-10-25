fixture_release_page <- function(title, documents) {
  payload <- list(
    Title = title,
    PageBlocks = list(list(BlockDocuments = documents))
  )
  json <- jsonlite::toJSON(payload, auto_unbox = TRUE, null = "null")
  charToRaw(sprintf(
    "<html><body><div id=\"pageViewData\" data-value='%s'></div></body></html>",
    json
  ))
}

fixture_document <- function(name, title = name, size = "1 KB") {
  list(
    Name = name,
    FileName = name,
    Title = title,
    DocumentLink = paste0("/assets/Uploads/Test/", name),
    DocumentExtension = tools::file_ext(name),
    DocumentSize = size
  )
}

fixture_csv <- function(directory, name = "sample.csv") {
  path <- file.path(directory, name)
  utils::write.csv(
    data.frame(
      Series_reference = c("TEST.S1", "TEST.S1", "TEST.S2"),
      Period = c("2025.03", "2025.06", "2025.03"),
      Data_value = c("10.5", "11.0", "1,200"),
      STATUS = c("F", "F", "P"),
      UNITS = c("Index", "Index", "Dollars"),
      MAGNTUDE = c("0", "0", "6"),
      Series_title_1 = c("Series one", "Series one", "Series two"),
      check.names = FALSE
    ),
    path,
    row.names = FALSE,
    na = ""
  )
  path
}
