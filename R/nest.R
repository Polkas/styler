#' Obtain a nested parse table from a character vector
#'
#' Parses `text` to a flat parse table and subsequently changes its
#' representation into a nested parse table with [nest_parse_data()].
#' @inheritParams text_to_flat_pd
#' @return A nested parse table. See [tokenize()] for details on the columns
#'   of the parse table.
#' @importFrom purrr when
#' @keywords internal
compute_parse_data_nested <- function(text,
                                      transformers,
                                      more_specs) {
  parse_data <- text_to_flat_pd(text, transformers, more_specs = more_specs)
  env_add_stylerignore(parse_data)
  parse_data$child <- rep(list(NULL), length(parse_data$text))
  pd_nested <- parse_data %>%
    nest_parse_data() %>%
    flatten_operators() %>%
    when(any(parse_data$token == "EQ_ASSIGN") ~ relocate_eq_assign(.), ~.) %>%
    add_cache_block()

  pd_nested
}

#' Creates a flat parse table with minimal initialization
#'
#' Creates a flat parse table with minimal initialization and makes the parse
#' table shallow where appropriate.
#' @details
#' This includes:
#'
#' * token before and after.
#' * stylerignore attribute.
#' * caching attributes.
#' @inheritParams tokenize
#' @inheritParams add_attributes_caching
#' @details
#' Note that the parse table might be shallow if caching is enabled and some
#' values are cached.
#' @keywords internal
text_to_flat_pd <- function(text, transformers, more_specs) {
  tokenize(text) %>%
    add_terminal_token_before() %>%
    add_terminal_token_after() %>%
    add_stylerignore() %>%
    add_attributes_caching(transformers, more_specs = more_specs) %>%
    drop_cached_children()
}

#' Add the block id to a parse table
#'
#' Must be after [nest_parse_data()] because requires a nested parse table as
#' input.
#' @param pd_nested A top level nest.
#' @keywords internal
#' @importFrom rlang seq2
add_cache_block <- function(pd_nested) {
  if (cache_is_activated()) {
    pd_nested$block <- cache_find_block(pd_nested)
  } else {
    pd_nested$block <- rep(1, length(pd_nested$block))
  }
  pd_nested
}

#' Drop all children of a top level expression that are cached
#'
#' Note that we do not cache top-level comments. Because package code has a lot
#' of roxygen comments and each of them is a top level expression, checking is
#' very expensive. More expensive than styling, because comments are always
#' terminals.
#' @param pd A top-level nest.
#' @details
#' Because we process in blocks of expressions for speed, a cached expression
#' will always end up in a block that won't be styled again (usual case), unless
#' it's on a line where multiple expressions sit and at least one is not styled
#' (exception).
#'
#' **usual case: All other expressions in a block are cached**
#'
#' Cached expressions don't need to be transformed with `transformers` in
#' [parse_transform_serialize_r_block()], we simply return `text` for the top
#' level token. For that
#' reason, the nested parse table can, at the rows where these expressions are
#' located, be shallow, i.e. it does not have to contain a child, because it
#' will neither be transformed nor serialized anytime. This function drops all
#' associated tokens except the top-level token for such expressions, which will
#' result in large speed improvements in [compute_parse_data_nested()] because
#' nesting is expensive and will not be done for cached expressions.
#'
#' **exception: Not all other expressions in a block are cached**
#'
#' As described in [cache_find_block()], expressions on the same line are always
#' put into one block. If any element of a block is not cached, the block will
#' be styled as a whole. If the parse table was made shallow (and the top level)
#' expression is still marked as non-terminal, `text` will never be used in the
#' transformation process and eventually lost. Hence, we must change the top
#' level expression to a terminal. It will act like a comment in the sense that
#' it is a fixed `text`.
#'
#' Because for the usual case, it does not even matter if the cached expression
#' is a terminal or not (because it is not processed), we can safely set
#' `terminal = TRUE` in general.
#' @section Implementation:
#' Because the structure of the parse table is not always "top-level expression
#' first, then children", this function creates a temporary parse table that has
#' this property and then extract the ids and subset the original parse table so
#' it is shallow in the right places.
#' @keywords internal
drop_cached_children <- function(pd) {
  if (cache_is_activated()) {
    order <- order(pd$line1, pd$col1, -pd$line2, -pd$col2, as.integer(pd$terminal))
    pd_parent_first <- pd[order, ]
    pos_ids_to_keep <- pd_parent_first %>%
      split(cumsum(pd_parent_first$parent == 0L)) %>%
      map(find_pos_id_to_keep) %>%
      unlist(use.names = FALSE)
    pd[pd$pos_id %in% pos_ids_to_keep, ]
  } else {
    pd
  }
}

