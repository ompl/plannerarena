no_database_text <-
  "No database loaded yet. Upload one by clicking on \u201CChange database\u201D."

#' The application server-side
#'
#' @param input,output,session Internal parameters for {shiny}.
#'     DO NOT REMOVE.
#' @import shiny
#' @noRd
app_server <- function(input, output, session) {
  default_database <- getOption("plannerarena.default_database", NULL)
  data <-
    get_benchmark_data(session, shiny::reactive(input$database), default_database)

  # Go straight to the database upload page if there is no default database
  shiny::observe({
    if (is.null(data())) {
      shiny::updateTabsetPanel(session, "navbar", selected = "database")
    }
  })

  mod_performance_server("performance_1", data)
  mod_progress_server("progress_1", data)
  mod_database_info_server("database_info_1", data)
  mod_regression_server("regression_1", data)
}
