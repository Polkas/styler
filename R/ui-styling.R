#' @keywords api
#' @importFrom magrittr %>%
NULL

#' Prettify R source code
#'
#' Performs various substitutions in all `.R` files in a package
#' (code and tests), `.Rmd`, `.Rmarkdown` and/or
#' `.qmd`, `.Rnw` files (vignettes and readme).
#' Carefully examine the results after running this function!
#'
#' @param pkg Path to a (subdirectory of an) R package.
#' @param ... Arguments passed on to the `style` function,
#'   see [tidyverse_style()] for the default argument.
#' @param style A function that creates a style guide to use, by default
#'   [`tidyverse_style`]. Not used
#'   further except to construct the argument `transformers`. See
#'   [style_guides()] for details.
#' @param transformers A set of transformer functions. This argument is most
#'   conveniently constructed via the `style` argument and `...`. See
#'   'Examples'.
#' @inheritParams prettify_pkg
#' @section Warning:
#' This function overwrites files (if styling results in a change of the
#' code to be formatted and `dry = "off"`). It is strongly suggested to only
#' style files that are under version control or to create a backup copy.
#'
#' We suggest to first style with `scope < "tokens"` and inspect and commit
#' changes, because these changes are guaranteed to leave the abstract syntax
#' tree (AST) unchanged. See section 'Round trip validation' for details.
#'
#' Then, we suggest to style with `scope = "tokens"` (if desired) and carefully
#' inspect the changes to make sure the AST is not changed in an unexpected way
#' that invalidates code.
#' @section Round trip validation:
#' The following section describes when and how styling is guaranteed to
#' yield correct code.
#'
#' If tokens are not in the styling scope (as specified with the `scope`
#' argument), no tokens are changed and the abstract syntax tree (AST) should
#' not change.
#' Hence, it is possible to validate the styling by comparing whether the parsed
#' expression before and after styling have the same AST.
#' This comparison omits roxygen code examples and comments. styler throws an
#' error if the AST has changed through styling.
#'
#' Note that if tokens are to be styled, such a comparison is not conducted because
#' the AST might well change and such a change is intended. There is no way
#' styler can validate styling, that is why we inform the user to carefully
#' inspect the changes.
#'
#' See section 'Warning' for a good strategy to apply styling safely.
#' @inheritSection transform_files Value
#' @family stylers
#' @examples
#' \dontrun{
#' # the following is identical (because of ... and defaults)
#' # but the first is most convenient:
#' style_pkg(strict = TRUE)
#' style_pkg(style = tidyverse_style, strict = TRUE)
#' style_pkg(transformers = tidyverse_style(strict = TRUE))
#'
#' # more options from `tidyverse_style()`
#' style_pkg(
#'   scope = "line_breaks",
#'   math_token_spacing = specify_math_token_spacing(zero = "'+'")
#' )
#'
#' # don't write back and fail if input is not already styled
#' style_pkg("/path/to/pkg/", dry = "fail")
#' }
#' @export
style_pkg <- function(pkg = ".",
                      ...,
                      style = tidyverse_style,
                      transformers = style(...),
                      filetype = c("R", "Rprofile", "Rmd", "Rmarkdown", "Rnw", "Qmd"),
                      exclude_files = c("R/RcppExports.R", "R/cpp11.R"),
                      exclude_dirs = c("packrat", "renv"),
                      include_roxygen_examples = TRUE,
                      base_indention = 0L,
                      dry = "off") {
  pkg_root <- rprojroot::find_package_root_file(path = pkg)
  changed <- withr::with_dir(pkg_root, prettify_pkg(
    transformers,
    filetype, exclude_files, exclude_dirs, include_roxygen_examples,
    base_indention,
    dry
  ))
  invisible(changed)
}

