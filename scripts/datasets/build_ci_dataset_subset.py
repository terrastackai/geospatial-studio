#!/usr/bin/env python3
# SPDX-License-Identifier: Apache-2.0
"""Build a small, representative subset of a paired-GeoTIFF dataset for CI.

CI exercises Geospatial Studio's onboard -> fine-tune -> inference flow. Running that against the full 804-scene, ~2.9GB "Wildfire burn scars" dataset makes every CI run slow. This script samples a small subset that still behaves like the full dataset.

Sampling approach:
- Scenes are bucketed into quantile strata by burn-pixel fraction (from each mask), then sampled proportionally per stratum with a fixed seed. This avoids a naive sample collapsing to all-background or all-foreground tiles.
- If the full dataset has scenes with the "Ignore" label class, at least one is swapped into the subset so that code path stays covered.
- Mask files are read directly from the remote zip via `remotezip` - only the final selected merged+mask pairs are downloaded, not the whole dataset.
- Selected pairs are validated for consistent shape/bands/dtype before being written to a flat output zip using the source dataset's filename convention.
- A JSON manifest records the seed, strata, selected scenes, and before/after class distribution, so the subset is auditable and reproducible.

Usage:
    # Dry run - scan and print the sampling plan, no download/write.
    python build_ci_dataset_subset.py --source-url <url> --num-scenes 24 --dry-run

    # Build the subset zip + manifest.
    python build_ci_dataset_subset.py --source-url <url> --num-scenes 24 \\
        --output-zip out.zip --manifest out.manifest.json

Requires: remotezip, rasterio, numpy.
"""

from __future__ import annotations

import argparse
import io
import json
import math
import os
import random
import sys
import time
import zipfile
from collections import defaultdict
from dataclasses import dataclass, field
from pathlib import Path
from typing import Optional

import numpy as np
import rasterio
from remotezip import RemoteZip

# ---------------------------------------------------------------------------
# Constants
# ---------------------------------------------------------------------------

IGNORE_LABEL = -1
DEFAULT_SEED = 42
DEFAULT_STRATA = 4
# Minimum scenes so a 60/20/20 split never leaves a split empty.
MIN_SCENES_FOR_SPLIT = 5

# ---------------------------------------------------------------------------
# Data model
# ---------------------------------------------------------------------------


@dataclass
class SceneStats:
    stem: str
    mask_member: str
    merged_member: str
    total_pixels: int
    class_counts: dict
    ignore_pixels: int
    burn_fraction: float
    has_ignore: bool


@dataclass
class SamplingPlan:
    seed: int
    num_strata: int
    requested_scenes: int
    total_scenes_available: int
    selected: list = field(default_factory=list)
    strata_summary: list = field(default_factory=list)
    forced_ignore_swap: Optional[str] = None


# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------


def log(msg: str) -> None:
    print(f"[build_ci_dataset_subset] {msg}", flush=True)


def stem_from_mask(name: str, mask_suffix: str) -> str:
    base = name.rsplit("/", 1)[-1]
    if not base.endswith(mask_suffix):
        raise ValueError(f"{name!r} does not end with mask suffix {mask_suffix!r}")
    return base[: -len(mask_suffix)]


def compute_mask_stats(stem: str, mask_member: str, merged_member: str, data: bytes) -> SceneStats:
    with rasterio.MemoryFile(data) as mem:
        with mem.open() as ds:
            arr = ds.read(1)
    total = int(arr.size)
    values, counts = np.unique(arr, return_counts=True)
    class_counts = {int(v): int(c) for v, c in zip(values, counts)}
    ignore_pixels = class_counts.get(IGNORE_LABEL, 0)
    denom = total - ignore_pixels
    burn_pixels = class_counts.get(1, 0)
    burn_fraction = (burn_pixels / denom) if denom > 0 else 0.0
    return SceneStats(
        stem=stem,
        mask_member=mask_member,
        merged_member=merged_member,
        total_pixels=total,
        class_counts=class_counts,
        ignore_pixels=ignore_pixels,
        burn_fraction=burn_fraction,
        has_ignore=ignore_pixels > 0,
    )


