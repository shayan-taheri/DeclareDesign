
#' Diagnose the design
#'
#' Generates diagnosands from a design or simulations of a design.
#'
#' @param ... A design or set of designs typically created using the + operator, or a \code{data.frame} of simulations, typically created by \code{\link{simulate_design}}.
#' @param diagnosands A set of diagnosands created by \code{\link{declare_diagnosands}}. By default, these include bias, root mean-squared error, power, frequentist coverage, the mean and standard deviation of the estimate(s), the "type S" error rate (Gelman and Carlin 2014), and the mean of the estimand(s).
#' @param add_grouping_variables Variables used to generate groups of simulations for diagnosis. Added to list default list: c("design_label", "estimand_label", "estimator_label", "term")
#' @param sims The number of simulations, defaulting to 500. sims may also be a vector indicating the number of simulations for each step in a design, as described for \code{\link{simulate_design}}
#' @param bootstrap_sims Number of bootstrap replicates for the diagnosands to obtain the standard errors of the diagnosands, defaulting to \code{100}. Set to FALSE to turn off bootstrapping.
#' @return a list with a data frame of simulations, a data frame of diagnosands, a vector of diagnosand names, and if calculated, a data frame of bootstrap replicates.
#'
#'
#' @details
#'
#' If the diagnosand function contains a \code{group_by} attribute, it will be used to split-apply-combine diagnosands rather than the intersecting column names.
#'
#' If \code{sims} is named, or longer than one element, a fan-out strategy is created and used instead.
#'
#' If the packages \code{future} and \code{future.apply} are installed, you can set \code{\link[future]{plan}} to run multiple simulations in parallel.
#'
#'
#' @examples
#' my_population <- declare_population(N = 500, noise = rnorm(N))
#'
#' my_potential_outcomes <- declare_potential_outcomes(
#'   Y_Z_0 = noise, Y_Z_1 = noise +
#'   rnorm(N, mean = 2, sd = 2))
#'
#' my_assignment <- declare_assignment()
#'
#' my_estimand <- declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0))
#'
#' my_reveal <- declare_reveal()
#'
#' my_estimator <- declare_estimator(Y ~ Z, estimand = my_estimand)
#'
#' design <- my_population +
#'    my_potential_outcomes +
#'    my_estimand +
#'    my_assignment +
#'    my_reveal +
#'    my_estimator
#'
#' \dontrun{
#' # using built-in defaults:
#' diagnosis <- diagnose_design(design)
#' diagnosis
#' }
#'
#' # using a user-defined diagnosand
#' my_diagnosand <- declare_diagnosands(absolute_error = mean(abs(estimate - estimand)))
#'
#' \dontrun{
#' diagnosis <- diagnose_design(design, diagnosands = my_diagnosand)
#' diagnosis
#'
#' get_diagnosands(diagnosis)
#'
#' get_simulations(diagnosis)
#'
#' }
#' # Using an existing data frame of simulations
#' \dontrun{
#' simulations <- simulate_design(designs, sims = 2)
#' diagnosis   <- diagnose_design(simulations_df = simulations_df)
#'
#' }

