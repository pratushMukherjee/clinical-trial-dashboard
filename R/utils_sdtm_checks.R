# utils_sdtm_checks.R -- CDISC SDTM-specific validation rules

#' SDTM controlled terminology for common variables
SDTM_CONTROLLED_TERMS <- list(
  SEX = c("M", "F", "U", "UNDIFFERENTIATED"),
  RACE = c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN",
           "AMERICAN INDIAN OR ALASKA NATIVE",
           "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER", "OTHER", "MULTIPLE",
           "NOT REPORTED", "UNKNOWN"),
  ETHNICITY = c("HISPANIC OR LATINO", "NOT HISPANIC OR LATINO",
                "NOT REPORTED", "UNKNOWN"),
  AESEV = c("MILD", "MODERATE", "SEVERE"),
  AESER = c("Y", "N"),
  LBNRIND = c("NORMAL", "HIGH", "LOW", "ABNORMAL", "")
)

#' Check SDTM controlled terminology compliance
#' @param df Data frame
#' @param domain Domain code
#' @return Data frame of findings
check_sdtm_compliance <- function(df, domain) {
  results <- data.frame(
    domain = character(), variable = character(), check_type = character(),
    n_missing = integer(), pct_missing = numeric(), severity = character(),
    description = character(), affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  for (var_name in names(SDTM_CONTROLLED_TERMS)) {
    if (var_name %in% names(df)) {
      valid_terms <- SDTM_CONTROLLED_TERMS[[var_name]]
      invalid <- df[!is.na(df[[var_name]]) & df[[var_name]] != "" & !(df[[var_name]] %in% valid_terms), ]

      if (nrow(invalid) > 0) {
        bad_values <- unique(invalid[[var_name]])
        affected <- unique(invalid$USUBJID)
        affected_str <- paste(head(affected, 5), collapse = ", ")

        results <- rbind(results, data.frame(
          domain = domain, variable = var_name,
          check_type = "SDTM Compliance",
          n_missing = nrow(invalid),
          pct_missing = round(nrow(invalid) / nrow(df) * 100, 2),
          severity = "Major",
          description = sprintf("%s contains non-standard values: %s",
                                 var_name, paste(head(bad_values, 3), collapse = ", ")),
          affected_subjects = affected_str,
          stringsAsFactors = FALSE
        ))
      }
    }
  }

  results
}

#' Run predefined edit checks (clinical validation rules)
#' @param datasets Named list of domain data frames
#' @return Data frame with edit check results
run_edit_checks <- function(datasets) {
  results <- data.frame(
    check_id = character(),
    check_name = character(),
    domain = character(),
    status = character(),
    n_violations = integer(),
    n_records = integer(),
    description = character(),
    affected_subjects = character(),
    stringsAsFactors = FALSE
  )

  dm <- datasets$DM
  ae <- datasets$AE
  lb <- datasets$LB
  vs <- datasets$VS

  # EC-01: All subjects must have demographics
  all_subjects <- unique(unlist(lapply(datasets, function(df) unique(df$USUBJID))))
  dm_subjects <- unique(dm$USUBJID)
  missing_dm <- setdiff(all_subjects, dm_subjects)
  results <- rbind(results, data.frame(
    check_id = "EC-01", check_name = "All subjects must have demographics",
    domain = "DM", status = if (length(missing_dm) == 0) "PASS" else "FAIL",
    n_violations = length(missing_dm), n_records = length(all_subjects),
    description = if (length(missing_dm) == 0) "All subjects have DM records" else
      sprintf("%d subjects missing DM records", length(missing_dm)),
    affected_subjects = paste(head(missing_dm, 5), collapse = ", "),
    stringsAsFactors = FALSE
  ))

  # EC-02: Age must be >= 18
  if ("AGE" %in% names(dm)) {
    underage <- dm[!is.na(dm$AGE) & dm$AGE < 18, ]
    results <- rbind(results, data.frame(
      check_id = "EC-02", check_name = "Subject age must be >= 18",
      domain = "DM", status = if (nrow(underage) == 0) "PASS" else "FAIL",
      n_violations = nrow(underage), n_records = nrow(dm),
      description = if (nrow(underage) == 0) "All subjects >= 18 years" else
        sprintf("%d subjects under 18", nrow(underage)),
      affected_subjects = paste(head(underage$USUBJID, 5), collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }

  # EC-03: Lab results must have units
  if (!is.null(lb) && "LBORRESU" %in% names(lb)) {
    no_units <- lb[is.na(lb$LBORRESU) | lb$LBORRESU == "", ]
    results <- rbind(results, data.frame(
      check_id = "EC-03", check_name = "Lab results must have units",
      domain = "LB", status = if (nrow(no_units) == 0) "PASS" else "FAIL",
      n_violations = nrow(no_units), n_records = nrow(lb),
      description = if (nrow(no_units) == 0) "All lab results have units" else
        sprintf("%d lab records missing units", nrow(no_units)),
      affected_subjects = paste(head(unique(no_units$USUBJID), 5), collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }

  # EC-04: AE severity must be populated
  if (!is.null(ae) && "AESEV" %in% names(ae)) {
    no_sev <- ae[is.na(ae$AESEV) | ae$AESEV == "", ]
    results <- rbind(results, data.frame(
      check_id = "EC-04", check_name = "AE severity must be populated",
      domain = "AE", status = if (nrow(no_sev) == 0) "PASS" else "FAIL",
      n_violations = nrow(no_sev), n_records = nrow(ae),
      description = if (nrow(no_sev) == 0) "All AEs have severity" else
        sprintf("%d AEs missing severity", nrow(no_sev)),
      affected_subjects = paste(head(unique(no_sev$USUBJID), 5), collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }

  # EC-05: Serious AEs must have outcome
  if (!is.null(ae) && all(c("AESER", "AEOUT") %in% names(ae))) {
    serious_no_outcome <- ae[ae$AESER == "Y" & (is.na(ae$AEOUT) | ae$AEOUT == ""), ]
    results <- rbind(results, data.frame(
      check_id = "EC-05", check_name = "Serious AEs must have outcome",
      domain = "AE", status = if (nrow(serious_no_outcome) == 0) "PASS" else "FAIL",
      n_violations = nrow(serious_no_outcome), n_records = sum(ae$AESER == "Y", na.rm = TRUE),
      description = if (nrow(serious_no_outcome) == 0) "All serious AEs have outcomes" else
        sprintf("%d serious AEs missing outcome", nrow(serious_no_outcome)),
      affected_subjects = paste(head(unique(serious_no_outcome$USUBJID), 5), collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }

  # EC-06: Reference start date must be before end date in DM
  if (all(c("RFSTDTC", "RFENDTC") %in% names(dm))) {
    dm_dates <- dm[!is.na(dm$RFSTDTC) & !is.na(dm$RFENDTC) & dm$RFSTDTC != "" & dm$RFENDTC != "", ]
    inversions <- dm_dates[as.Date(dm_dates$RFENDTC) < as.Date(dm_dates$RFSTDTC), ]
    results <- rbind(results, data.frame(
      check_id = "EC-06", check_name = "Reference start date before end date",
      domain = "DM", status = if (nrow(inversions) == 0) "PASS" else "FAIL",
      n_violations = nrow(inversions), n_records = nrow(dm_dates),
      description = if (nrow(inversions) == 0) "All reference dates are valid" else
        sprintf("%d subjects with RFENDTC before RFSTDTC", nrow(inversions)),
      affected_subjects = paste(head(inversions$USUBJID, 5), collapse = ", "),
      stringsAsFactors = FALSE
    ))
  }

  results
}
