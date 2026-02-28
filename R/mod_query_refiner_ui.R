# mod_query_refiner_ui.R -- Query Refiner Module UI

query_refiner_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      box(
        title = "Refine Your Clinical Data Query",
        status = "primary", solidHeader = TRUE, width = 12,
        fluidRow(
          column(8,
            textAreaInput(ns("rough_query"), "Enter your question about the clinical data:",
                          placeholder = "e.g., 'Are there patients with bad liver numbers after surgery?'",
                          rows = 3, width = "100%")
          ),
          column(4,
            br(),
            actionButton(ns("refine_btn"), "Refine Query",
                         icon = icon("magic"), class = "btn-primary btn-lg",
                         style = "width: 100%;"),
            br(), br(),
            radioButtons(ns("provider"), "Mode:",
                         choices = c("Demo Mode" = "demo", "OpenAI GPT-4" = "openai"),
                         selected = "demo", inline = TRUE)
          )
        )
      )
    ),

    # Results
    conditionalPanel(
      condition = sprintf("output['%s'] !== null", ns("has_result")),
      ns = ns,
      fluidRow(
        box(
          title = "Original Query",
          status = "warning", solidHeader = TRUE, width = 6,
          div(style = "font-size: 16px; padding: 15px; background: #fff3cd; border-radius: 8px;",
            textOutput(ns("original_query"))
          )
        ),
        box(
          title = "Refined Query",
          status = "success", solidHeader = TRUE, width = 6,
          div(style = "font-size: 16px; padding: 15px; background: #d4edda; border-radius: 8px;",
            textOutput(ns("refined_query"))
          )
        )
      ),

      fluidRow(
        box(
          title = "Relevant Domains & Variables",
          status = "info", solidHeader = TRUE, width = 4,
          tags$h4("Domains:"),
          uiOutput(ns("domains_list")),
          tags$h4("Variables:"),
          uiOutput(ns("variables_list"))
        ),
        box(
          title = "R Code",
          status = "primary", solidHeader = TRUE, width = 5,
          tags$pre(style = "background: #1e1e1e; color: #d4d4d4; padding: 15px; border-radius: 8px; font-size: 13px;",
            textOutput(ns("r_code"))
          )
        ),
        box(
          title = "Assumptions",
          status = "warning", solidHeader = TRUE, width = 3,
          uiOutput(ns("assumptions_list"))
        )
      )
    ),

    # Query History
    fluidRow(
      box(
        title = "Query History",
        status = "default", solidHeader = FALSE, width = 12,
        collapsible = TRUE, collapsed = TRUE,
        DT::dataTableOutput(ns("history_table"))
      )
    )
  )
}
