# seed_config.R -- Configuration constants for synthetic SDTM data generation
# Study: SURG-2024-001 (Hypothetical MedTech Surgical Device Trial)

# Reproducibility
SEED <- 42

# Study-level constants
STUDY_ID <- "SURG-2024-001"
N_SUBJECTS <- 200
STUDY_START <- as.Date("2024-01-15")
STUDY_END <- as.Date("2024-12-15")

# Sites
SITE_IDS <- c("101", "102", "103", "104", "105")
SITE_COUNTRIES <- c("USA", "USA", "DEU", "GBR", "JPN")
SITE_WEIGHTS <- c(0.30, 0.25, 0.20, 0.15, 0.10)

# Treatment arms
ARM_CODES <- c("DEVA", "DEVB", "CTRL")
ARM_LABELS <- c("Device A", "Device B", "Control")
ARM_WEIGHTS <- c(0.40, 0.40, 0.20)

# Visit schedule
VISIT_NUMS <- c(1, 2, 3, 4, 5, 6)
VISIT_NAMES <- c("SCREENING", "BASELINE", "WEEK 4", "WEEK 8", "WEEK 12", "END OF STUDY")
VISIT_DAYS <- c(-14, 0, 28, 56, 84, 168)  # Days relative to treatment start

# Lab tests
LAB_TESTS <- data.frame(
  LBTESTCD = c("ALT", "AST", "CREAT", "HGB", "WBC", "GLUC"),
  LBTEST = c("Alanine Aminotransferase", "Aspartate Aminotransferase",
             "Creatinine", "Hemoglobin", "White Blood Cells", "Glucose"),
  LBCAT = c("CHEMISTRY", "CHEMISTRY", "CHEMISTRY", "HEMATOLOGY", "HEMATOLOGY", "CHEMISTRY"),
  LBORRESU = c("U/L", "U/L", "mg/dL", "g/dL", "10^9/L", "mg/dL"),
  LBORNRLO = c(7, 8, 0.6, 12.0, 4.0, 70),
  LBORNRHI = c(40, 40, 1.2, 17.5, 11.0, 100),
  MEAN = c(25, 24, 0.9, 14.5, 7.0, 90),
  SD = c(10, 10, 0.2, 1.5, 2.0, 15),
  stringsAsFactors = FALSE
)

# Vital signs
VITAL_TESTS <- data.frame(
  VSTESTCD = c("SYSBP", "DIABP", "PULSE", "TEMP", "RESP"),
  VSTEST = c("Systolic Blood Pressure", "Diastolic Blood Pressure",
             "Pulse Rate", "Temperature", "Respiratory Rate"),
  VSORRESU = c("mmHg", "mmHg", "beats/min", "F", "breaths/min"),
  VSSTRESU = c("mmHg", "mmHg", "beats/min", "C", "breaths/min"),
  MEAN = c(125, 78, 72, 98.6, 16),
  SD = c(15, 10, 10, 0.7, 3),
  stringsAsFactors = FALSE
)

# Adverse event terms (surgical/MedTech relevant)
AE_TERMS <- data.frame(
  AETERM = c("Nausea", "Headache", "Surgical site infection", "Wound dehiscence",
             "Device malfunction pain", "Post-operative fever", "Fatigue",
             "Dizziness", "Incision site erythema", "Hematoma at surgical site",
             "Constipation", "Insomnia", "Back pain", "Peripheral edema",
             "Urinary tract infection", "Deep vein thrombosis", "Pneumonia",
             "Anemia", "Hypertension", "Hypotension"),
  AEDECOD = c("Nausea", "Headache", "Surgical site infection", "Wound dehiscence",
              "Device related pain", "Pyrexia", "Fatigue",
              "Dizziness", "Erythema", "Haematoma",
              "Constipation", "Insomnia", "Back pain", "Oedema peripheral",
              "Urinary tract infection", "Deep vein thrombosis", "Pneumonia",
              "Anaemia", "Hypertension", "Hypotension"),
  AEBODSYS = c("GASTROINTESTINAL DISORDERS", "NERVOUS SYSTEM DISORDERS",
               "INFECTIONS AND INFESTATIONS", "INJURY, POISONING AND PROCEDURAL COMPLICATIONS",
               "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS", "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
               "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS", "NERVOUS SYSTEM DISORDERS",
               "SKIN AND SUBCUTANEOUS TISSUE DISORDERS", "INJURY, POISONING AND PROCEDURAL COMPLICATIONS",
               "GASTROINTESTINAL DISORDERS", "PSYCHIATRIC DISORDERS",
               "MUSCULOSKELETAL AND CONNECTIVE TISSUE DISORDERS", "GENERAL DISORDERS AND ADMINISTRATION SITE CONDITIONS",
               "INFECTIONS AND INFESTATIONS", "VASCULAR DISORDERS",
               "INFECTIONS AND INFESTATIONS", "BLOOD AND LYMPHATIC SYSTEM DISORDERS",
               "VASCULAR DISORDERS", "VASCULAR DISORDERS"),
  WEIGHT = c(0.12, 0.10, 0.08, 0.05, 0.06, 0.07, 0.08, 0.06,
             0.05, 0.04, 0.05, 0.04, 0.05, 0.03, 0.03, 0.02,
             0.02, 0.02, 0.02, 0.01),
  stringsAsFactors = FALSE
)

