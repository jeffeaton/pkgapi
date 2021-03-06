context("input")

test_that("Basic input", {
  obj <- pkgapi_input$new("a", "numeric", "query")$bind(function(a) NULL)
  expect_equal(obj$name, "a")
  expect_equal(obj$type, "numeric")
  expect_equal(obj$where, "query")
  expect_true(obj$required)
  expect_null(obj$default)

  expect_equal(obj$validate(list(query = list(a = "1"))), 1)
  err <- expect_error(
    obj$validate(list()),
    class = "pkgapi_error")
  err <- expect_error(
    obj$validate(list(query = list(a = "one"))),
    class = "pkgapi_error")
})


test_that("Binary input", {
  obj <- pkgapi_input_body_binary("a")$bind(function(a) NULL)
  expect_equal(obj$name, "a")
  expect_equal(obj$type, "binary")
  expect_equal(obj$where, "body")
  expect_true(obj$required)
  expect_null(obj$default)

  r <- as.raw(0:255)
  body <- pkgapi_body(parse_mime("application/octet-stream"), r)
  expect_equal(obj$validate(list(body = body)), r)

  err <- expect_error(
    obj$validate(list(body = pkgapi_body(NULL, NULL))),
    class = "pkgapi_error")
  body <- pkgapi_body(parse_mime("application/json"), "{}")
  err <- expect_error(
    obj$validate(list(body = body)),
    class = "pkgapi_error")
})


test_that("JSON input", {
  obj <- pkgapi_input_body_json("a", "Number", "schema")$bind(function(a) NULL)
  expect_equal(obj$name, "a")
  expect_equal(obj$type, "json")
  expect_equal(obj$where, "body")
  expect_true(obj$required)
  expect_null(obj$default)
  body <- pkgapi_body(parse_mime("application/json"), "1")
  expect_equal(obj$validate(list(body = body)), "1")
  err <- expect_error(
    obj$validate(list()),
    class = "pkgapi_error")

  body$value <- '{"one": 1}'
  err <- expect_error(
    obj$validate(list(body = list(a = body))),
    class = "pkgapi_error")
})


test_that("inputs collector works", {
  target <- function(x, a, b, c) {
    NULL
  }
  inputs <- list(
    pkgapi_input_path("/foo/<x>"),
    pkgapi_input_query(a = "numeric", b = "string"),
    pkgapi_input_body_binary("c"))
  obj <- pkgapi_inputs$new(inputs)$bind(target)
  body <- pkgapi_body(parse_mime("application/octet-stream"), as.raw(0:4))
  expect_equal(
    obj$validate(list(path = list(x = "x"),
                      query = list(a = "1", b = "b"),
                      body = body)),
    list(x = "x", a = 1, b = "b", c = as.raw(0:4)))
  err <- expect_error(
    obj$validate(list(path = list(x = "x"),
                      query = list(a = "one", b = "b"),
                      body = as.raw(0:4))),
    class = "pkgapi_error")
})


test_that("logical validator works", {
  expect_true(pkgapi_input_validate_logical("TRUE"))
  expect_true(pkgapi_input_validate_logical("True"))
  expect_true(pkgapi_input_validate_logical("true"))
  expect_true(pkgapi_input_validate_logical("T"))
  expect_false(pkgapi_input_validate_logical("FALSE"))
  expect_false(pkgapi_input_validate_logical("False"))
  expect_false(pkgapi_input_validate_logical("false"))
  expect_false(pkgapi_input_validate_logical("F"))

  expect_error(pkgapi_input_validate_logical("1"),
               "Could not convert '1' into a logical")
  expect_error(pkgapi_input_validate_logical("maybe"),
               "Could not convert 'maybe' into a logical")
})


test_that("integer validator works", {
  expect_equal(pkgapi_input_validate_integer("1"), 1L)
  expect_equal(pkgapi_input_validate_integer("-100"), -100L)

  expect_error(pkgapi_input_validate_integer("one"),
               "Could not convert 'one' into an integer")
  expect_error(pkgapi_input_validate_integer("string"),
               "Could not convert 'string' into an integer")

  expect_error(pkgapi_input_validate_integer("1.4"),
               "Could not convert '1.4' into an integer (loses precision)",
               fixed = TRUE)
})


