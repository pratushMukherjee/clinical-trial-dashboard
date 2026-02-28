# utils_data_quality.R -- Reusable data quality check functions

#' Check for missing values in a dataframe
#' @param df A data frame (any SDTM domain)
#' @param domain Character string identifying the domain
#' @param threshold Minimum proportion of missing values to flag (default 0.01)
#' @return A tibble with columns: domain, variable, n_missing, pct_missing, severity, description
check_missing_data <- function(df, domain, threshold = 0.01) {
  results <- data.frame(
    domain = character(),
    variable = character(),
    check_type = character(),
    n_missing = integer(),
    pct_missing = numeric(),
    severity = character(),
    description = character(),
    affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  for (col in names(df)) {
    n_miss <- sum(is.na(df[[col]]) | df[[col]] == "")
    pct_miss <- n_miss / nrow(df)

    if (pct_miss >= threshold) {
      severity <- if (pct_miss >= 0.10) "Critical" else if (pct_miss >= 0.05) "Major" else "Minor"
      affected <- unique(df$USUBJID[is.na(df[[col]]) | df[[col]] == ""])
      affected_str <- paste(head(affected, 5), collapse = ", ")
      if (length(affected) > 5) affected_str <- paste0(affected_str, " (+", length(affected) - 5, " more)")

      results <- rbind(results, data.frame(
        domain = domain,
        variable = col,
        check_type = "Missing Data",
        n_missing = n_miss,
        pct_missing = round(pct_miss * 100, 2),
        severity = severity,
        description = sprintf("%s has %d missing values (%.1f%%)", col, n_miss, pct_miss * 100),
        affected_subjects = affected_str,
        stringsAsFactors = FALSE
      ))
    }
  }

  results
}

#' Detect outliers using IQR method and/or clinical reference ranges
#' @param df A data frame with numeric results
#' @param domain Character string identifying the domain
#' @param method "iqr", "clinical", or "both"
#' @return A tibble of outlier findings
check_outliers <- function(df, domain, method = "both") {
  results <- data.frame(
    domain = character(), variable = character(), check_type = character(),
    n_missing = integer(), pct_missing = numeric(), severity = character(),
    description = character(), affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  if (domain == "LB" && "LBSTRESN" %in% names(df)) {
    for (test in unique(df$LBTESTCD)) {
      test_data <- df[df$LBTESTCD == test & !is.na(df$LBSTRESN), ]
      if (nrow(test_data) < 5) next

      outlier_ids <- character()

      # IQR method
      if (method %in% c("iqr", "both")) {
        q1 <- quantile(test_data$LBSTRESN, 0.25)
        q3 <- quantile(test_data$LBSTRESN, 0.75)
        iqr <- q3 - q1
        lower <- q1 - 3 * iqr
        upper <- q3 + 3 * iqr
        iqr_outliers <- test_data$USUBJID[test_data$LBSTRESN < lower | test_data$LBSTRESN > upper]
        outlier_ids <- union(outlier_ids, iqr_outliers)
      }

      # Clinical reference range
      if (method %in% c("clinical", "both") && "LBORNRHI" %in% names(test_data)) {
        hi <- test_data$LBORNRHI[1]
        lo <- test_data$LBORNRLO[1]
        if (!is.na(hi)) {
          clin_outliers <- test_data$USUBJID[test_data$LBSTRESN > 3 * hi | test_data$LBSTRESN < lo / 3]
          outlier_ids <- union(outlier_ids, clin_outliers)
        }
      }

      if (length(outlier_ids) > 0) {
        affected_str <- paste(head(unique(outlier_ids), 5), collapse = ", ")
        if (length(unique(outlier_ids)) > 5) {
          affected_str <- paste0(affected_str, " (+", length(unique(outlier_ids)) - 5, " more)")
        }

        results <- rbind(results, data.frame(
          domain = domain, variable = paste0("LBSTRESN (", test, ")"),
          check_type = "Outlier",
          n_missing = length(unique(outlier_ids)),
          pct_missing = round(length(unique(outlier_ids)) / length(unique(test_data$USUBJID)) * 100, 2),
          severity = if (length(unique(outlier_ids)) > 5) "Major" else "Minor",
          description = sprintf("%s: %d extreme outlier records detected", test, length(outlier_ids)),
          affected_subjects = affected_str,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  if (domain == "VS" && "VSSTRESN" %in% names(df)) {
    for (test in unique(df$VSTESTCD)) {
      test_data <- df[df$VSTESTCD == test & !is.na(df$VSSTRESN), ]
      if (nrow(test_data) < 5) next

      q1 <- quantile(test_data$VSSTRESN, 0.25)
      q3 <- quantile(test_data$VSSTRESN, 0.75)
      iqr <- q3 - q1
      lower <- q1 - 3 * iqr
      upper <- q3 + 3 * iqr

      outlier_ids <- unique(test_data$USUBJID[test_data$VSSTRESN < lower | test_data$VSSTRESN > upper])

      if (length(outlier_ids) > 0) {
        affected_str <- paste(head(outlier_ids, 5), collapse = ", ")
        if (length(outlier_ids) > 5) affected_str <- paste0(affected_str, " (+", length(outlier_ids) - 5, " more)")

        results <- rbind(results, data.frame(
          domain = domain, variable = paste0("VSSTRESN (", test, ")"),
          check_type = "Outlier",
          n_missing = length(outlier_ids),
          pct_missing = round(length(outlier_ids) / length(unique(test_data$USUBJID)) * 100, 2),
          severity = if (length(outlier_ids) > 5) "Major" else "Minor",
          description = sprintf("%s: %d subjects with extreme outlier values", test, length(outlier_ids)),
          affected_subjects = affected_str,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  results
}

#' Check date logic within a domain
#' @param df A data frame with date columns
#' @param domain Character string identifying the domain
#' @return A tibble of date logic violations
check_date_logic <- function(df, domain) {
  results <- data.frame(
    domain = character(), variable = character(), check_type = character(),
    n_missing = integer(), pct_missing = numeric(), severity = character(),
    description = character(), affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  date_pairs <- list(
    DM = list(c("RFSTDTC", "RFENDTC"), c("RFXSTDTC", "RFXENDTC")),
    AE = list(c("AESTDTC", "AEENDTC")),
    DV = list(c("DVSTDTC", "DVENDTC"))
  )

  pairs <- date_pairs[[domain]]
  if (is.null(pairs)) return(results)

  for (pair in pairs) {
    start_col <- pair[1]
    end_col <- pair[2]

    if (!all(c(start_col, end_col) %in% names(df))) next

    start_dates <- as.Date(df[[start_col]])
    end_dates <- as.Date(df[[end_col]])

    # Find records where end < start
    inversions <- which(!is.na(start_dates) & !is.na(end_dates) & end_dates < start_dates)

    if (length(inversions) > 0) {
      affected <- unique(df$USUBJID[inversions])
      affected_str <- paste(head(affected, 5), collapse = ", ")
      if (length(affected) > 5) affected_str <- paste0(affected_str, " (+", length(affected) - 5, " more)")

      results <- rbind(results, data.frame(
        domain = domain,
        variable = paste(start_col, "/", end_col),
        check_type = "Date Logic",
        n_missing = length(inversions),
        pct_missing = round(length(inversions) / nrow(df) * 100, 2),
        severity = "Critical",
        description = sprintf("%d records where %s > %s (date inversion)",
                               length(inversions), end_col, start_col),
        affected_subjects = affected_str,
        stringsAsFactors = FALSE
      ))
    }
  }

  results
}

#' Check cross-form consistency between domains
#' @param dm Demographics data
#' @param ae Adverse Events data
#' @param lb Laboratory data
#' @param vs Vital Signs data
#' @return A tibble of cross-form inconsistencies
check_cross_form_consistency <- function(dm, ae, lb, vs) {
  results <- data.frame(
    domain = character(), variable = character(), check_type = character(),
    n_missing = integer(), pct_missing = numeric(), severity = character(),
    description = character(), affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  # Check: AE subjects not in DM
  if (!is.null(ae) && !is.null(dm)) {
    orphan_ae <- setdiff(unique(ae$USUBJID), unique(dm$USUBJID))
    if (length(orphan_ae) > 0) {
      results <- rbind(results, data.frame(
        domain = "AE/DM", variable = "USUBJID",
        check_type = "Consistency",
        n_missing = length(orphan_ae),
        pct_missing = round(length(orphan_ae) / length(unique(ae$USUBJID)) * 100, 2),
        severity = "Critical",
        description = sprintf("%d subjects in AE not found in DM", length(orphan_ae)),
        affected_subjects = paste(head(orphan_ae, 5), collapse = ", "),
        stringsAsFactors = FALSE
      ))
    }
  }

  # Check: AE start dates before treatment start
  if (!is.null(ae) && !is.null(dm)) {
    ae_dm <- merge(ae, dm[, c("USUBJID", "RFXSTDTC")], by = "USUBJID")
    ae_dm$ae_start <- as.Date(ae_dm$AESTDTC)
    ae_dm$trt_start <- as.Date(ae_dm$RFXSTDTC)

    pre_trt <- ae_dm[!is.na(ae_dm$ae_start) & !is.na(ae_dm$trt_start) & ae_dm$ae_start < ae_dm$trt_start, ]

    if (nrow(pre_trt) > 0) {
      affected <- unique(pre_trt$USUBJID)
      affected_str <- paste(head(affected, 5), collapse = ", ")
      if (length(affected) > 5) affected_str <- paste0(affected_str, " (+", length(affected) - 5, " more)")

      results <- rbind(results, data.frame(
        domain = "AE/DM", variable = "AESTDTC vs RFXSTDTC",
        check_type = "Consistency",
        n_missing = nrow(pre_trt),
        pct_missing = round(nrow(pre_trt) / nrow(ae) * 100, 2),
        severity = "Major",
        description = sprintf("%d AEs with start date before treatment start", nrow(pre_trt)),
        affected_subjects = affected_str,
        stringsAsFactors = FALSE
      ))
    }
  }

  # Check: ARM/ACTARM mismatch in DM
  if (!is.null(dm) && all(c("ARMCD", "ACTARMCD") %in% names(dm))) {
    mismatches <- dm[dm$ARMCD != dm$ACTARMCD, ]
    if (nrow(mismatches) > 0) {
      affected <- unique(mismatches$USUBJID)
      results <- rbind(results, data.frame(
        domain = "DM", variable = "ARMCD / ACTARMCD",
        check_type = "Consistency",
        n_missing = nrow(mismatches),
        pct_missing = round(nrow(mismatches) / nrow(dm) * 100, 2),
        severity = "Major",
        description = sprintf("%d subjects with ARM/ACTARM mismatch", nrow(mismatches)),
        affected_subjects = paste(head(affected, 5), collapse = ", "),
        stringsAsFactors = FALSE
      ))
    }
  }

  # Check: VSTESTCD/VSTEST mismatch
  if (!is.null(vs)) {
    vs_ref <- data.frame(
      VSTESTCD = c("SYSBP", "DIABP", "PULSE", "TEMP", "RESP"),
      EXPECTED = c("Systolic Blood Pressure", "Diastolic Blood Pressure",
                   "Pulse Rate", "Temperature", "Respiratory Rate"),
      stringsAsFactors = FALSE
    )
    vs_check <- merge(vs, vs_ref, by = "VSTESTCD")
    mismatches <- vs_check[vs_check$VSTEST != vs_check$EXPECTED, ]
    if (nrow(mismatches) > 0) {
      affected <- unique(mismatches$USUBJID)
      affected_str <- paste(head(affected, 5), collapse = ", ")
      if (length(affected) > 5) affected_str <- paste0(affected_str, " (+", length(affected) - 5, " more)")

      results <- rbind(results, data.frame(
        domain = "VS", variable = "VSTESTCD / VSTEST",
        check_type = "Consistency",
        n_missing = nrow(mismatches),
        pct_missing = round(nrow(mismatches) / nrow(vs) * 100, 2),
        severity = "Major",
        description = sprintf("%d records with VSTESTCD/VSTEST mismatch", nrow(mismatches)),
        affected_subjects = affected_str,
        stringsAsFactors = FALSE
      ))
    }
  }

  results
}

#' Run all quality checks and return combined results
#' @param datasets Named list of domain data frames
#' @return Combined findings data frame
run_all_quality_checks <- function(datasets) {
  all_findings <- data.frame(
    domain = character(), variable = character(), check_type = character(),
    n_missing = integer(), pct_missing = numeric(), severity = character(),
    description = character(), affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  # Missing data checks per domain
  for (domain_name in names(datasets)) {
    findings <- check_missing_data(datasets[[domain_name]], domain_name)
    if (nrow(findings) > 0) all_findings <- rbind(all_findings, findings)
  }

  # Outlier checks for LB and VS
  if (!is.null(datasets$LB)) {
    findings <- check_outliers(datasets$LB, "LB")
    if (nrow(findings) > 0) all_findings <- rbind(all_findings, findings)
  }
  if (!is.null(datasets$VS)) {
    findings <- check_outliers(datasets$VS, "VS")
    if (nrow(findings) > 0) all_findings <- rbind(all_findings, findings)
  }

  # Date logic checks
  for (domain_name in c("DM", "AE", "DV")) {
    if (!is.null(datasets[[domain_name]])) {
      findings <- check_date_logic(datasets[[domain_name]], domain_name)
      if (nrow(findings) > 0) all_findings <- rbind(all_findings, findings)
    }
  }

  # Cross-form consistency
  findings <- check_cross_form_consistency(
    datasets$DM, datasets$AE, datasets$LB, datasets$VS
  )
  if (nrow(findings) > 0) all_findings <- rbind(all_findings, findings)

  all_findings
}

#' Calculate quality dimension scores (0-100)
#' @param findings Data frame from run_all_quality_checks
#' @param datasets Named list of domain data frames
#' @return Named numeric vector of scores
calculate_quality_scores <- function(findings, datasets) {
  total_records <- sum(sapply(datasets, nrow))

  # Completeness: based on missing data
  missing_findings <- findings[findings$check_type == "Missing Data", ]
  total_missing <- sum(missing_findings$n_missing)
  total_cells <- sum(sapply(datasets, function(df) nrow(df) * ncol(df)))
  completeness <- max(0, round(100 * (1 - total_missing / total_cells)))

  # Consistency: based on consistency checks
  consistency_findings <- findings[findings$check_type == "Consistency", ]
  n_consistency_issues <- sum(consistency_findings$n_missing)
  consistency <- max(0, round(100 * (1 - n_consistency_issues / total_records)))

  # Validity: based on outliers
  outlier_findings <- findings[findings$check_type == "Outlier", ]
  n_outliers <- sum(outlier_findings$n_missing)
  validity <- max(0, round(100 * (1 - n_outliers / total_records * 10)))

  # Timeliness: based on date logic
  date_findings <- findings[findings$check_type == "Date Logic", ]
  n_date_issues <- sum(date_findings$n_missing)
  timeliness <- max(0, round(100 * (1 - n_date_issues / total_records * 20)))

  # Accuracy: composite
  accuracy <- round(mean(c(completeness, consistency, validity, timeliness)))

  c(Completeness = completeness, Consistency = consistency,
    Validity = validity, Timeliness = timeliness, Accuracy = accuracy)
}
