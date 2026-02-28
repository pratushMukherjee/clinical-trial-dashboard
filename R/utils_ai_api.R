# utils_ai_api.R -- AI API wrapper functions (OpenAI GPT-4 + Demo Mode)

#' Call the OpenAI API
#' @param system_prompt System role message
#' @param user_message User message
#' @param provider "openai" or "demo"
#' @return Character string of the AI response
call_ai_api <- function(system_prompt, user_message, provider = "openai") {
  if (provider == "demo" || Sys.getenv("OPENAI_API_KEY", "") == "") {
    message("API key not found or demo mode selected. Using demo responses.")
    return(NULL)
  }

  tryCatch({
    resp <- httr2::request("https://api.openai.com/v1/chat/completions") |>
      httr2::req_headers(
        "Authorization" = paste("Bearer", Sys.getenv("OPENAI_API_KEY")),
        "Content-Type" = "application/json"
      ) |>
      httr2::req_body_json(list(
        model = "gpt-4",
        messages = list(
          list(role = "system", content = system_prompt),
          list(role = "user", content = user_message)
        ),
        temperature = 0.3,
        max_tokens = 1500
      )) |>
      httr2::req_perform()

    body <- httr2::resp_body_json(resp)
    body$choices[[1]]$message$content
  }, error = function(e) {
    message(sprintf("API call failed: %s", e$message))
    NULL
  })
}

#' Build schema context string from loaded datasets
#' @param datasets Named list of data frames
#' @return Character string describing available data
build_schema_context <- function(datasets) {
  lines <- "Available CDISC SDTM domains:\n"
  for (name in names(datasets)) {
    df <- datasets[[name]]
    cols <- paste(names(df), collapse = ", ")
    lines <- paste0(lines, sprintf("\n%s (%d records, %d subjects): %s",
                                    name, nrow(df), length(unique(df$USUBJID)), cols))
  }
  lines
}

#' Refine a rough clinical data query into a precise CDISC-compliant query
#' @param rough_query User's informal query
#' @param datasets Named list of domain data frames
#' @param provider "openai" or "demo"
#' @return List with refined_query, domains, variables, r_code, assumptions
refine_query <- function(rough_query, datasets, provider = "openai") {
  # Try demo mode first (always available)
  demo_result <- refine_query_demo(rough_query)

  if (provider == "demo" || Sys.getenv("OPENAI_API_KEY", "") == "") {
    return(demo_result)
  }

  schema <- build_schema_context(datasets)

  system_prompt <- paste0(
    "You are a clinical data management expert working with CDISC SDTM data. ",
    "Your task is to refine informal data queries into precise, actionable queries. ",
    schema,
    "\n\nRespond with JSON only (no markdown fences):\n",
    '{"refined_query": "...", "domains": ["..."], "variables": ["..."], ',
    '"r_code": "...", "assumptions": ["..."]}'
  )

  response <- call_ai_api(system_prompt, rough_query, provider)

  if (is.null(response)) return(demo_result)

  tryCatch({
    parsed <- jsonlite::fromJSON(response)
    list(
      refined_query = parsed$refined_query %||% demo_result$refined_query,
      domains = parsed$domains %||% demo_result$domains,
      variables = parsed$variables %||% demo_result$variables,
      r_code = parsed$r_code %||% demo_result$r_code,
      assumptions = parsed$assumptions %||% demo_result$assumptions
    )
  }, error = function(e) {
    demo_result
  })
}

