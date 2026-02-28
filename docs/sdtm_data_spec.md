# SDTM Data Specification

## Study: SURG-2024-001

Simulated MedTech surgical device trial with 200 subjects across 3 treatment arms and 5 study sites.

## DM -- Demographics

| Variable | Label | Type | Values |
|----------|-------|------|--------|
| STUDYID | Study Identifier | Char | "SURG-2024-001" |
| DOMAIN | Domain | Char | "DM" |
| USUBJID | Unique Subject ID | Char | "SURG-2024-001-0001" to "SURG-2024-001-0200" |
| SUBJID | Subject ID | Char | "0001" to "0200" |
| SITEID | Site ID | Char | "101", "102", "103", "104", "105" |
| AGE | Age | Num | 22-82 (~5% missing) |
| SEX | Sex | Char | "M", "F" |
| RACE | Race | Char | CDISC controlled terminology |
| ETHNICITY | Ethnicity | Char | "HISPANIC OR LATINO", "NOT HISPANIC OR LATINO" |
| ARMCD | Planned Arm Code | Char | "DEVA", "DEVB", "CTRL" |
| ARM | Planned Arm | Char | "Device A", "Device B", "Control" |
| COUNTRY | Country | Char | "USA", "DEU", "GBR", "JPN" |

## AE -- Adverse Events

| Variable | Label | Type | Values |
|----------|-------|------|--------|
| AETERM | Reported Term | Char | 20 surgical-relevant terms |
| AEDECOD | Dictionary Term | Char | MedDRA preferred terms |
| AEBODSYS | Body System | Char | SOC-level terms |
| AESEV | Severity | Char | "MILD", "MODERATE", "SEVERE" |
| AESER | Serious | Char | "Y", "N" |
| AEREL | Causality | Char | "RELATED", "POSSIBLY RELATED", "NOT RELATED" |

## LB -- Laboratory Results

| Variable | Label | Type | Values |
|----------|-------|------|--------|
| LBTESTCD | Test Code | Char | ALT, AST, CREAT, HGB, WBC, GLUC |
| LBSTRESN | Numeric Result | Num | Continuous, ~3% missing |
| LBORNRHI | Upper Ref Range | Num | Test-specific |
| LBNRIND | Range Indicator | Char | "NORMAL", "HIGH", "LOW" |
| VISIT | Visit Name | Char | SCREENING through END OF STUDY |

## VS -- Vital Signs

| Variable | Label | Type | Values |
|----------|-------|------|--------|
| VSTESTCD | Test Code | Char | SYSBP, DIABP, PULSE, TEMP, RESP |
| VSSTRESN | Numeric Result | Num | Standard units, ~2% missing |
| VISIT | Visit Name | Char | 6 visits |

## DV -- Protocol Deviations

| Variable | Label | Type | Values |
|----------|-------|------|--------|
| DVTERM | Deviation Term | Char | Free-text descriptions |
| DVCAT | Category | Char | 7 TransCelerate categories |
| EPOCH | Epoch | Char | SCREENING, TREATMENT, FOLLOW-UP |

### DV Categories (TransCelerate Standard)
1. INFORMED CONSENT
2. INCLUSION/EXCLUSION CRITERIA
3. STUDY PROCEDURES
4. STUDY TREATMENT/MEDICATION
5. VISIT SCHEDULE
6. SAFETY REPORTING
7. OTHER

## Intentional Quality Issues (for testing)
- DM: ~5% missing AGE, ~3% date inversions, ~2% ARM mismatches
- AE: ~5% pre-treatment AEs, ~3% date errors
- LB: ~2% ALT outliers (>200 U/L), ~2% HGB outliers (<7 g/dL), ~3% missing
- VS: ~1.5% extreme outliers, ~2% VSTESTCD/VSTEST mismatches, ~2% missing
