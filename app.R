# app.R -- Clinical Trial Data Quality & AI Review Dashboard
# Entry point for the Shiny application

source("global.R")
source("ui.R")
source("server.R")

shinyApp(ui = ui, server = server)