def scan_source_dataset(
    source_url: str,
    mask_suffix: str,
    merged_suffix: str,
    cache_path: Optional[Path],
    limit: Optional[int] = None,
) -> list:
    """
    Lazily lists the remote zip and streams every mask file to compute
    per-scene label statistics, WITHOUT downloading any `_merged.tif` image
    data or the zip as a whole. Results are cached to `cache_path` (JSON) so
    repeat runs (e.g. iterating on --num-scenes) don't re-scan the network.
    """
    if cache_path and cache_path.exists():
        log(f"Loading cached scene stats from {cache_path}")
        with open(cache_path) as fh:
            raw = json.load(fh)
        return [SceneStats(**s) for s in raw]

    log(f"Opening remote zip index: {source_url}")
    stats: list = []
    with RemoteZip(source_url) as z:
        names = z.namelist()
        mask_names = sorted(n for n in names if n.endswith(mask_suffix) and "__MACOSX" not in n)
        merged_by_stem = {
            stem_from_mask(n, merged_suffix): n
            for n in names
            if n.endswith(merged_suffix) and "__MACOSX" not in n
        }
        log(f"Found {len(mask_names)} mask files / {len(merged_by_stem)} merged files in source zip")

        if limit:
            mask_names = mask_names[:limit]

        t0 = time.time()
        for i, mask_member in enumerate(mask_names, 1):
            stem = stem_from_mask(mask_member, mask_suffix)
            merged_member = merged_by_stem.get(stem)
            if merged_member is None:
                log(f"  WARNING: no matching merged file for mask {mask_member!r}; skipping")
                continue
            data = z.read(mask_member)
            stats.append(compute_mask_stats(stem, mask_member, merged_member, data))
            if i % 50 == 0 or i == len(mask_names):
                elapsed = time.time() - t0
                log(f"  scanned {i}/{len(mask_names)} masks ({elapsed:.1f}s elapsed)")

    if cache_path:
        cache_path.parent.mkdir(parents=True, exist_ok=True)
        with open(cache_path, "w") as fh:
            json.dump([s.__dict__ for s in stats], fh)
        log(f"Cached scene stats to {cache_path}")

    return stats


def build_sampling_plan(
    stats: list,
    num_scenes: int,
    num_strata: int,
    seed: int,
) -> SamplingPlan:
    if num_scenes > len(stats):
        raise ValueError(
            f"Requested {num_scenes} scenes but only {len(stats)} are available in the source dataset"
        )
    if num_scenes < MIN_SCENES_FOR_SPLIT:
        raise ValueError(
            f"--num-scenes must be >= {MIN_SCENES_FOR_SPLIT} to guarantee a non-empty "
            f"60/20/20 train/val/test split (requested {num_scenes})"
        )

    rng = random.Random(seed)

    # Stratify on burn_fraction using quantile bin edges computed from the
    # *full* population so strata are balanced by count, not by value range
    # (robust to the heavily right-skewed burn_fraction distribution).
    fractions = sorted(s.burn_fraction for s in stats)
    quantile_edges = [
        fractions[min(int(round(q * (len(fractions) - 1))), len(fractions) - 1)]
        for q in [i / num_strata for i in range(1, num_strata)]
    ]

    def stratum_of(frac: float) -> int:
        for idx, edge in enumerate(quantile_edges):
            if frac <= edge:
                return idx
        return num_strata - 1

    strata: dict = defaultdict(list)
    for s in stats:
        strata[stratum_of(s.burn_fraction)].append(s)

    # Allocate num_scenes across strata proportional to stratum size, using
    # the largest-remainder method so allocations sum exactly to num_scenes.
    stratum_sizes = {k: len(v) for k, v in strata.items()}
    total = sum(stratum_sizes.values())
    raw_alloc = {k: (v / total) * num_scenes for k, v in stratum_sizes.items()}
    base_alloc = {k: int(math.floor(v)) for k, v in raw_alloc.items()}
    remainder = num_scenes - sum(base_alloc.values())
    # distribute leftover slots to strata with the largest fractional remainder
    order = sorted(raw_alloc, key=lambda k: raw_alloc[k] - base_alloc[k], reverse=True)
    for k in order[:remainder]:
        base_alloc[k] += 1

    selected: list = []
    strata_summary = []
    for k in sorted(strata):
        pool = strata[k]
        n = min(base_alloc.get(k, 0), len(pool))
        chosen = rng.sample(pool, n) if n > 0 else []
        selected.extend(chosen)
        strata_summary.append(
            {
                "stratum": k,
                "burn_fraction_range": [
                    quantile_edges[k - 1] if k > 0 else 0.0,
                    quantile_edges[k] if k < len(quantile_edges) else max(fractions),
                ],
                "population_size": len(pool),
                "sampled": n,
            }
        )

    plan = SamplingPlan(
        seed=seed,
        num_strata=num_strata,
        requested_scenes=num_scenes,
        total_scenes_available=len(stats),
        selected=selected,
        strata_summary=strata_summary,
    )

    # Edge-case guarantee: make sure at least one scene with the "Ignore"
    # label is present in the subset if any exist in the full dataset, so
    # the CI subset still exercises that schema path.
    if not any(s.has_ignore for s in selected):
        ignore_candidates = [s for s in stats if s.has_ignore]
        if ignore_candidates:
            # Prefer swapping out the selected scene whose burn_fraction is
            # closest to the ignore-candidate's, minimizing distribution
            # disturbance, and prefer swapping within the same stratum.
            target = min(
                ignore_candidates,
                key=lambda c: min(abs(c.burn_fraction - s.burn_fraction) for s in selected),
            )
            victim = min(selected, key=lambda s: abs(s.burn_fraction - target.burn_fraction))
            selected.remove(victim)
            selected.append(target)
            plan.forced_ignore_swap = (
                f"Swapped out {victim.stem} (burn_fraction={victim.burn_fraction:.4f}) "
                f"for {target.stem} (burn_fraction={target.burn_fraction:.4f}, has_ignore=True) "
                "to guarantee the 'Ignore' label class is represented in the CI subset."
            )
            log(plan.forced_ignore_swap)

    plan.selected = selected
    return plan


