# mod_deviation_classifier_ui.R -- Protocol Deviation Classifier Module UI

deviation_classifier_ui <- function(id) {
  ns <- NS(id)

  tagList(
    # Single classification
    fluidRow(
      box(
        title = "Classify a Protocol Deviation",
        status = "primary", solidHeader = TRUE, width = 12,
        fluidRow(
          column(8,
            textAreaInput(ns("deviation_text"),
              "Enter or paste a protocol deviation description:",
              placeholder = "e.g., 'Subject took prohibited concomitant medication (ibuprofen) during washout period'",
              rows = 3, width = "100%"),
            div(style = "margin-top: 5px;",
              tags$strong("Or select from loaded data: "),
              selectInput(ns("sample_dv"), NULL,
                          choices = c("-- Type your own --"),
                          width = "100%")
            )
          ),
          column(4,
            br(),
            actionButton(ns("classify_btn"), "Classify",
                         icon = icon("tags"), class = "btn-primary btn-lg",
                         style = "width: 100%;"),
            br(), br(),
            div(style = "background: #f8f9fa; padding: 15px; border-radius: 8px;",
              tags$h4("Prediction:"),
              uiOutput(ns("prediction_badge")),
              br(),
              tags$h4("Confidence:"),
              uiOutput(ns("confidence_gauge"))
            )
          )
        )
      )
    ),

    # Probability distribution
    conditionalPanel(
      condition = sprintf("output['%s'] !== null", ns("has_prediction")),
      ns = ns,
      fluidRow(
        box(
          title = "Category Probability Distribution",
          status = "info", solidHeader = TRUE, width = 6,
          plotlyOutput(ns("probability_chart"), height = "300px")
        ),
        box(
          title = "Classification Details",
          status = "info", solidHeader = TRUE, width = 6,
          DT::dataTableOutput(ns("probability_table"))
        )
      )
    ),

    # Batch classification
    fluidRow(
      box(
        title = "Batch Classification",
        status = "warning", solidHeader = TRUE, width = 12,
        collapsible = TRUE, collapsed = FALSE,
        p("Classify all protocol deviations in the loaded DV dataset and compare with actual categories."),
        actionButton(ns("batch_btn"), "Run Batch Classification",
                     icon = icon("play"), class = "btn-warning"),
        br(), br(),
        fluidRow(
          valueBoxOutput(ns("batch_accuracy"), width = 3),
          valueBoxOutput(ns("batch_total"), width = 3),
          valueBoxOutput(ns("batch_correct"), width = 3),
          valueBoxOutput(ns("batch_incorrect"), width = 3)
        ),
        fluidRow(
          column(6,
            tags$h4("Confusion Matrix"),
            plotlyOutput(ns("confusion_matrix"), height = "400px")
          ),
          column(6,
            tags$h4("Batch Results"),
            DT::dataTableOutput(ns("batch_table"))
          )
        )
      )
    )
  )
}
