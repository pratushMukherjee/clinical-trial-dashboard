# generate_sdtm_data.R -- Master script to generate all CDISC SDTM synthetic datasets
# Run: Rscript data-raw/generate_sdtm_data.R

source("data-raw/seed_config.R")
set.seed(SEED)

cat("=== Generating CDISC SDTM Synthetic Data ===\n")
cat(sprintf("Study: %s | Subjects: %d | Sites: %d\n\n", STUDY_ID, N_SUBJECTS, length(SITE_IDS)))

# ============================================================================
# DM -- Demographics Domain
# ============================================================================
cat("Generating DM (Demographics)...\n")

# Assign subjects to sites and arms
site_assignments <- sample(SITE_IDS, N_SUBJECTS, replace = TRUE, prob = SITE_WEIGHTS)
arm_assignments <- sample(seq_along(ARM_CODES), N_SUBJECTS, replace = TRUE, prob = ARM_WEIGHTS)

dm <- data.frame(
  STUDYID = STUDY_ID,
  DOMAIN = "DM",
  USUBJID = sprintf("%s-%04d", STUDY_ID, 1:N_SUBJECTS),
  SUBJID = sprintf("%04d", 1:N_SUBJECTS),
  SITEID = site_assignments,
  stringsAsFactors = FALSE
)

# Reference dates (treatment start varies by subject)
dm$RFXSTDTC <- as.character(STUDY_START + sample(0:60, N_SUBJECTS, replace = TRUE))
dm$RFSTDTC <- as.character(as.Date(dm$RFXSTDTC) - sample(7:21, N_SUBJECTS, replace = TRUE))
dm$RFXENDTC <- as.character(as.Date(dm$RFXSTDTC) + sample(140:180, N_SUBJECTS, replace = TRUE))
dm$RFENDTC <- as.character(as.Date(dm$RFXENDTC) + sample(7:30, N_SUBJECTS, replace = TRUE))

# INTENTIONAL QUALITY ISSUE: ~3% of subjects have RFSTDTC > RFENDTC (date inversion)
date_inversion_idx <- sample(1:N_SUBJECTS, round(N_SUBJECTS * 0.03))
dm$RFENDTC[date_inversion_idx] <- as.character(
  as.Date(dm$RFSTDTC[date_inversion_idx]) - sample(5:30, length(date_inversion_idx), replace = TRUE)
)

# Demographics
dm$AGE <- round(rnorm(N_SUBJECTS, mean = 55, sd = 12))
dm$AGE <- pmax(22, pmin(82, dm$AGE))
dm$AGEU <- "YEARS"
dm$BRTHDTC <- as.character(as.Date(dm$RFSTDTC) - dm$AGE * 365.25)

# INTENTIONAL QUALITY ISSUE: ~5% missing AGE
missing_age_idx <- sample(1:N_SUBJECTS, round(N_SUBJECTS * 0.05))
dm$AGE[missing_age_idx] <- NA

dm$SEX <- sample(c("M", "F"), N_SUBJECTS, replace = TRUE, prob = c(0.52, 0.48))
dm$RACE <- sample(RACE_OPTIONS, N_SUBJECTS, replace = TRUE, prob = RACE_WEIGHTS)
dm$ETHNICITY <- sample(ETHNICITY_OPTIONS, N_SUBJECTS, replace = TRUE, prob = ETHNICITY_WEIGHTS)

dm$ARMCD <- ARM_CODES[arm_assignments]
dm$ARM <- ARM_LABELS[arm_assignments]
dm$ACTARMCD <- dm$ARMCD
dm$ACTARM <- dm$ARM

# INTENTIONAL QUALITY ISSUE: ~2% arm mismatch (ACTARM differs from ARM)
arm_mismatch_idx <- sample(1:N_SUBJECTS, round(N_SUBJECTS * 0.02))
for (i in arm_mismatch_idx) {
  other_arms <- setdiff(seq_along(ARM_CODES), which(ARM_CODES == dm$ARMCD[i]))
  new_arm <- sample(other_arms, 1)
  dm$ACTARMCD[i] <- ARM_CODES[new_arm]
  dm$ACTARM[i] <- ARM_LABELS[new_arm]
}

dm$COUNTRY <- SITE_COUNTRIES[match(dm$SITEID, SITE_IDS)]
dm$DTHFL <- ifelse(runif(N_SUBJECTS) < 0.015, "Y", "")