#' Find the pos ids to keep
#'
#' To make a parse table shallow, we must know which ids to keep.
#' `split(cumsum(pd_parent_first$parent == 0L))` above puts comments with
#' negative parents in the same block as proceeding expressions (but also with
#' positive).
#' `find_pos_id_to_keep()` must hence always keep negative comments. We did not
#' use `split(cumsum(pd_parent_first$parent < 1L))` because then every top-level
#' comment is an expression on its own and processing takes much longer for
#' typical roxygen annotated code.
#' @param pd A temporary top level nest where the first expression is always a
#'   top level expression, potentially cached.
#' @details
#' Note that top-level comments **above** code have negative parents
#' (the negative value of the parent of the code expression that follows after,
#' another comment might be in the way though), all comments that are not top
#' level have positive ids. All comments for which no code follows afterwards
#' have parent 0.
#' @examples
#' styler:::get_parse_data(c("#", "1"))
#' styler:::get_parse_data(c("c(#", "1)"))
#' styler:::get_parse_data(c("", "c(#", "1)", "#"))
#' @keywords internal
find_pos_id_to_keep <- function(pd) {
  if (pd$is_cached[1L]) {
    pd$pos_id[pd$parent <= 0]
  } else {
    pd$pos_id
  }
}


#' Turn off styling for parts of the code
#'
#' Using stylerignore markers, you can temporarily turn off styler. Beware that
#' for `styler > 1.2.0`, some alignment is
#' [detected by styler](https://styler.r-lib.org/articles/detect-alignment.html),
#' making stylerignore redundant. See a few illustrative examples below.
#' @details
#' Styling is on for all lines by default when you run styler.
#'
#' - To mark the start of a sequence where you want to turn styling off, use
#'   `# styler: off`.
#' - To mark the end of this sequence, put `# styler: on` in your code. After
#'   that line, styler will again format your code.
#' - To ignore an inline statement (i.e. just one line), place `# styler: off`
#'   at the end of the line.
#' To use something else as start and stop markers, set the R options
#' `styler.ignore_start` and
#' `styler.ignore_stop` using [options()]. For styler version > 1.6.2, the
#' option supports character vectors longer than one and the marker are not
#' exactly matched, but using a  regular expression, which means you can have
#' multiple marker on one line, e.g. `# nolint start styler: off`.
# nolint end
#' @name stylerignore
#' @examples
#' # as long as the order of the markers is correct, the lines are ignored.
#' style_text(
#'   "
#'   1+1
#'   # styler: off
#'   1+1
#'   # styler: on
#'   1+1
#'   "
#' )
#'
#' # if there is a stop marker before a start marker, styler won't be able
#' # to figure out which lines you want to ignore and won't ignore anything,
#' # issuing a warning.
#' \dontrun{
#' style_text(
#'   "
#'   1+1
#'   # styler: off
#'   1+1
#'   # styler: off
#'   1+1
#'   "
#' )
#' }
#' # some alignment of code is detected, so you don't need to use stylerignore
#' style_text(
#'   "call(
#'     xyz =  3,
#'     x   = 11
#'   )"
#' )
NULL


#' Enhance the mapping of text to the token "SPECIAL"
#'
#' Map text corresponding to the token "SPECIAL" to a (more) unique token
#' description.
#' @param pd A parse table.
#' @keywords internal
enhance_mapping_special <- function(pd) {
  pipes <- pd$token == "SPECIAL" & pd$text == "%>%"
  pd$token[pipes] <- special_and("PIPE")

  ins <- pd$token == "SPECIAL" & pd$text == "%in%"
  pd$token[ins] <- special_and("IN")

  others <- pd$token == "SPECIAL" & !(pipes | ins)
  pd$token[others] <- special_and("OTHER")

  pd
}

special_and <- function(text) {
  paste0("SPECIAL-", text)
}

#' Add information about previous / next token to each terminal
#'
#' @param pd_flat A flat parse table.
#' @name add_token_terminal
#' @keywords internal
NULL

#' @rdname add_token_terminal
#' @keywords internal
add_terminal_token_after <- function(pd_flat) {
  terminals <- pd_flat %>%
    filter(terminal) %>%
    arrange_pos_id()

  rhs <- new_styler_df(
    list(
      pos_id = terminals$pos_id,
      token_after = lead(terminals$token, default = "")
    )
  )

  left_join(pd_flat, rhs, by = "pos_id")
}