#' Demo mode query refinement with keyword matching
refine_query_demo <- function(query) {
  query_lower <- tolower(query)

  # Pattern matching for common clinical queries
  if (grepl("liver|alt|ast|hepat", query_lower)) {
    return(list(
      refined_query = "Identify subjects with hepatic laboratory values (ALT, AST) exceeding the upper limit of normal (LBSTRESN > LBORNRHI) at any post-baseline visit (VISITNUM > 2)",
      domains = c("LB", "DM"),
      variables = c("LBTESTCD", "LBSTRESN", "LBORNRHI", "VISITNUM", "USUBJID"),
      r_code = "lb %>% filter(LBTESTCD %in% c('ALT', 'AST'), LBSTRESN > LBORNRHI, VISITNUM > 2) %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID')",
      assumptions = c("'Liver numbers' interpreted as ALT and AST values above reference range", "Post-baseline defined as VISITNUM > 2")
    ))
  }

  if (grepl("blood pressure|hypertens|bp|sysbp|diabp", query_lower)) {
    return(list(
      refined_query = "Identify subjects with systolic blood pressure (SYSBP) >= 140 mmHg or diastolic blood pressure (DIABP) >= 90 mmHg at any study visit",
      domains = c("VS", "DM"),
      variables = c("VSTESTCD", "VSSTRESN", "VISITNUM", "USUBJID"),
      r_code = "vs %>% filter((VSTESTCD == 'SYSBP' & VSSTRESN >= 140) | (VSTESTCD == 'DIABP' & VSSTRESN >= 90)) %>% left_join(dm %>% select(USUBJID, ARM, AGE), by = 'USUBJID')",
      assumptions = c("Hypertension defined as SYSBP >= 140 or DIABP >= 90 mmHg", "Checking all visits, not just baseline")
    ))
  }

  if (grepl("serious|sae|severe", query_lower)) {
    return(list(
      refined_query = "Retrieve all Serious Adverse Events (AESER = 'Y') with their severity, causality, and outcome, grouped by treatment arm",
      domains = c("AE", "DM"),
      variables = c("AETERM", "AESEV", "AESER", "AEREL", "AEOUT", "ARM"),
      r_code = "ae %>% filter(AESER == 'Y') %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID') %>% select(USUBJID, ARM, AETERM, AESEV, AEREL, AEOUT, AESTDTC)",
      assumptions = c("Serious defined as AESER = 'Y' per SDTM conventions", "Including all severity levels of serious events")
    ))
  }

  if (grepl("deviation|protocol|non.?compliance", query_lower)) {
    return(list(
      refined_query = "Summarize protocol deviations by category (DVCAT), including count per category and affected subjects, stratified by treatment arm",
      domains = c("DV", "DM"),
      variables = c("DVTERM", "DVCAT", "DVSCAT", "EPOCH", "USUBJID"),
      r_code = "dv %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID') %>% group_by(ARM, DVCAT) %>% summarise(n_deviations = n(), n_subjects = n_distinct(USUBJID), .groups = 'drop')",
      assumptions = c("Using DVCAT for primary categorization", "Stratifying by planned treatment arm (ARM)")
    ))
  }

  if (grepl("missing|incomplete|empty", query_lower)) {
    return(list(
      refined_query = "Identify variables with missing data rates above 1% across all SDTM domains, ranked by missing percentage",
      domains = c("DM", "AE", "LB", "VS", "DV"),
      variables = c("All variables"),
      r_code = "lapply(list(DM=dm, AE=ae, LB=lb, VS=vs, DV=dv), function(df) { sapply(df, function(x) round(mean(is.na(x) | x == '') * 100, 2)) }) %>% lapply(function(x) x[x > 1]) ",
      assumptions = c("Missing defined as NA or empty string", "Threshold set at 1% for flagging")
    ))
  }

  if (grepl("age|demographic|elderly|old|young", query_lower)) {
    return(list(
      refined_query = "Analyze demographics distribution by treatment arm, including age, sex, and race breakdown with summary statistics",
      domains = c("DM"),
      variables = c("AGE", "SEX", "RACE", "ETHNICITY", "ARM"),
      r_code = "dm %>% group_by(ARM) %>% summarise(n = n(), mean_age = round(mean(AGE, na.rm=TRUE), 1), sd_age = round(sd(AGE, na.rm=TRUE), 1), pct_male = round(mean(SEX == 'M') * 100, 1), .groups = 'drop')",
      assumptions = c("Age computed from AGE variable (may have missing values)", "Demographics based on planned ARM assignment")
    ))
  }

  if (grepl("adverse event|ae |side effect", query_lower)) {
    return(list(
      refined_query = "Summarize adverse event frequency by preferred term (AEDECOD) and body system (AEBODSYS), stratified by treatment arm",
      domains = c("AE", "DM"),
      variables = c("AETERM", "AEDECOD", "AEBODSYS", "AESEV", "ARM"),
      r_code = "ae %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID') %>% group_by(ARM, AEBODSYS, AEDECOD) %>% summarise(n_events = n(), n_subjects = n_distinct(USUBJID), .groups = 'drop') %>% arrange(desc(n_events))",
      assumptions = c("Counting events not subjects (one subject may have multiple events)", "Using dictionary-derived term (AEDECOD) for standardized grouping")
    ))
  }

  if (grepl("vital|temperature|pulse|heart rate|resp", query_lower)) {
    return(list(
      refined_query = "Display vital signs trends over time for all subjects, showing mean values by visit and treatment arm",
      domains = c("VS", "DM"),
      variables = c("VSTESTCD", "VSTEST", "VSSTRESN", "VISIT", "VISITNUM", "ARM"),
      r_code = "vs %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID') %>% filter(!is.na(VSSTRESN)) %>% group_by(ARM, VSTESTCD, VISITNUM, VISIT) %>% summarise(mean_value = round(mean(VSSTRESN), 1), sd_value = round(sd(VSSTRESN), 1), .groups = 'drop')",
      assumptions = c("Using standardized numeric results (VSSTRESN)", "Grouping by planned ARM and visit number")
    ))
  }

  if (grepl("lab|creatinine|hemoglobin|glucose|wbc", query_lower)) {
    return(list(
      refined_query = "Display laboratory results trends for specified tests, comparing baseline to post-baseline values by treatment arm",
      domains = c("LB", "DM"),
      variables = c("LBTESTCD", "LBTEST", "LBSTRESN", "LBORNRHI", "LBORNRLO", "VISIT", "ARM"),
      r_code = "lb %>% left_join(dm %>% select(USUBJID, ARM), by = 'USUBJID') %>% filter(!is.na(LBSTRESN)) %>% group_by(ARM, LBTESTCD, VISITNUM, VISIT) %>% summarise(mean_value = round(mean(LBSTRESN), 1), n_above_uln = sum(LBSTRESN > LBORNRHI), .groups = 'drop')",
      assumptions = c("Using standardized numeric results (LBSTRESN)", "ULN = upper limit of normal (LBORNRHI)")
    ))
  }

  if (grepl("site|center|location", query_lower)) {
    return(list(
      refined_query = "Compare enrollment and data quality metrics across study sites",
      domains = c("DM", "AE", "LB"),
      variables = c("SITEID", "COUNTRY", "USUBJID", "ARM"),
      r_code = "dm %>% group_by(SITEID, COUNTRY) %>% summarise(n_subjects = n(), n_missing_age = sum(is.na(AGE)), pct_complete = round((1 - mean(is.na(AGE))) * 100, 1), .groups = 'drop')",
      assumptions = c("Site identified by SITEID from DM domain", "Data quality proxied by missing AGE rate")
    ))
  }

  # Default fallback
  list(
    refined_query = paste0("Investigate: ", query, " -- Please refine this query by specifying the SDTM domain(s), variable(s), and conditions of interest."),
    domains = c("DM", "AE", "LB", "VS", "DV"),
    variables = c("USUBJID"),
    r_code = "# Please specify domain and conditions for a more targeted query",
    assumptions = c("Query is too general for automated refinement", "Consider specifying domain, variable, or condition")
  )
}

