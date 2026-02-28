# mod_data_chat_ui.R -- Data Chat Module UI

data_chat_ui <- function(id) {
  ns <- NS(id)

  tagList(
    fluidRow(
      box(
        title = "Chat with Your Clinical Data",
        status = "primary", solidHeader = TRUE, width = 12,

        # Quick action buttons
        div(style = "margin-bottom: 15px;",
          tags$strong("Quick Queries: "),
          actionButton(ns("quick_demo"), "Demographics Summary", class = "btn-sm btn-default"),
          actionButton(ns("quick_sae"), "Serious Adverse Events", class = "btn-sm btn-default"),
          actionButton(ns("quick_alt"), "Elevated ALT Values", class = "btn-sm btn-default"),
          actionButton(ns("quick_dv"), "Protocol Deviations", class = "btn-sm btn-default"),
          actionButton(ns("quick_missing"), "Missing Data", class = "btn-sm btn-default"),
          actionButton(ns("quick_site"), "Site Enrollment", class = "btn-sm btn-default")
        ),

        # Chat area
        div(class = "chat-container", id = ns("chat_area"),
          uiOutput(ns("chat_messages"))
        ),

        # Input area
        fluidRow(
          column(9,
            textInput(ns("user_input"), NULL,
                      placeholder = "Ask a question about the clinical data...",
                      width = "100%")
          ),
          column(2,
            actionButton(ns("send_btn"), "Send", icon = icon("paper-plane"),
                         class = "btn-primary", style = "width: 100%;")
          ),
          column(1,
            actionButton(ns("clear_btn"), "Clear", icon = icon("trash"),
                         class = "btn-default btn-sm", style = "width: 100%; margin-top: 5px;")
          )
        )
      )
    ),

    # Results area
    fluidRow(
      box(
        title = "Results",
        status = "info", solidHeader = TRUE, width = 12,
        uiOutput(ns("result_area")),
        conditionalPanel(
          condition = sprintf("output['%s'] !== null", ns("has_code")),
          ns = ns,
          hr(),
          tags$strong("Generated Code:"),
          tags$pre(style = "background: #1e1e1e; color: #d4d4d4; padding: 10px; border-radius: 8px; font-size: 12px;",
            textOutput(ns("generated_code"))
          )
        )
      )
    )
  )
}
