#' Copy a script to the clipboard
#' @param name A character string.
#' @return A message indicating that the script has been copied to the clipboard.
#' @export

copy_script <- function(name) {
  # locate the valid examples
  valid_examples <- list.files(system.file("scripts", package = "scriptr"))

  # create a message for the user
  valid_msg <-
    paste0(
      "Valid examples are:\n",
      paste(
        valid_examples,
        collapse = "\n"
      )
    )

  # if an invalid example is given, throw an error
  if (missing(name) || !nzchar(name) || !name %in% valid_examples) {
    stop(
      "Please run `plotgraph()` with a valid argument.\n",
      valid_msg,
      call. = TRUE
    )
  }

  # where the graphs are stored
  directory <- system.file("scripts/", package = "scriptr")

  # append the file extension
  file_final <- paste(directory, name, sep = "/")

  #read file
  script <- readLines(file_final)

  # copy file to clip board
  clipr::write_clip(script)

  # inform the user
  cli::cli_alert_success("Script copied to clipboard")
}


utils::globalVariables(c("showplot"))
