#!/usr/bin/env python3

import argparse
import csv
import subprocess
import time
from concurrent.futures import ThreadPoolExecutor, as_completed
from pathlib import Path

# === Argument Parser ===
parser = argparse.ArgumentParser(description="Set ImageDescription from EXIF")
parser.add_argument("files", nargs="+", help="Glob pattern(s) or file paths")
parser.add_argument("--dry-run", "-n", action="store_true", help="Dry-run mode (no write)")
parser.add_argument("--skip-tagged", action="store_true", help="Skip images with existing ImageDescription")
parser.add_argument("--logfile", default="set_description_log.csv", help="CSV output file")
parser.add_argument("--stats", action="store_true", help="Show processing summary")
parser.add_argument("--jobs", type=int, default=4, help="Number of parallel jobs")
args = parser.parse_args()

# === CSV Header ===
LOG_COLUMNS = ["File", "OriginalDescription", "NewDescription", "MissingFields", "Status"]

# === Stats ===
stats = {
    "total": 0,
    "updated": 0,
    "skipped": 0,
    "dry_run": 0,
    "not_a_file": 0
}

# === Helper: Run exiftool and get field ===
def get_exif_field(file, tag):
    try:
        result = subprocess.run([
            "exiftool", f"-{tag}", "-s3", str(file)
        ], capture_output=True, text=True)
        return result.stdout.strip()
    except Exception:
        return ""

# === Main processing function ===
def process_file(file_path):
    path = Path(file_path)
    if not path.is_file():
        stats["not_a_file"] += 1
        return [str(path), "", "", "", "Not a file"]

    stats["total"] += 1
    original = get_exif_field(path, "ImageDescription")

    if args.skip_tagged and original:
        stats["skipped"] += 1
        return [str(path), original, "", "", "Skipped - already tagged"]

    tags = {
        "Camera": get_exif_field(path, "Model"),
        "Lens": get_exif_field(path, "LensID"),
        "Focal": get_exif_field(path, "FocalLength"),
        "Shutter": get_exif_field(path, "ShutterSpeedValue"),
        "Aperture": get_exif_field(path, "ApertureValue"),
        "ISO": get_exif_field(path, "ISO")
    }

    missing = [k for k, v in tags.items() if not v]
    description = " - ".join([
        tags["Camera"] or "[Missing]",
        tags["Lens"] or "[Missing]",
        tags["Focal"] or "[Missing]",
        tags["Shutter"] or "[Missing]",
        tags["Aperture"] or "[Missing]",
        tags["ISO"] or "[Missing]"
    ])

    if args.dry_run:
        stats["dry_run"] += 1
        status = "Dry run"
    else:
        subprocess.run([
            "exiftool", "-overwrite_original",
            f"-ImageDescription={description}", str(path)
        ], capture_output=True)
        stats["updated"] += 1
        status = "Updated"

    return [str(path), original, description, "; ".join(missing), status]

# === File expansion ===
import glob
all_files = []
for pattern in args.files:
    all_files.extend(glob.glob(pattern, recursive=True))

# === Start processing ===
start = time.time()
print(f"📸 Processing started at {time.ctime()}")
print(f"📝 Logging to {args.logfile}...")

rows = []
with ThreadPoolExecutor(max_workers=args.jobs) as executor:
    futures = [executor.submit(process_file, f) for f in all_files]
    for future in as_completed(futures):
        rows.append(future.result())

# === Write CSV ===
with open(args.logfile, "w", newline="", encoding="utf-8") as f:
    writer = csv.writer(f)
    writer.writerow(LOG_COLUMNS)
    writer.writerows(rows)

elapsed = time.time() - start
fps = stats["total"] / elapsed if elapsed > 0 else stats["total"]
print(f"✅ Done. Processed {stats['total']} files in {int(elapsed)}s ({fps:.2f} files/sec).")
print(f"📄 CSV log saved to {args.logfile}")

# === Optional stats ===
if args.stats:
    print("\n📊 Summary:")
    print(f"  Total Files:     {stats['total']}")
    print(f"  Updated:         {stats['updated']}")
    print(f"  Dry-run:         {stats['dry_run']}")
    print(f"  Skipped Tagged:  {stats['skipped']}")
    print(f"  Not a File:      {stats['not_a_file']}")
