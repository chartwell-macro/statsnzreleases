# Installed example data

`release_manifest.csv` is package-authored metadata used by
`statsnz_releases()`. `example-release.csv` is package-authored synthetic data
used to test the common release schema.

## CPI chart snapshot

`cpi-tradables-non-tradables-june-2026.csv` is an attributed row extract from
the official Stats NZ attachment listed below. It contains the quarterly index
series `CPIQ.SE9NS6000` (Tradable All Groups) and `CPIQ.SE9NS6500`
(Non-Tradable All Groups) from March 2016 through June 2026. All nine source
columns are retained. The extraction selected only those two series and that
period range; CSV quoting was normalised when the subset was written. No
observation values were calculated or altered.

- Release: *Consumers price index: June 2026 quarter*, published 21 July 2026
- Release URL: <https://www.stats.govt.nz/information-releases/consumers-price-index-june-2026-quarter/>
- Attachment: `consumers-price-index-june-2026-quarter-tradeables-and-non-tradeables.csv`
- Attachment URL: <https://www.stats.govt.nz/assets/Uploads/Consumers-price-index/Consumers-price-index-June-2026-quarter/Download-data/consumers-price-index-june-2026-quarter-tradeables-and-non-tradeables.csv>
- Full attachment SHA-256: `f6fa38eeb10d7575fd690d3ff995e4afc2867ce5cd620eb7c248320b9bbc83e8`
- Snapshot created: 24 August 2026
- Snapshot rows: 84 observations plus the header
- Snapshot SHA-256: `455c6c4bbad4345bae69da6d91db3a0455e54a025c77ce4bc844e35593e00c0e`

Stats NZ states that, unless otherwise specified, its content is licensed for
reuse under the Creative Commons Attribution 4.0 International licence. The
release page and attachment carried no more specific notice when this snapshot
was created. See the [Stats NZ copyright guidance](https://www.stats.govt.nz/about-us/copyright/)
and the [CC BY 4.0 licence](https://creativecommons.org/licenses/by/4.0/).

Attribution: This work includes Stats NZ's data, licensed by Stats NZ for reuse
under the Creative Commons Attribution 4.0 International licence.

`man/figures/README-cpi-chart-1.png` is a package-authored chart derived from
this attributed extract. It is not a Stats NZ graphic or logo. Its visible
caption identifies the official source; the surrounding documentation and this
record carry the full data attribution.

The snapshot is installed solely to make documentation and examples
deterministic and offline. Users should retrieve the current official release
for current analysis and retain the provenance returned by
`statsnz_provenance()`.
