# utils_helpers.R -- General utility functions

#' Parse ISO date strings safely
#' @param x Character vector of date strings
#' @return Date vector
parse_iso_date <- function(x) {
  as.Date(x, format = "%Y-%m-%d")
}

#' Format a number with commas
#' @param x Numeric value
#' @return Formatted string
format_number <- function(x) {
  formatC(x, format = "d", big.mark = ",")
}

#' Calculate study duration in days
#' @param start_date Character ISO date
#' @param end_date Character ISO date
#' @return Integer days
study_duration_days <- function(start_date, end_date) {
  as.integer(as.Date(end_date) - as.Date(start_date))
}

#' Severity color mapping
severity_color <- function(severity) {
  colors <- c(
    "Critical" = "#dc3545",
    "Major" = "#fd7e14",
    "Minor" = "#ffc107",
    "Info" = "#17a2b8"
  )
  ifelse(severity %in% names(colors), colors[severity], "#6c757d")
}

#' Create a value box color based on a threshold
#' @param value Numeric value
#' @param warn_threshold Warning threshold
#' @param danger_threshold Danger threshold
#' @return Color string for shinydashboard
threshold_color <- function(value, warn_threshold = 10, danger_threshold = 50) {
  if (is.na(value)) return("blue")
  if (value >= danger_threshold) return("red")
  if (value >= warn_threshold) return("yellow")
  return("green")
}