#' @importFrom stats setNames
#' @importFrom utils head
#' @export
diagnose_design <- function(...,
                            diagnosands = NULL,
                            sims = 500,
                            bootstrap_sims = 100,
                            add_grouping_variables = NULL) {
  dots <- quos(...)

  # two cases:
  # 1. it's a data frame -- this is the simulations df
  # 2. it's something else, and needs to be simulated
  if (is.data.frame(..1)) {
    simulations_df <- ..1
    if (is_empty(c("estimator_label", "estimand_label") %icn% simulations_df)) {
      stop("Can't calculate diagnosands on this data.frame, which does not include either an estimator_label or an estimand_label. Did you send a simulations data frame?")
    }
    diagnosands <- diagnosands %||% attr(simulations_df, "diagnosands") %||% default_diagnosands
  } else {
    # simulate if needed ------------------------------------------------------
    simulations_df <- simulate_design(!!!dots, sims = sims)
    diagnosands <- setup_diagnosands(!!!dots, diagnosands = diagnosands)
  }

  # figure out what to group by ---------------------------------------------

  group_by_set <- c("design_label", "estimand_label", "estimator_label", "term")

  if (!is.null(add_grouping_variables)) {
    group_by_set <- c(group_by_set, add_grouping_variables)
  }

  group_by_set <- group_by_set %icn% simulations_df

  # Actually calculate diagnosands ------------------------------------------

  diagnosands_df <- calculate_diagnosands(
    simulations_df = simulations_df,
    diagnosands = diagnosands,
    group_by_set = group_by_set
  )

  diagnosand_names <- setdiff(names(diagnosands_df), group_by_set)

  # Calculate n_sims --------------------------------------------------------

  n_sims_df <- calculate_sims(simulations_df = simulations_df, group_by_set = group_by_set)

  # Bootstrap ---------------------------------------------------------------

  if (bootstrap_sims > 0) {
    bootout <- bootstrap_diagnosands(
      bootstrap_sims = bootstrap_sims,
      diagnosands = diagnosands,
      simulations_df = simulations_df,
      diagnosands_df = diagnosands_df,
      group_by_set = group_by_set
    )
    diagnosands_df <- bootout$diagnosands_df
  }

  # prep for return ---------------------------------------------------------

  diagnosands_df <- merge(x = diagnosands_df, y = n_sims_df, by = group_by_set, all = TRUE)

  parameters_df <- attr(simulations_df, "parameters")
  diagnosands_df <- merge(diagnosands_df, parameters_df, by = "design_label")

  # make design_label a factor
  diagnosands_df$design_label <- factor(diagnosands_df$design_label, levels = as.character(parameters_df$design_label))

  # Reorder rows
  sort_by_list <- c(group_by_set, "statistic") %icn% diagnosands_df
  diagnosands_df <- diagnosands_df[do.call(order, as.list(diagnosands_df[sort_by_list])), , drop = FALSE]

  rownames(diagnosands_df) <- NULL

  # reorder columns

  diagnosands_df <- diagnosands_df[, reorder_columns(parameters_df, diagnosands_df), drop = FALSE]

  # Return frames
  out <- list(simulations_df = simulations_df, diagnosands_df = diagnosands_df, diagnosand_names = diagnosand_names, group_by_set = group_by_set, parameters_df = parameters_df)

  if (bootstrap_sims != 0) {
    out$bootstrap_replicates <- bootout$diagnosand_replicates
    out$bootstrap_replicates <- merge(out$bootstrap_replicates, parameters_df, by = "design_label")
    out$bootstrap_replicates <- out$bootstrap_replicates[, reorder_columns(parameters_df, out$bootstrap_replicates), drop = FALSE]
  }
  out$bootstrap_sims <- bootstrap_sims

  structure(out, class = "diagnosis")
}

#' @rdname diagnose_design
#' @export
diagnose_designs <- diagnose_design

reorder_columns <- function(a, b, n1 = colnames(a), n2 = colnames(b))
  c(n1, setdiff(n2, n1))

check_design_class <- function(designs) {
  if (!all(sapply(designs, function(x) {
    inherits(x, "design") || (inherits(x, "function") && is.null(formals(x)))
  }))) {
    stop("Please only send design objects or functions with no arguments.")
  }
}

setup_diagnosands <- function(..., diagnosands) {
  designs <- dots_to_list_of_designs(...)

  diagnosands %||% lapply(designs, function(x) attr(x, "diagnosands") %||% default_diagnosands)
}

calculate_diagnosands <- function(simulations_df, diagnosands, group_by_set) {
  if ("design_label" %in% group_by_set) {
    group_by_list <- simulations_df[, "design_label", drop = FALSE]
    labels_df <- split(group_by_list, lapply(group_by_list, addNA), drop = TRUE)
    labels_df <- lapply(labels_df, head, n = 1)

    # ensure diagnosand functions are in the same order as designs
    # diagnosands <- diagnosands[names(labels_df)]

    if (is.list(diagnosands)) {
      diagnosands <- diagnosands[names(labels_df)]
    }

    simulations_list <- split(simulations_df, lapply(group_by_list, addNA), drop = TRUE)

    if (is.list(diagnosands)) {
      diagnosands_df <- mapply(calculate_diagnosands_single_design, simulations_list, diagnosands,
        MoreArgs = list(group_by_set), SIMPLIFY = FALSE
      )
    } else {
      diagnosands_df <- mapply(calculate_diagnosands_single_design, simulations_list,
        MoreArgs = list(
          diagnosands = diagnosands,
          group_by_set = group_by_set
        ),
        SIMPLIFY = FALSE
      )
    }

    diagnosands_df <- rbind_disjoint(diagnosands_df)
  } else {
    diagnosands_df <- calculate_diagnosands_single_design(
      simulations_df, diagnosands[[1]], group_by_set
    )
  }

  diagnosands_df
}

