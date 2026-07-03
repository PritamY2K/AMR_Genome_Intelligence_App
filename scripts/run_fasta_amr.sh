#!/bin/bash

INPUT=$1
SAMPLE=$2

if [ -z "$INPUT" ] || [ -z "$SAMPLE" ]; then
    echo "Usage: bash run_fasta_amr.sh input.fna sample_name"
    exit 1
fi

BASE="${AMR_APP_BASE:-/app}"

if [ ! -d "$BASE" ]; then
    BASE="$HOME/AMR_App"
fi

RESULTS="$BASE/results"
mkdir -p "$RESULTS"

echo "Step 1: Running Prodigal..."

prodigal -i "$INPUT" \
-a "$RESULTS/${SAMPLE}_proteins.faa" \
-d "$RESULTS/${SAMPLE}_genes.fna" \
-o "$RESULTS/${SAMPLE}_prodigal.gbk"

if [ $? -ne 0 ]; then
    echo "Prodigal failed."
    exit 1
fi

echo "Step 2: Running AMRFinderPlus protein-only mode..."

amrfinder \
-p "$RESULTS/${SAMPLE}_proteins.faa" \
-o "$RESULTS/${SAMPLE}_amrfinder.tsv"

if [ $? -ne 0 ]; then
    echo "AMRFinderPlus failed."
    exit 1
fi

echo "Step 3: Running ABRicate ResFinder..."

abricate --db resfinder "$INPUT" > "$RESULTS/${SAMPLE}_abricate_resfinder.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate ResFinder failed."
    exit 1
fi

echo "Step 4: Running ABRicate CARD..."

abricate --db card "$INPUT" > "$RESULTS/${SAMPLE}_abricate_card.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate CARD failed."
    exit 1
fi

echo "Step 5: Running CARD-RGI..."

if [ -x /home/pritam/miniforge3/envs/rgi_env/bin/rgi ]; then
    /home/pritam/miniforge3/envs/rgi_env/bin/rgi main \
    -i "$INPUT" \
    -o "$RESULTS/${SAMPLE}_rgi" \
    -t contig \
    -a DIAMOND \
    --clean \
    --local

    if [ $? -ne 0 ]; then
        echo "CARD-RGI failed, but continuing pipeline."
        echo -e "Status	Message" > "$RESULTS/${SAMPLE}_rgi.txt"
        echo -e "Skipped	CARD-RGI failed during execution" >> "$RESULTS/${SAMPLE}_rgi.txt"
    fi
else
    echo "CARD-RGI skipped because rgi command is not installed."
    echo -e "Status	Message" > "$RESULTS/${SAMPLE}_rgi.txt"
    echo -e "Skipped	CARD-RGI is not installed in the current environment" >> "$RESULTS/${SAMPLE}_rgi.txt"
fi

echo "FASTA AMR pipeline completed successfully."
echo "AMRFinderPlus result:"
echo "$RESULTS/${SAMPLE}_amrfinder.tsv"
echo "ABRicate ResFinder result:"
echo "$RESULTS/${SAMPLE}_abricate_resfinder.tsv"
echo "ABRicate CARD result:"
echo "$RESULTS/${SAMPLE}_abricate_card.tsv"
echo "CARD-RGI result:"
echo "$RESULTS/${SAMPLE}_rgi.txt"