#' @rdname add_token_terminal
#' @keywords internal
add_terminal_token_before <- function(pd_flat) {
  terminals <- pd_flat %>%
    filter(terminal) %>%
    arrange_pos_id()

  rhs <- new_styler_df(
    list(
      id = terminals$id,
      token_before = lag(terminals$token, default = "")
    )
  )

  left_join(pd_flat, rhs, by = "id")
}


#' Initialise variables related to caching
#'
#' Note that this does function must be called in [compute_parse_data_nested()]
#' and we cannot wait to initialize this attribute until [apply_transformers()],
#' where all other attributes are initialized with
#' [default_style_guide_attributes()] (when using [tidyverse_style()]) because
#' for cached code, we don't build up the nested structure and leave it shallow
#' (to speed up things), see also [drop_cached_children()].
#' @inheritParams is_cached
#' @describeIn add_token_terminal Initializes `newlines` and `lag_newlines`.
#' @keywords internal
add_attributes_caching <- function(pd_flat, transformers, more_specs) {
  pd_flat$block <- rep(NA, nrow(pd_flat))
  pd_flat$is_cached <- rep(FALSE, nrow(pd_flat))
  if (cache_is_activated()) {
    is_parent <- pd_flat$parent == 0L
    pd_flat$is_cached[is_parent] <- map_lgl(
      pd_flat$text[pd_flat$parent == 0L],
      is_cached, transformers,
      more_specs = more_specs
    )
    is_comment <- pd_flat$token == "COMMENT"
    pd_flat$is_cached[is_comment] <- rep(FALSE, sum(is_comment))
  }
  pd_flat
}

#' Helper for setting spaces
#'
#' @param spaces_after_prefix An integer vector with the number of spaces
#'   after the prefix.
#' @param force_one Whether spaces_after_prefix should be set to one in all
#'   cases.
#' @return An integer vector of length spaces_after_prefix, which is either
#'   one (if `force_one = TRUE`) or `space_after_prefix` with all values
#'   below one set to one.
#' @return
#' Numeric vector indicating the number of spaces.
#' @keywords internal
set_spaces <- function(spaces_after_prefix, force_one) {
  if (force_one) {
    rep(1, length(spaces_after_prefix))
  } else {
    pmax(spaces_after_prefix, 1L)
  }
}

#' Nest a flat parse table
#'
#' `nest_parse_data` groups `pd_flat` into a parse table with tokens that are
#'  a parent to other tokens (called internal) and such that are not (called
#'  child). Then, the token in child are joined to their parents in internal
#'  and all token information of the children is nested into a column "child".
#'  This is done recursively until we are only left with a nested data frame that
#'  contains one row: The nested parse table.
#' @param pd_flat A flat parse table including both terminals and non-terminals.
#' @seealso [compute_parse_data_nested()]
#' @return A nested parse table.
#' @importFrom purrr map2
#' @keywords internal
nest_parse_data <- function(pd_flat) {
  if (all(pd_flat$parent <= 0L)) {
    return(pd_flat)
  }
  pd_flat$internal <- with(pd_flat, (id %in% parent) | (parent <= 0L))
  split_data <- split(pd_flat, pd_flat$internal)

  child <- split_data$`FALSE`
  internal <- split_data$`TRUE`

  internal$internal_child <- internal$child
  internal$child <- NULL

  child$parent_ <- child$parent

  rhs <- nest_(child, "child", setdiff(names(child), "parent_"))

  nested <- left_join(internal, rhs, by = c("id" = "parent_"))

  children <- nested$child
  for (i in seq_along(children)) {
    new <- combine_children(children[[i]], nested$internal_child[[i]])
    # Work around is.null(new)
    children[i] <- list(new)
  }
  nested$child <- children
  nested$internal_child <- NULL
  nest_parse_data(nested)
}

#' Combine child and internal child
#'
#' Binds two parse tables together and arranges them so that the tokens are in
#' the correct order.
#' @param child A parse table or `NULL`.
#' @param internal_child A parse table or `NULL`.
#' @details Essentially, this is a wrapper around [dplyr::bind_rows()], but
#'   returns `NULL` if the result of [dplyr::bind_rows()] is a data frame with
#'   zero rows.
#' @keywords internal
combine_children <- function(child, internal_child) {
  bound <- bind_rows(child, internal_child)
  if (nrow(bound) == 0L) {
    return(NULL)
  }
  bound[order(bound$pos_id), ]
}
