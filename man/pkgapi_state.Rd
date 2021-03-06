% Generated by roxygen2: do not edit by hand
% Please edit documentation in R/state.R
\name{pkgapi_state}
\alias{pkgapi_state}
\title{Bind state into an endpoint}
\usage{
pkgapi_state(..., .state = list(...))
}
\arguments{
\item{...}{Named arguments representing state to bind; see
\code{Details}.}

\item{.state}{A list of named state to bind, instead
of using \code{...} - this interface is considerably easier to
program against if building an API programmatically, avoiding
the use of \code{\link{do.call}}.}
}
\description{
Bind state into an endpoint
}
\details{
This method allows state to be bound to the target function.  Each
element of \code{...} (or \code{.state}) is named with the
argument to the target function being bound, and the value is the
value that argument will take.  Once bound, the arguments to the
target function may not be provided by an input.

The primary use case for this is to bind mutable state (database
connections, etc) that may be shared amongst different endpoints
within an API.
}
