#' performance UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS tagList
mod_performance_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("page"))
}

parse_performance_input <-
  function(input, parameters, performance_data) {
    values <- parameters()$values
    if (length(values) > 0)
      filter_expr <-
        mapply(problem_parameter_select, names(values), values, USE.NAMES = FALSE)
    else
      filter_expr <- TRUE
    grouping <- parameters()$grouping

    # extract the data to be plotted
    plot_data <- performance_data() |>
      dplyr::filter(.data$planner %in% !!input$planners, !!!filter_expr)

    if (input$show_simplified)
      plot_data <- plot_data |>
      dplyr::select(.data$planner,
                    dplyr::matches(stringr::str_glue("(simplified_)?{input$attribute}")),!!grouping)
    else
      plot_data <- plot_data |>
      dplyr::select(.data$planner, !!input$attribute, !!grouping)
    simplified_attribute <-
      stringr::str_glue("simplified_{input$attribute}")
    if (simplified_attribute %in% colnames(plot_data))
    {
      value_types <- c(input$attribute, simplified_attribute)
      plot_data <- plot_data |>
        tidyr::pivot_longer(value_types,
                            names_to = "type",
                            values_to = "value") |>
        dplyr::mutate(type = factor(.data$type, levels = value_types))
    } else {
      plot_data <- plot_data |> dplyr::rename(value = !!input$attribute)
    }

    plot_data
  }

