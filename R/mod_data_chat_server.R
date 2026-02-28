# mod_data_chat_server.R -- Data Chat Module Server

data_chat_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    chat_history <- reactiveVal(list())
    current_result <- reactiveVal(NULL)

    # Helper to add a message
    add_message <- function(role, text) {
      h <- chat_history()
      h[[length(h) + 1]] <- list(role = role, text = text, time = format(Sys.time(), "%H:%M"))
      chat_history(h)
    }

    # Process a query
    process_query <- function(query) {
      add_message("user", query)

      ds <- list(DM = datasets$DM, AE = datasets$AE, LB = datasets$LB,
                 VS = datasets$VS, DV = datasets$DV)

      result <- data_chat_query(query, ds, provider = "demo")
      current_result(result)

      add_message("assistant", result$explanation)
    }

    # Send button
    observeEvent(input$send_btn, {
      req(input$user_input)
      query <- input$user_input
      updateTextInput(session, "user_input", value = "")
      process_query(query)
    })

    # Quick action buttons
    observeEvent(input$quick_demo, { process_query("Show demographics summary") })
    observeEvent(input$quick_sae, { process_query("List all serious adverse events") })
    observeEvent(input$quick_alt, { process_query("Show patients with elevated ALT values") })
    observeEvent(input$quick_dv, { process_query("Protocol deviation summary") })
    observeEvent(input$quick_missing, { process_query("Show missing data by domain") })
    observeEvent(input$quick_site, { process_query("Compare enrollment by site") })

    # Clear chat
    observeEvent(input$clear_btn, {
      chat_history(list())
      current_result(NULL)
    })

    # Render chat messages
    output$chat_messages <- renderUI({
      messages <- chat_history()
      if (length(messages) == 0) {
        return(div(style = "text-align: center; color: #999; padding: 40px;",
          icon("comments", "fa-3x"),
          tags$p("Ask a question about the clinical data, or use a quick query above.")
        ))
      }

      msg_divs <- lapply(messages, function(msg) {
        if (msg$role == "user") {
          div(class = "chat-message chat-user",
            tags$small(msg$time),
            tags$p(msg$text)
          )
        } else {
          div(class = "chat-message chat-assistant",
            tags$small(paste(icon("robot"), msg$time)),
            tags$p(msg$text)
          )
        }
      })

      do.call(tagList, msg_divs)
    })

    # Render results
    output$result_area <- renderUI({
      result <- current_result()
      if (is.null(result)) {
        return(div(style = "text-align: center; color: #999; padding: 20px;",
          "Results will appear here after you ask a question."
        ))
      }

      viz_type <- result$visualization
      data <- result$data_result

      if (is.null(data) || (is.data.frame(data) && nrow(data) == 0)) {
        return(tags$p("No data returned for this query."))
      }

      if (viz_type == "table") {
        DT::renderDataTable({
          DT::datatable(data, options = list(pageLength = 10, scrollX = TRUE),
                        rownames = FALSE)
        }) -> dt_output
        DT::dataTableOutput(session$ns("result_table"))
      } else if (viz_type == "bar") {
        plotlyOutput(session$ns("result_plot"), height = "350px")
      } else if (viz_type == "histogram") {
        plotlyOutput(session$ns("result_plot"), height = "350px")
      } else if (viz_type == "pie") {
        plotlyOutput(session$ns("result_plot"), height = "350px")
      } else {
        DT::dataTableOutput(session$ns("result_table"))
      }
    })

    output$result_table <- DT::renderDataTable({
      result <- current_result()
      req(result)
      DT::datatable(result$data_result,
                    options = list(pageLength = 10, scrollX = TRUE),
                    rownames = FALSE)
    })

    output$result_plot <- renderPlotly({
      result <- current_result()
      req(result)
      data <- result$data_result

      if (result$visualization == "bar") {
        col_names <- names(data)
        plot_ly(data, x = ~data[[col_names[1]]], y = ~data[[col_names[2]]],
                type = "bar", marker = list(color = "#2196F3")) %>%
          layout(xaxis = list(title = col_names[1]),
                 yaxis = list(title = col_names[2]))
      } else if (result$visualization == "histogram") {
        plot_ly(x = ~data[[1]], type = "histogram",
                marker = list(color = "#2196F3")) %>%
          layout(xaxis = list(title = names(data)[1]),
                 yaxis = list(title = "Count"))
      } else if (result$visualization == "pie") {
        col_names <- names(data)
        plot_ly(data, labels = ~data[[col_names[1]]], values = ~data[[col_names[2]]],
                type = "pie") %>%
          layout(showlegend = TRUE)
      }
    })

    output$has_code <- reactive({ !is.null(current_result()) })
    outputOptions(output, "has_code", suspendWhenHidden = FALSE)

    output$generated_code <- renderText({
      result <- current_result()
      if (is.null(result)) return("")
      result$code
    })
  })
}