#' Prettify a package
#'
#' @param filetype Vector of file extensions indicating which file types should
#'   be styled. Case is ignored, and the `.` is optional, e.g.
#'   `c(".R", ".Rmd")`, or `c("r", "rmd")`. Supported values (after
#'   standardization) are: "r", "rprofile", "rmd", "rmarkdown", "rnw". Rmarkdown is treated as Rmd.
#' @param exclude_files Character vector with paths to files that should be
#'   excluded from styling.
#' @param exclude_dirs Character vector with directories to exclude
#'   (recursively). Note that the default values were set for consistency with
#'   [style_dir()] and as these directories are anyways not styled.
#' @inheritParams transform_files
#' @keywords internal
prettify_pkg <- function(transformers,
                         filetype,
                         exclude_files,
                         exclude_dirs,
                         include_roxygen_examples,
                         base_indention,
                         dry) {
  filetype_ <- set_and_assert_arg_filetype(filetype)
  r_files <- rprofile_files <- vignette_files <- readme <- NULL
  exclude_files <- c(
    set_arg_paths(exclude_files),
    dir_without_.(exclude_dirs, pattern = map_filetype_to_pattern(filetype))
  )
  if ("\\.r" %in% filetype_) {
    r_files <- dir_without_.(
      path = c("R", "tests", "data-raw", "demo"),
      pattern = "\\.r$"
    )
  }

  if ("\\.rprofile" %in% filetype_) {
    rprofile_files <- dir_without_.(
      path = ".", pattern = "^\\.rprofile$"
    )
  }
  if ("\\.rmd" %in% filetype_) {
    vignette_files <- dir_without_.(
      path = "vignettes", pattern = "\\.rmd$"
    )
    readme <- dir_without_.(
      path = ".",
      pattern = "^readme\\.rmd$"
    )
  }

  if ("\\.rmarkdown" %in% filetype_) {
    vignette_files <- append(
      vignette_files,
      dir_without_.(
        path = "vignettes", pattern = "\\.rmarkdown$"
      )
    )
    readme <- append(
      readme,
      dir_without_.(
        path = ".", pattern = "^readme\\.rmarkdown$"
      )
    )
  }

  if ("\\.rnw" %in% filetype_) {
    vignette_files <- append(
      vignette_files,
      dir_without_.(
        path = "vignettes", pattern = "\\.rnw$"
      )
    )
  }

  if ("\\.qmd" %in% filetype_) {
    vignette_files <- append(
      vignette_files,
      dir_without_.(
        path = ".",
        pattern = "\\.qmd$"
      )
    )
  }

  files <- setdiff(
    c(r_files, rprofile_files, vignette_files, readme),
    exclude_files
  )
  transform_files(files,
    transformers = transformers,
    include_roxygen_examples = include_roxygen_examples,
    base_indention = base_indention,
    dry = dry
  )
}

#' Style a string
#'
#' Styles a character vector. Each element of the character vector corresponds
#' to one line of code.
#' @param text A character vector with text to style.
#' @inheritParams style_pkg
#' @family stylers
#' @examples
#' style_text("call( 1)")
#' style_text("1    + 1", strict = FALSE)
#'
#' # the following is identical (because of ... and defaults)
#' # but the first is most convenient:
#' style_text("a<-3++1", strict = TRUE)
#' style_text("a<-3++1", style = tidyverse_style, strict = TRUE)
#' style_text("a<-3++1", transformers = tidyverse_style(strict = TRUE))
#'
#' # more invasive scopes include less invasive scopes by default
#' style_text("a%>%b", scope = "spaces")
#' style_text("a%>%b; a", scope = "line_breaks")
#' style_text("a%>%b; a", scope = "tokens")
#'
#' # opt out with I() to only style specific levels
#' style_text("a%>%b; a", scope = I("tokens"))
#' @export
style_text <- function(text,
                       ...,
                       style = tidyverse_style,
                       transformers = style(...),
                       include_roxygen_examples = TRUE,
                       base_indention = 0L) {
  transformer <- make_transformer(transformers,
    include_roxygen_examples = include_roxygen_examples,
    base_indention = base_indention
  )
  styled_text <- transformer(text)
  construct_vertical(styled_text)
}

