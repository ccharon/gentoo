#!/bin/bash
set -euo pipefail

# === DEFAULT CONFIGURATION ===
IMG_SRC=""
DRIVE="A"
FORMAT="ibm.1440"
DRY_RUN=false

# === HELP TEXT ===
print_help() {
    cat <<EOF
Usage: $0 -i <disk_image> [options]

This script writes a floppy disk using Greaseweazle and verifies the written
data by reading it back and comparing it byte-for-byte to the original image.

Steps:
  1. Write the image with pre-erase and full track formatting
  2. Re-write the same image three more times without erase
  3. Read the disk back into a temporary image
  4. Compare the readback against the original using cmp

Required:
  -i, --image <file>     Path to the disk image to write

Optional:
  -d, --drive <letter>   Drive (A or B). Default: A
  -f, --format <name>    Format type for the disk. Default: ibm.1440
  -n, --dry-run          Simulate actions without writing/reading the disk
  -h, --help             Show this help message

Example:
  $0 --image msdos.img --drive B --format ibm.720
EOF
}

# === LOGGING FUNCTION ===
log() {
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] $*"
}

# === ARGUMENT PARSING ===
while [[ $# -gt 0 ]]; do
    case "$1" in
        -i|--image)
            IMG_SRC="$2"
            shift 2
            ;;
        -d|--drive)
            DRIVE="${2^^}"
            shift 2
            ;;
        -f|--format)
            FORMAT="$2"
            shift 2
            ;;
        -n|--dry-run)
            DRY_RUN=true
            shift
            ;;
        -h|--help)
            print_help
            exit 0
            ;;
        *)
            echo "Unknown option: $1"
            print_help
            exit 1
            ;;
    esac
done

# === VALIDATE IMAGE PARAM ===
if [[ -z "$IMG_SRC" ]]; then
    echo "Error: No image specified."
    print_help
    exit 1
fi

# === RESOLVE IMAGE ABSOLUTE PATH ===
if ! IMG_SRC_ABS=$(realpath "$IMG_SRC" 2>/dev/null); then
    echo "Error: Image file '$IMG_SRC' not found."
    exit 1
fi

if [[ ! -f "$IMG_SRC_ABS" ]]; then
    echo "Error: Resolved image path '$IMG_SRC_ABS' is not a file."
    exit 1
fi

# === VALIDATE DRIVE NAME ===
if [[ "$DRIVE" != "A" && "$DRIVE" != "B" ]]; then
    echo "Error: Drive must be A or B."
    exit 1
fi

# === CHECK 'gw' COMMAND EXISTS ===
if ! command -v gw >/dev/null 2>&1; then
    echo "Error: 'gw' (Greaseweazle) command not found in PATH."
    exit 1
fi

# === CREATE TEMP FILE WITH CORRECT EXTENSION
IMG_SRC_BASENAME="$(basename "$IMG_SRC_ABS")"
TMP_IMG_EXT="${IMG_SRC_BASENAME##*.}"

# If there's no dot in filename, ext == filename, so check for that
if [[ "TMP_IMG_EXT" == "IMG_SRC_BASENAME" ]]; then
    TMP_IMG_EXT=""
else
    # Convert to lowercase only if extension exists
    TMP_IMG_EXT="${TMP_IMG_EXT,,}"
fi

if [[ -z "$TMP_IMG_EXT" ]]; then
    echo "Error: Image file needs an extension to determine format."
    exit 1
fi

TMP_IMG=$(mktemp /tmp/gw_readback_XXXXXX.$TMP_IMG_EXT) || {
    echo "Error: Failed to create temporary file."
    exit 1
}

# === CLEANUP ON EXIT OR SIGNALS ===
cleanup() {
    log "Cleaning up temporary file..."
    rm -f "$TMP_IMG"
}
trap cleanup EXIT INT TERM HUP

# === DRY-RUN NOTICE ===
if [[ "$DRY_RUN" == true ]]; then
    log "Dry-run mode enabled. Commands will be shown but not executed."
fi

# === STEP 1: Write With Pre-Erase ===
log "Step 1: Writing '$IMG_SRC_ABS' to drive $DRIVE with erase..."
$DRY_RUN || gw write --format="$FORMAT" --drive="$DRIVE" --pre-erase --erase-empty "$IMG_SRC_ABS"

# === STEP 2: Re-write 3 Times Without Erase ===
for i in {1..3}; do
    log "Step 2.$i: Rewriting pass $i without erase..."
    $DRY_RUN || gw write --format="$FORMAT" --drive="$DRIVE" "$IMG_SRC_ABS"
done

# === STEP 3: Read Back to Temp Image ===
log "Step 3: Reading disk back into temporary image $TMP_IMG ..."
$DRY_RUN || gw read --format="$FORMAT" --drive="$DRIVE" "$TMP_IMG"

# === STEP 4: Byte-wise Comparison ===
log "Step 4: Comparing readback with original image..."
if $DRY_RUN; then
    log "Dry-run: Skipping comparison."
else
    if cmp -s "$IMG_SRC_ABS" "$TMP_IMG"; then
        log "✅ SUCCESS: Disk matches image exactly (byte-wise)."
        exit 0
    else
        log "❌ ERROR: Disk content does not match the image."
        exit 2
    fi
fi
