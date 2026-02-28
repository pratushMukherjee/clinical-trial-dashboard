# mod_data_overview_ui.R -- Data Overview Module UI

data_overview_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      valueBoxOutput(ns("total_subjects"), width = 3),
      valueBoxOutput(ns("total_sites"), width = 3),
      valueBoxOutput(ns("study_duration"), width = 3),
      valueBoxOutput(ns("completion_rate"), width = 3)
    ),

    fluidRow(
      box(
        title = "Subject Distribution by Treatment Arm",
        status = "primary", solidHeader = TRUE, width = 4,
        plotlyOutput(ns("arm_chart"), height = "300px")
      ),
      box(
        title = "Age Distribution",
        status = "primary", solidHeader = TRUE, width = 4,
        plotlyOutput(ns("age_chart"), height = "300px")
      ),
      box(
        title = "Demographics Breakdown",
        status = "primary", solidHeader = TRUE, width = 4,
        selectInput(ns("demo_var"), "Variable:",
                    choices = c("SEX", "RACE", "ETHNICITY", "COUNTRY"),
                    selected = "SEX"),
        plotlyOutput(ns("demo_chart"), height = "250px")
      )
    ),

    fluidRow(
      box(
        title = "Domain Data Explorer",
        status = "info", solidHeader = TRUE, width = 12,
        fluidRow(
          column(3,
            selectInput(ns("domain_select"), "Select Domain:",
                        choices = c("DM - Demographics" = "DM",
                                    "AE - Adverse Events" = "AE",
                                    "LB - Laboratory Results" = "LB",
                                    "VS - Vital Signs" = "VS",
                                    "DV - Protocol Deviations" = "DV"),
                        selected = "DM")
          ),
          column(3,
            valueBoxOutput(ns("domain_rows"), width = 12)
          ),
          column(3,
            valueBoxOutput(ns("domain_subjects"), width = 12)
          ),
          column(3,
            valueBoxOutput(ns("domain_completeness"), width = 12)
          )
        ),
        DT::dataTableOutput(ns("domain_table"))
      )
    )
  )
}