def fetch_and_validate_pairs(source_url: str, plan: SamplingPlan) -> list:
    """
    Fetches the merged+mask bytes for every scene in the sampling plan and
    validates internal consistency (band count / shape / dtype match across
    all selected scenes) before anything is written to disk.
    """
    fetched = []
    reference_shape = None
    reference_bands = None
    reference_dtype = None

    with RemoteZip(source_url) as z:
        for i, scene in enumerate(plan.selected, 1):
            log(f"  fetching pair {i}/{len(plan.selected)}: {scene.stem}")
            mask_bytes = z.read(scene.mask_member)
            merged_bytes = z.read(scene.merged_member)

            with rasterio.MemoryFile(merged_bytes) as mem:
                with mem.open() as ds:
                    bands, height, width = ds.count, ds.height, ds.width
                    dtype = ds.dtypes[0]

            if reference_shape is None:
                reference_shape = (height, width)
                reference_bands = bands
                reference_dtype = dtype
            else:
                if (height, width) != reference_shape:
                    raise ValueError(
                        f"Scene {scene.stem} has shape {(height, width)}, expected {reference_shape}"
                    )
                if bands != reference_bands:
                    raise ValueError(
                        f"Scene {scene.stem} has {bands} bands, expected {reference_bands}"
                    )
                if dtype != reference_dtype:
                    log(
                        f"  WARNING: scene {scene.stem} dtype {dtype} differs from "
                        f"reference {reference_dtype} (bands are still usable; "
                        "GeoTIFF dtype can vary per-scene upstream)"
                    )

            fetched.append((scene, mask_bytes, merged_bytes))

    log(
        f"Validated {len(fetched)} scene pairs: shape={reference_shape}, "
        f"bands={reference_bands}, dtype={reference_dtype}"
    )
    return fetched


