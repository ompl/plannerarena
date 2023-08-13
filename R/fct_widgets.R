problem_params_aggregate_text <- "all (aggregate)"
problem_params_separate_text <- "all (separate)"

# see https://groups.google.com/d/msg/shiny-discuss/usSetp4TtW-s/Jktu3fS60RAJ
disable <- function(x) {
  if (inherits(x, "shiny.tag")) {
    if (x$name %in% c("input", "select", "label")) {
      x$attribs$disabled <- "disabled"
    }
    x$children <- disable(x$children)
  } else if (is.list(x) && length(x) > 0) {
    for (i in 1:length(x)) {
      x[[i]] <- disable(x[[i]])
    }
  }
  x
}

conditional_disable <- function(widget, condition) {
  if (condition) {
    disable(widget)
  } else {
    widget
  }
}

problem_select_widget <- function(id, problems) {
  widget <- shiny::selectInput(
    shiny::NS(id, "problem"),
    label = shiny::h4("Motion planning problem"),
    choices = problems
  )
  conditional_disable(widget, length(problems) < 2)
}

problem_parameter_select <- function(param, val) {
  if (val == problem_params_aggregate_text ||
      val == problem_params_separate_text) {
    # select all
    TRUE
  } else {
    # select specific parameter value.
    # Use fuzzy matching when comparing numbers because precision is lost
    # when real-valued parameter values are converted to strings for
    # parameter selection widget.
    p <- rlang::sym(param)
    if (is.numeric(val)) {
      v <- as.numeric(val)
      rlang::expr(abs(!!p-!!v) < 0.0000001)
    } else {
      rlang::expr(!!p == !!val)
    }
  }
}
# Return parameters of parametrized benchmarks if they exist, NULL otherwise
problem_parameters <- function(experiments) {
  parameters <- dplyr::tbl_vars(experiments)
  num_parameters <- length(parameters)
  if (num_parameters > 12) {
    parameters[13:num_parameters]
  }
}
# Return selected values of benchmark parameters
problem_parameter_values <- function(id, experiments, input) {
  sapply(problem_parameters(experiments),
         function(name)
           input[[stringr::str_glue("problem_param{name}")]])
}
# Determine whether a performance attribute should be grouped by a benchmark
# parameter value
problem_parameter_group_by <- function(values) {
  grouping <- match(problem_params_separate_text, values)
  if (!is.na(grouping)) {
    names(values)[grouping]
  }
}
# create a widget for a given benchmark parameter
problem_parameter_select_widget <-
  function(name, id, experiments, problem, version) {
    values <- experiments |>
      dplyr::filter(.data$experiment == {
        {
          problem
        }
      } & .data$version == {
        {
          version
        }
      }) |>
      dplyr::select({
        {
          name
        }
      }) |>
      dplyr::distinct() |>
      tidyr::drop_na() |>
      dplyr::pull(name) |>
      sort()
    display_name <- gsub("_", " ", name)
    internal_name <- stringr::str_glue("problem_param{name}")
    if (length(values) == 1) {
      # don't show any widget for parameter if the only value is NA
      # (this means that the given benchmark parameter is not applicable to
      # the currently selected benchmark problem)
      if (!is.na(values[1])) {
        # disable selection if there is only value for parameter
        disable(shiny::selectInput(
          shiny::NS(id, internal_name),
          label = shiny::h6(display_name),
          choices = values
        ))
      }
    } else {
      shiny::selectInput(
        shiny::NS(id, internal_name),
        label = shiny::h6(display_name),
        choices = append(
          values,
          c(
            problem_params_aggregate_text,
            problem_params_separate_text
          ),
          0
        )
      )
    }
  }
# create widgets for all benchmark parameters
problem_parameter_select_widgets <-
  function(id, experiments, problem, version) {
    parameters <- problem_parameters(experiments)
    if (!is.null(parameters)) {
      shiny::div(
        class = "well well-light",
        shiny::h5("Problem parameters"),
        lapply(
          parameters,
          problem_parameter_select_widget,
          id = id,
          experiments = experiments,
          problem = problem,
          version = version
        )
      )
    }
  }

version_select_widget <- function(id, experiments, checkbox) {
  versions <- experiments |> dplyr::pull(version) |> unique()
  if (checkbox) {
    widget <- shiny::checkboxGroupInput(
      shiny::NS(id, "version"),
      label = shiny::h4("Selected versions"),
      choices = versions,
      selected = versions
    )
  } else {
    widget <- shiny::selectInput(
      shiny::NS(id, "version"),
      label = shiny::h4("Version"),
      choices = versions,
      # select most recent version by default
      selected = utils::tail(versions, n = 1)
    )
  }
  conditional_disable(widget, length(versions) < 2)
}

planner_select_widget <- function(id, performance) {
  if (!is.null(performance)) {
    planners <- performance |> dplyr::pull(.data$planner) |> unique()
    # select first 4 planners (or all if there are less than 4)
    if (length(planners) < 4)
      selection <- planners
    else
      selection <- planners[1:4]
    shiny::checkboxGroupInput(
      shiny::NS(id, "planners"),
      label = shiny::h4("Selected planners"),
      choices = planners,
      selected = selection
    )
  }
}

attribute_select_widget <- function(id, runs) {
  attrs <- dplyr::tbl_vars(runs) |>
    rlang::set_names(stringr::str_replace_all, "^run\\.", "") |>
    rlang::set_names(stringr::str_replace_all, "_", " ")
  if ("time" %in% attrs)
    selection <- "time"
  else
    selection <- NULL
  # strip off first 3 names, which correspond to internal id's
  shiny::selectInput(
    shiny::NS(id, "attribute"),
    label = shiny::h4("Benchmark attribute"),
    choices = attrs[4:length(attrs)],
    selected = selection
  )
}

progress_attribute_select_widget <- function(id, progress) {
  attrs <- dplyr::tbl_vars(progress) |>
    rlang::set_names(stringr::str_replace_all, "_", " ")
  # strip off first 2 names, which correspond to an internal id and time
  attrs <- attrs[3:length(attrs)]
  conditional_disable(
    shiny::selectInput(
      shiny::NS(id, "attribute"),
      label = shiny::h4("Progress attribute"),
      choices = attrs
    ),
    length(attrs) < 2
  )
}
