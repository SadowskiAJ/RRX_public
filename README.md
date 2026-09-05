# RRX: a crowdsourced Abaqus reproducibility benchmark

> **This benchmark is ongoing, and we are still accepting new submissions.**
> Contributions from additional hardware and Abaqus releases are welcome.
> See [Run a new benchmark](#run-a-new-benchmark) for instructions and contact
> [Adam J. Sadowski](mailto:a.sadowski@imperial.ac.uk) to contribute your results.
> Please send participant and system details privately, not through public issues.

Anonymised submissions, benchmark inputs and MATLAB analysis code accompanying
**Machine-dependent nonlinear finite element responses via a crowdsourced Abaqus benchmark**, by
Yuhan Wei, Molly Balassa and Adam J. Sadowski.

[Read the manuscript](RRX%20paper.pdf). This is the current write-up intended for
the *Journal of Computational Physics*, under review. It is not a published or
accepted journal version. The PDF is supplied unchanged from the authors' working manuscript.

The benchmark concerns a cylindrical shell under uniform meridional compression.
It compares one materially nonlinear, geometrically linear analysis (MNA) with
three geometrically nonlinear, elastic analyses (GNA1–3). The GNA input files
differ only in their initial and maximum arc-length increments (0.01, 0.03 and
0.05 respectively), apart from job-name comments. 

As of 05/09/26 the dataset contains 33 submissions of all four analyses.

## Contents

| Path | Purpose |
| --- | --- |
| `Anonymised/` | The 33 submitted histories and retained platform metadata, under anonymised filenames. |
| `cBlock_Object.m`, `cRRX_Object.m` | Parse histories and metadata and calculate deterministic fingerprints. |
| `S1_Build.m` | Build the submission objects and exact-fingerprint groups. |
| `S2_Frechet.m` | Calculate scaled, multivariate discrete Fréchet distance matrices for unique histories. |
| `S3_ClusterAnalysis.m` | Build complete-linkage trees and cluster memberships for all four analyses. |
| `JCP_Fig1.m`–`JCP_Fig3.m` | Generate the three manuscript figures. |
| `JCP_Fig1.png`–`JCP_Fig3.png` | Supplied high-resolution figure exports. |
| `MNA_clusters.png`, `GNA1_clusters.png`–`GNA3_clusters.png` | Additional dendrogram exports for comparison across analyses. |
| `ReferenceResults.xlsx` | Reference deformation profiles and response paths required by Fig. 1. |
| `Benchmark/` | Four unchanged Abaqus input files and the original history-extraction script. |
| `RRX paper.pdf` | Manuscript intended for JCP, under review. |

Private participant records, raw submission archives, identity mappings and the
private preprocessing stage `S0_Zip2Txt.m` are intentionally excluded. The optional
significant-digit plotting script is not part of this release.

## Reproduce the analysis and figures

The authors used MATLAB R2025b with Statistics and Machine Learning Toolbox and Java enabled.
The analysis has been checked with this version on Windows; older releases and
other platforms have not been validated. The figure scripts use `theme`, and the
clustering uses `linkage`, `cluster`, `squareform` and `optimalleaforder`.
Times New Roman should be installed to reproduce the figure typography.
Abaqus and Python are **not** needed to analyse the supplied submissions.

Set MATLAB's current folder to the repository root, then run in this order to reproduce the figures of the paper:

```matlab
S1_Build
S2_Frechet
S3_ClusterAnalysis

JCP_Fig1
JCP_Fig2
JCP_Fig3
```

`S1_Build` clears the workspace. The later scripts use variables left in memory;
do not clear them between stages. The figure scripts close existing figures and
overwrite their corresponding PNG files at 600 dpi. Wait for an export to finish
before copying its PNG into another document. Pixel dimensions and text layout
can vary with screen size, installed fonts and MATLAB version.

Expected results with the supplied data and default controls:

| Analysis | Unique full-history fingerprints | Cluster cut | Number of clusters |
| --- | ---: | ---: | ---: |
| MNA | 12 | `1e-10` | 7 |
| GNA1 | 11 | `1e-6` | 7 |
| GNA2 | 14 | `1e-6` | 8 |
| GNA3 | 11 | `1e-6` | 7 |

`S1_Build` also finds 14 unique combined-submission fingerprints.
`S3_ClusterAnalysis` leaves `MNA_Clusters`, `GNA1_Clusters`, `GNA2_Clusters` and
`GNA3_Clusters` in memory. Figures 1 and 3 use the same `GNA2_Clusters` structure.

For a different dendrogram, change `GNA2_Clusters` to the required structure in
`JCP_Fig3.m` (both the required-variable list and the `families` assignment), change
`txt` to that analysis name, and set `exportFilename` to a different PNG name.
No new distance calculations are needed. C1–C3 are assigned left-to-right within
each tree: their labels and colours are not an automatic cross-analysis matching.

## Data format and analysis choices

Each file in `Anonymised/` starts with four metadata lines: CPU description,
operating system, Abaqus release/build and RAM description. Sections headed
`#MNA`, `#GNA1`, `#GNA2` and `#GNA3` contain comma-separated numeric rows:

```text
arc length,load proportionality factor,loaded-edge displacement,maximum force residual,negative-eigenvalue count
```

The parser preserves row order and requires nondecreasing arc length. Recognised
NaN spellings represent missing diagnostics; the negative-eigenvalue count uses
an `int32(-1)` sentinel internally. Platform descriptions are parsed using
heuristics; the original CPU string is retained. Filenames identify submissions,
not distinct people or statistically independent computing environments.

SHA-256 fingerprints include the row count and all five recorded histories, in a
fixed byte order with signed zero canonicalised. Exact-fingerprint deduplication
is not tolerance-based clustering. Fréchet distances use only LPF, **signed**
loaded-edge displacement and maximum force residual. Arc length is implicit in
the point ordering. Consequently, distinct full-history fingerprints may have
zero Fréchet distance. Figure 1 displays displacement magnitude instead.

The default `sigmaPolicy = 'unique'` in `S2_Frechet.m` uses coordinate standard
deviations from concatenated representative histories, separately for each
analysis. The alternative `'pooled'` includes every submission with its observed
multiplicity. Longer histories contribute more samples under either policy.
Missing residuals are omitted from the corresponding scale calculation and from
pointwise costs when unavailable in either history. Available coordinate
differences are divided by their scales and combined using Euclidean distance. The discrete Fréchet recurrence preserves the order of curve points. The
missing-coordinate convention is an implementation choice, not a claim of all
metric properties for incomplete data.

Clustering expands the compact distance matrices back to all submissions by
indexing, then uses complete linkage. It does not calculate new Fréchet
distances or use platform metadata to choose the clusters. The three largest
non-singleton clusters are highlighted, with one first-submission representative
per highlighted family in Fig. 1. Fig. 2 uses a shared logarithmic colour scale;
zero is a separate grey category. Fig. 3 displays zero-height merges on a
separate baseline so they remain visible on a logarithmic axis.

## Run a new benchmark

The complete model definitions, material properties, mesh, boundary conditions
and solver controls are in `Benchmark/*.inp`. To repeat the original exercise,
use a licensed Abaqus installation and run each input unchanged, serially, from
a separate working copy of `Benchmark/`. For example:

```text
abaqus job=RRX_GNA_2 input=RRX_GNA_2.inp cpus=1 interactive
abaqus python RRX_Export_Paths.py
```

Repeat for MNA, GNA1 and GNA3. The extraction script reads all `.odb` files in its
current folder and writes corresponding five-column `.csv` files. It requires
the Abaqus Python/ODB API, not a standalone Python installation. It is included
unchanged as part of the original protocol; running new solver jobs and testing
the exporter across Abaqus releases are separate from reproducing the MATLAB
analysis of the supplied dataset. Keep the original inputs and record the CPU,
operating system, Abaqus release/build, RAM and execution settings for new runs.
The public pipeline starts from the combined anonymised text format described
above; it does not automatically import fresh CSVs or anonymise participant data.

## Interpretation and limitations

These are observed numerical responses, not validated engineering design
solutions. Some responses depart from the expected benchmark paths. The small,
self-selected dataset demonstrates variability and recurring platform-associated
families, but does not isolate a causal hardware or software mechanism.
Microscopic differences can also reflect export precision, missing diagnostics
and the chosen distance coordinates. The similar platform groupings in MNA occur
at a much smaller distance scale than the macroscopically different GNA paths.

## Authors, contributions and AI assistance

- **Yuhan Wei:** Formal analysis; writing – original draft.
- **Molly Balassa:** Conceptualization; formal analysis; writing – original draft.
- **Adam J. Sadowski:** Conceptualization; formal analysis; writing – original draft.

Department of Civil and Environmental Engineering, Imperial College London, UK.
The authors thank all contributors to the crowdsourcing exercise.

This README was generated with OpenAI Codex.

OpenAI Codex was used to assist with development, refactoring, debugging and
documentation of the analysis code. The authors review the code and remain
responsible for the released work and its interpretation.

## Citation, licence and contact

Please cite the accompanying manuscript and this repository when using the
benchmark, data or code. The manuscript is under review; no journal DOI or final
publication details are asserted here. [`CITATION.cff`](CITATION.cff) supplies
machine-readable repository citation metadata. Citation is requested as scholarly
practice, not imposed as an additional licence condition.

The authors' original code and accompanying benchmark materials are made
available under the [BSD Zero Clause licence (0BSD)](LICENSE), without warranty.
This does not grant rights to proprietary Abaqus or MATLAB software, their
trademarks, or any third-party material. The supplied manuscript remains the
authors' under-review version, not a publisher-issued article.

For questions or additional benchmark results, use the repository's issue
tracker or contact Adam J. Sadowski at <a.sadowski@imperial.ac.uk>. Do not post
personal participant information or confidential system information publicly.