def write_subset_zip(
    fetched: list,
    output_zip: Path,
    mask_suffix: str,
    merged_suffix: str,
) -> None:
    output_zip.parent.mkdir(parents=True, exist_ok=True)
    with zipfile.ZipFile(output_zip, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as zf:
        for scene, mask_bytes, merged_bytes in fetched:
            zf.writestr(f"{scene.stem}{mask_suffix}", mask_bytes)
            zf.writestr(f"{scene.stem}{merged_suffix}", merged_bytes)
    size_mb = output_zip.stat().st_size / 1e6
    log(f"Wrote subset zip: {output_zip} ({size_mb:.1f} MB, {len(fetched)} scene pairs)")


def aggregate_class_distribution(scenes: list) -> dict:
    agg: dict = defaultdict(int)
    for s in scenes:
        for cls, count in s.class_counts.items():
            agg[str(cls)] += count
    total = sum(agg.values())
    return {cls: {"pixels": count, "fraction": count / total} for cls, count in agg.items()}


def write_manifest(
    manifest_path: Path,
    source_url: str,
    plan: SamplingPlan,
    all_stats: list,
    output_zip: Optional[Path],
) -> None:
    manifest = {
        "source_dataset_url": source_url,
        "generated_at_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
        "methodology": (
            "Stratified sampling on per-scene burn/foreground pixel fraction "
            "(quantile bins computed over the full population), with a "
            "forced-inclusion rule guaranteeing the 'Ignore' label class is "
            "represented if present anywhere in the source dataset. "
            "Sampling is deterministic given --seed. See module docstring "
            "of build_ci_dataset_subset.py for full details."
        ),
        "seed": plan.seed,
        "num_strata": plan.num_strata,
        "requested_scenes": plan.requested_scenes,
        "total_scenes_available": plan.total_scenes_available,
        "forced_ignore_swap": plan.forced_ignore_swap,
        "strata_summary": plan.strata_summary,
        "selected_scenes": [
            {
                "stem": s.stem,
                "burn_fraction": round(s.burn_fraction, 6),
                "has_ignore": s.has_ignore,
                "class_counts": s.class_counts,
            }
            for s in sorted(plan.selected, key=lambda s: s.stem)
        ],
        "class_distribution_full_dataset": aggregate_class_distribution(all_stats),
        "class_distribution_subset": aggregate_class_distribution(plan.selected),
        "output_zip": str(output_zip) if output_zip else None,
    }
    manifest_path.parent.mkdir(parents=True, exist_ok=True)
    with open(manifest_path, "w") as fh:
        json.dump(manifest, fh, indent=2)
    log(f"Wrote manifest: {manifest_path}")


# ---------------------------------------------------------------------------
# CLI
# ---------------------------------------------------------------------------


def parse_args() -> argparse.Namespace:
    p = argparse.ArgumentParser(
        description=__doc__,
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )
    p.add_argument(
        "--source-url",
        required=True,
        help="HTTPS URL of the full source dataset zip (must support HTTP range requests)",
    )
    p.add_argument(
        "--mask-suffix",
        default=".mask.tif",
        help="Filename suffix identifying label/mask files (default: .mask.tif)",
    )
    p.add_argument(
        "--merged-suffix",
        default="_merged.tif",
        help="Filename suffix identifying image files (default: _merged.tif)",
    )
    p.add_argument(
        "--num-scenes",
        type=int,
        default=24,
        help="Number of scene pairs to include in the CI subset (default: 24)",
    )
    p.add_argument(
        "--strata",
        type=int,
        default=DEFAULT_STRATA,
        help="Number of quantile strata to stratify sampling on burn_fraction (default: 4)",
    )
    p.add_argument(
        "--seed",
        type=int,
        default=DEFAULT_SEED,
        help="Random seed for deterministic sampling (default: 42)",
    )
    p.add_argument(
        "--output-zip",
        type=Path,
        default=None,
        help="Path to write the subset zip to (required unless --dry-run)",
    )
    p.add_argument(
        "--manifest",
        type=Path,
        default=None,
        help="Path to write the JSON manifest to (defaults to <output-zip>.manifest.json)",
    )
    p.add_argument(
        "--cache",
        type=Path,
        default=None,
        help="Path to cache the full-dataset mask scan results as JSON (speeds up repeat runs)",
    )
    p.add_argument(
        "--scan-limit",
        type=int,
        default=None,
        help="For local testing only: limit the number of masks scanned from the source zip",
    )
    p.add_argument(
        "--dry-run",
        action="store_true",
        help="Scan and print the sampling plan without downloading images or writing a zip",
    )
    return p.parse_args()


def main() -> int:
    args = parse_args()

    if not args.dry_run and args.output_zip is None:
        print("error: --output-zip is required unless --dry-run is set", file=sys.stderr)
        return 2

    stats = scan_source_dataset(
        source_url=args.source_url,
        mask_suffix=args.mask_suffix,
        merged_suffix=args.merged_suffix,
        cache_path=args.cache,
        limit=args.scan_limit,
    )
    log(f"Scanned {len(stats)} scenes from source dataset")

    plan = build_sampling_plan(
        stats=stats,
        num_scenes=args.num_scenes,
        num_strata=args.strata,
        seed=args.seed,
    )

    log("Sampling plan:")
    for row in plan.strata_summary:
        log(
            f"  stratum {row['stratum']}: burn_fraction in "
            f"[{row['burn_fraction_range'][0]:.4f}, {row['burn_fraction_range'][1]:.4f}] "
            f"-> sampled {row['sampled']}/{row['population_size']}"
        )
    log(f"Selected {len(plan.selected)} scenes: {[s.stem for s in plan.selected]}")

    if args.dry_run:
        log("Dry run complete (no data downloaded, no zip written).")
        return 0

    fetched = fetch_and_validate_pairs(args.source_url, plan)
    write_subset_zip(fetched, args.output_zip, args.mask_suffix, args.merged_suffix)

    manifest_path = args.manifest or args.output_zip.with_suffix(".manifest.json")
    write_manifest(manifest_path, args.source_url, plan, stats, args.output_zip)

    log("Done.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
