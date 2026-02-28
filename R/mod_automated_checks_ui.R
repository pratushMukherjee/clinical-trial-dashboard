# mod_automated_checks_ui.R -- Automated Checks Module UI

automated_checks_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Edit Check Validation
    fluidRow(
      box(
        title = "Edit Check Validation",
        status = "primary", solidHeader = TRUE, width = 12,
        p("Pre-defined clinical edit checks against loaded study data."),
        actionButton(ns("run_edit_checks"), "Run Edit Checks",
                     icon = icon("check-circle"), class = "btn-primary",
                     style = "margin-bottom: 15px;"),
        fluidRow(
          valueBoxOutput(ns("checks_passed"), width = 4),
          valueBoxOutput(ns("checks_failed"), width = 4),
          valueBoxOutput(ns("total_violations"), width = 4)
        ),
        DT::dataTableOutput(ns("edit_check_table"))
      )
    ),

    # Dataset Comparison
    fluidRow(
      box(
        title = "Dataset Comparison",
        status = "info", solidHeader = TRUE, width = 12,
        p("Compare two versions of a dataset to identify differences."),
        fluidRow(
          column(4,
            selectInput(ns("compare_domain"), "Select Domain to Compare:",
                        choices = c("DM", "AE", "LB", "VS", "DV"),
                        selected = "DM")
          ),
          column(4,
            fileInput(ns("compare_file"), "Upload Comparison File (CSV):",
                      accept = ".csv")
          ),
          column(4,
            br(),
            actionButton(ns("run_compare"), "Compare Datasets",
                         icon = icon("exchange-alt"), class = "btn-info")
          )
        ),
        conditionalPanel(
          condition = sprintf("output['%s'] !== undefined", ns("compare_summary")),
          ns = ns,
          hr(),
          fluidRow(
            valueBoxOutput(ns("new_records"), width = 3),
            valueBoxOutput(ns("deleted_records"), width = 3),
            valueBoxOutput(ns("modified_records"), width = 3),
            valueBoxOutput(ns("unchanged_records"), width = 3)
          ),
          DT::dataTableOutput(ns("compare_table"))
        )
      )
    )
  )
}
