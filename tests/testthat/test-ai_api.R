# test-ai_api.R -- Tests for AI API wrapper functions

source("../../R/utils_data_loading.R")
source("../../R/utils_helpers.R")
source("../../R/utils_ai_api.R")

domains <- load_all_domains("../../data")

test_that("refine_query returns valid structure in demo mode", {
  result <- refine_query("patients with high blood pressure", domains, provider = "demo")
  expect_type(result, "list")
  expect_true(all(c("refined_query", "domains", "variables", "r_code", "assumptions") %in% names(result)))
  expect_true(nchar(result$refined_query) > 0)
})

test_that("refine_query handles liver query", {
  result <- refine_query("patients with bad liver numbers", domains, provider = "demo")
  expect_true(grepl("ALT|AST|hepatic", result$refined_query))
  expect_true("LB" %in% result$domains)
})

test_that("refine_query handles serious AE query", {
  result <- refine_query("list all serious adverse events", domains, provider = "demo")
  expect_true(grepl("Serious|SAE|AESER", result$refined_query, ignore.case = TRUE))
  expect_true("AE" %in% result$domains)
})

test_that("refine_query handles unknown query with fallback", {
  result <- refine_query("something completely random", domains, provider = "demo")
  expect_type(result, "list")
  expect_true(nchar(result$refined_query) > 0)
})

test_that("data_chat_query returns valid structure in demo mode", {
  result <- data_chat_query("Show demographics summary", domains, provider = "demo")
  expect_type(result, "list")
  expect_true(all(c("explanation", "code", "visualization", "data_result") %in% names(result)))
  expect_true(is.data.frame(result$data_result))
})

test_that("data_chat_query handles SAE query", {
  result <- data_chat_query("List all serious adverse events", domains, provider = "demo")
  expect_true(nrow(result$data_result) > 0)
  expect_true("AETERM" %in% names(result$data_result))
})

test_that("data_chat_query handles ALT query", {
  result <- data_chat_query("Show patients with elevated ALT", domains, provider = "demo")
  expect_true(nrow(result$data_result) > 0)
})

test_that("data_chat_query handles unknown query gracefully", {
  result <- data_chat_query("xyz random nonsense", domains, provider = "demo")
  expect_type(result, "list")
  expect_true(nchar(result$explanation) > 0)
})

test_that("build_schema_context returns string with domain names", {
  ctx <- build_schema_context(domains)
  expect_true(grepl("DM", ctx))
  expect_true(grepl("AE", ctx))
  expect_true(grepl("LB", ctx))
})

test_that("call_ai_api returns NULL in demo mode", {
  result <- call_ai_api("system", "user", provider = "demo")
  expect_null(result)
})
