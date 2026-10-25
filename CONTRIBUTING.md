# Contributing to statsnzreleases

Contributions are welcome through the [GitHub repository](https://github.com/chartwell-macro/statsnzreleases).
For a bug, please email [chartwellmacro@gmail.com](mailto:chartwellmacro@gmail.com)
with a small reproducible example, the release ID and URL involved, the
package and R versions, and the relevant error or warning. Do not include
credentials, private data, or downloaded files that are subject to source
restrictions.

For a change, email [chartwellmacro@gmail.com](mailto:chartwellmacro@gmail.com) first when the proposal affects the public API,
supported release families, output columns, cache behavior, or network
policy. Pull requests should explain the user-facing effect, preserve
attachment-level provenance, and include focused tests and documentation for
new behavior. Keep live Stats NZ calls out of the default test path; use
small deterministic fixtures or mocks for tests and examples.

Before opening a pull request, run the package test suite and an R CMD check in
a clean environment. Review generated documentation, check the diff for
unintended files, and do not commit caches, source downloads, credentials,
coverage output, or local pkgdown builds.

The package retrieves public release files from Stats NZ. Contributions that
describe or redistribute source data must follow the [Stats NZ copyright and
licensing guidance](https://www.stats.govt.nz/about-us/copyright/) and any
source-specific notice.
