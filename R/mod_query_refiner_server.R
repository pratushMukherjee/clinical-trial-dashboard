# mod_query_refiner_server.R -- Query Refiner Module Server

query_refiner_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    current_result <- reactiveVal(NULL)
    original_query <- reactiveVal("")
    history <- reactiveVal(data.frame(
      Time = character(), Original = character(), Refined = character(),
      Domains = character(), stringsAsFactors = FALSE
    ))

    observeEvent(input$refine_btn, {
      req(input$rough_query)

      ds <- list(DM = datasets$DM, AE = datasets$AE, LB = datasets$LB,
                 VS = datasets$VS, DV = datasets$DV)

      withProgress(message = "Refining query...", value = 0.5, {
        result <- refine_query(input$rough_query, ds, provider = input$provider)
        incProgress(0.5)
      })

      original_query(input$rough_query)
      current_result(result)

      # Add to history
      h <- history()
      new_row <- data.frame(
        Time = format(Sys.time(), "%H:%M:%S"),
        Original = input$rough_query,
        Refined = result$refined_query,
        Domains = paste(result$domains, collapse = ", "),
        stringsAsFactors = FALSE
      )
      history(rbind(new_row, h))
    })

    output$has_result <- reactive({ !is.null(current_result()) })
    outputOptions(output, "has_result", suspendWhenHidden = FALSE)

    output$original_query <- renderText({ original_query() })

    output$refined_query <- renderText({
      res <- current_result()
      if (is.null(res)) return("")
      res$refined_query
    })

    output$domains_list <- renderUI({
      res <- current_result()
      if (is.null(res)) return(NULL)
      tags$ul(lapply(res$domains, function(d) {
        tags$li(tags$span(class = "label label-primary", style = "font-size: 14px;", d))
      }))
    })

    output$variables_list <- renderUI({
      res <- current_result()
      if (is.null(res)) return(NULL)
      tags$ul(lapply(res$variables, function(v) {
        tags$li(tags$code(v))
      }))
    })

    output$r_code <- renderText({
      res <- current_result()
      if (is.null(res)) return("")
      res$r_code
    })

    output$assumptions_list <- renderUI({
      res <- current_result()
      if (is.null(res)) return(NULL)
      tags$ul(lapply(res$assumptions, function(a) {
        tags$li(icon("info-circle"), a)
      }))
    })

    output$history_table <- DT::renderDataTable({
      h <- history()
      if (nrow(h) == 0) return(DT::datatable(data.frame(Message = "No queries yet")))
      DT::datatable(h, options = list(pageLength = 5, dom = "t"), rownames = FALSE)
    })
  })
}
