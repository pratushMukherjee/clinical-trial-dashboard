# mod_deviation_classifier_server.R -- Protocol Deviation Classifier Module Server

# R-native keyword fallback classifier (no Python needed)
classify_deviation_r <- function(text) {
  text_lower <- tolower(text)

  keyword_map <- list(
    "INFORMED CONSENT" = c("consent", "icf", "signed", "signature", "witness", "re-consent"),
    "INCLUSION/EXCLUSION CRITERIA" = c("inclusion", "exclusion", "eligibility", "criteria",
                                        "enrolled", "bmi", "pregnancy", "hemoglobin",
                                        "age requirement", "positive"),
    "STUDY PROCEDURES" = c("procedure", "assessment", "blood sample", "mri",
                           "photograph", "rehabilitation", "collection", "vital signs",
                           "post-operative"),
    "STUDY TREATMENT/MEDICATION" = c("device", "medication", "concomitant", "prohibited",
                                      "treatment", "implanted", "calibration", "storage",
                                      "took", "washout"),
    "VISIT SCHEDULE" = c("visit", "schedule", "window", "late", "missed",
                          "early", "phone call", "days late", "earlier"),
    "SAFETY REPORTING" = c("safety", "adverse event", "sae", "report",
                           "malfunction", "severity", "downgrade", "reported")
  )

  scores <- sapply(keyword_map, function(keywords) {
    sum(sapply(keywords, function(kw) grepl(kw, text_lower, fixed = TRUE)))
  })

  best_cat <- names(which.max(scores))
  if (max(scores) == 0) best_cat <- "OTHER"

  total <- max(sum(scores), 1)
  probs <- scores / total
  probs[best_cat] <- max(probs[best_cat], 0.4)

  # Add OTHER
  all_cats <- c(names(keyword_map), "OTHER")
  all_probs <- setNames(rep(0, length(all_cats)), all_cats)
  all_probs[names(probs)] <- probs
  if (best_cat == "OTHER") all_probs["OTHER"] <- 0.5

  # Normalize
  all_probs <- all_probs / sum(all_probs)

  list(
    category = best_cat,
    confidence = round(as.numeric(all_probs[best_cat]), 4),
    probabilities = as.list(round(all_probs, 4))
  )
}

# Try to load Python classifier
python_available <- FALSE
tryCatch({
  if (requireNamespace("reticulate", quietly = TRUE)) {
    py_classifier_path <- "python/deviation_classifier.py"
    model_path <- "models/deviation_pipeline.pkl"
    if (file.exists(py_classifier_path) && file.exists(model_path)) {
      reticulate::source_python(py_classifier_path)
      python_available <- TRUE
    }
  }
}, error = function(e) {
  message("Python classifier not available, using R keyword fallback: ", e$message)
})

# Unified classify function
classify_deviation_unified <- function(text) {
  if (python_available) {
    tryCatch(
      classify_deviation(text),
      error = function(e) classify_deviation_r(text)
    )
  } else {
    classify_deviation_r(text)
  }
}

classify_batch_unified <- function(texts) {
  if (python_available) {
    tryCatch(
      classify_deviations_batch(texts),
      error = function(e) lapply(texts, classify_deviation_r)
    )
  } else {
    lapply(texts, classify_deviation_r)
  }
}


