# mod_automated_checks_server.R -- Automated Checks Module Server

automated_checks_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    edit_check_results <- reactiveVal(NULL)
    compare_results <- reactiveVal(NULL)

    # --- Edit Checks ---
    observeEvent(input$run_edit_checks, {
      ds <- list(DM = datasets$DM, AE = datasets$AE,
                 LB = datasets$LB, VS = datasets$VS, DV = datasets$DV)

      withProgress(message = "Running edit checks...", value = 0, {
        results <- run_edit_checks(ds)
        incProgress(1)
      })

      edit_check_results(results)
    })

    # Auto-run on load
    observe({
      if (is.null(edit_check_results())) {
        ds <- list(DM = datasets$DM, AE = datasets$AE,
                   LB = datasets$LB, VS = datasets$VS, DV = datasets$DV)
        edit_check_results(run_edit_checks(ds))
      }
    })

    output$checks_passed <- renderValueBox({
      res <- edit_check_results()
      n <- if (!is.null(res)) sum(res$status == "PASS") else 0
      valueBox(n, "Checks Passed", icon = icon("check"), color = "green")
    })

    output$checks_failed <- renderValueBox({
      res <- edit_check_results()
      n <- if (!is.null(res)) sum(res$status == "FAIL") else 0
      valueBox(n, "Checks Failed", icon = icon("times"), color = "red")
    })

    output$total_violations <- renderValueBox({
      res <- edit_check_results()
      n <- if (!is.null(res)) sum(res$n_violations) else 0
      valueBox(format_number(n), "Total Violations", icon = icon("exclamation"), color = "yellow")
    })

    output$edit_check_table <- DT::renderDataTable({
      res <- edit_check_results()
      if (is.null(res)) return(DT::datatable(data.frame(Message = "Click 'Run Edit Checks'")))

      display <- res[, c("check_id", "check_name", "domain", "status",
                          "n_violations", "n_records", "description")]
      names(display) <- c("Check ID", "Check Name", "Domain", "Status",
                           "Violations", "Records Checked", "Description")

      DT::datatable(display, options = list(pageLength = 10, dom = "t"),
                    rownames = FALSE) %>%
        DT::formatStyle("Status",
                        backgroundColor = DT::styleEqual(
                          c("PASS", "FAIL"),
                          c("#d4edda", "#f8d7da")
                        ),
                        fontWeight = "bold")
    })

    # --- Dataset Comparison ---
    observeEvent(input$run_compare, {
      req(input$compare_file)

      uploaded <- read.csv(input$compare_file$datapath, stringsAsFactors = FALSE)
      current <- switch(input$compare_domain,
        DM = datasets$DM, AE = datasets$AE, LB = datasets$LB,
        VS = datasets$VS, DV = datasets$DV
      )

      # Simple comparison by USUBJID
      key_col <- "USUBJID"
      if (!(key_col %in% names(uploaded)) || !(key_col %in% names(current))) {
        showNotification("Both datasets must contain USUBJID column", type = "error")
        return()
      }

      current_ids <- unique(current[[key_col]])
      uploaded_ids <- unique(uploaded[[key_col]])

      new_ids <- setdiff(uploaded_ids, current_ids)
      deleted_ids <- setdiff(current_ids, uploaded_ids)
      common_ids <- intersect(current_ids, uploaded_ids)

      # For common records, check for value differences
      common_cols <- intersect(names(current), names(uploaded))
      modified_ids <- character()

      for (uid in common_ids) {
        row_current <- current[current[[key_col]] == uid, common_cols, drop = FALSE]
        row_uploaded <- uploaded[uploaded[[key_col]] == uid, common_cols, drop = FALSE]

        if (nrow(row_current) > 0 && nrow(row_uploaded) > 0) {
          row_c <- row_current[1, ]
          row_u <- row_uploaded[1, ]
          diffs <- sapply(common_cols, function(col) {
            !identical(as.character(row_c[[col]]), as.character(row_u[[col]]))
          })
          if (any(diffs)) modified_ids <- c(modified_ids, uid)
        }
      }

      compare_results(list(
        new = new_ids,
        deleted = deleted_ids,
        modified = modified_ids,
        unchanged = setdiff(common_ids, modified_ids),
        summary = data.frame(
          Change = c(rep("New", length(new_ids)),
                     rep("Deleted", length(deleted_ids)),
                     rep("Modified", length(modified_ids))),
          USUBJID = c(new_ids, deleted_ids, modified_ids),
          stringsAsFactors = FALSE
        )
      ))
    })

    output$new_records <- renderValueBox({
      res <- compare_results()
      n <- if (!is.null(res)) length(res$new) else 0
      valueBox(n, "New Records", icon = icon("plus"), color = "green")
    })

    output$deleted_records <- renderValueBox({
      res <- compare_results()
      n <- if (!is.null(res)) length(res$deleted) else 0
      valueBox(n, "Deleted Records", icon = icon("minus"), color = "red")
    })

    output$modified_records <- renderValueBox({
      res <- compare_results()
      n <- if (!is.null(res)) length(res$modified) else 0
      valueBox(n, "Modified Records", icon = icon("edit"), color = "yellow")
    })

    output$unchanged_records <- renderValueBox({
      res <- compare_results()
      n <- if (!is.null(res)) length(res$unchanged) else 0
      valueBox(n, "Unchanged", icon = icon("equals"), color = "blue")
    })

    output$compare_table <- DT::renderDataTable({
      res <- compare_results()
      if (is.null(res) || nrow(res$summary) == 0) {
        return(DT::datatable(data.frame(Message = "No differences found")))
      }
      DT::datatable(res$summary, options = list(pageLength = 20), rownames = FALSE) %>%
        DT::formatStyle("Change",
                        backgroundColor = DT::styleEqual(
                          c("New", "Deleted", "Modified"),
                          c("#d4edda", "#f8d7da", "#fff3cd")
                        ))
    })

    output$compare_summary <- reactive({ !is.null(compare_results()) })
    outputOptions(output, "compare_summary", suspendWhenHidden = FALSE)
  })
}
