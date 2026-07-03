import streamlit as st
import pandas as pd
import matplotlib.pyplot as plt
import subprocess
from pathlib import Path

st.set_page_config(
    page_title="AMR Genome Intelligence App",
    page_icon="🧬",
    layout="wide"
)

BASE = Path("/app")
if not BASE.exists():
    BASE = Path.home() / "AMR_App"

INPUT = BASE / "input"
RESULTS = BASE / "results"
WGS_READS = BASE / "wgs_reads"
SCRIPTS = BASE / "scripts"

INPUT.mkdir(parents=True, exist_ok=True)
RESULTS.mkdir(parents=True, exist_ok=True)
WGS_READS.mkdir(parents=True, exist_ok=True)

st.title("🧬 AMR Genome Intelligence App")

st.markdown(
    """
    This application detects antimicrobial resistance genes from bacterial genome data using:

    - **AMRFinderPlus**
    - **ABRicate ResFinder**
    - **ABRicate CARD**
    - **CARD-RGI**

    Supported input modes:

    - Genome FASTA upload
    - NCBI genome accession
    - WGS paired FASTQ reads
    """
)

mode = st.sidebar.radio(
    "Select input type",
    [
        "Upload genome FASTA",
        "NCBI genome accession",
        "WGS paired FASTQ reads"
    ]
)


def run_command(command):
    process = subprocess.run(
        command,
        shell=True,
        capture_output=True,
        text=True
    )
    return process


def load_tsv(path):
    try:
        return pd.read_csv(path, sep="\t")
    except Exception:
        return None


def show_result_table(title, path):
    st.subheader(title)

    if not path.exists():
        st.warning(f"Result file not found: {path}")
        return

    df = load_tsv(path)

    if df is None:
        st.error(f"Could not read result file: {path}")
        return

    st.write(f"Result file: `{path}`")
    st.write(f"Number of detected rows: **{len(df)}**")

    if len(df) == 0:
        st.info("No AMR gene was detected by this method.")
        return

    st.dataframe(df, width="stretch")

    csv_data = df.to_csv(index=False).encode("utf-8")
    st.download_button(
        label=f"Download {title} CSV",
        data=csv_data,
        file_name=path.name.replace(".tsv", ".csv").replace(".txt", ".csv"),
        mime="text/csv"
    )

    excel_path = path.with_suffix(".xlsx")
    df.to_excel(excel_path, index=False)

    with open(excel_path, "rb") as f:
        st.download_button(
            label=f"Download {title} Excel",
            data=f,
            file_name=excel_path.name,
            mime="application/vnd.openxmlformats-officedocument.spreadsheetml.sheet"
        )


def count_rows(path):
    if not path.exists():
        return None

    df = load_tsv(path)

    if df is None:
        return None

    return len(df)


def show_summary(amrfinder_path, resfinder_path, card_path, rgi_path):
    st.subheader("Comparative AMR Detection Summary")

    summary = []

    methods = [
        ("AMRFinderPlus", amrfinder_path),
        ("ABRicate ResFinder", resfinder_path),
        ("ABRicate CARD", card_path),
        ("CARD-RGI", rgi_path)
    ]

    for method, path in methods:
        row_count = count_rows(path)
        if row_count is not None:
            summary.append(
                {
                    "Method": method,
                    "Detected AMR rows": row_count
                }
            )

    if not summary:
        st.warning("No comparative summary available.")
        return

    summary_df = pd.DataFrame(summary)

    st.markdown("### Comparative table")
    st.dataframe(summary_df, width="stretch")

    st.markdown("### Bar chart: AMR hits detected by each method")
    bar_df = summary_df.set_index("Method")
    st.bar_chart(bar_df)

    positive_df = summary_df[summary_df["Detected AMR rows"] > 0]

    if len(positive_df) > 0:
        st.markdown("### Pie chart: Relative share of AMR hits by method")

        fig, ax = plt.subplots()
        ax.pie(
            positive_df["Detected AMR rows"],
            labels=positive_df["Method"],
            autopct="%1.1f%%",
            startangle=90
        )
        ax.axis("equal")
        st.pyplot(fig)

        st.caption(
            "Note: These are method-wise detected rows, not necessarily unique AMR genes. "
            "The same gene may be detected by more than one database/tool."
        )
    else:
        st.info("No positive AMR hits were available for pie chart visualization.")


