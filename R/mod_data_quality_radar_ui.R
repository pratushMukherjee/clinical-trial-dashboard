# mod_data_quality_radar_ui.R -- Data Quality Radar Module UI

data_quality_radar_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      column(12,
        actionButton(ns("run_scan"), "Run Quality Scan",
                     icon = icon("search-plus"),
                     class = "btn-primary btn-lg",
                     style = "margin-bottom: 15px;"),
        downloadButton(ns("export_report"), "Export Report",
                       class = "btn-default",
                       style = "margin-bottom: 15px; margin-left: 10px;")
      )
    ),

    # Summary value boxes
    fluidRow(
      valueBoxOutput(ns("missing_count"), width = 3),
      valueBoxOutput(ns("outlier_count"), width = 3),
      valueBoxOutput(ns("consistency_count"), width = 3),
      valueBoxOutput(ns("date_error_count"), width = 3)
    ),

    # Radar chart + severity breakdown
    fluidRow(
      box(
        title = "Quality Dimension Scores",
        status = "primary", solidHeader = TRUE, width = 6,
        plotlyOutput(ns("radar_chart"), height = "380px")
      ),
      box(
        title = "Findings by Severity",
        status = "warning", solidHeader = TRUE, width = 3,
        plotlyOutput(ns("severity_chart"), height = "380px")
      ),
      box(
        title = "Findings by Check Type",
        status = "info", solidHeader = TRUE, width = 3,
        plotlyOutput(ns("type_chart"), height = "380px")
      )
    ),

    # Detailed findings table
    fluidRow(
      box(
        title = "Detailed Findings",
        status = "danger", solidHeader = TRUE, width = 12,
        fluidRow(
          column(3,
            selectInput(ns("filter_domain"), "Filter by Domain:",
                        choices = c("All", "DM", "AE", "LB", "VS", "DV", "AE/DM"),
                        selected = "All")
          ),
          column(3,
            selectInput(ns("filter_type"), "Filter by Check Type:",
                        choices = c("All", "Missing Data", "Outlier", "Date Logic",
                                    "Consistency", "SDTM Compliance"),
                        selected = "All")
          ),
          column(3,
            selectInput(ns("filter_severity"), "Filter by Severity:",
                        choices = c("All", "Critical", "Major", "Minor"),
                        selected = "All")
          ),
          column(3,
            br(),
            textOutput(ns("findings_count"))
          )
        ),
        DT::dataTableOutput(ns("findings_table"))
      )
    )
  )
}
