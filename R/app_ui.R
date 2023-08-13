#' The application User-Interface
#'
#' @param request Internal parameter for `{shiny}`.
#'     DO NOT REMOVE.
#' @import shiny markdown
#' @noRd
app_ui <- function(request) {
  tagList(
    # Leave this function for adding external resources
    golem_add_external_resources(),
    # Your application UI logic
    navbarPage(
      "Planner Arena",
      tabPanel(
        "Overall performance",
        mod_performance_ui("performance_1"),
        value = "performance",
        icon = icon("bar-chart")
      ),
      tabPanel(
        "Progress",
        mod_progress_ui("progress_1"),
        value = "progress",
        icon = icon("area-chart")
      ),
      tabPanel(
        "Regression",
        mod_regression_ui("regression_1"),
        value = "regression",
        icon = icon("bar-chart")
      ),
      tabPanel(
        "Database info",
        mod_database_info_ui("database_info_1"),
        value = "database_info",
        icon = icon("info-circle")
      ),
      tabPanel(
        "Change database",
        div(
          class = "row",
          div(
            class = "col-sm-10 col-sm-offset-1",
            h2("Upload benchmark database"),
            fileInput(
              "database",
              label = "",
              accept = c("application/x-sqlite3", ".db")
            ),
            h2("Default benchmark database"),
            tags$ul(tags$li(
              a(href = "javascript:history.go(0)", "Reset to default database")
            ),
            tags$li(
              a(href = "benchmark.db", "Download default database")
            ))
          )
        ),
        value = "database",
        icon = icon("database")
      ),
      tabPanel(
        "Help",
        div(
          class = "row",
          div(class = "col-sm-10 col-sm-offset-1",
              includeMarkdown(
                system.file("app/help.md", package = "plannerarena")
              ))
        ),
        value = "help",
        icon = icon("question-circle")
      ),
      tabPanel(
        "Settings",
        div(
          class = "row",
          div(
            class = "col-sm-10 col-sm-offset-1",
            h2("Plot settings"),
            h3("Font settings"),
            selectInput(
              "fontFamily",
              label = "Font family",
              choices = c("Courier", "Helvetica", "Palatino", "Times"),
              selected = "Helvetica"
            ),
            numericInput("fontSize", "Font size", 20, min = 1, max = 100),
            h3("PDF export paper size (in inches)"),
            numericInput("paperWidth", "Width", 12, min = 1, max = 50),
            numericInput("paperHeight", "Height", 8, min = 1, max = 50)
          )
        ),
        value = "settings",
        icon = icon("gear")
      ),
      id = "navbar",
      header = shinyjs::useShinyjs(),
      footer = div(
        class = "footer",
        div(
          class = "container",
          a(href = "http://kavrakilab.org", "Kavraki Lab"),
          HTML("&bull;"),
          a(href = "https://www.cs.rice.edu", "Department of Computer Science"),
          HTML("&bull;"),
          a(href = "https://www.rice.edu", "Rice University"),
          br(),
          "Funded in part by the",
          a(href = "https://www.nsf.gov", "National Science Foundation")
        ),
      ),
      inverse = TRUE
    )
  )
}

#' Add external Resources to the Application
#'
#' This function is internally used to add external
#' resources inside the Shiny application.
#'
#' @import shiny
#' @importFrom golem add_resource_path activate_js favicon bundle_resources
#' @noRd
golem_add_external_resources <- function() {
  add_resource_path("www",
                    app_sys("app/www"))

  tags$head(favicon(),
            bundle_resources(path = app_sys("app/www"),
                             app_title = "plannerarena"))
            # Add here other external resources
            # for example, you can add shinyalert::useShinyalert())
}
