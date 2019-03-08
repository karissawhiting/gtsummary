#' Report statistics from gtsummary tables inline
#'
#' @param x object created from a gtsummary funciton
#' @param ... further arguments passed to or from other methods.
#' @author Daniel Sjoberg
#' @seealso \link{inline_text.tbl_summary}, \link{tbl_summary}, \link{tbl_regression}, \link{tbl_uvregression}
#' @export
inline_text <- function(x, ...) UseMethod("inline_text")

#' Report statistics from summary tables inline
#'
#' Functions takes an object with class `tbl_summary`, and the
#' location of the statistic to report and returns the statistic for reporting
#' inline in an R markdown document
#'
#' @param x object created from  \link{tbl_summary}
#' @param variable variable name of statistic to present
#' @param level level of the variable to display for categorical variables.
#' Can also specify the 'Unknown' row.  Default is `NULL`
#' @param column name column name to return from `x$table_body`.
#' Can also pass the level of a by variable.
#' @param pvalue_fun function for rounding/formatting p-values.
#' Default is \code{\link{style_pvalue}}.
#' The function must have a single input (the numeric, exact p-value),
#' and return a string that is the rounded/formatted p-value (e.g.
#' \code{pvalue_fun = function(x) style_pvalue(x, digits = 2)} or equivalently,
#'  \code{purrr::partial(style_pvalue, digits = 2)}).
#' @param ... not used
#' @author Daniel Sjoberg
#' @export


inline_text.tbl_summary <-
  function(x, variable, level = NULL,
           column = ifelse(is.null(x$by), "stat_0", stop("Must specify column")),
           pvalue_fun = purrr::partial(style_pvalue, prepend_p = TRUE), ...) {
    # checking column ----------------------------------------------------------
    # the follwing code converts the column input to a column name in x$table_body
    col_lookup_table <- tibble(input = names(x$table_body),
                               column_name =  names(x$table_body))
    # adding levels if there is a by variable
    if(!is.null(x$by)) {
      col_lookup_table <-
        col_lookup_table %>%
        bind_rows(
          x$df_by %>% select(c("by_chr", "by_col")) %>% set_names(c("input", "column_name"))
        )
    }

    column <- col_lookup_table %>%
      filter(!!parse_expr(glue("input == '{column}'"))) %>%
      slice(1) %>%
      pull("column_name")

    if(length(column) == 0) stop(
      stop(glue(
        "No column selected.  Must be one of: ",
        "{paste(col_lookup_table, collapse = ', ')}"
      ))
    )



    # select variable ----------------------------------------------------------
    # grabbing rows matching variable
    result <-
      x$table_body %>%
      filter(!!parse_expr(glue("variable ==  '{variable}'")))

    # select variable level ----------------------------------------------------
    if(is.null(level)) {
      result <- result %>% slice(1)
    }
    else {
      result <-
        result %>% filter(!!parse_expr(glue("label ==  '{level}'")))
    }

    if(nrow(result) == 0)
      stop("No statistic selected. Is the variable name and/or level spelled correctly?")

    # select column ------------------------------------------------------------
    result <- result %>% pull(column)

    # return statistic ---------------------------------------------------------
    if(column %in% c("pvalue", "qvalue")) {
      return(pvalue_fun(result))
    }

    result
  }


#' Report statistics from regression summary tables inline
#'
#' Functions takes an object with class `tbl_regression`, and the
#' location of the statistic to report and returns the statistic for reporting
#' inline in an R markdown document
#'
#' @param x object created from  \link{tbl_regression}
#' @param variable variable name of statistic to present
#' @param level level of the variable to display for categorical variables.
#' Default is `NULL`, returning the top row in the table for the variable.
#' @param pattern statistics to return.  Uses \link[glue]{glue} formatting.
#' Default is "{coef} ({conf.level}% CI {ll}, {ul}; {pvalue})".  All columns from
#' `.$table_body` are available to print as well as the confidence level (conf.level)
#' @param coef_fun function to style model coefficients.
#' Columns 'coef', 'll', and 'ul' are formatted. Default is `x$inputs$coef_fun`
#' @param pvalue_fun function to style p-values and/or q-values.
#' Default is `function(x) style_pvalue(x, prepend_p = TRUE)`
#' @param ... not used
#' @author Daniel Sjoberg
#' @export

inline_text.tbl_regression <-
  function(x, variable, level = NULL,
           pattern = "{coef} ({conf.level*100}% CI {ll}, {ul}; {pvalue})",
           coef_fun = x$inputs$coef_fun,
           pvalue_fun = function(x) style_pvalue(x, prepend_p = TRUE), ...) {
    # table_body preformatting -------------------------------------------------
    # this is only being performed for tbl_uvregression benefit
    # getting N on every row of the table
    x$table_body <-
      dplyr::left_join(
        x$table_body %>% select(-"N"),
        x$table_body %>% filter_('row_type == "label"') %>% select(c("variable", "N")),
        by = "variable"
      )

    # select variable ----------------------------------------------------------
    # grabbing rows matching variable
    filter_expr <-
      result <-
      x$table_body %>%
      filter(!!parse_expr(glue("variable ==  '{variable}'")))

    # select variable level ----------------------------------------------------
    if(is.null(level)) {
      result <- result %>% slice(1)
    }
    else {
      result <-
        result %>% filter(!!parse_expr(glue("label ==  '{level}'")))
    }

    if(nrow(result) == 0)
      stop("No statistic selected. Is the variable name and/or level spelled correctly?")

    # calculating statistic ----------------------------------------------------
    pvalue_cols <- names(result) %>% intersect(c("pvalue", "qvalue"))
    result <-
      result %>%
      mutate_at(vars(one_of(c("coef", "ll", "ul"))), coef_fun) %>%
      mutate_at(vars(one_of(pvalue_cols)), pvalue_fun) %>%
      mutate_(
        conf.level = ~x$inputs$conf.level,
        stat = ~glue(pattern)
      ) %>%
      pull("stat")

    result
  }


#' Report statistics from regression summary tables inline
#'
#' Functions takes an object with class `tbl_uvregression`, and the
#' location of the statistic to report and returns the statistic for reporting
#' inline in an R markdown document
#'
#' @inherit inline_text.tbl_regression
#' @export

inline_text.tbl_uvregression <- inline_text.tbl_regression