# Protocol deviation templates per category
DV_TEMPLATES <- list(
  "INFORMED CONSENT" = c(
    "Informed consent obtained %d days after screening procedures began",
    "Subject signed an outdated version of the informed consent form (v%d instead of v%d)",
    "Informed consent form was not signed by the principal investigator within required timeframe",
    "Subject was not re-consented after protocol amendment %d was implemented",
    "Witness signature missing from informed consent form for non-English speaking subject"
  ),
  "INCLUSION/EXCLUSION CRITERIA" = c(
    "Subject enrolled with BMI of %.1f which exceeds the upper limit of %d specified in inclusion criteria",
    "Subject did not meet minimum age requirement at time of screening (age %d, required >= %d)",
    "Subject had a prior surgical procedure within %d months, violating exclusion criterion #%d",
    "Subject enrolled despite positive pregnancy test at screening",
    "Subject had hemoglobin level of %.1f g/dL at screening, below the required %.1f g/dL minimum"
  ),
  "STUDY PROCEDURES" = c(
    "Subject did not complete the %d-hour post-operative vital signs assessment",
    "Blood samples for Visit %d were collected %d hours outside the specified collection window",
    "MRI assessment at Week %d was not performed per protocol specifications",
    "Wound assessment photographs were not taken at the Visit %d follow-up appointment",
    "Post-surgical rehabilitation protocol was not initiated within %d days as required"
  ),
  "STUDY TREATMENT/MEDICATION" = c(
    "Study device used outside the approved temperature storage range (stored at %d°C vs required %d-%d°C)",
    "Subject took prohibited concomitant medication (%s) during the washout period",
    "Study device was implanted %d days after the protocol-specified window",
    "Subject received incorrect device size (%s instead of %s as randomized)",
    "Device calibration was not performed within %d hours prior to the procedure as required"
  ),
  "VISIT SCHEDULE" = c(
    "Visit %d performed %d days late, outside the protocol-specified window of +/- %d days",
    "Subject missed Visit %d entirely and was seen at Visit %d instead",
    "End of study visit conducted %d weeks earlier than scheduled due to subject relocation",
    "Follow-up phone call at Week %d was not completed within the allowed %d-day window",
    "Subject attended Visit %d at a non-designated study site without prior approval"
  ),
  "SAFETY REPORTING" = c(
    "Serious adverse event (%s) not reported to sponsor within %d hours as required",
    "Adverse event severity was downgraded from %s to %s without documented justification",
    "Device malfunction report was submitted %d days after the required %d-day reporting deadline",
    "Follow-up safety assessment for SAE #%d was not completed per protocol timeline",
    "Concomitant medication started for AE management was not recorded in the eCRF for %d days"
  ),
  "OTHER" = c(
    "Source document verification could not be completed for %d data points at Site %s",
    "Electronic case report form data entry was completed %d days after the visit, exceeding the %d-day requirement",
    "Protocol training for new site staff member was not documented prior to study activities",
    "Study drug accountability log was not updated for %d consecutive dispensing events",
    "Subject diary was not returned at Visit %d; replacement diary not issued until Visit %d"
  )
)

# Race categories with weights
RACE_OPTIONS <- c("WHITE", "BLACK OR AFRICAN AMERICAN", "ASIAN",
                  "AMERICAN INDIAN OR ALASKA NATIVE",
                  "NATIVE HAWAIIAN OR OTHER PACIFIC ISLANDER", "OTHER")
RACE_WEIGHTS <- c(0.55, 0.18, 0.15, 0.03, 0.02, 0.07)

# Ethnicity
ETHNICITY_OPTIONS <- c("HISPANIC OR LATINO", "NOT HISPANIC OR LATINO")
ETHNICITY_WEIGHTS <- c(0.18, 0.82)

# Medications for deviation templates
PROHIBITED_MEDS <- c("ibuprofen", "aspirin", "naproxen", "warfarin",
                      "clopidogrel", "prednisone", "methotrexate")
