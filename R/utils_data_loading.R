# utils_data_loading.R -- Standardized SDTM data loading and validation

# Required columns per domain
REQUIRED_COLS <- list(
  DM = c("STUDYID", "DOMAIN", "USUBJID", "SUBJID", "AGE", "SEX", "ARMCD", "ARM"),
  AE = c("STUDYID", "DOMAIN", "USUBJID", "AESEQ", "AETERM", "AESEV", "AESTDTC"),
  LB = c("STUDYID", "DOMAIN", "USUBJID", "LBSEQ", "LBTESTCD", "LBTEST", "LBSTRESN"),
  VS = c("STUDYID", "DOMAIN", "USUBJID", "VSSEQ", "VSTESTCD", "VSTEST", "VSSTRESN"),
  DV = c("STUDYID", "DOMAIN", "USUBJID", "DVSEQ", "DVTERM", "DVCAT")
)

#' Load and validate an SDTM domain from CSV
#' @param path File path to CSV
#' @param domain SDTM domain code ("DM", "AE", "LB", "VS", "DV")
#' @return A validated data frame or NULL with warning
load_sdtm_domain <- function(path, domain) {
  if (!file.exists(path)) {
    warning(sprintf("File not found: %s", path))
    return(NULL)
  }

  df <- tryCatch(
    read.csv(path, stringsAsFactors = FALSE, na.strings = c("", "NA")),
    error = function(e) {
      warning(sprintf("Error reading %s: %s", path, e$message))
      return(NULL)
    }
  )

  if (is.null(df)) return(NULL)

  # Validate required columns
  required <- REQUIRED_COLS[[domain]]
  if (!is.null(required)) {
    missing_cols <- setdiff(required, names(df))
    if (length(missing_cols) > 0) {
      warning(sprintf("Domain %s missing required columns: %s",
                       domain, paste(missing_cols, collapse = ", ")))
    }
  }

  # Validate domain field matches
  if ("DOMAIN" %in% names(df)) {
    if (!all(df$DOMAIN == domain, na.rm = TRUE)) {
      warning(sprintf("DOMAIN field contains values other than '%s'", domain))
    }
  }

  df
}

#' Load all SDTM domains from the data directory
#' @param data_dir Path to directory containing CSVs
#' @return Named list of data frames
load_all_domains <- function(data_dir = "data") {
  domains <- list(
    DM = load_sdtm_domain(file.path(data_dir, "sdtm_dm.csv"), "DM"),
    AE = load_sdtm_domain(file.path(data_dir, "sdtm_ae.csv"), "AE"),
    LB = load_sdtm_domain(file.path(data_dir, "sdtm_lb.csv"), "LB"),
    VS = load_sdtm_domain(file.path(data_dir, "sdtm_vs.csv"), "VS"),
    DV = load_sdtm_domain(file.path(data_dir, "sdtm_dv.csv"), "DV")
  )

  # Remove NULL entries
  domains <- domains[!sapply(domains, is.null)]
  domains
}

#' Get summary statistics for a domain
#' @param df A data frame
#' @return List with n_rows, n_cols, n_subjects, completeness
domain_summary <- function(df) {
  list(
    n_rows = nrow(df),
    n_cols = ncol(df),
    n_subjects = length(unique(df$USUBJID)),
    completeness = round(1 - sum(is.na(df)) / (nrow(df) * ncol(df)), 4)
  )
}
