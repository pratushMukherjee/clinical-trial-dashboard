# mod_data_overview_server.R -- Data Overview Module Server

data_overview_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    dm <- reactive({ datasets$DM })
    ae <- reactive({ datasets$AE })
    lb <- reactive({ datasets$LB })
    vs <- reactive({ datasets$VS })
    dv <- reactive({ datasets$DV })

    # --- Value Boxes ---
    output$total_subjects <- renderValueBox({
      n <- length(unique(dm()$USUBJID))
      valueBox(format_number(n), "Total Subjects", icon = icon("users"), color = "blue")
    })

    output$total_sites <- renderValueBox({
      n <- length(unique(dm()$SITEID))
      valueBox(n, "Study Sites", icon = icon("hospital"), color = "purple")
    })

    output$study_duration <- renderValueBox({
      dates <- parse_iso_date(dm()$RFSTDTC)
      dur <- as.integer(max(parse_iso_date(dm()$RFENDTC), na.rm = TRUE) - min(dates, na.rm = TRUE))
      valueBox(paste(dur, "days"), "Study Duration", icon = icon("calendar"), color = "green")
    })

    output$completion_rate <- renderValueBox({
      has_end <- !is.na(dm()$RFENDTC) & dm()$RFENDTC != ""
      rate <- round(sum(has_end) / nrow(dm()) * 100, 1)
      valueBox(paste0(rate, "%"), "Completion Rate", icon = icon("check-circle"), color = "teal")
    })

    # --- Charts ---
    output$arm_chart <- renderPlotly({
      df <- dm()
      arm_counts <- as.data.frame(table(df$ARM))
      names(arm_counts) <- c("Arm", "Count")

      plot_ly(arm_counts, x = ~Arm, y = ~Count, type = "bar",
              marker = list(color = c("#2196F3", "#4CAF50", "#FF9800"))) %>%
        layout(xaxis = list(title = ""),
               yaxis = list(title = "Subjects"),
               margin = list(b = 80))
    })

    output$age_chart <- renderPlotly({
      df <- dm()
      ages <- df$AGE[!is.na(df$AGE)]

      plot_ly(x = ages, type = "histogram",
              marker = list(color = "#2196F3", line = list(color = "white", width = 1)),
              nbinsx = 20) %>%
        layout(xaxis = list(title = "Age (years)"),
               yaxis = list(title = "Count"))
    })

    output$demo_chart <- renderPlotly({
      df <- dm()
      var <- input$demo_var
      counts <- as.data.frame(table(df[[var]]))
      names(counts) <- c("Category", "Count")

      plot_ly(counts, labels = ~Category, values = ~Count, type = "pie",
              textposition = "inside",
              textinfo = "label+percent",
              marker = list(colors = c("#2196F3", "#4CAF50", "#FF9800",
                                       "#9C27B0", "#F44336", "#607D8B"))) %>%
        layout(showlegend = FALSE)
    })

    # --- Domain Data Table ---
    selected_domain <- reactive({
      domain <- input$domain_select
      switch(domain,
        DM = dm(), AE = ae(), LB = lb(), VS = vs(), DV = dv(),
        dm()
      )
    })

    output$domain_rows <- renderValueBox({
      df <- selected_domain()
      valueBox(format_number(nrow(df)), "Records",
               icon = icon("table"), color = "blue")
    })

    output$domain_subjects <- renderValueBox({
      df <- selected_domain()
      valueBox(length(unique(df$USUBJID)), "Subjects",
               icon = icon("user"), color = "purple")
    })

    output$domain_completeness <- renderValueBox({
      df <- selected_domain()
      pct <- round((1 - sum(is.na(df)) / (nrow(df) * ncol(df))) * 100, 1)
      valueBox(paste0(pct, "%"), "Completeness",
               icon = icon("chart-pie"), color = "green")
    })

    output$domain_table <- DT::renderDataTable({
      DT::datatable(selected_domain(),
                    options = list(
                      pageLength = 15,
                      scrollX = TRUE,
                      dom = "Bfrtip",
                      order = list(list(0, "asc"))
                    ),
                    filter = "top",
                    rownames = FALSE)
    })
  })
}