#' performance Server Functions
#'
#' @noRd
mod_performance_server <- function(id, data) {
  stopifnot(shiny::is.reactive(data))

  moduleServer(id, function(input, output, session) {
    ns <- session$ns

    performance_data <- shiny::reactive({
      shiny::validate(shiny::need(input$problem, ""),
                      shiny::need(input$version, ""))
      data()$runs |> dplyr::filter(.data$experiment == !!input$problem &
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
      shiny::validate(shiny::need(performance_data, ""),
                      shiny::need(parameters, ""))
      parse_performance_input(input, parameters, performance_data)
    })

    # plot of overall performance
    performance_plot <- shiny::reactive({
      shiny::validate(shiny::need(plot_data, ""))
      if (input$hide_outliers)
        outlier_shape <- NA
      else
        outlier_shape <- 16

      df <- plot_data()
      grouping = parameters()$grouping
      # use stacked bar charts for factors
      if (is.factor(df$value)) {
        plot <-
          ggplot2::ggplot(df, ggplot2::aes(x = .data$planner, fill = .data$value)) +
          ggplot2::geom_bar()
      }
      else {
        if (input$show_as_cdf) {
          if ("type" %in% colnames(df))
            plot <-
              ggplot2::ggplot(
                df,
                ggplot2::aes(
                  x = .data$value,
                  color = .data$planner,
                  linetype = .data$type
                )
              ) +
              ggplot2::scale_linetype_discrete(
                name = "",
                labels = c("before simplification", "after simplification")
              )
          else
            plot <-
              ggplot2::ggplot(df,
                              ggplot2::aes(x = .data$value, color = .data$planner))
          plot <- plot + ggplot2::stat_ecdf(size = 1) +
            ggplot2::labs(x = snakecase::to_sentence_case(input$attribute),
                          y = "cumulative probability")
        } else {
          if ("type" %in% colnames(df))
            plot <-
              ggplot2::ggplot(
                df,
                ggplot2::aes(
                  x = .data$planner,
                  y = .data$value,
                  color = .data$type,
                  fill = .data$type
                )
              ) +
              ggplot2::scale_fill_manual(
                values = c("#99c9eb", "#ebc999"),
                labels = c("before simplification", "after simplification")
              ) +
              ggplot2::scale_color_manual(
                values = c("#3073ba", "#ba7330"),
                labels = c("before simplification", "after simplification")
              )
          else
            plot <-
              ggplot2::ggplot(df,
                              ggplot2::aes(
                                x = .data$planner,
                                y = .data$value,
                                color = I("#3073ba"),
                                fill = I("#99c9eb")
                              ))

          plot <- plot +
            ggplot2::geom_boxplot(
              position = "dodge",
              outlier.shape = outlier_shape,
              na.rm = TRUE
            ) +
            ggplot2::ylab(snakecase::to_sentence_case(input$attribute)) +
            ggplot2::scale_x_discrete(expand = c(0.05, 0))

          if (input$y_log_scale)
            plot <- plot + ggplot2::scale_y_log10()
        }
      }

      if (!is.null(grouping)) {
        plot <-
          plot + ggplot2::facet_wrap(ggplot2::vars(!!rlang::sym(grouping)), nrow =
                                       1)
      }

      plot
    })

    output$page <- shiny::renderUI({
      shiny::validate(shiny::need(data(), no_database_text))
      shiny::sidebarLayout(
        shiny::sidebarPanel(
          shiny::uiOutput(ns("problem_select")),
          shiny::uiOutput(ns("problem_parameter_select")),
          shiny::uiOutput(ns("attribute_select")),
          shiny::checkboxInput("advanced_perf_options", "Show advanced options", FALSE),
          shiny::conditionalPanel(
            condition = "input.advanced_perf_options",
            shiny::div(
              class = "well well-light",
              shiny::checkboxInput(ns("show_as_cdf"), label = "Show as cumulative distribution function"),
              shiny::checkboxInput(ns("show_simplified"), label = "Include results after simplification"),
              shiny::checkboxInput(ns("hide_outliers"), label = "Hide outliers in box plots"),
              shiny::checkboxInput(ns("y_log_scale"), label = "Use log scale for Y-axis")
            )
          ),
          shiny::uiOutput(ns("version_select")),
          shiny::uiOutput(ns("planner_select"))
        ),
        shiny::mainPanel(
          shiny::includeHTML(system.file("app/cite.html", package = "plannerarena")),
          shiny::downloadButton(ns("download_plot"), "Download plot as PDF"),
          shiny::downloadButton(ns("download_rdata"), "Download plot as R data"),
          shiny::plotOutput(ns("plot")),
          shiny::h4(
            "Number of missing data points out of the total number of runs per planner"
          ),
          shiny::tableOutput(ns("missing_data_table"))
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
        attribute_select_widget(id, data()$runs)
      })
    output$version_select <-
      shiny::renderUI({
        version_select_widget(id, data()$experiments, FALSE)
      })
    output$planner_select <-
      shiny::renderUI({
        planner_select_widget(id, performance_data())
      })
    output$download_plot <-
      shiny::downloadHandler(
        filename = "performance_plot.pdf",
        content = function(file) {
          grDevices::pdf(
            file = file,
            width = input$paper_width,
            height = input$paper_height
          )
          print(performance_plot())
          grDevices::dev.off()
        }
      )
    output$download_rdata <-
      shiny::downloadHandler(
        filename = "performance_plot.rds",
        content = function(file) {
          saveRDS(performance_plot(), file = file)
        }
      )
    output$plot <- shiny::renderPlot({
      shiny::validate(
        shiny::need(input$version, "Select a version"),
        shiny::need(input$problem, "Select a problem"),
        shiny::need(input$attribute, "Select a benchmark attribute"),
        shiny::need(input$planners, "Select some planners")
      )
      print(performance_plot())
    })

    output$missing_data_table <- shiny::renderTable({
      shiny::validate(
        shiny::need(input$version, "Select a version"),
        shiny::need(input$problem, "Select a problem"),
        shiny::need(input$attribute, "Select a benchmark attribute"),
        shiny::need(input$planners, "Select some planners"),
        shiny::need(parameters, "")
      )
      # for parametrized benchmarks we want only the data that matches all parameters exactly
      values <- parameters()$values
      if (length(values) > 0) {
        filter_expr <- mapply(problem_parameter_select,
                              names(values),
                              values,
                              USE.NAMES = FALSE)
      }
      else
        filter_expr <- TRUE
      data <- performance_data() |>
        dplyr::filter(.data$planner %in% !!input$planners, !!!filter_expr) |>
        dplyr::group_by(.data$planner)
      # performance results for parametrized benchmarks can be grouped by parameter values
      grouping <- parameters()$grouping
      if (!is.null(grouping))
        data <-
        data |> dplyr::group_by(!!rlang::sym(grouping), .add = TRUE)
      data |>
        dplyr::select(dplyr::group_cols(), attr = !!input$attribute) |>
        dplyr::mutate(missing = is.na(attr)) |>
        dplyr::summarize(missing = sum(missing, na.rm = TRUE),
                         total = dplyr::n())
    }, rownames = FALSE)

  })
}

## To be copied in the UI
# mod_performance_ui("performance_1")

## To be copied in the server
# mod_performance_server("performance_1")