test_that("integer validator works", {
  expect_equal(pkgapi_input_validate_numeric("1"), 1)
  expect_equal(pkgapi_input_validate_numeric("-100"), -100)
  expect_equal(pkgapi_input_validate_numeric("1.23"), 1.23)
  expect_equal(pkgapi_input_validate_numeric("1e-5"), 1e-5)

  expect_error(pkgapi_input_validate_numeric("one"),
               "Could not convert 'one' into a numeric")
  expect_error(pkgapi_input_validate_numeric("string"),
               "Could not convert 'string' into a numeric")
})


test_that("string validator", {
  expect_equal(pkgapi_input_validate_string("1"), "1")
  expect_equal(pkgapi_input_validate_string("TRUE"), "TRUE")
  expect_equal(pkgapi_input_validate_string("string"), "string")
  expect_error(pkgapi_input_validate_string(letters), "must be a scalar")
})


test_that("Can use single query parameter", {
  square <- function(n) {
    jsonlite::unbox(n * n)
  }
  endpoint <- pkgapi_endpoint$new(
    "GET", "/square", square,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_query(n = "numeric"),
    validate = TRUE)

  ## endpoint directly:
  res <- endpoint$run(4)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(16))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("GET", "/square", c(n = 4))
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})


test_that("Can validate query parameters from plumber, throwing nice errors", {
  multiply <- pkgapi_endpoint$new(
    "GET", "/multiply", function(a, b) jsonlite::unbox(a * b),
    pkgapi_input_query(a = "numeric", b = "numeric"),
    returning = pkgapi_returning_json())

  expect_equal(
    multiply$inputs$validate(list(query = list(a = "1", b = "2"))),
    list(a = 1, b = 2))

  api <- pkgapi$new()$handle(multiply)

  res <- api$request("GET", "/multiply", c(a = 1, b = 2))
  expect_equal(res$status, 200)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  expect_equal(res$body, multiply$run(1, 2)$body)

  res <- api$request("GET", "/multiply", c(a = 1, b = "x"))
  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  dat <- jsonlite::fromJSON(res$body, FALSE)
  expect_equal(dat$errors[[1]]$error, "INVALID_INPUT")
  expect_match(
    dat$errors[[1]]$detail,
    "Error parsing query parameter 'b': Could not convert 'x'",
    fixed = TRUE)
})


test_that("use routing parameter", {
  power <- function(n, m = 2) {
    jsonlite::unbox(n^m)
  }
  endpoint <- pkgapi_endpoint$new(
    "GET", "/power/<m:int>", power,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_query(n = "numeric"),
    validate = TRUE)

  ## endpoint directly:
  res <- endpoint$run(n = 4, m = 3)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(64))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("GET", "/power/3", c(n = 4))
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})


test_that("use text routing parameter", {
  operation <- function(type, x, y) {
    op <- switch(type,
           "plus" = `+`,
           "minus" = `-`)
    jsonlite::unbox(op(x, y))
  }
  endpoint <- pkgapi_endpoint$new(
    "GET", "/operation/<type>", operation,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_query(x = "numeric", y = "numeric"),
    validate = TRUE)

  res <- endpoint$run(type = "plus", x = 3, y = 4)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(7))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("GET", "/operation/plus", c(x = 3, y = 4))
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})


