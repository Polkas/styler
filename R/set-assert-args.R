#' Set the write_tree argument
#'
#' Sets the argument `write_tree` in [test_collection()] to be `TRUE` for R
#' versions higher or equal to 3.2, and `FALSE` otherwise since the second-level
#' dependency `DiagrammeR` from `data.tree` is not available for R < 3.2.
#' @param write_tree Whether or not to write tree.
#' @keywords internal
set_arg_write_tree <- function(write_tree) {
  if (is.na(write_tree)) {
    write_tree <- is_installed("data.tree")
  } else if (write_tree) {
    assert_data.tree_installation()
  }
  write_tree
}

#' Assert the transformers
#'
#' Actually only assert name and version of style guide in order to make sure
#' caching works correctly.
#' @inheritParams make_transformer
#' @keywords internal
assert_transformers <- function(transformers) {
  version_cutoff <- 2.0
  no_name <- is.null(transformers$style_guide_name)
  no_version <- is.null(transformers$style_guide_version)
  if (no_name || no_version) {
    action <- if (utils::packageVersion("styler") >= version_cutoff) {
      "are not supported anymore"
    } else {
      "depreciated and will be removed in a future version of styler."
    }
    message <- paste(
      "Style guides without a name and a version field are",
      action, "\nIf you are a user: Open an issue on",
      "https://github.com/r-lib/styler and provide a reproducible example",
      "of this error. \nIf you are a developer:",
      "When you create a style guide with `styler::create_style_guide()`, the",
      "argument `style_guide_name` and `style_guide_version` should be",
      "non-NULL. See help(\"create_style_guide\") for how to set them."
    )

    if (utils::packageVersion("styler") >= version_cutoff) {
      rlang::abort(message)
    } else {
      rlang::warn(message)
    }
  }
}

#' Set the file type argument
#'
#' Sets and asserts the file type argument to a standard format for further internal
#' processing.
#' @param filetype A character vector with file types to convert to the internal
#'   standard format.
#' @examples
#' styler:::set_and_assert_arg_filetype("rMd")
#' \dontrun{
#' styler:::set_and_assert_arg_filetype("xyz")
#' }
#' @keywords internal
set_and_assert_arg_filetype <- function(filetype) {
  without_dot <- gsub("^\\.", "", tolower(filetype))
  assert_filetype(without_dot)
  paste0("\\.", without_dot)
}

#' Make sure all supplied file types are allowed
#'
#' @param lowercase_filetype A vector with file types to check, all lower case.
#' @importFrom rlang abort
#' @keywords internal
assert_filetype <- function(lowercase_filetype) {
  allowed_types <- c("r", "rmd", "rmarkdown", "rnw", "rprofile", "qmd")
  if (!all(lowercase_filetype %in% allowed_types)) {
    abort(paste(
      "filetype must not contain other values than 'R', 'Rprofile',",
      "'Rmd', 'Rmarkdown', 'qmd' or 'Rnw' (case is ignored)."
    ))
  }
}

#' Assert text to be of positive length and replace it with the empty
#' string otherwise.
#' @param text The input to style.
#' @keywords internal
assert_text <- function(text) {
  if (length(text) < 1L) {
    text <- ""
  }
  text
}

#' Check token validity
#'
#' Check whether one or more tokens exist and have a unique token-text mapping
#' @param tokens Tokens to check.
#' @importFrom rlang abort
#' @keywords internal
assert_tokens <- function(tokens) {
  invalid_tokens <- tokens[!(tokens %in% lookup_tokens()$token)]
  if (length(invalid_tokens) > 0L) {
    abort(paste(
      "Token(s)", paste0(invalid_tokens, collapse = ", "), "are invalid.",
      "You can lookup all valid tokens and their text",
      "with styler:::lookup_tokens(). Make sure you supply the values of",
      "the column 'token', not 'text'."
    ))
  }
}

#' Standardize paths in root
#'
#' Standardization required to use `setdiff()` with paths.
#' @param path A path.
#' @keywords internal
#' @seealso dir_without_.
#' @examples
#' styler:::set_arg_paths(c("./file.R", "file.R", "../another-file.R"))
set_arg_paths <- function(path) {
  gsub("^[.]/", "", path)
}
