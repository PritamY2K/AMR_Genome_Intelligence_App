# AMR Genome Intelligence App

A Streamlit-based GUI for antimicrobial resistance detection from bacterial genome data.

## Input modes

1. Genome FASTA upload
2. NCBI genome accession
3. WGS paired FASTQ reads

## AMR detection methods

1. AMRFinderPlus
2. ABRicate ResFinder
3. ABRicate CARD
4. CARD-RGI optional

## License and database notice

This repository contains only the GUI wrapper and pipeline scripts.

This repository does not redistribute third-party AMR databases. Users must install and use third-party tools and databases according to their own licenses and terms.

CARD/RGI use may be restricted for commercial purposes. Commercial users should check CARD/McMaster University licensing terms before use.

## Installation

Clone the repository:

    git clone https://github.com/YOUR_USERNAME/AMR_Genome_Intelligence_App.git
    cd AMR_Genome_Intelligence_App

Create the main environment:

    conda env create -f environment.yml
    conda activate amr_tools

Download/setup databases:

    amrfinder -u
    abricate --setupdb

Optional CARD-RGI environment:

    conda env create -f environment_rgi.yml
    conda activate rgi_env
    rgi auto_load --local

Run the app:

    conda activate amr_tools
    streamlit run app.py

Open in browser:

    http://localhost:8501

## Output

The app provides individual result tables, comparative summary, bar chart, pie chart, and CSV/Excel download options.

## Notes

Do not upload private genomes, FASTQ reads, patient data, unpublished data, databases, or result files to GitHub.

Results may differ among AMRFinderPlus, ResFinder, CARD, and CARD-RGI because each method uses different databases, thresholds, and algorithms.

The comparative charts show method-wise detected rows, not necessarily unique AMR genes.

## Citation

Please cite the relevant third-party tools and databases when using this app in publications: AMRFinderPlus, ABRicate, ResFinder, CARD/RGI.