deviation_classifier_server <- function(id, datasets) {
  moduleServer(id, function(input, output, session) {

    prediction <- reactiveVal(NULL)
    batch_results <- reactiveVal(NULL)

    # Populate sample deviations dropdown
    observe({
      dv <- datasets$DV
      if (!is.null(dv) && nrow(dv) > 0) {
        choices <- c("-- Type your own --", setNames(dv$DVTERM, paste0("[", dv$DVCAT, "] ", substr(dv$DVTERM, 1, 80))))
        updateSelectInput(session, "sample_dv", choices = choices)
      }
    })

    # When sample selected, fill text area
    observeEvent(input$sample_dv, {
      if (input$sample_dv != "-- Type your own --") {
        updateTextAreaInput(session, "deviation_text", value = input$sample_dv)
      }
    })

    # Classify button
    observeEvent(input$classify_btn, {
      req(input$deviation_text)
      req(nchar(trimws(input$deviation_text)) > 0)

      withProgress(message = "Classifying...", value = 0.5, {
        result <- classify_deviation_unified(input$deviation_text)
        incProgress(0.5)
      })

      prediction(result)
    })

    output$has_prediction <- reactive({ !is.null(prediction()) })
    outputOptions(output, "has_prediction", suspendWhenHidden = FALSE)

    # Prediction badge
    output$prediction_badge <- renderUI({
      pred <- prediction()
      if (is.null(pred)) return(tags$p(style = "color: #999;", "No prediction yet"))

      color <- switch(pred$category,
        "INFORMED CONSENT" = "#2196F3",
        "INCLUSION/EXCLUSION CRITERIA" = "#4CAF50",
        "STUDY PROCEDURES" = "#FF9800",
        "STUDY TREATMENT/MEDICATION" = "#9C27B0",
        "VISIT SCHEDULE" = "#F44336",
        "SAFETY REPORTING" = "#00BCD4",
        "OTHER" = "#607D8B",
        "#607D8B"
      )

      div(
        span(style = sprintf("background: %s; color: white; padding: 8px 16px; border-radius: 20px; font-size: 16px; font-weight: bold;", color),
             pred$category)
      )
    })

    # Confidence gauge
    output$confidence_gauge <- renderUI({
      pred <- prediction()
      if (is.null(pred)) return(NULL)

      pct <- round(pred$confidence * 100, 1)
      color <- if (pct >= 70) "#4CAF50" else if (pct >= 40) "#FF9800" else "#F44336"

      div(
        div(style = "background: #e0e0e0; border-radius: 10px; height: 25px; width: 100%;",
          div(style = sprintf("background: %s; border-radius: 10px; height: 25px; width: %s%%; text-align: center; color: white; line-height: 25px; font-weight: bold;",
                               color, pct),
              paste0(pct, "%"))
        )
      )
    })

    # Probability chart
    output$probability_chart <- renderPlotly({
      pred <- prediction()
      req(pred)

      probs <- unlist(pred$probabilities)
      df <- data.frame(
        Category = names(probs),
        Probability = as.numeric(probs),
        stringsAsFactors = FALSE
      )
      df <- df[order(df$Probability, decreasing = TRUE), ]

      colors <- ifelse(df$Category == pred$category, "#2196F3", "#B0BEC5")

      plot_ly(df, y = ~reorder(Category, Probability), x = ~Probability,
              type = "bar", orientation = "h",
              marker = list(color = colors)) %>%
        layout(
          xaxis = list(title = "Probability", range = c(0, 1), tickformat = ".0%"),
          yaxis = list(title = ""),
          margin = list(l = 200)
        )
    })

    # Probability table
    output$probability_table <- DT::renderDataTable({
      pred <- prediction()
      req(pred)

      probs <- unlist(pred$probabilities)
      df <- data.frame(
        Category = names(probs),
        Probability = paste0(round(as.numeric(probs) * 100, 1), "%"),
        stringsAsFactors = FALSE
      )
      df <- df[order(-as.numeric(probs)), ]

      DT::datatable(df, options = list(pageLength = 7, dom = "t"),
                    rownames = FALSE)
    })

    # --- Batch Classification ---
    observeEvent(input$batch_btn, {
      dv <- datasets$DV
      req(dv, nrow(dv) > 0)

      withProgress(message = "Batch classifying...", value = 0, {
        results_list <- classify_batch_unified(dv$DVTERM)
        incProgress(1)
      })

      predicted_cats <- sapply(results_list, function(r) r$category)
      confidences <- sapply(results_list, function(r) r$confidence)

      result_df <- data.frame(
        USUBJID = dv$USUBJID,
        DVTERM = substr(dv$DVTERM, 1, 80),
        Actual = dv$DVCAT,
        Predicted = predicted_cats,
        Confidence = round(confidences * 100, 1),
        Correct = ifelse(dv$DVCAT == predicted_cats, "Yes", "No"),
        stringsAsFactors = FALSE
      )

      batch_results(result_df)
    })

    output$batch_accuracy <- renderValueBox({
      res <- batch_results()
      if (is.null(res)) return(valueBox("--", "Accuracy", icon = icon("bullseye"), color = "blue"))
      acc <- round(mean(res$Correct == "Yes") * 100, 1)
      valueBox(paste0(acc, "%"), "Accuracy",
               icon = icon("bullseye"),
               color = if (acc >= 70) "green" else if (acc >= 50) "yellow" else "red")
    })

    output$batch_total <- renderValueBox({
      res <- batch_results()
      n <- if (!is.null(res)) nrow(res) else 0
      valueBox(n, "Total Classified", icon = icon("list"), color = "blue")
    })

    output$batch_correct <- renderValueBox({
      res <- batch_results()
      n <- if (!is.null(res)) sum(res$Correct == "Yes") else 0
      valueBox(n, "Correct", icon = icon("check"), color = "green")
    })

    output$batch_incorrect <- renderValueBox({
      res <- batch_results()
      n <- if (!is.null(res)) sum(res$Correct == "No") else 0
      valueBox(n, "Incorrect", icon = icon("times"), color = "red")
    })

    # Confusion matrix heatmap
    output$confusion_matrix <- renderPlotly({
      res <- batch_results()
      req(res)

      cats <- sort(unique(c(res$Actual, res$Predicted)))
      cm <- table(factor(res$Actual, levels = cats), factor(res$Predicted, levels = cats))
      cm_df <- as.data.frame.matrix(cm)

      plot_ly(
        x = colnames(cm_df), y = rownames(cm_df),
        z = as.matrix(cm_df), type = "heatmap",
        colorscale = list(c(0, "#ffffff"), c(1, "#2196F3")),
        text = as.matrix(cm_df), texttemplate = "%{text}",
        showscale = FALSE
      ) %>%
        layout(
          xaxis = list(title = "Predicted", tickangle = 45),
          yaxis = list(title = "Actual", autorange = "reversed"),
          margin = list(b = 150, l = 200)
        )
    })

    # Batch results table
    output$batch_table <- DT::renderDataTable({
      res <- batch_results()
      req(res)
      DT::datatable(res, options = list(pageLength = 10, scrollX = TRUE),
                    rownames = FALSE) %>%
        DT::formatStyle("Correct",
                        backgroundColor = DT::styleEqual(c("Yes", "No"), c("#d4edda", "#f8d7da")))
    })
  })
}