#' Process a natural language data exploration question (Data Chat)
#' @param question User's question
#' @param datasets Named list of domain data frames
#' @param provider "openai" or "demo"
#' @return List with explanation, code, visualization_type, data_result
data_chat_query <- function(question, datasets, provider = "openai") {
  # Try demo mode first
  demo_result <- data_chat_demo(question, datasets)

  if (provider == "demo" || Sys.getenv("OPENAI_API_KEY", "") == "") {
    return(demo_result)
  }

  schema <- build_schema_context(datasets)

  system_prompt <- paste0(
    "You are a clinical data analyst. The user will ask questions about clinical trial data. ",
    "You have access to these SDTM datasets as data frames: dm, ae, lb, vs, dv. ",
    schema,
    "\n\nRespond with JSON only (no markdown fences):\n",
    '{"explanation": "...", "code": "...", "visualization": "table|bar|line|pie|histogram"}'
  )

  response <- call_ai_api(system_prompt, question, provider)

  if (is.null(response)) return(demo_result)

  tryCatch({
    parsed <- jsonlite::fromJSON(response)

    # Execute code safely
    data_result <- tryCatch({
      env <- new.env()
      env$dm <- datasets$DM
      env$ae <- datasets$AE
      env$lb <- datasets$LB
      env$vs <- datasets$VS
      env$dv <- datasets$DV
      for (pkg_fn in c("filter", "select", "mutate", "group_by", "summarise",
                       "arrange", "left_join", "n", "n_distinct", "desc",
                       "mean", "sd", "sum", "round", "head", "unique")) {
        if (exists(pkg_fn, envir = asNamespace("dplyr"), inherits = FALSE)) {
          env[[pkg_fn]] <- get(pkg_fn, envir = asNamespace("dplyr"))
        }
      }
      env[["n_distinct"]] <- dplyr::n_distinct
      env[["%>%"]] <- magrittr::`%>%`
      eval(parse(text = parsed$code), envir = env)
    }, error = function(e) {
      data.frame(Error = e$message)
    })

    list(
      explanation = parsed$explanation %||% demo_result$explanation,
      code = parsed$code %||% demo_result$code,
      visualization = parsed$visualization %||% "table",
      data_result = data_result
    )
  }, error = function(e) {
    demo_result
  })
}

