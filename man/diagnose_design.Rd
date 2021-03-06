% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/diagnose_design.R
\name{diagnose_design}
\alias{diagnose_design}
\alias{diagnose_designs}
\title{Diagnose the design}
\usage{
diagnose_design(..., diagnosands = NULL, sims = 500,
  bootstrap_sims = 100, add_grouping_variables = NULL)

diagnose_designs(..., diagnosands = NULL, sims = 500,
  bootstrap_sims = 100, add_grouping_variables = NULL)
}
\arguments{
\item{...}{A design or set of designs typically created using the + operator, or a \code{data.frame} of simulations, typically created by \code{\link{simulate_design}}.}

\item{diagnosands}{A set of diagnosands created by \code{\link{declare_diagnosands}}. By default, these include bias, root mean-squared error, power, frequentist coverage, the mean and standard deviation of the estimate(s), the "type S" error rate (Gelman and Carlin 2014), and the mean of the estimand(s).}

\item{sims}{The number of simulations, defaulting to 500. sims may also be a vector indicating the number of simulations for each step in a design, as described for \code{\link{simulate_design}}}

\item{bootstrap_sims}{Number of bootstrap replicates for the diagnosands to obtain the standard errors of the diagnosands, defaulting to \code{100}. Set to FALSE to turn off bootstrapping.}

\item{add_grouping_variables}{Variables used to generate groups of simulations for diagnosis. Added to list default list: c("design_label", "estimand_label", "estimator_label", "term")}
}
\value{
a list with a data frame of simulations, a data frame of diagnosands, a vector of diagnosand names, and if calculated, a data frame of bootstrap replicates.
}
\description{
Generates diagnosands from a design or simulations of a design.
}
\details{
If the diagnosand function contains a \code{group_by} attribute, it will be used to split-apply-combine diagnosands rather than the intersecting column names.

If \code{sims} is named, or longer than one element, a fan-out strategy is created and used instead.

If the packages \code{future} and \code{future.apply} are installed, you can set \code{\link[future]{plan}} to run multiple simulations in parallel.
}
\examples{
my_population <- declare_population(N = 500, noise = rnorm(N))

my_potential_outcomes <- declare_potential_outcomes(
  Y_Z_0 = noise, Y_Z_1 = noise +
  rnorm(N, mean = 2, sd = 2))

my_assignment <- declare_assignment()

my_estimand <- declare_estimand(ATE = mean(Y_Z_1 - Y_Z_0))

my_reveal <- declare_reveal()

my_estimator <- declare_estimator(Y ~ Z, estimand = my_estimand)

design <- my_population +
   my_potential_outcomes +
   my_estimand +
   my_assignment +
   my_reveal +
   my_estimator

\dontrun{
# using built-in defaults:
diagnosis <- diagnose_design(design)
diagnosis
}

# using a user-defined diagnosand
my_diagnosand <- declare_diagnosands(absolute_error = mean(abs(estimate - estimand)))

\dontrun{
diagnosis <- diagnose_design(design, diagnosands = my_diagnosand)
diagnosis

get_diagnosands(diagnosis)

get_simulations(diagnosis)

}
# Using an existing data frame of simulations
\dontrun{
simulations <- simulate_design(designs, sims = 2)
diagnosis   <- diagnose_design(simulations_df = simulations_df)

}
}
