#' regression UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS uiOutput
mod_regression_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("regression"))
}

parse_regression_input <-
  function(input, parameters, regression_data) {
    values <- parameters()$values
    if (length(values) > 0)
      filter_expr <-
        mapply(problem_parameter_select, names(values), values, USE.NAMES = FALSE)
    else
      filter_expr <- TRUE
    grouping <- parameters()$grouping

    # extract the data to be plotted
    regression_data() |>
      dplyr::filter(.data$planner %in% !!input$planners,
                    version %in% !!input$version,
                    !!!filter_expr) |>
      dplyr::select(.data$planner,!!input$attribute, version,!!grouping) |>
      dplyr::rename(value = !!input$attribute) |>
      # strip "OMPL " prefix, so we can fit more labels on the X-axis
      # assume the version number is the last "word" in the string
      dplyr::mutate(version = stringr::str_split_i(version, " ",-1)) |>
      dplyr::mutate(version = factor(version, unique(version)))
  }

#' regression Server Functions
#'
#' @noRd
mod_regression_server <- function(id, data) {
  stopifnot(shiny::is.reactive(data))

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    regression_data <- shiny::reactive({
      shiny::validate(shiny::need(input$problem, ""),
                      shiny::need(input$version, ""))
      data()$runs |> dplyr::filter(.data$experiment == !!input$problem &
                                     version %in% !!input$version)
    })
    # performance results for parametrized benchmarks can be grouped by parameter values
    parameters <- shiny::reactive({
      parameter_values <-
        problem_parameter_values(id, data()$experiments, input)
      grouping <- problem_parameter_group_by(parameter_values)
      list(values = parameter_values, grouping = grouping)
    })
    # extract data frame for plotting
    plot_data <- shiny::reactive({
      shiny::validate(shiny::need(regression_data, ""),
                      shiny::need(parameters, ""))
      parse_regression_input(input, parameters, regression_data)
    })

    # plot of overall performance

    regression_plot <- shiny::reactive({
      shiny::validate(shiny::need(plot_data, ""))
      df <- plot_data()
      grouping = parameters()$grouping
      plot <-
        ggplot2::ggplot(
          df,
          ggplot2::aes(
            x = .data$version,
            y = .data$value,
            fill = .data$planner,
            group = .data$planner
          )
        ) +
        # labels
        ggplot2::ylab(snakecase::to_sentence_case(input$attribute)) +
        #theme(legend.title = element_blank(), text = font_selection()) +
        # plot mean and error bars
        ggplot2::stat_summary(
          fun.data = ggplot2::mean_cl_boot,
          geom = "bar",
          position = ggplot2::position_dodge()
        ) +
        ggplot2::stat_summary(
          fun.data = ggplot2::mean_cl_boot,
          geom = "errorbar",
          position = ggplot2::position_dodge()
        )
      if (!is.null(grouping))
        plot <-
        plot + ggplot2::facet_wrap(ggplot2::vars(!!rlang::sym(grouping)))
      plot
    })

    output$regression <- shiny::renderUI({
      shiny::validate(shiny::need(data(), no_database_text))
      shiny::validate(
        shiny::need(
          data()$experiments |> dplyr::select(version) |> dplyr::distinct() |>
            dplyr::tally() > 1,
          "Only one version of OMPL was used for the benchmarks."
        )
      )
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          shiny::uiOutput(ns("problem_select")),
          shiny::uiOutput(ns("problem_param_select")),
          shiny::uiOutput(ns("attribute_select")),
          shiny::uiOutput(ns("version_select")),
          shiny::uiOutput(ns("planner_select"))
        ),
        shiny::mainPanel(
          shiny::downloadButton(ns("download_plot"), "Download plot as PDF"),
          shiny::downloadButton(ns("download_rdata"), "Download plot as RData"),
          shiny::plotOutput(ns("plot"))
        )
      )
    })

    output$problem_select <-
      shiny::renderUI({
        problem_select_widget(id, data()$problem_names)
      })
    output$problem_parameter_select <- shiny::renderUI({
      shiny::validate(
        shiny::need(input$problem, "Select a problem"),
        shiny::need(input$version, "Select a version")
      )
      problem_parameter_select_widgets(id,
                                       data()$experiments,
                                       input$problem,
                                       utils::tail(input$version, n = 1))
    })
    output$attribute_select <-
      shiny::renderUI({
        attribute_select_widget(id, data()$runs)
      })
    output$version_select <-
      shiny::renderUI({
        version_select_widget(id, data()$experiments, TRUE)
      })
    output$planner_select <-
      shiny::renderUI({
        planner_select_widget(id, regression_data())
      })

    output$download_plot <-
      shiny::downloadHandler(
        filename = "regression_plot.pdf",
        content = function(file) {
          grDevices::pdf(
            file = file,
            width = input$paper_width,
            height = input$paper_height
          )
          print(regression_plot())
          grDevices::dev.off()
        }
      )
    output$download_rdata <-
      shiny::downloadHandler(
        filename = "regression_plot.rds",
        content = function(file) {
          regrplot <- regression_plot()
          saveRDS(regrplot, file = file)
        }
      )

    output$plot <- shiny::renderPlot({
      shiny::validate(
        shiny::need(input$version, "Select a version"),
        shiny::need(input$problem, "Select a problem"),
        shiny::need(input$attribute, "Select a benchmark attribute"),
        shiny::need(input$planners, "Select some planners")
      )
      print(regression_plot())
    })
  })
}

## To be copied in the UI
# mod_regression_ui("regression_1")

## To be copied in the server
# mod_regression_server("regression_1")
