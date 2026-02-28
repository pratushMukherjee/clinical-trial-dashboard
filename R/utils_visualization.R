# utils_visualization.R -- Reusable plotly chart builder functions

#' Create a radar/spider chart for quality dimension scores
#' @param scores Named numeric vector (e.g., Completeness=95, Consistency=88, ...)
#' @return plotly object
build_radar_chart <- function(scores) {
  categories <- names(scores)
  values <- as.numeric(scores)

  # Close the polygon by repeating the first value
  categories <- c(categories, categories[1])
  values <- c(values, values[1])

  plot_ly(
    type = "scatterpolar",
    r = values,
    theta = categories,
    fill = "toself",
    fillcolor = "rgba(33, 150, 243, 0.3)",
    line = list(color = "#2196F3", width = 2),
    marker = list(size = 8, color = "#2196F3")
  ) %>%
    layout(
      polar = list(
        radialaxis = list(
          visible = TRUE,
          range = c(0, 100),
          tickvals = seq(0, 100, 25),
          ticktext = paste0(seq(0, 100, 25), "%")
        ),
        angularaxis = list(
          tickfont = list(size = 13)
        )
      ),
      showlegend = FALSE,
      margin = list(l = 60, r = 60, t = 40, b = 40)
    )
}

#' Create a severity summary bar chart
#' @param findings Data frame with severity column
#' @return plotly object
build_severity_chart <- function(findings) {
  if (nrow(findings) == 0) {
    return(plotly_empty(type = "bar") %>% layout(title = "No findings"))
  }

  severity_counts <- as.data.frame(table(findings$severity))
  names(severity_counts) <- c("Severity", "Count")

  colors <- c("Critical" = "#dc3545", "Major" = "#fd7e14", "Minor" = "#ffc107")

  severity_counts$Color <- colors[as.character(severity_counts$Severity)]
  severity_counts$Color[is.na(severity_counts$Color)] <- "#6c757d"

  plot_ly(severity_counts, x = ~Severity, y = ~Count, type = "bar",
          marker = list(color = severity_counts$Color)) %>%
    layout(
      xaxis = list(title = "", categoryorder = "array",
                   categoryarray = c("Critical", "Major", "Minor")),
      yaxis = list(title = "Number of Findings")
    )
}

#' Create a check type distribution pie chart
#' @param findings Data frame with check_type column
#' @return plotly object
build_check_type_chart <- function(findings) {
  if (nrow(findings) == 0) {
    return(plotly_empty(type = "pie") %>% layout(title = "No findings"))
  }

  type_counts <- as.data.frame(table(findings$check_type))
  names(type_counts) <- c("Type", "Count")

  plot_ly(type_counts, labels = ~Type, values = ~Count, type = "pie",
          marker = list(colors = c("#2196F3", "#4CAF50", "#FF9800", "#9C27B0", "#F44336")),
          textposition = "inside", textinfo = "label+percent") %>%
    layout(showlegend = TRUE)
}
