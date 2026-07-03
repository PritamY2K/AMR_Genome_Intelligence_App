#!/bin/bash

ACCESSION=$1

if [ -z "$ACCESSION" ]; then
    echo "Usage: bash download_ncbi_genome.sh GCF_000005845.2"
    exit 1
fi

BASE="${AMR_APP_BASE:-/app}"

if [ ! -d "$BASE" ]; then
    BASE="$HOME/AMR_App"
fi
DOWNLOAD_BASE="$BASE/ncbi_downloads"
DOWNLOAD_DIR="$DOWNLOAD_BASE/$ACCESSION"
ZIP_FILE="$DOWNLOAD_BASE/${ACCESSION}.zip"
INPUT_FILE="$BASE/input/${ACCESSION}.fna"

mkdir -p "$DOWNLOAD_DIR"
mkdir -p "$BASE/input"

echo "Downloading genome for accession: $ACCESSION"

datasets download genome accession "$ACCESSION" \
    --include genome,gff3,protein \
    --filename "$ZIP_FILE"

if [ $? -ne 0 ]; then
    echo "NCBI download failed."
    exit 1
fi

echo "Extracting genome package..."

unzip -o "$ZIP_FILE" -d "$DOWNLOAD_DIR"

FASTA_FILE=$(find "$DOWNLOAD_DIR" -name "*.fna" | head -n 1)

if [ -z "$FASTA_FILE" ]; then
    echo "No genome FASTA file found."
    exit 1
fi

cp "$FASTA_FILE" "$INPUT_FILE"

echo "Genome FASTA saved as:"
echo "$INPUT_FILE"
