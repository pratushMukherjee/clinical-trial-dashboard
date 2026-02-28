# test-data_quality.R -- Tests for data quality check functions

source("../../R/utils_data_loading.R")
source("../../R/utils_data_quality.R")
source("../../R/utils_helpers.R")

test_that("check_missing_data returns correct structure", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  result <- check_missing_data(dm, "DM")
  expect_s3_class(result, "data.frame")
  expect_true(all(c("domain", "variable", "check_type", "severity", "description") %in% names(result)))
})

test_that("check_missing_data detects known missing AGE", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  result <- check_missing_data(dm, "DM")
  age_findings <- result[result$variable == "AGE", ]
  expect_gt(nrow(age_findings), 0)
  expect_gt(age_findings$n_missing[1], 0)
})

test_that("check_outliers detects known ALT outliers in LB", {
  lb <- load_sdtm_domain("../../data/sdtm_lb.csv", "LB")
  result <- check_outliers(lb, "LB")
  alt_findings <- result[grepl("ALT", result$variable), ]
  expect_gt(nrow(alt_findings), 0)
})

test_that("check_date_logic detects DM date inversions", {
  dm <- load_sdtm_domain("../../data/sdtm_dm.csv", "DM")
  result <- check_date_logic(dm, "DM")
  expect_gt(nrow(result), 0)
  expect_equal(result$check_type[1], "Date Logic")
  expect_equal(result$severity[1], "Critical")
})

test_that("check_date_logic detects AE date errors", {
  ae <- load_sdtm_domain("../../data/sdtm_ae.csv", "AE")
  result <- check_date_logic(ae, "AE")
  expect_gt(nrow(result), 0)
})

test_that("check_cross_form_consistency detects ARM mismatch", {
  domains <- load_all_domains("../../data")
  result <- check_cross_form_consistency(domains$DM, domains$AE, domains$LB, domains$VS)
  arm_findings <- result[grepl("ARM", result$variable), ]
  expect_gt(nrow(arm_findings), 0)
})

test_that("run_all_quality_checks returns combined findings", {
  domains <- load_all_domains("../../data")
  result <- run_all_quality_checks(domains)
  expect_s3_class(result, "data.frame")
  expect_gt(nrow(result), 0)
  expect_true(all(c("Missing Data", "Outlier", "Date Logic", "Consistency")
                   %in% result$check_type))
})

test_that("calculate_quality_scores returns scores between 0-100", {
  domains <- load_all_domains("../../data")
  findings <- run_all_quality_checks(domains)
  scores <- calculate_quality_scores(findings, domains)
  expect_true(all(scores >= 0 & scores <= 100))
  expect_true(all(c("Completeness", "Consistency", "Validity", "Timeliness", "Accuracy")
                   %in% names(scores)))
})
