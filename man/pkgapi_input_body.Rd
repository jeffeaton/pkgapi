% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/input.R
\name{pkgapi_input_body_binary}
\alias{pkgapi_input_body_binary}
\alias{pkgapi_input_body_json}
\title{Control for body parameters}
\usage{
pkgapi_input_body_binary(name)

pkgapi_input_body_json(name, schema, root)
}
\arguments{
\item{name}{Name of the parameter}

\item{schema}{The name of the json schema to use}

\item{root}{The root of the schema directory.}
}
\description{
Control for body parameters.  This might change.  There are
several types of HTTP bodies that we want to consider here - the
primary ones are a body uploaded in binary, the other is a json
object.  In the latter we want to validate the body against a
schema (at least if validation is used).  In future we might also
support a form input here too.
}
