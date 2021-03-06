#' Compare two designs
#'
#' @param design1 A design object, typically created using the + operator
#' @param design2 A design object, typically created using the + operator
#' @param format Format (in console or HTML) options from \code{diffobj::diffChr}
#' @param mode Mode options from \code{diffobj::diffChr}
#' @param pager Pager option from \code{diffobj::diffChr}
#' @param context Context option from \code{diffobj::diffChr} which sets the number of lines around differences that are printed. By default, all lines of the two objects are shown. To show only the lines that are different, set \code{context = 0}; to get one line around differences for context, set to 1.
#' @param rmd Set to \code{TRUE} use in Rmarkdown HTML output. NB: will not work with LaTeX, Word, or other .Rmd outputs.
#'
#' @examples
#' 
#' design1 <- declare_population(N = 100, u = rnorm(N)) +
#'   declare_potential_outcomes(Y ~ Z + u) +
#'   declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0)) +
#'   declare_sampling(n = 75) +
#'   declare_assignment(m = 50) +
#'   declare_reveal(Y, Z) +
#'   declare_estimator(Y ~ Z, estimand = "ATE")
#' 
#' design2 <- declare_population(N = 200, u = rnorm(N)) +
#'   declare_potential_outcomes(Y ~ 0.5*Z + u) +
#'   declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0)) +
#'   declare_sampling(n = 100) +
#'   declare_assignment(m = 25) +
#'   declare_reveal(Y, Z) +
#'   declare_estimator(Y ~ Z, model = lm_robust, estimand = "ATE")
#'  
#'  compare_designs(design1, design2)
#'  compare_design_code(design1, design2)
#'  compare_design_summaries(design1, design2)
#'  compare_design_data(design1, design2)
#'  compare_design_estimates(design1, design2)
#'  compare_design_estimands(design1, design2)
#' 
#' @name compare_functions


#' @rdname compare_functions
#' @export
compare_designs <- function(design1, design2, format = "ansi8", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_functions <-
    list(code_comparison = compare_design_code,
         data_comparison = compare_design_data, 
         estimands_comparison = compare_design_estimands,
         estimates_comparison = compare_design_estimates)
  
  vals <-
    lapply(compare_functions, function(fun)
      fun(
        design1,
        design2,
        format = format,
        mode = mode,
        pager = pager,
        context = context, 
        rmd = rmd
      )
    )
  
  class(vals) <- "design_comparison"
  
  vals
}

#' @export
print.design_comparison <- function(x, ...) {
  cat("Research design comparison\n\n")
  
  labels <- c("code_comparison" = "design code", 
              "data_comparison" = "draw_data(design)",
              "estimands_comparison" = "draw_estimands(design)",
              "estimates_comparison" = "draw_estimates(design)")
  
  for(n in names(labels)) {
    print_console_header(paste("Compare", labels[n]))
    print(x[[n]])
  }
  
}


#' @rdname compare_functions
#' @importFrom diffobj diffChr
#' @export
compare_design_code <- function(design1, design2, format = "ansi8", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_design_internal(get_design_code, diffChr, design1, design2, format, mode, pager, context, rmd)
  
}

#' @rdname compare_functions
#' @importFrom diffobj diffChr
#' @export
compare_design_summaries <- function(design1, design2, format = "ansi256", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_design_internal(function(x) capture.output(summary(x)), diffChr, design1, design2, format, mode, pager, context, rmd)
  
}

#' @rdname compare_functions
#' @importFrom diffobj diffObj
#' @export
compare_design_data <- function(design1, design2, format = "ansi256", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_design_internal(draw_data, diffObj, design1, design2, format, mode, pager, context, rmd)
  
}

#' @rdname compare_functions
#' @importFrom diffobj diffObj
#' @export
compare_design_estimates <- function(design1, design2, format = "ansi256", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_design_internal(draw_estimates, diffObj, design1, design2, format, mode, pager, context, rmd)
  
}

#' @rdname compare_functions
#' @importFrom diffobj diffObj
#' @export
compare_design_estimands <- function(design1, design2, format = "ansi256", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE) {
  
  compare_design_internal(draw_estimands, diffObj, design1, design2, format, mode, pager, context, rmd)
  
}

compare_design_internal <- function(FUN, DIFFFUN, design1, design2, format = "ansi256", mode = "sidebyside", pager = "off", context = -1L, rmd = FALSE){
  check_design_class_single(design1)
  check_design_class_single(design2)
  
  seed <- .Random.seed
  design1 <- FUN(design1)
  set.seed(seed)
  design2 <- FUN(design2)
  
  if(rmd == TRUE) {
    format <- "html"
    style <- list(html.output = "diff.w.style")
  } else {
    style <- "auto"
  }
  
  diff_output <- structure(
    DIFFFUN(
      design1,
      design2,
      format = format,
      mode = mode,
      pager = pager,
      context = context,
      style = style
    ),
    class = "Diff",
    package = "diffobj"
  )
  
  if(rmd == TRUE) {
    cat(as.character(diff_output))
  } else {
    diff_output
  }
  
}

clean_call <- function(call) {
  paste(sapply(deparse(call), trimws), collapse = " ")
}

get_design_code <- function(design){
  if (is.null(attributes(design)$code)) {
    sapply(design, function(x) clean_call(attr(x, "call")))
  } else {
    attributes(design)$code
  }
}

print_console_header <- function(text) {
  width <- options()$width
  cat("\n\n#", text, paste(rep("-", width - nchar(text) - 2), collapse = ""), "\n\n")
}