#' Prettify arbitrary R code
#'
#' Performs various substitutions in all `.R`, `.Rmd`, `.Rmarkdown`, `qmd`
#' and/or `.Rnw` files in a directory (by default only `.R` files are styled -
#' see `filetype` argument).
#' Carefully examine the results after running this function!
#' @param path Path to a directory with files to transform.
#' @param recursive A logical value indicating whether or not files in
#'   sub directories of `path` should be styled as well.
#' @param exclude_dirs Character vector with directories to exclude
#'   (recursively).
##' @inheritParams style_pkg
#' @inheritSection transform_files Value
#' @inheritSection style_pkg Warning
#' @inheritSection style_pkg Round trip validation
#' @family stylers
#' @examples
#' \dontrun{
#' style_dir("path/to/dir", filetype = c("rmd", ".R"))
#'
#' # the following is identical (because of ... and defaults)
#' # but the first is most convenient:
#' style_dir(strict = TRUE)
#' style_dir(style = tidyverse_style, strict = TRUE)
#' style_dir(transformers = tidyverse_style(strict = TRUE))
#' }
#' @export
style_dir <- function(path = ".",
                      ...,
                      style = tidyverse_style,
                      transformers = style(...),
                      filetype = c("R", "Rprofile", "Rmd", "Rmarkdown", "Rnw", "Qmd"),
                      recursive = TRUE,
                      exclude_files = NULL,
                      exclude_dirs = c("packrat", "renv"),
                      include_roxygen_examples = TRUE,
                      base_indention = 0L,
                      dry = "off") {
  changed <- withr::with_dir(
    path, prettify_any(
      transformers,
      filetype, recursive, exclude_files, exclude_dirs,
      include_roxygen_examples, base_indention, dry
    )
  )
  invisible(changed)
}

#' Prettify R code in current working directory
#'
#' This is a helper function for style_dir.
#' @inheritParams style_pkg
#' @param recursive A logical value indicating whether or not files in
#'   subdirectories should be styled as well.
#' @keywords internal
prettify_any <- function(transformers,
                         filetype,
                         recursive,
                         exclude_files,
                         exclude_dirs,
                         include_roxygen_examples,
                         base_indention = 0L,
                         dry) {
  exclude_files <- set_arg_paths(exclude_files)
  exclude_dirs <- exclude_dirs %>%
    list.dirs(recursive = TRUE, full.names = TRUE) %>%
    set_arg_paths()
  files_root <- dir(
    path = ".", pattern = map_filetype_to_pattern(filetype),
    ignore.case = TRUE, recursive = FALSE, all.files = TRUE
  )
  if (recursive) {
    files_other <- list.dirs(full.names = FALSE, recursive = TRUE) %>%
      setdiff(c("", exclude_dirs)) %>%
      dir_without_.(
        pattern = map_filetype_to_pattern(filetype),
        recursive = FALSE
      )
  } else {
    files_other <- NULL
  }
  transform_files(
    setdiff(c(files_root, files_other), exclude_files),
    transformers, include_roxygen_examples, base_indention, dry
  )
}

#' Style files with R source code
#'
#' Performs various substitutions in the files specified.
#' Carefully examine the results after running this function!
#' @section Encoding:
#' UTF-8 encoding is assumed. Please convert your code to UTF-8 if necessary
#' before applying styler.
#' @param path A character vector with paths to files to style. Supported
#'   extensions: `.R`, `.Rmd`, `.Rmarkdown`, `.qmd` and `.Rnw`.
#' @inheritParams style_pkg
#' @inheritSection transform_files Value
#' @inheritSection style_pkg Warning
#' @inheritSection style_pkg Round trip validation
#' @examples
#' file <- tempfile("styler", fileext = ".R")
#' writeLines("1++1", file)
#'
#' # the following is identical (because of ... and defaults),
#' # but the first is most convenient:
#' style_file(file, strict = TRUE)
#' style_file(file, style = tidyverse_style, strict = TRUE)
#' style_file(file, transformers = tidyverse_style(strict = TRUE))
#'
#' # only style indention and less invasive  levels (i.e. spaces)
#' style_file(file, scope = "indention", strict = TRUE)
#' # name levels explicitly to not style less invasive levels
#' style_file(file, scope = I(c("tokens", "spaces")), strict = TRUE)
#'
#' readLines(file)
#' unlink(file)
#' @family stylers
#' @export
style_file <- function(path,
                       ...,
                       style = tidyverse_style,
                       transformers = style(...),
                       include_roxygen_examples = TRUE,
                       base_indention = 0L,
                       dry = "off") {
  path <- set_arg_paths(path)
  changed <- transform_files(path,
    transformers = transformers,
    include_roxygen_examples = include_roxygen_examples,
    base_indention = base_indention,
    dry = dry
  )
  invisible(changed)
}
