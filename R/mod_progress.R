#' progress UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS uiOutput
mod_progress_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("progress"))
}

parse_progress_input <- function(input, parameters, progress_data) {
  values <- parameters()$values
  if (length(values) > 0)
    filter_expr <-
      mapply(problem_parameter_select, names(values), values, USE.NAMES = FALSE)
  else
    filter_expr <- TRUE
  grouping <- parameters()$grouping

  # extract the data to be plotted
  progress_data() |>
    dplyr::filter(.data$planner %in% !!input$planners, !!!filter_expr) |>
    dplyr::select(
      .data$planner,
      value = !!input$attribute,
      time = .data$time.progress,!!grouping
    )
}

#' progress Server Functions
#'
#' @noRd
mod_progress_server <- function(id, data) {
  stopifnot(shiny::is.reactive(data))

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    progress_data <- shiny::reactive({
      shiny::validate(shiny::need(input$problem, ""),
                      shiny::need(input$version, ""))
      data()$runs |>
        dplyr::inner_join(data()$progress,
                          c("run.id" = "runid"),
                          suffix = c("", ".progress")) |>
        dplyr::filter(.data$experiment == !!input$problem &
                        .data$version == !!input$version)
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
      shiny::validate(shiny::need(progress_data, ""),
                      shiny::need(parameters, ""))
      parse_progress_input(input, parameters, progress_data)
    })

    # plot of progress during planner runs
    progress_plot <- shiny::reactive({
      df <- plot_data()
      grouping <- parameters()$grouping
      shiny::validate(
        shiny::need(
          nrow(df) > 0,
          "No progress data available; select a different benchmark, progress attribute, or planners."
        )
      )
      plot <-
        ggplot2::ggplot(
          df,
          ggplot2::aes(
            x = .data$time,
            y = .data$value,
            group = .data$planner,
            color = .data$planner,
            fill = .data$planner
          )
        ) +
        # labels
        ggplot2::labs(x = "time (s)",
                      y = snakecase::to_sentence_case(input$attribute)) +
        #theme(text = font_selection()) +
        # smooth interpolating curve
        ggplot2::geom_smooth(method = "gam") +
        ggplot2::coord_cartesian(xlim = c(0, trunc(max(df$time))))
      # optionally, add individual measurements as semi-transparent points
      if (input$show_measurements)
        plot <-
        plot + ggplot2::geom_point(alpha = I(input$opacity / 100))
      if (!is.null(grouping)) {
        plot <-
          plot + ggplot2::facet_wrap(ggplot2::vars(!!rlang::sym(grouping)), nrow =
                                       1)
      }

      plot
    })

    num_measurements_plot <- shiny::reactive({
      df <- plot_data()
      grouping <- parameters()$grouping
      if (nrow(df) > 0) {
        plot <-
          ggplot2::ggplot(df,
                          ggplot2::aes(
                            x = .data$time,
                            group = .data$planner,
                            color = .data$planner
                          )) +
          # labels
          ggplot2::labs(
            x = "time (s)",
            y = sprintf(
              "# measurements for %s",
              snakecase::to_sentence_case(input$attribute)
            )
          ) +
          #theme(text = font_selection()) +
          ggplot2::geom_freqpoly(binwidth = 1) +
          ggplot2::coord_cartesian(xlim = c(0, trunc(max(df$time))))
        if (!is.null(grouping)) {
          plot <-
            plot + ggplot2::facet_wrap(ggplot2::vars(!!rlang::sym(grouping)), nrow =
                                         1)
        }

        plot
      }
    })

    output$progress <- shiny::renderUI({
      shiny::validate(shiny::need(data(), no_database_text))
      shiny::validate(
        shiny::need(
          data()$progress |> dplyr::tally() > 0,
          "There is no progress data in this database."
        )
      )
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          shiny::uiOutput(ns("problem_select")),
          shiny::uiOutput(ns("problem_parameter_select")),
          shiny::uiOutput(ns("attribute_select")),
          shiny::checkboxInput("advanced_prog_options", "Show advanced options", FALSE),
          shiny::conditionalPanel(
            condition = "input.advanced_prog_options",
            shiny::div(
              class = "well well-light",
              shiny::checkboxInput(ns("show_measurements"), label = "Show individual measurements"),
              shiny::sliderInput(ns("opacity"), label = "Measurement opacity", 0, 100, 50)
            )
          ),
          shiny::uiOutput(ns("version_select")),
          shiny::uiOutput(ns("planner_select"))
        ),
        shiny::mainPanel(
          shiny::downloadButton(ns("download_plot"), "Download plot as PDF"),
          shiny::downloadButton(ns("download_rdata"), "Download plot as R data"),
          shiny::plotOutput(ns("plot")),
          shiny::plotOutput(ns("num_measurements_plot"))
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
      problem_parameter_select_widgets(id, data()$experiments, input$problem, input$version)
    })
    output$attribute_select <-
      shiny::renderUI({
        progress_attribute_select_widget(id, data()$progress)
      })
    output$version_select <-
      shiny::renderUI({
        version_select_widget(id, data()$experiments, FALSE)
      })
    output$planner_select <-
      shiny::renderUI({
        planner_select_widget(id, progress_data())
      })
    output$download_plot <-
      shiny::downloadHandler(
        filename = "progress_plot.pdf",
        content = function(file) {
          grDevices::pdf(
            file = file,
            width = input$paper_width,
            height = input$paper_height
          )
          print(progress_plot())
          print(num_measurements_plot())
          grDevices::dev.off()
        }
      )
    output$download_rdata <-
      shiny::downloadHandler(
        filename = "progress_plot.RData",
        content = function(file) {
          progplot <- progress_plot()
          prognummeasurementsplot <- num_measurements_plot()
          save(progplot, prognummeasurementsplot, file = file)
        }
      )
    output$plot <- shiny::renderPlot({
      shiny::validate(
        shiny::need(input$version, "Select a version"),
        shiny::need(input$problem, "Select a problem"),
        shiny::need(input$attribute, "Select a benchmark attribute"),
        shiny::need(input$planners, "Select some planners")
      )
      print(progress_plot())
    })
    output$num_measurements_plot <- shiny::renderPlot({
      num_measurements_plot()
    })

  })
}

## To be copied in the UI
# mod_progress_ui("progress_1")

## To be copied in the server
# mod_progress_server("progress_1")