write.csv(dm, "data/sdtm_dm.csv", row.names = FALSE)
cat(sprintf("  -> %d records written to data/sdtm_dm.csv\n", nrow(dm)))

# ============================================================================
# AE -- Adverse Events Domain
# ============================================================================
cat("Generating AE (Adverse Events)...\n")

ae_list <- list()
for (i in 1:N_SUBJECTS) {
  n_ae <- sample(0:6, 1, prob = c(0.15, 0.25, 0.25, 0.15, 0.10, 0.05, 0.05))
  if (n_ae == 0) next

  subj_start <- as.Date(dm$RFXSTDTC[i])
  subj_end <- as.Date(dm$RFXENDTC[i])

  for (j in 1:n_ae) {
    ae_idx <- sample(1:nrow(AE_TERMS), 1, prob = AE_TERMS$WEIGHT)
    ae_start <- subj_start + sample(1:as.numeric(subj_end - subj_start), 1)
    ae_duration <- sample(1:30, 1)
    ae_end <- ae_start + ae_duration

    severity <- sample(c("MILD", "MODERATE", "SEVERE"), 1, prob = c(0.55, 0.30, 0.15))
    serious <- ifelse(severity == "SEVERE" & runif(1) < 0.6, "Y", "N")
    relatedness <- sample(c("RELATED", "POSSIBLY RELATED", "NOT RELATED"), 1,
                          prob = c(0.20, 0.35, 0.45))

    ae_list[[length(ae_list) + 1]] <- data.frame(
      STUDYID = STUDY_ID,
      DOMAIN = "AE",
      USUBJID = dm$USUBJID[i],
      AESEQ = j,
      AETERM = AE_TERMS$AETERM[ae_idx],
      AEDECOD = AE_TERMS$AEDECOD[ae_idx],
      AEBODSYS = AE_TERMS$AEBODSYS[ae_idx],
      AESEV = severity,
      AESER = serious,
      AEREL = relatedness,
      AEACN = sample(c("DOSE NOT CHANGED", "DRUG INTERRUPTED", "DRUG WITHDRAWN", "NOT APPLICABLE"),
                      1, prob = c(0.60, 0.20, 0.10, 0.10)),
      AEOUT = sample(c("RECOVERED/RESOLVED", "RECOVERING/RESOLVING",
                        "NOT RECOVERED/NOT RESOLVED", "FATAL"),
                      1, prob = c(0.65, 0.20, 0.14, 0.01)),
      AESTDTC = as.character(ae_start),
      AEENDTC = as.character(ae_end),
      stringsAsFactors = FALSE
    )
  }
}

ae <- do.call(rbind, ae_list)

# INTENTIONAL QUALITY ISSUE: ~5% of AEs have start date before treatment start
pre_treatment_idx <- sample(1:nrow(ae), round(nrow(ae) * 0.05))
for (idx in pre_treatment_idx) {
  subj <- ae$USUBJID[idx]
  trt_start <- as.Date(dm$RFXSTDTC[dm$USUBJID == subj])
  ae$AESTDTC[idx] <- as.character(trt_start - sample(5:30, 1))
}

# INTENTIONAL QUALITY ISSUE: ~3% of AEs have end date before start date
date_error_idx <- sample(1:nrow(ae), round(nrow(ae) * 0.03))
ae$AEENDTC[date_error_idx] <- as.character(
  as.Date(ae$AESTDTC[date_error_idx]) - sample(1:10, length(date_error_idx), replace = TRUE)
)

write.csv(ae, "data/sdtm_ae.csv", row.names = FALSE)
cat(sprintf("  -> %d records written to data/sdtm_ae.csv\n", nrow(ae)))

# ============================================================================
# LB -- Laboratory Results Domain
# ============================================================================
cat("Generating LB (Laboratory Results)...\n")

lb_list <- list()
seq_counter <- rep(0, N_SUBJECTS)

