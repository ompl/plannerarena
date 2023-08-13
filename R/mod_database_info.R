#' database_info UI Function
#'
#' @description A shiny Module.
#'
#' @param id,input,output,session Internal parameters for {shiny}.
#'
#' @noRd
#'
#' @importFrom shiny NS uiOutput
mod_database_info_ui <- function(id) {
  ns <- NS(id)
  uiOutput(ns("database_info"))
}

#' database_info Server Functions
#'
#' @noRd
mod_database_info_server <- function(id, data) {
  stopifnot(shiny::is.reactive(data))

  moduleServer(id, function(input, output, session) {
    ns <- session$ns
    output$benchmark_info <- shiny::renderTable({
      shiny::validate(shiny::need(data()$experiments, no_database_text))
      data()$experiments |> t()
    }, rownames = TRUE, colnames = FALSE)
    output$planner_configs <- shiny::renderTable({
      data()$planner_configs |>
        dplyr::select(.data$planner, .data$settings) |>
        dplyr::distinct()
    }, rownames = FALSE, colnames = FALSE)

    output$database_info <- shiny::renderUI({
      shiny::validate(shiny::need(data(), no_database_text))
      shiny::tabsetPanel(
        shiny::tabPanel("Benchmark setup", shiny::tableOutput(ns(
          "benchmark_info"
        ))),
        shiny::tabPanel("Planner Configurations", shiny::tableOutput(ns(
          "planner_configs"
        )))
      )
    })
  })
}

## To be copied in the UI
# mod_database_info_ui("database_info_1")

## To be copied in the server
# mod_database_info_server("database_info_1")