calculate_diagnosands_single_design <- function(simulations_df, diagnosands, group_by_set) {
  group_by_list <- simulations_df[, group_by_set, drop = FALSE]
  
  labels_df <- split(group_by_list, lapply(group_by_list, addNA), drop = TRUE)
  labels_df <- lapply(labels_df, head, n = 1)

  diagnosands_df <- split(simulations_df, lapply(group_by_list, addNA), drop = TRUE)
  diagnosands_df <- lapply(diagnosands_df, FUN = function(x) {
    dg <- diagnosands(x)
    setNames(dg[[2]], dg[[1]])
  })

  # c appropriate and fast here bc labels_df must be a list (drop=FALSE above)
  diagnosands_df <- as.data.frame(t(mapply(c, labels_df, diagnosands_df)), stringsAsFactors = FALSE)

  diagnosands_df[] <- lapply(diagnosands_df, unlist)

  diagnosands_df
}

calculate_sims <- function(simulations_df, group_by_set) {
  group_by_list <- simulations_df[, group_by_set, drop = FALSE]
  
  labels_df <- split(group_by_list, lapply(group_by_list, addNA), drop = TRUE)
  labels_df <- lapply(labels_df, head, n = 1)

  n_sims_df <- split(simulations_df, lapply(group_by_list, addNA), drop = TRUE)
  n_sims_df <- lapply(n_sims_df, FUN = function(x) {
    data.frame(n_sims = nrow(x))
  })

  # c appropriate and fast here bc labels_df must be a list (drop=FALSE above)
  n_sims_df <- as.data.frame(t(mapply(c, labels_df, n_sims_df)), stringsAsFactors = FALSE)
  n_sims_df[] <- lapply(n_sims_df, unlist)

  n_sims_df
}


bootstrap_diagnosands <- function(bootstrap_sims, simulations_df, diagnosands, diagnosands_df, group_by_set) {
  bootstrap_level <- if ("step_1_draw" %in% names(simulations_df)) "step_1_draw" else "sim_ID"

  boot_indicies_by_id <- split(seq_len(nrow(simulations_df)), simulations_df[, bootstrap_level])
  nsims <- max(simulations_df[, bootstrap_level])

  boot_function <- function() {
    boot_ids <- sample.int(nsims, nsims, TRUE)
    boot_indicies <- unlist(boot_indicies_by_id[boot_ids])
    calculate_diagnosands(
      simulations_df = simulations_df[boot_indicies, , drop = FALSE],
      diagnosands = diagnosands,
      group_by_set = group_by_set
    )
  }

  # Make a list of diagnosand replicates
  diagnosand_replicates <- future_lapply(seq_len(bootstrap_sims),
    function(i) cbind(bootstrap_id = i, boot_function()), # Add bootstrap ID
    future.seed = NA,
    future.globals = "boot_function"
  )

  # Make a data.frame of diagnosand replicates
  diagnosand_replicates <- do.call(rbind.data.frame, diagnosand_replicates)
  rownames(diagnosand_replicates) <- NULL

  # Prep for se calculation
  group_by_list <- diagnosand_replicates[, group_by_set, drop = FALSE]
  labels_df <- split(group_by_list, lapply(group_by_list, addNA), drop = TRUE)
  labels_df <- lapply(labels_df, head, n = 1)

  diagnosands_df_group <- diagnosands_df[, group_by_set, drop = FALSE]
  diagnosands_df[group_by_set] <- NULL
  diagnosands_names <- colnames(diagnosands_df)

  diagnosands_df <- split(diagnosands_df, lapply(diagnosands_df_group, addNA), drop = TRUE)
  diagnosands_df <- diagnosands_df[names(labels_df)]

  # Calculate standard errors
  use_vars <- setdiff(names(diagnosand_replicates), c(group_by_set, "bootstrap_id"))
  diagnosands_se_df <- split(diagnosand_replicates[use_vars], lapply(group_by_list, addNA), drop = TRUE)
  diagnosands_se_df <- lapply(diagnosands_se_df, lapply, sd)

  # Clean up
  diagnosands_se_df <- lapply(diagnosands_se_df, setNames, sprintf("se(%s)", diagnosands_names))

  diagnosands_df <- as.data.frame(t(mapply(c, labels_df, diagnosands_df, diagnosands_se_df)),
    stringsAsFactors = FALSE
  )
  diagnosands_df[] <- lapply(diagnosands_df, unlist)

  # Permute columns so SEs are right of diagnosands
  n_diag <- length(diagnosands_names)
  i <- c(
    seq_along(group_by_set),
    length(group_by_set) + rep(seq_len(n_diag), each = 2) + c(0, n_diag)
  )
  diagnosands_df <- diagnosands_df[, i, drop = FALSE]

  # Reordering columns
  dim_cols <- c("estimator_label", "term", "estimand_label") %i% group_by_set
  ix <- sort(match(dim_cols, colnames(diagnosands_df)))
  diagnosands_df[ix] <- diagnosands_df[dim_cols]
  names(diagnosands_df)[ix] <- dim_cols

  list(
    diagnosands_df = diagnosands_df,
    diagnosand_replicates = diagnosand_replicates
  )
}