for (i in 1:N_SUBJECTS) {
  subj_start <- as.Date(dm$RFXSTDTC[i])

  for (v in seq_along(VISIT_NUMS)) {
    visit_date <- subj_start + VISIT_DAYS[v]

    # ~8% chance of missing a visit entirely
    if (v > 2 && runif(1) < 0.08) next

    for (t in 1:nrow(LAB_TESTS)) {
      seq_counter[i] <- seq_counter[i] + 1

      # Generate result value
      value <- rnorm(1, mean = LAB_TESTS$MEAN[t], sd = LAB_TESTS$SD[t])
      value <- round(max(0, value), 1)

      # Reference range indicator
      nrind <- "NORMAL"
      if (value < LAB_TESTS$LBORNRLO[t]) nrind <- "LOW"
      if (value > LAB_TESTS$LBORNRHI[t]) nrind <- "HIGH"

      lb_list[[length(lb_list) + 1]] <- data.frame(
        STUDYID = STUDY_ID,
        DOMAIN = "LB",
        USUBJID = dm$USUBJID[i],
        LBSEQ = seq_counter[i],
        LBTESTCD = LAB_TESTS$LBTESTCD[t],
        LBTEST = LAB_TESTS$LBTEST[t],
        LBCAT = LAB_TESTS$LBCAT[t],
        LBORRES = as.character(value),
        LBORRESU = LAB_TESTS$LBORRESU[t],
        LBORNRLO = LAB_TESTS$LBORNRLO[t],
        LBORNRHI = LAB_TESTS$LBORNRHI[t],
        LBSTRESN = value,
        LBSTRESU = LAB_TESTS$LBORRESU[t],
        LBNRIND = nrind,
        VISITNUM = VISIT_NUMS[v],
        VISIT = VISIT_NAMES[v],
        LBDTC = as.character(visit_date),
        LBBLFL = ifelse(v == 2, "Y", ""),
        stringsAsFactors = FALSE
      )
    }
  }
}

lb <- do.call(rbind, lb_list)

# INTENTIONAL QUALITY ISSUE: Inject extreme outliers (~2%)
outlier_idx <- sample(which(lb$LBTESTCD == "ALT"), round(sum(lb$LBTESTCD == "ALT") * 0.02))
lb$LBSTRESN[outlier_idx] <- round(runif(length(outlier_idx), 200, 500), 1)
lb$LBORRES[outlier_idx] <- as.character(lb$LBSTRESN[outlier_idx])
lb$LBNRIND[outlier_idx] <- "HIGH"

outlier_idx2 <- sample(which(lb$LBTESTCD == "HGB"), round(sum(lb$LBTESTCD == "HGB") * 0.02))
lb$LBSTRESN[outlier_idx2] <- round(runif(length(outlier_idx2), 4, 7), 1)
lb$LBORRES[outlier_idx2] <- as.character(lb$LBSTRESN[outlier_idx2])
lb$LBNRIND[outlier_idx2] <- "LOW"

# INTENTIONAL QUALITY ISSUE: ~3% missing LBSTRESN
missing_lb_idx <- sample(1:nrow(lb), round(nrow(lb) * 0.03))
lb$LBSTRESN[missing_lb_idx] <- NA
lb$LBNRIND[missing_lb_idx] <- ""

write.csv(lb, "data/sdtm_lb.csv", row.names = FALSE)
cat(sprintf("  -> %d records written to data/sdtm_lb.csv\n", nrow(lb)))

# ============================================================================
# VS -- Vital Signs Domain
# ============================================================================
cat("Generating VS (Vital Signs)...\n")

vs_list <- list()
vs_seq_counter <- rep(0, N_SUBJECTS)

for (i in 1:N_SUBJECTS) {
  subj_start <- as.Date(dm$RFXSTDTC[i])

  for (v in seq_along(VISIT_NUMS)) {
    visit_date <- subj_start + VISIT_DAYS[v]

    if (v > 2 && runif(1) < 0.05) next

    for (t in 1:nrow(VITAL_TESTS)) {
      vs_seq_counter[i] <- vs_seq_counter[i] + 1

      value <- rnorm(1, mean = VITAL_TESTS$MEAN[t], sd = VITAL_TESTS$SD[t])
      value <- round(max(0, value), 1)

      # Convert F to C for standard units
      std_value <- value
      if (VITAL_TESTS$VSTESTCD[t] == "TEMP") {
        std_value <- round((value - 32) * 5 / 9, 1)
      }

      # Determine test name -- will intentionally mismatch some
      test_name <- VITAL_TESTS$VSTEST[t]

      vs_list[[length(vs_list) + 1]] <- data.frame(
        STUDYID = STUDY_ID,
        DOMAIN = "VS",
        USUBJID = dm$USUBJID[i],
        VSSEQ = vs_seq_counter[i],
        VSTESTCD = VITAL_TESTS$VSTESTCD[t],
        VSTEST = test_name,
        VSORRES = as.character(value),
        VSORRESU = VITAL_TESTS$VSORRESU[t],
        VSSTRESN = std_value,
        VSSTRESU = VITAL_TESTS$VSSTRESU[t],
        VISITNUM = VISIT_NUMS[v],
        VISIT = VISIT_NAMES[v],
        VSDTC = as.character(visit_date),
        VSBLFL = ifelse(v == 2, "Y", ""),
        stringsAsFactors = FALSE
      )
    }
  }
}

