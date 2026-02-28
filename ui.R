# ui.R -- Main UI layout for Clinical Trial Dashboard

ui <- dashboardPage(
  skin = "blue",

  dashboardHeader(
    title = span(icon("heartbeat"), " Clinical Data Review"),
    titleWidth = 300
  ),

  dashboardSidebar(
    width = 300,
    sidebarMenu(
      id = "sidebar",
      menuItem("Data Overview", tabName = "overview", icon = icon("database")),
      menuItem("Data Quality Radar", tabName = "quality_radar", icon = icon("search-plus")),
      menuItem("Query Refiner", tabName = "query_refiner", icon = icon("magic")),
      menuItem("Protocol Deviation Classifier", tabName = "deviation_classifier", icon = icon("tags")),
      menuItem("Data Chat", tabName = "data_chat", icon = icon("comments")),
      menuItem("Automated Checks", tabName = "automated_checks", icon = icon("check-circle"))
    ),
    hr(),
    div(style = "padding: 10px; color: #b8c7ce; font-size: 12px;",
      p(icon("flask"), STUDY_NAME),
      p(icon("info-circle"),
        ifelse(DEMO_MODE,
               "Demo Mode (no API key)",
               "Live Mode (API connected)")),
      p(icon("code-branch"), paste("v", APP_VERSION))
    )
  ),

  dashboardBody(
    tags$head(
      tags$link(rel = "stylesheet", type = "text/css", href = "custom.css")
    ),

    # Demo mode banner
    if (DEMO_MODE) {
      div(class = "alert alert-info", style = "margin: 10px;",
        icon("info-circle"),
        strong(" Running in Demo Mode"),
        " -- AI features use pre-computed responses.",
        " Set OPENAI_API_KEY in .Renviron for live AI."
      )
    },

    tabItems(
      tabItem(tabName = "overview",
        h2("Data Overview"),
        data_overview_ui("overview")
      ),

      tabItem(tabName = "quality_radar",
        h2("Data Quality Radar"),
        data_quality_radar_ui("quality_radar")
      ),

      tabItem(tabName = "query_refiner",
        h2("AI Query Refiner"),
        query_refiner_ui("query_refiner")
      ),

      tabItem(tabName = "deviation_classifier",
        h2("Protocol Deviation Classifier"),
        deviation_classifier_ui("deviation_classifier")
      ),

      tabItem(tabName = "data_chat",
        h2("Data Chat"),
        data_chat_ui("data_chat")
      ),

      tabItem(tabName = "automated_checks",
        h2("Automated Checks"),
        automated_checks_ui("automated_checks")
      )
    )
  )
)