if mode == "Upload genome FASTA":
    st.header("Upload genome FASTA")

    uploaded_file = st.file_uploader(
        "Upload bacterial genome FASTA file",
        type=["fna", "fa", "fasta"]
    )

    if uploaded_file is not None:
        input_path = INPUT / uploaded_file.name

        with open(input_path, "wb") as f:
            f.write(uploaded_file.getbuffer())

        sample = Path(uploaded_file.name).stem

        st.success(f"Uploaded file saved as: {input_path}")

        if st.button("Run AMR analysis"):
            command = f"bash {SCRIPTS / 'run_fasta_amr.sh'} {input_path} {sample}"

            with st.spinner("Running FASTA AMR pipeline..."):
                result = run_command(command)

            if result.returncode == 0:
                st.success("Pipeline completed successfully.")

                with st.expander("Pipeline log"):
                    st.text(result.stdout)

                amrfinder_path = RESULTS / f"{sample}_amrfinder.tsv"
                resfinder_path = RESULTS / f"{sample}_abricate_resfinder.tsv"
                card_path = RESULTS / f"{sample}_abricate_card.tsv"
                rgi_path = RESULTS / f"{sample}_rgi.txt"

                show_summary(amrfinder_path, resfinder_path, card_path, rgi_path)

                show_result_table("AMRFinderPlus result", amrfinder_path)
                show_result_table("ABRicate ResFinder result", resfinder_path)
                show_result_table("ABRicate CARD result", card_path)
                show_result_table("CARD-RGI result", rgi_path)

            else:
                st.error("Pipeline failed.")
                st.text(result.stdout)
                st.text(result.stderr)


elif mode == "NCBI genome accession":
    st.header("NCBI genome accession")

    accession = st.text_input(
        "Enter NCBI genome accession",
        value="GCA_041080895.1"
    )

    if st.button("Download and run AMR analysis"):
        command = f"bash {SCRIPTS / 'run_accession_amr.sh'} {accession}"

        with st.spinner("Downloading genome and running AMR pipeline..."):
            result = run_command(command)

        if result.returncode == 0:
            st.success("Pipeline completed successfully.")

            with st.expander("Pipeline log"):
                st.text(result.stdout)

            amrfinder_path = RESULTS / f"{accession}_amrfinder.tsv"
            resfinder_path = RESULTS / f"{accession}_abricate_resfinder.tsv"
            card_path = RESULTS / f"{accession}_abricate_card.tsv"
            rgi_path = RESULTS / f"{accession}_rgi.txt"

            show_summary(amrfinder_path, resfinder_path, card_path, rgi_path)

            show_result_table("AMRFinderPlus result", amrfinder_path)
            show_result_table("ABRicate ResFinder result", resfinder_path)
            show_result_table("ABRicate CARD result", card_path)
            show_result_table("CARD-RGI result", rgi_path)

        else:
            st.error("Pipeline failed.")
            st.text(result.stdout)
            st.text(result.stderr)


elif mode == "WGS paired FASTQ reads":
    st.header("WGS paired FASTQ reads")

    r1_file = st.file_uploader(
        "Upload R1 FASTQ file",
        type=["fastq", "fq", "gz"],
        key="r1"
    )

    r2_file = st.file_uploader(
        "Upload R2 FASTQ file",
        type=["fastq", "fq", "gz"],
        key="r2"
    )

    sample = st.text_input("Sample name", value="sample_wgs")

    if r1_file is not None and r2_file is not None:
        r1_path = WGS_READS / r1_file.name
        r2_path = WGS_READS / r2_file.name

        with open(r1_path, "wb") as f:
            f.write(r1_file.getbuffer())

        with open(r2_path, "wb") as f:
            f.write(r2_file.getbuffer())

        st.success(f"R1 saved as: {r1_path}")
        st.success(f"R2 saved as: {r2_path}")

        if st.button("Run WGS AMR analysis"):
            command = f"bash {SCRIPTS / 'run_wgs_amr.sh'} {r1_file.name} {r2_file.name} {sample}"

            with st.spinner("Running WGS AMR pipeline. This may take time..."):
                result = run_command(command)

            if result.returncode == 0:
                st.success("Pipeline completed successfully.")

                with st.expander("Pipeline log"):
                    st.text(result.stdout)

                amrfinder_path = RESULTS / f"{sample}_wgs_amrfinder.tsv"
                resfinder_path = RESULTS / f"{sample}_wgs_abricate_resfinder.tsv"
                card_path = RESULTS / f"{sample}_wgs_abricate_card.tsv"
                rgi_path = RESULTS / f"{sample}_wgs_rgi.txt"

                show_summary(amrfinder_path, resfinder_path, card_path, rgi_path)

                show_result_table("AMRFinderPlus result", amrfinder_path)
                show_result_table("ABRicate ResFinder result", resfinder_path)
                show_result_table("ABRicate CARD result", card_path)
                show_result_table("CARD-RGI result", rgi_path)

            else:
                st.error("Pipeline failed.")
                st.text(result.stdout)
                st.text(result.stderr)
