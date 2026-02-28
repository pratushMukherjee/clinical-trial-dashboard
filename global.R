# global.R -- Global configuration for Clinical Trial Data Quality Dashboard

# Load required packages
library(shiny)
library(shinydashboard)
library(plotly)
library(DT)
library(dplyr)
library(tidyr)
library(readr)
library(lubridate)
library(stringr)
library(httr2)
library(jsonlite)
library(ggplot2)
library(scales)

# Source all R files from the R/ directory
r_files <- list.files("R", pattern = "\\.R$", full.names = TRUE)
sapply(r_files, source)

# Load synthetic datasets
DATASETS <- load_all_domains("data")

# Application constants
APP_TITLE <- "Clinical Trial Data Quality & AI Review Dashboard"
APP_VERSION <- "1.0.0"
STUDY_NAME <- "SURG-2024-001"

# Color palette
COLORS <- list(
  primary = "#2196F3",
  success = "#4CAF50",
  warning = "#FF9800",
  danger = "#F44336",
  info = "#00BCD4",
  purple = "#9C27B0"
)

# Check for API keys
OPENAI_API_KEY <- Sys.getenv("OPENAI_API_KEY", "")
DEMO_MODE <- (OPENAI_API_KEY == "")