vs <- do.call(rbind, vs_list)

# INTENTIONAL QUALITY ISSUE: Extreme vital sign outliers (~1.5%)
bp_idx <- sample(which(vs$VSTESTCD == "SYSBP"), round(sum(vs$VSTESTCD == "SYSBP") * 0.015))
vs$VSSTRESN[bp_idx] <- sample(c(40, 45, 240, 250, 260), length(bp_idx), replace = TRUE)
vs$VSORRES[bp_idx] <- as.character(vs$VSSTRESN[bp_idx])

temp_idx <- sample(which(vs$VSTESTCD == "TEMP"), round(sum(vs$VSTESTCD == "TEMP") * 0.015))
vs$VSORRES[temp_idx] <- as.character(sample(c(94.0, 95.0, 104.5, 105.0, 106.0), length(temp_idx), replace = TRUE))

# INTENTIONAL QUALITY ISSUE: ~2% VSTESTCD/VSTEST mismatch
mismatch_idx <- sample(1:nrow(vs), round(nrow(vs) * 0.02))
mismatched_names <- sample(VITAL_TESTS$VSTEST, length(mismatch_idx), replace = TRUE)
vs$VSTEST[mismatch_idx] <- mismatched_names

# INTENTIONAL QUALITY ISSUE: ~2% missing VSSTRESN
missing_vs_idx <- sample(1:nrow(vs), round(nrow(vs) * 0.02))
vs$VSSTRESN[missing_vs_idx] <- NA

write.csv(vs, "data/sdtm_vs.csv", row.names = FALSE)
cat(sprintf("  -> %d records written to data/sdtm_vs.csv\n", nrow(vs)))

# ============================================================================
# DV -- Protocol Deviations Domain
# ============================================================================
cat("Generating DV (Protocol Deviations)...\n")

dv_categories <- names(DV_TEMPLATES)
dv_list <- list()

# ~35% of subjects have deviations
dv_subjects <- sample(1:N_SUBJECTS, round(N_SUBJECTS * 0.35))

for (i in dv_subjects) {
  n_dv <- sample(1:3, 1, prob = c(0.55, 0.30, 0.15))
  subj_start <- as.Date(dm$RFXSTDTC[i])
  subj_end <- as.Date(dm$RFXENDTC[i])

  for (j in 1:n_dv) {
    cat_idx <- sample(seq_along(dv_categories), 1)
    category <- dv_categories[cat_idx]
    templates <- DV_TEMPLATES[[category]]
    template <- sample(templates, 1)

    # Fill template with random values
    n_formats <- length(gregexpr("%", template)[[1]])
    if (n_formats > 0) {
      args <- list()
      for (k in 1:n_formats) {
        fmt <- regmatches(template, gregexpr("%[dfs.0-9]*", template))[[1]][k]
        if (grepl("d", fmt)) {
          args[[k]] <- sample(1:30, 1)
        } else if (grepl("f", fmt)) {
          args[[k]] <- round(runif(1, 5, 45), 1)
        } else if (grepl("s", fmt)) {
          args[[k]] <- sample(PROHIBITED_MEDS, 1)
        }
      }
      dvterm <- tryCatch(
        do.call(sprintf, c(list(template), args)),
        error = function(e) template
      )
    } else {
      dvterm <- template
    }

    dv_start <- subj_start + sample(0:as.numeric(subj_end - subj_start), 1)
    dv_end <- ifelse(runif(1) < 0.7,
                     as.character(dv_start + sample(1:30, 1)),
                     "")

    epoch <- sample(c("SCREENING", "TREATMENT", "FOLLOW-UP"), 1, prob = c(0.15, 0.65, 0.20))

    dv_list[[length(dv_list) + 1]] <- data.frame(
      STUDYID = STUDY_ID,
      DOMAIN = "DV",
      USUBJID = dm$USUBJID[i],
      DVSEQ = j,
      DVTERM = dvterm,
      DVDECOD = category,
      DVCAT = category,
      DVSCAT = paste(category, "- SUBCATEGORY", sample(1:3, 1)),
      DVSTDTC = as.character(dv_start),
      DVENDTC = dv_end,
      EPOCH = epoch,
      stringsAsFactors = FALSE
    )
  }
}

