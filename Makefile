PACKAGE := $(shell grep '^Package:' DESCRIPTION | sed -E 's/^Package:[[:space:]]+//')
RSCRIPT = Rscript --no-init-file

all: install

test:
	${RSCRIPT} -e 'library(methods); devtools::test()'

test_all:
	REMAKE_TEST_INSTALL_PACKAGES=true make test

# https://github.com/r-lib/roxygen2/issues/963
roxygen:
	@mkdir -p man
	${RSCRIPT} -e "library(methods); devtools::document()"
	sed -i.bak 's/^.*plumber::hookable}} -> //' man/pkgapi.Rd
	rm -f man/pkgapi.Rd.bak

install:
	R CMD INSTALL .

build:
	R CMD build .

check:
	_R_CHECK_CRAN_INCOMING_=FALSE make check_all

check_all:
	${RSCRIPT} -e "rcmdcheck::rcmdcheck(args = c('--as-cran', '--no-manual'))"

README.md: README.Rmd
	Rscript -e "options(warnPartialMatchArgs=FALSE); knitr::knit('$<')"
	sed -i.bak 's/[[:space:]]*$$//' README.md
	rm -f $@.bak


pkgdown:
	${RSCRIPT} -e "library(methods); pkgdown::build_site()"

website: pkgdown
	./scripts/update_web.sh

vignettes: vignettes/traduire.Rmd
	${RSCRIPT} -e 'tools::buildVignettes(dir = ".")'
	mkdir -p inst/doc
	cp vignettes/*.html vignettes/*.Rmd inst/doc

.PHONY: all test document install vignettes