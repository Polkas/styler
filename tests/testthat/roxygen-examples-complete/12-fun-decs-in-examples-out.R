
#' Create a style guide
#'
#' @param reindention A list of parameters for regex re-indention, most
#'   conveniently constructed using [specify_reindention()].
#' @examples
#' set_line_break_before_crly_opening <- function(pd_flat) {
#'   op <- pd_flat$token %in% "'{'"
#'   pd_flat$lag_newlines[op] <- 1L
#'   pd_flat
#' }
#' set_line_break_before_curly_opening_style <- function() {
#'   create_style_guide(line_break = list(set_line_break_before_curly_opening))
#' }
#' style_text("a <- function(x) { x }
#' ", style = set_line_break_before_curly_opening_style)
#' \donttest{
#' set_line_break_before_crly_opening <- function(pd_flat) {
#'   op <- pd_flat$token %in% "'{'"
#'   pd_flat$lag_newlines[op] <- 1L
#'   pd_flat
#' }
#' }
#' @importFrom purrr compact
#' @export
create_style_guide <- function(initialize = default_style_guide_attributes,
                               line_break = NULL,
                               space = NULL,
                               token = NULL,
                               indention = NULL,
                               use_raw_indention = FALSE,
                               reindention = tidyverse_reindention()) {
  list(
    # transformer functions
    initialize = list(initialize),
    line_break,
    space,
    token,
    indention,
    # transformer options
    use_raw_indention,
    reindention
  ) %>%
    map(compact)
}

#' Another
#' @examples
#' \donttest{
#' op <- pd_flat$token %in% "'('"
#' }
#' \donttest{
#' op <- pd_flat$token %in% "')'"
#' }
#' \donttest{
#' op <- pd_flat$token %in% "("
#' }
#' \donttest{
#' op <- pd_flat$token %in% ")"
#' }
#' \donttest{
#' op <- pd_flat$token %in% "{"
#' }
#' \donttest{
#' op <- pd_flat$token %in% "}"
#' }
#' op <- pd_flat$token %in% "'['"
#' \donttest{
#' op <- pd_flat$token %in% "']'"
#' }
#' \donttest{
#' op <- pd_flat$token %in% "["
#' }
#' \donttest{
#' op <- pd_flat$token %in% "]"
#' }
NULL
