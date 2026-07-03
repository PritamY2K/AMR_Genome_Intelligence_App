#!/bin/bash

ACCESSION=$1

if [ -z "$ACCESSION" ]; then
    echo "Usage: bash run_accession_amr.sh GCF_or_GCA_accession"
    exit 1
fi

BASE="${AMR_APP_BASE:-/app}"

if [ ! -d "$BASE" ]; then
    BASE="$HOME/AMR_App"
fi

RESULTS="$BASE/results"
DOWNLOAD_BASE="$BASE/ncbi_downloads"

mkdir -p "$RESULTS" "$DOWNLOAD_BASE"

ZIP_FILE="$DOWNLOAD_BASE/${ACCESSION}.zip"
EXTRACT_DIR="$DOWNLOAD_BASE/${ACCESSION}"

echo "Step 1: Downloading genome from NCBI..."

datasets download genome accession "$ACCESSION" \
--include genome \
--filename "$ZIP_FILE"

if [ $? -ne 0 ]; then
    echo "NCBI genome download failed."
    exit 1
fi

rm -rf "$EXTRACT_DIR"
mkdir -p "$EXTRACT_DIR"

unzip -q "$ZIP_FILE" -d "$EXTRACT_DIR"

GENOME_FASTA=$(find "$EXTRACT_DIR" -name "*genomic.fna" | head -n 1)

if [ -z "$GENOME_FASTA" ]; then
    echo "No genomic FASTA file found after NCBI download."
    exit 1
fi

echo "Genome FASTA found:"
echo "$GENOME_FASTA"

echo "Step 2: Running Prodigal..."

prodigal -i "$GENOME_FASTA" \
-a "$RESULTS/${ACCESSION}_proteins.faa" \
-d "$RESULTS/${ACCESSION}_genes.fna" \
-o "$RESULTS/${ACCESSION}_prodigal.gbk"

if [ $? -ne 0 ]; then
    echo "Prodigal failed."
    exit 1
fi

echo "Step 3: Running AMRFinderPlus protein-only mode..."

amrfinder \
-p "$RESULTS/${ACCESSION}_proteins.faa" \
-o "$RESULTS/${ACCESSION}_amrfinder.tsv"

if [ $? -ne 0 ]; then
    echo "AMRFinderPlus failed."
    exit 1
fi

echo "Step 4: Running ABRicate ResFinder..."

abricate --db resfinder "$GENOME_FASTA" > "$RESULTS/${ACCESSION}_abricate_resfinder.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate ResFinder failed."
    exit 1
fi

echo "Step 5: Running ABRicate CARD..."

abricate --db card "$GENOME_FASTA" > "$RESULTS/${ACCESSION}_abricate_card.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate CARD failed."
    exit 1
fi

echo "Step 6: Running CARD-RGI..."

if [ -x /home/pritam/miniforge3/envs/rgi_env/bin/rgi ]; then
    /home/pritam/miniforge3/envs/rgi_env/bin/rgi main \
    -i "$GENOME_FASTA" \
    -o "$RESULTS/${ACCESSION}_rgi" \
    -t contig \
    -a DIAMOND \
    --clean \
    --local

    if [ $? -ne 0 ]; then
        echo "CARD-RGI failed, but continuing pipeline."
        echo -e "Status	Message" > "$RESULTS/${ACCESSION}_rgi.txt"
        echo -e "Skipped	CARD-RGI failed during execution" >> "$RESULTS/${ACCESSION}_rgi.txt"
    fi
else
    echo "CARD-RGI skipped because rgi command is not installed."
    echo -e "Status	Message" > "$RESULTS/${ACCESSION}_rgi.txt"
    echo -e "Skipped	CARD-RGI is not installed in the current environment" >> "$RESULTS/${ACCESSION}_rgi.txt"
fi

echo "NCBI accession AMR pipeline completed successfully."
echo "AMRFinderPlus result:"
echo "$RESULTS/${ACCESSION}_amrfinder.tsv"
echo "ABRicate ResFinder result:"
echo "$RESULTS/${ACCESSION}_abricate_resfinder.tsv"
echo "ABRicate CARD result:"
echo "$RESULTS/${ACCESSION}_abricate_card.tsv"
echo "CARD-RGI result:"
echo "$RESULTS/${ACCESSION}_rgi.txt"