dv <- do.call(rbind, dv_list)
write.csv(dv, "data/sdtm_dv.csv", row.names = FALSE)
cat(sprintf("  -> %d records written to data/sdtm_dv.csv\n", nrow(dv)))

# ============================================================================
# Data Dictionary
# ============================================================================
cat("Generating data dictionary...\n")

dict_entries <- list(
  data.frame(DOMAIN = "DM", VARIABLE = names(dm),
             LABEL = c("Study Identifier", "Domain Abbreviation", "Unique Subject Identifier",
                        "Subject ID for the Study", "Study Site Identifier",
                        "Date of First Study Treatment", "Subject Reference Start Date",
                        "Date of Last Study Treatment", "Subject Reference End Date",
                        "Age", "Age Units", "Date of Birth",
                        "Sex", "Race", "Ethnicity",
                        "Planned Arm Code", "Description of Planned Arm",
                        "Actual Arm Code", "Description of Actual Arm",
                        "Country", "Subject Death Flag"),
             TYPE = c(rep("Char", 5), rep("Char/ISO", 4), "Num", "Char", "Char/ISO",
                      rep("Char", 7), "Char", "Char"),
             stringsAsFactors = FALSE),
  data.frame(DOMAIN = "AE", VARIABLE = names(ae),
             LABEL = c("Study Identifier", "Domain Abbreviation", "Unique Subject Identifier",
                        "Sequence Number", "Reported Term for the AE", "Dictionary-Derived Term",
                        "Body System or Organ Class", "Severity/Intensity", "Serious Event",
                        "Causality", "Action Taken with Study Treatment",
                        "Outcome of Adverse Event", "Start Date/Time of AE", "End Date/Time of AE"),
             TYPE = c(rep("Char", 3), "Num", rep("Char", 8), rep("Char/ISO", 2)),
             stringsAsFactors = FALSE),
  data.frame(DOMAIN = "DV", VARIABLE = names(dv),
             LABEL = c("Study Identifier", "Domain Abbreviation", "Unique Subject Identifier",
                        "Sequence Number", "Protocol Deviation Term", "Dictionary-Derived Term",
                        "Category of Deviation", "Subcategory",
                        "Start Date of Deviation", "End Date of Deviation", "Epoch"),
             TYPE = c(rep("Char", 3), "Num", rep("Char", 5), rep("Char/ISO", 2)),
             stringsAsFactors = FALSE)
)

data_dict <- do.call(rbind, dict_entries)
write.csv(data_dict, "data/data_dictionary.csv", row.names = FALSE)
cat(sprintf("  -> %d entries written to data/data_dictionary.csv\n", nrow(data_dict)))

# ============================================================================
# Summary
# ============================================================================
cat("\n=== Generation Complete ===\n")
cat(sprintf("DM: %d records\n", nrow(dm)))
cat(sprintf("AE: %d records\n", nrow(ae)))
cat(sprintf("LB: %d records\n", nrow(lb)))
cat(sprintf("VS: %d records\n", nrow(vs)))
cat(sprintf("DV: %d records\n", nrow(dv)))
cat("\nIntentional quality issues injected:\n")
cat(sprintf("  - DM: %d missing AGE, %d date inversions, %d arm mismatches\n",
            length(missing_age_idx), length(date_inversion_idx), length(arm_mismatch_idx)))
cat(sprintf("  - AE: %d pre-treatment AEs, %d date errors\n",
            length(pre_treatment_idx), length(date_error_idx)))
cat(sprintf("  - LB: %d ALT outliers, %d HGB outliers, %d missing values\n",
            length(outlier_idx), length(outlier_idx2), length(missing_lb_idx)))
cat(sprintf("  - VS: %d BP outliers, %d temp outliers, %d mismatches, %d missing values\n",
            length(bp_idx), length(temp_idx), length(mismatch_idx), length(missing_vs_idx)))
cat(sprintf("  - DV: %d total deviations across %d subjects\n",
            nrow(dv), length(dv_subjects)))
