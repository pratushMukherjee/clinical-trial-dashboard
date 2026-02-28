# server.R -- Main server logic for Clinical Trial Dashboard

server <- function(input, output, session) {

  # Shared datasets as reactiveValues so modules can access them
  datasets <- reactiveValues(
    DM = DATASETS$DM,
    AE = DATASETS$AE,
    LB = DATASETS$LB,
    VS = DATASETS$VS,
    DV = DATASETS$DV
  )

  # Module servers
  data_overview_server("overview", datasets)
  data_quality_radar_server("quality_radar", datasets)
  automated_checks_server("automated_checks", datasets)
}