#' Demo mode data chat with pre-programmed responses
data_chat_demo <- function(question, datasets) {
  q <- tolower(question)

  dm <- datasets$DM
  ae <- datasets$AE
  lb <- datasets$LB
  vs <- datasets$VS
  dv <- datasets$DV

  if (grepl("demograph|summary|overview", q)) {
    result <- data.frame(
      Arm = tapply(dm$ARM, dm$ARM, function(x) x[1]),
      Subjects = as.integer(table(dm$ARM)),
      Mean_Age = round(tapply(dm$AGE, dm$ARM, mean, na.rm = TRUE), 1),
      Pct_Male = round(tapply(dm$SEX == "M", dm$ARM, mean) * 100, 1)
    )
    return(list(
      explanation = "Demographics summary by treatment arm showing subject count, mean age, and percent male.",
      code = "dm %>% group_by(ARM) %>% summarise(n = n(), mean_age = mean(AGE, na.rm=TRUE), pct_male = mean(SEX == 'M') * 100)",
      visualization = "table",
      data_result = result
    ))
  }

  if (grepl("serious|sae", q)) {
    sae <- ae[ae$AESER == "Y", c("USUBJID", "AETERM", "AESEV", "AEREL", "AEOUT", "AESTDTC")]
    return(list(
      explanation = sprintf("Found %d serious adverse events across %d subjects.", nrow(sae), length(unique(sae$USUBJID))),
      code = "ae %>% filter(AESER == 'Y') %>% select(USUBJID, AETERM, AESEV, AEREL, AEOUT, AESTDTC)",
      visualization = "table",
      data_result = sae
    ))
  }

  if (grepl("elevated alt|high alt|alt value|liver", q)) {
    alt_high <- lb[lb$LBTESTCD == "ALT" & !is.na(lb$LBSTRESN) & !is.na(lb$LBORNRHI) & lb$LBSTRESN > lb$LBORNRHI,
                   c("USUBJID", "LBSTRESN", "LBORNRHI", "VISIT", "LBDTC")]
    return(list(
      explanation = sprintf("Found %d lab records with ALT above the upper limit of normal (>%s U/L).",
                            nrow(alt_high), alt_high$LBORNRHI[1]),
      code = "lb %>% filter(LBTESTCD == 'ALT', LBSTRESN > LBORNRHI)",
      visualization = "table",
      data_result = alt_high
    ))
  }

  if (grepl("deviation|protocol", q)) {
    dv_summary <- as.data.frame(table(dv$DVCAT))
    names(dv_summary) <- c("Category", "Count")
    dv_summary <- dv_summary[order(-dv_summary$Count), ]
    return(list(
      explanation = sprintf("Protocol deviations summary: %d total deviations across %d categories.",
                            sum(dv_summary$Count), nrow(dv_summary)),
      code = "dv %>% group_by(DVCAT) %>% summarise(n = n()) %>% arrange(desc(n))",
      visualization = "bar",
      data_result = dv_summary
    ))
  }

  if (grepl("adverse event|ae rate|ae freq", q)) {
    ae_counts <- as.data.frame(table(ae$AEDECOD))
    names(ae_counts) <- c("Term", "Count")
    ae_counts <- ae_counts[order(-ae_counts$Count), ]
    ae_counts <- head(ae_counts, 10)
    return(list(
      explanation = "Top 10 adverse events by frequency (dictionary-derived term).",
      code = "ae %>% count(AEDECOD) %>% arrange(desc(n)) %>% head(10)",
      visualization = "bar",
      data_result = ae_counts
    ))
  }

  if (grepl("age distribution|age histogram", q)) {
    ages <- dm$AGE[!is.na(dm$AGE)]
    result <- data.frame(Age = ages)
    return(list(
      explanation = sprintf("Age distribution of %d subjects (mean: %.1f, SD: %.1f).",
                            length(ages), mean(ages), sd(ages)),
      code = "dm %>% filter(!is.na(AGE)) %>% select(AGE)",
      visualization = "histogram",
      data_result = result
    ))
  }

  if (grepl("missing|completeness", q)) {
    missing_by_domain <- data.frame(
      Domain = c("DM", "AE", "LB", "VS", "DV"),
      Records = c(nrow(dm), nrow(ae), nrow(lb), nrow(vs), nrow(dv)),
      Missing_Cells = c(sum(is.na(dm)), sum(is.na(ae)), sum(is.na(lb)),
                        sum(is.na(vs)), sum(is.na(dv))),
      stringsAsFactors = FALSE
    )
    missing_by_domain$Pct_Complete <- round((1 - missing_by_domain$Missing_Cells /
                                              (missing_by_domain$Records * c(ncol(dm), ncol(ae), ncol(lb), ncol(vs), ncol(dv)))) * 100, 1)
    return(list(
      explanation = "Data completeness summary across all SDTM domains.",
      code = "# Computed missing cell counts per domain",
      visualization = "table",
      data_result = missing_by_domain
    ))
  }

  if (grepl("site|center", q)) {
    site_summary <- aggregate(USUBJID ~ SITEID + COUNTRY, data = dm, FUN = function(x) length(unique(x)))
    names(site_summary)[3] <- "Subjects"
    return(list(
      explanation = sprintf("Study site enrollment summary across %d sites.", nrow(site_summary)),
      code = "dm %>% group_by(SITEID, COUNTRY) %>% summarise(n_subjects = n_distinct(USUBJID))",
      visualization = "bar",
      data_result = site_summary
    ))
  }

  if (grepl("vital|bp|blood pressure|temperature", q)) {
    vs_summary <- aggregate(VSSTRESN ~ VSTESTCD + VISIT, data = vs[!is.na(vs$VSSTRESN), ],
                            FUN = function(x) round(mean(x), 1))
    names(vs_summary)[3] <- "Mean_Value"
    return(list(
      explanation = "Vital signs mean values by test and visit.",
      code = "vs %>% filter(!is.na(VSSTRESN)) %>% group_by(VSTESTCD, VISIT) %>% summarise(mean = mean(VSSTRESN))",
      visualization = "table",
      data_result = vs_summary
    ))
  }

  # Default
  list(
    explanation = "I can help with questions about demographics, adverse events, lab results, vital signs, protocol deviations, data completeness, and study sites. Try asking about one of these topics!",
    code = "# Try: 'Show demographics summary', 'List serious adverse events', 'Patients with elevated ALT'",
    visualization = "table",
    data_result = data.frame(
      Topic = c("Demographics", "Adverse Events", "Lab Results", "Vital Signs",
                "Protocol Deviations", "Missing Data", "Study Sites"),
      Example_Query = c("Show demographics summary", "List all serious adverse events",
                        "Patients with elevated ALT", "Show vital signs trends",
                        "Protocol deviation summary", "Show missing data by domain",
                        "Compare enrollment by site")
    )
  )
}
