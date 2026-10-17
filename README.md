# Pavement field experiments: data and code

Study: *Causal appraisal of asphalt pavement field experiments: warm mix asphalt and rehabilitation policies*.

Version: **v5b-20261017**. [Release page](https://github.com/hrgentry/causal-pavement-field-experiments/releases/tag/v5b-20261017).

## Use the complete archive

1. Download the [full archive](https://github.com/hrgentry/causal-pavement-field-experiments/releases/download/v5b-20261017/pavement-causal-appraisal-v5b-20261017.zip).
2. Download SHA256SUMS.txt from the release page.
3. Check the archive against its SHA-256 value.
4. Extract the archive into a new directory.
5. Install the required Python package:

```text
python -m pip install -r requirements.txt
```

6. Run the result check:

```text
python -X utf8 tools/v5b_replay.py --output replay-result.json
```

The complete archive contains ten large NumPy data files. The Git source archive does not contain these files.

## Contents

- Study data and stored model results: `studies/01-wma-long-term-factors/analysis/outputs/`.
- Data, seeds and diagnostics for 73 new model jobs: `native-jobs/`.
- Stan model source: the study's `analysis/method-first/substantive-revision-v5/` directory.
- Result-check code: `tools/`.
- Standard deviations and sample counts: `reporting_variability/`.
- R, ggdag and TeX figure source: the study's `manuscript/` directory.

## Check limits

The result check passed 3852 tests. It uses stored results. It does not refit models or confirm causal identification.

The paper reports 135 model fits in total. This release supplies native inputs for the 73 new jobs.

The models give conditional comparisons. The common subsequent-management rule **g remains undefined**. A survey date or model draw is not an independent road section.

The source is LTPP Standard Data Release 40. [LTPP InfoPave](https://infopave.fhwa.dot.gov/) provides access to the original source.

The release excludes national databases, full chains, executables, private settings, third-party full texts, the paper and internal reviews.

See `release-manifest.json` for file hashes and source records. See `RIGHTS.md` for reuse limits. No blanket license or DOI is assigned.

Repository maintainer: `hrgentry`.