test_that("Can use an optional logical parameter", {
  hello <- function(positive = TRUE) {
    jsonlite::unbox(if (positive) 1 else -1)
  }
  endpoint <- pkgapi_endpoint$new(
    "GET", "/hello", hello,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_query(positive = "logical"),
    validate = TRUE)

  ## endpoint directly:
  resf <- endpoint$run(FALSE)
  expect_equal(resf$status_code, 200)
  expect_equal(resf$content_type, "application/json")
  expect_equal(resf$data, jsonlite::unbox(-1))
  expect_equal(resf$body, to_json_string(response_success(resf$data)))

  rest <- endpoint$run()
  expect_equal(rest$status_code, 200)
  expect_equal(rest$content_type, "application/json")
  expect_equal(rest$data, jsonlite::unbox(1))
  expect_equal(rest$body, to_json_string(response_success(rest$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  resf_api <- pr$request("GET", "/hello", c(positive = FALSE))
  expect_equal(resf_api$status, 200)
  expect_equal(resf_api$headers[["Content-Type"]], "application/json")
  expect_equal(resf_api$body, resf$body)

  pr <- pkgapi$new()$handle(endpoint)
  rest_api <- pr$request("GET", "/hello")
  expect_equal(rest_api$status, 200)
  expect_equal(rest_api$headers[["Content-Type"]], "application/json")
  expect_equal(rest_api$body, rest$body)
})


test_that("use binary body", {
  mean_rds <- function(x) {
    jsonlite::unbox(mean(unserialize(x)))
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/mean", mean_rds,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_body_binary("x"),
    validate = TRUE)

  data <- runif(10)
  payload <- serialize(data, NULL)

  ## endpoint directly:
  res <- endpoint$run(x = payload)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(mean(data)))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("POST", "/mean", body = payload)
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})


test_that("validate binary body on input", {
  mean_rds <- function(x) {
    jsonlite::unbox(mean(unserialize(x)))
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/mean", mean_rds,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_body_binary("x"),
    validate = TRUE)

  data <- runif(10)
  payload <- serialize(data, NULL)

  pr <- pkgapi$new()$handle(endpoint)

  res <- pr$request("POST", "/mean")
  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  expect_equal(from_json(res$body)$errors[[1]],
               list(error = "INVALID_INPUT",
                    detail = "Body was not provided"))

  res <- pr$request("POST", "/mean", body = "[1,2,3]",
                    content_type = "application/json")
  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  expect_equal(
    from_json(res$body)$errors[[1]],
    list(
      error = "INVALID_INPUT",
      detail = paste("Expected content type 'application/octet-stream'",
                     "but was sent 'application/json'")))
})


test_that("Binary body can be optional", {
  mean_rds <- function(x = NULL) {
    if (is.null(x)) {
      value <- 0
    } else {
      value <- mean(unserialize(x))
    }
    jsonlite::unbox(value)
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/mean", mean_rds,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_body_binary("x"),
    validate = TRUE)

  data <- runif(10)
  payload <- serialize(data, NULL)

  ## endpoint directly:
  res1 <- endpoint$run()
  expect_equal(res1$status_code, 200)
  expect_equal(res1$content_type, "application/json")
  expect_equal(res1$data, jsonlite::unbox(0))
  expect_equal(res1$body, to_json_string(response_success(res1$data)))

  res2 <- endpoint$run(payload)
  expect_equal(res2$status_code, 200)
  expect_equal(res2$content_type, "application/json")
  expect_equal(res2$data, jsonlite::unbox(mean(data)))
  expect_equal(res2$body, to_json_string(response_success(res2$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res1_api <- pr$request("POST", "/mean")
  expect_equal(res1_api$status, 200)
  expect_equal(res1_api$headers[["Content-Type"]], "application/json")
  expect_equal(res1_api$body, res1$body)

  res2_api <- pr$request("POST", "/mean", body = payload)
  expect_equal(res2_api$status, 200)
  expect_equal(res2_api$headers[["Content-Type"]], "application/json")
  expect_equal(res2_api$body, res2$body)
})


test_that("Use json body", {
  square <- function(n) {
    x <- jsonlite::fromJSON(n)
    jsonlite::unbox(x * x)
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/square", square,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_body_json("n", "Number", "schema"),
    validate = TRUE)

  data <- 3
  payload <- to_json_string(jsonlite::unbox(data))

  ## endpoint directly:
  res <- endpoint$run(n = payload)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(9L))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("POST", "/square", body = payload)
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})


test_that("validate json body against schema", {
  square <- function(n) {
    x <- jsonlite::fromJSON(n)
    jsonlite::unbox(x * x)
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/square", square,
    returning = pkgapi_returning_json("Number", "schema"),
    pkgapi_input_body_json("n", "Number", "schema"),
    validate = TRUE)

  data <- "not a number"
  payload <- to_json_string(jsonlite::unbox(data))

  v <- pkgapi_validator("Number", "schema", query = NULL)

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res <- pr$request("POST", "/square", body = payload)
  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  errs <- from_json(res$body)$errors[[1]]
  expect_equal(errs$error, "INVALID_INPUT")
  expect_match(errs$detail, "Error parsing body (for 'n')", fixed = TRUE)
  expect_match(errs$detail, get_error(v(payload))$message, fixed = TRUE)
})


test_that("POST body is forbidden if not specified", {
  square <- function(n) {
    jsonlite::unbox(n * n)
  }
  endpoint <- pkgapi_endpoint$new(
    "POST", "/square", square,
    returning = pkgapi_returning_json("Number", "schema"),
    input_query = pkgapi_input_query(n = "numeric"),
    validate = TRUE)

  pr <- pkgapi$new()$handle(endpoint)
  res <- pr$request("POST", "/square", c(n = 4), body = '{"a":2}')

  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  errs <- from_json(res$body)$errors[[1]]
  expect_equal(errs$error, "INVALID_INPUT")
  expect_equal(errs$detail,
               "This endpoint does not accept a body, but one was provided")
})


test_that("Reject unknown query parameters", {
  square <- function(n) {
    jsonlite::unbox(n * n)
  }
  endpoint <- pkgapi_endpoint$new(
    "GET", "/square", square,
    returning = pkgapi_returning_json("Number", "schema"),
    input_query = pkgapi_input_query(n = "numeric"),
    validate = TRUE)

  pr <- pkgapi$new()$handle(endpoint)
  res <- pr$request("GET", "/square", c(n = 4, m = 2))

  expect_equal(res$status, 400)
  expect_equal(res$headers[["Content-Type"]], "application/json")
  errs <- from_json(res$body)$errors[[1]]
  expect_equal(errs$error, "INVALID_INPUT")
  expect_equal(errs$detail,
               "Unconsumed query paramter: 'm'")
})


test_that("inputs must match function args", {
  square <- function(n) {
    jsonlite::unbox(n * n)
  }
  expect_error(
    pkgapi_endpoint$new(
      "GET", "/square", square,
      returning = pkgapi_returning_json("Number", "schema"),
      pkgapi_input_query(m = "numeric"),
      validate = TRUE),
    "Argument 'm' (used in query) missing from the target function",
    fixed = TRUE)
})


test_that("No duplicated args allowed", {
  square <- function(n) {
    jsonlite::unbox(n * n)
  }
  expect_error(
    pkgapi_endpoint$new(
      "GET", "/square/<n>", square,
      returning = pkgapi_returning_json("Number", "schema"),
      pkgapi_input_query(n = "numeric")),
    "Duplicated parameter names: 'n' (in path), 'n' (in query)",
    fixed = TRUE)
})


test_that("Must provide all non-optional args", {
  expect_error(
    pkgapi_endpoint$new(
      "GET", "/add", function(a, b) jsonlite::unbox(a + b),
      returning = pkgapi_returning_json("Number", "schema"),
      input_query = pkgapi_input_query(a = "numeric"),
      validate = TRUE),
    "Required arguments to target function missing from inputs: 'b'")
  expect_error(
    pkgapi_endpoint$new(
      "GET", "/add", function(a, b = 1) jsonlite::unbox(a + b),
      returning = pkgapi_returning_json("Number", "schema"),
      input_query = pkgapi_input_query(a = "numeric"),
      validate = TRUE),
    NA)
})


test_that("default parameters", {
  endpoint <- pkgapi_endpoint$new(
    "GET", "/multiply", function(a, b = 2) jsonlite::unbox(a * b),
    pkgapi_input_query(a = "numeric", b = "numeric"),
    returning = pkgapi_returning_json())

  res <- endpoint$run(10)
  expect_equal(res$status_code, 200)
  expect_equal(res$content_type, "application/json")
  expect_equal(res$data, jsonlite::unbox(20))
  expect_equal(res$body, to_json_string(response_success(res$data)))

  ## Through the api
  pr <- pkgapi$new()$handle(endpoint)
  res_api <- pr$request("GET", "/multiply", c(a = 10))
  expect_equal(res_api$status, 200)
  expect_equal(res_api$headers[["Content-Type"]], "application/json")
  expect_equal(res_api$body, res$body)
})
