## Test environments

Baseline evidence was captured before the documentation and CRAN-readiness
changes from the published base `pre-publication baseline`.

* macOS Sequoia 15.6, aarch64-apple-darwin24.4.0, R 4.5.1, UTF-8 locale,
  Australia/Sydney.
* Baseline test run: 51 passing expectations and 2 intentionally skipped live
  tests. One pre-existing Windows-1252 fixture portability failure was
  recorded (`Men\uFFFDs clothing` instead of `Men\u2019s clothing`).
* Baseline `R CMD build` succeeded and full built-tarball
  `R CMD check --as-cran` completed with 1 ERROR, 0 WARNINGs, and 2 NOTEs. The
  ERROR was the Windows-1252 test failure above. One NOTE was the expected
  incoming-feasibility new-submission notice (showing the placeholder
  maintainer); the other recorded that the locally installed HTML Tidy was too
  old for HTML validation. PDF and HTML manual generation otherwise passed.

## R CMD check results

`Authors@R` records Chartwell Macro as author, maintainer, and package copyright holder.
Package code is MIT, copyright Chartwell Macro. Stats NZ data retains its own CC BY 4.0
attribution and any source-specific terms, as recorded in `LICENSE.md` and
`inst/extdata/README.md`.

The final source tarball was built with R 4.5.1 and checked with
`R CMD check --as-cran` on macOS Sequoia 15.6
(`aarch64-apple-darwin24.4.0`). The final check completed with:

* 0 ERRORs
* 0 WARNINGs
* 1 NOTE

All dependency, namespace, installation, load/unload, S3, code, Rd, example,
test, vignette, PDF-manual, and HTML-manual checks passed. The package also
installed successfully into a new isolated library, and the source test suite
completed with 69 passing expectations and 2 intentionally skipped opt-in live
tests.

The NOTE identifies a new submission and reports the canonical GitHub
repository, issue tracker, and GitHub Pages URL as unavailable. The repository
is currently private and the Pages site has not been deployed, so these URLs
return HTTP 404 to an unauthenticated checker. They must be publicly reachable
before a CRAN submission.

The pre-amendment GitHub Actions checks for commit
`pre-publication baseline` completed successfully on:

* GitHub-hosted macOS with R release
* GitHub-hosted Windows with R release
* GitHub-hosted Linux with R release, oldrel-1, and devel

The separate coverage and pkgdown build workflows also completed successfully.
R-hub and Win-builder were not run. The package has no CRAN reverse
dependencies; an isolated read-only check of the known Chartwell downstream
provider contracts passed without changing its pinned dependency SHA.

## Notes to CRAN

This file documents the package metadata and checks for the current development
branch. It is not a CRAN submission and makes no claim that a submission has
been made or accepted. The package downloads public Stats NZ release
attachments at user request. It includes an 84-row extract from one official
Stats NZ CPI attachment so that the documented public-reader and chart workflow
can run deterministically without network access. The extract includes Stats NZ
data licensed by Stats NZ for reuse under CC BY 4.0;
`inst/extdata/README.md` records the source URLs, full-file and extract hashes,
extraction method, licence, and attribution.
