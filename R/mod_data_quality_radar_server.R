# mod_data_quality_radar_server.R -- Data Quality Radar Module Server

data_quality_radar_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    # Reactive storage for scan results
    scan_results <- reactiveVal(NULL)
    quality_scores <- reactiveVal(NULL)

    # Run quality scan when button is clicked
    observeEvent(input$run_scan, {
      # Collect datasets into list
      ds <- list(
        DM = datasets$DM,
        AE = datasets$AE,
        LB = datasets$LB,
        VS = datasets$VS,
        DV = datasets$DV
      )

      withProgress(message = "Running quality checks...", value = 0, {
        incProgress(0.2, detail = "Checking missing data...")
        findings <- run_all_quality_checks(ds)

        incProgress(0.3, detail = "Checking SDTM compliance...")
        for (domain_name in names(ds)) {
          compliance <- check_sdtm_compliance(ds[[domain_name]], domain_name)
          if (nrow(compliance) > 0) findings <- rbind(findings, compliance)
        }

        incProgress(0.3, detail = "Calculating scores...")
        scores <- calculate_quality_scores(findings, ds)

        incProgress(0.2, detail = "Done!")
      })

      scan_results(findings)
      quality_scores(scores)
    })

    # Auto-run scan on load
    observe({
      if (is.null(scan_results())) {
        ds <- list(DM = datasets$DM, AE = datasets$AE, LB = datasets$LB,
                   VS = datasets$VS, DV = datasets$DV)
        findings <- run_all_quality_checks(ds)
        for (domain_name in names(ds)) {
          compliance <- check_sdtm_compliance(ds[[domain_name]], domain_name)
          if (nrow(compliance) > 0) findings <- rbind(findings, compliance)
        }
        scores <- calculate_quality_scores(findings, ds)
        scan_results(findings)
        quality_scores(scores)
      }
    })

    # Filtered findings
    filtered_findings <- reactive({
      findings <- scan_results()
      if (is.null(findings) || nrow(findings) == 0) return(data.frame())

      if (input$filter_domain != "All") {
        findings <- findings[findings$domain == input$filter_domain, ]
      }
      if (input$filter_type != "All") {
        findings <- findings[findings$check_type == input$filter_type, ]
      }
      if (input$filter_severity != "All") {
        findings <- findings[findings$severity == input$filter_severity, ]
      }
      findings
    })

    # Value boxes
    output$missing_count <- renderValueBox({
      findings <- scan_results()
      n <- if (!is.null(findings)) sum(findings$check_type == "Missing Data") else 0
      valueBox(n, "Missing Data Issues", icon = icon("exclamation-triangle"),
               color = threshold_color(n, 5, 15))
    })

    output$outlier_count <- renderValueBox({
      findings <- scan_results()
      n <- if (!is.null(findings)) sum(findings$check_type == "Outlier") else 0
      valueBox(n, "Outlier Findings", icon = icon("chart-line"),
               color = threshold_color(n, 3, 8))
    })

    output$consistency_count <- renderValueBox({
      findings <- scan_results()
      n <- if (!is.null(findings)) sum(findings$check_type == "Consistency") else 0
      valueBox(n, "Consistency Issues", icon = icon("exchange-alt"),
               color = threshold_color(n, 2, 5))
    })

    output$date_error_count <- renderValueBox({
      findings <- scan_results()
      n <- if (!is.null(findings)) sum(findings$check_type == "Date Logic") else 0
      valueBox(n, "Date Logic Errors", icon = icon("calendar-times"),
               color = threshold_color(n, 1, 3))
    })

    # Radar chart
    output$radar_chart <- renderPlotly({
      scores <- quality_scores()
      if (is.null(scores)) {
        plotly_empty() %>% layout(title = "Click 'Run Quality Scan' to begin")
      } else {
        build_radar_chart(scores)
      }
    })

    # Severity chart
    output$severity_chart <- renderPlotly({
      findings <- scan_results()
      if (is.null(findings)) {
        plotly_empty(type = "bar")
      } else {
        build_severity_chart(findings)
      }
    })

    # Check type chart
    output$type_chart <- renderPlotly({
      findings <- scan_results()
      if (is.null(findings)) {
        plotly_empty(type = "pie")
      } else {
        build_check_type_chart(findings)
      }
    })

    # Findings count text
    output$findings_count <- renderText({
      f <- filtered_findings()
      total <- if (!is.null(scan_results())) nrow(scan_results()) else 0
      sprintf("Showing %d of %d findings", nrow(f), total)
    })

    # Findings table
    output$findings_table <- DT::renderDataTable({
      f <- filtered_findings()
      if (nrow(f) == 0) return(DT::datatable(data.frame(Message = "No findings")))

      display_df <- f[, c("domain", "variable", "check_type", "severity",
                           "description", "n_missing", "affected_subjects")]
      names(display_df) <- c("Domain", "Variable", "Check Type", "Severity",
                              "Description", "Affected Records", "Subjects")

      DT::datatable(display_df,
                    options = list(pageLength = 20, scrollX = TRUE,
                                   order = list(list(3, "asc"))),
                    rownames = FALSE) %>%
        DT::formatStyle("Severity",
                        backgroundColor = DT::styleEqual(
                          c("Critical", "Major", "Minor"),
                          c("#f8d7da", "#fff3cd", "#d4edda")
                        ))
    })

    # Export report
    output$export_report <- downloadHandler(
      filename = function() {
        paste0("quality_report_", Sys.Date(), ".csv")
      },
      content = function(file) {
        findings <- scan_results()
        if (is.null(findings)) {
          write.csv(data.frame(Message = "No scan results"), file, row.names = FALSE)
        } else {
          write.csv(findings, file, row.names = FALSE)
        }
      }
    )
  })
}
