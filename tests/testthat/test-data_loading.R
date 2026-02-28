# test-data_loading.R -- Tests for data loading utilities

source("../../R/utils_data_loading.R")

test_that("DM data loads with required SDTM columns", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  required_cols <- c("STUDYID", "DOMAIN", "USUBJID", "SUBJID", "AGE", "SEX", "ARMCD", "ARM")
  expect_true(all(required_cols %in% names(dm)))
  expect_equal(unique(dm$DOMAIN), "DM")
  expect_gt(nrow(dm), 0)
})

test_that("AE data loads with required columns", {
  ae <- load_sdtm_domain("../../data/sdtm_ae.csv", "AE")
  required_cols <- c("STUDYID", "DOMAIN", "USUBJID", "AESEQ", "AETERM", "AESEV", "AESTDTC")
  expect_true(all(required_cols %in% names(ae)))
  expect_equal(unique(ae$DOMAIN), "AE")
})

test_that("All AE USUBJIDs exist in DM", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  ae <- load_sdtm_domain("../../data/sdtm_ae.csv", "AE")
  orphan_subjects <- setdiff(ae$USUBJID, dm$USUBJID)
  expect_equal(length(orphan_subjects), 0)
})

test_that("All domains load via load_all_domains", {
  domains <- load_all_domains("../../data")
  expect_true(all(c("DM", "AE", "LB", "VS", "DV") %in% names(domains)))
  expect_gt(nrow(domains$DM), 0)
  expect_gt(nrow(domains$LB), 0)
})

test_that("load_sdtm_domain handles missing file", {
  expect_warning(result <- load_sdtm_domain("nonexistent.csv", "DM"))
  expect_null(result)
})

test_that("domain_summary returns correct structure", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  summary <- domain_summary(dm)
  expect_type(summary, "list")
  expect_true(all(c("n_rows", "n_cols", "n_subjects", "completeness") %in% names(summary)))
  expect_equal(summary$n_rows, 200)
})
