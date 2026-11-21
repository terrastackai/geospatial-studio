# CI Dataset Tooling

`build_ci_dataset_subset.py` builds a small, representative subset of a
paired-GeoTIFF dataset for fast CI testing of the dataset onboarding /
fine-tuning pipeline. See the module docstring for sampling methodology.

## Why

The full "Wildfire burn scars" dataset is 804 scenes (~2.9GB), too slow to
download on every CI run. The CI dataset
(`populate-studio/payloads/datasets/dataset-burn_scars-ci.json`) points at a
24-scene, ~90MB subset instead, preserving class balance and the rare
"Ignore" label.

## Regenerating

```bash
pip install -r scripts/datasets/requirements.txt

# Dry run: scans mask files only, prints the sampling plan.
python scripts/datasets/build_ci_dataset_subset.py \
    --source-url <full-dataset-zip-url> --num-scenes 24 \
    --cache /tmp/stats_cache.json --dry-run

# Build the subset zip + manifest (reuses the cache above).
python scripts/datasets/build_ci_dataset_subset.py \
    --source-url <full-dataset-zip-url> --num-scenes 24 \
    --cache /tmp/stats_cache.json \
    --output-zip burn-scar-training-data-ci.zip \
    --manifest burn-scar-training-data-ci.manifest.json
```

## Publishing

The zip needs unauthenticated HTTPS GET access (the onboarding pipeline
fetches `dataset_url` with no auth).

- Current copy: RIS3 IBM Cloud account, COS instance
  `geospatial-studio-fmaas-prod-cos`, bucket
  `geospatial-studio-temporary-uploads-fmaas-prod`, prefix
  `geospatial-studio-ci-datasets/`, uploaded via `boto3` with
  `ACL=public-read`.
- After re-uploading, update `dataset_url` in `dataset-burn_scars-ci.json`
  and copy the new manifest over `burn-scar-training-data-ci.manifest.json`.

## Validating before publishing

- Every `_merged.tif` has a matching `.mask.tif` by filename stem.
- Shape/band count matches the dataset payload (the script validates this
  automatically).
- `--num-scenes >= 5` so a 60/20/20 split never leaves a split empty.
- Manifest's `class_distribution_subset` is close to
  `class_distribution_full_dataset`.
