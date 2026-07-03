#!/bin/bash

R1=$1
R2=$2
SAMPLE=$3

if [ -z "$R1" ] || [ -z "$R2" ] || [ -z "$SAMPLE" ]; then
    echo "Usage: bash run_wgs_amr.sh reads_R1.fastq reads_R2.fastq sample_name"
    exit 1
fi

BASE="${AMR_APP_BASE:-/app}"

if [ ! -d "$BASE" ]; then
    BASE="$HOME/AMR_App"
fi

WGS_READS="$BASE/wgs_reads"
WGS_TRIMMED="$BASE/wgs_trimmed"
WGS_ASSEMBLY="$BASE/wgs_assembly"
WGS_QC="$BASE/wgs_qc"
RESULTS="$BASE/results"

mkdir -p "$WGS_READS" "$WGS_TRIMMED" "$WGS_ASSEMBLY" "$WGS_QC" "$RESULTS"

R1_PATH="$WGS_READS/$R1"
R2_PATH="$WGS_READS/$R2"

if [ ! -f "$R1_PATH" ]; then
    echo "R1 file not found:"
    echo "$R1_PATH"
    exit 1
fi

if [ ! -f "$R2_PATH" ]; then
    echo "R2 file not found:"
    echo "$R2_PATH"
    exit 1
fi

echo "Step 1: Running fastp quality control and trimming..."

fastp \
-i "$R1_PATH" \
-I "$R2_PATH" \
-o "$WGS_TRIMMED/${SAMPLE}_R1_trimmed.fastq.gz" \
-O "$WGS_TRIMMED/${SAMPLE}_R2_trimmed.fastq.gz" \
-h "$WGS_QC/${SAMPLE}_fastp.html" \
-j "$WGS_QC/${SAMPLE}_fastp.json"

if [ $? -ne 0 ]; then
    echo "fastp failed."
    exit 1
fi

echo "Step 2: Running SPAdes genome assembly..."

rm -rf "$WGS_ASSEMBLY/${SAMPLE}_spades"

spades.py \
-1 "$WGS_TRIMMED/${SAMPLE}_R1_trimmed.fastq.gz" \
-2 "$WGS_TRIMMED/${SAMPLE}_R2_trimmed.fastq.gz" \
-o "$WGS_ASSEMBLY/${SAMPLE}_spades"

if [ $? -ne 0 ]; then
    echo "SPAdes assembly failed."
    exit 1
fi

ASSEMBLY="$WGS_ASSEMBLY/${SAMPLE}_spades/contigs.fasta"

if [ ! -f "$ASSEMBLY" ]; then
    echo "SPAdes contigs.fasta not found."
    exit 1
fi

echo "Step 3: Running QUAST assembly quality check..."

quast.py "$ASSEMBLY" \
-o "$WGS_QC/${SAMPLE}_quast"

if [ $? -ne 0 ]; then
    echo "QUAST failed, but continuing AMR analysis..."
fi

echo "Step 4: Running Prodigal..."

prodigal -i "$ASSEMBLY" \
-a "$RESULTS/${SAMPLE}_wgs_proteins.faa" \
-d "$RESULTS/${SAMPLE}_wgs_genes.fna" \
-o "$RESULTS/${SAMPLE}_wgs_prodigal.gbk"

if [ $? -ne 0 ]; then
    echo "Prodigal failed."
    exit 1
fi

echo "Step 5: Running AMRFinderPlus protein-only mode..."

amrfinder \
-p "$RESULTS/${SAMPLE}_wgs_proteins.faa" \
-o "$RESULTS/${SAMPLE}_wgs_amrfinder.tsv"

if [ $? -ne 0 ]; then
    echo "AMRFinderPlus failed."
    exit 1
fi

echo "Step 6: Running ABRicate ResFinder..."

abricate --db resfinder "$ASSEMBLY" > "$RESULTS/${SAMPLE}_wgs_abricate_resfinder.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate ResFinder failed."
    exit 1
fi

echo "Step 7: Running ABRicate CARD..."

abricate --db card "$ASSEMBLY" > "$RESULTS/${SAMPLE}_wgs_abricate_card.tsv"

if [ $? -ne 0 ]; then
    echo "ABRicate CARD failed."
    exit 1
fi

echo "Step 8: Running CARD-RGI..."

if [ -x /home/pritam/miniforge3/envs/rgi_env/bin/rgi ]; then
    /home/pritam/miniforge3/envs/rgi_env/bin/rgi main \
    -i "$ASSEMBLY" \
    -o "$RESULTS/${SAMPLE}_wgs_rgi" \
    -t contig \
    -a DIAMOND \
    --clean \
    --local

    if [ $? -ne 0 ]; then
        echo "CARD-RGI failed, but continuing pipeline."
        echo -e "Status	Message" > "$RESULTS/${SAMPLE}_wgs_rgi.txt"
        echo -e "Skipped	CARD-RGI failed during execution" >> "$RESULTS/${SAMPLE}_wgs_rgi.txt"
    fi
else
    echo "CARD-RGI skipped because rgi command is not installed."
    echo -e "Status	Message" > "$RESULTS/${SAMPLE}_wgs_rgi.txt"
    echo -e "Skipped	CARD-RGI is not installed in the current environment" >> "$RESULTS/${SAMPLE}_wgs_rgi.txt"
fi

echo "WGS AMR pipeline completed successfully."
echo "AMRFinderPlus result:"
echo "$RESULTS/${SAMPLE}_wgs_amrfinder.tsv"
echo "ABRicate ResFinder result:"
echo "$RESULTS/${SAMPLE}_wgs_abricate_resfinder.tsv"
echo "ABRicate CARD result:"
echo "$RESULTS/${SAMPLE}_wgs_abricate_card.tsv"
echo "CARD-RGI result:"
echo "$RESULTS/${SAMPLE}_wgs_rgi.txt"
