"""
File:     10_cif_figures_matplotlib.py
Author:   Tendai Gwanzura
Revised:  2026-03-20
Purpose:  Generate Figures 1-3 (Cumulative Incidence Function plots) for
          COVID-19 Mortality in PWH, Florida 2020-2021 (PLOS ONE PONE-D-26-01190)

Requires: CIF estimates exported from SAS PROC LIFETEST or %CIF macro as CSV.
          Each CSV should contain columns: time, cif, lower_cl, upper_cl, group, period
          where period = "Before" or "During" and group = subgroup label.

Input files (from SAS CIF macro output):
  - cif_race_before.csv / cif_race_during.csv          -> Figure 1
  - cif_vl_before.csv / cif_vl_during.csv              -> Figure 2 panel A
  - cif_rural_before.csv / cif_rural_during.csv        -> Figure 2 panel B
  - cif_svi_before.csv / cif_svi_during.csv            -> Figure 2 panel C
  - cif_age_before.csv / cif_age_during.csv            -> Figure 3 panel A
  - cif_sex_before.csv / cif_sex_during.csv            -> Figure 3 panel B
  - cif_usborn_before.csv / cif_usborn_during.csv      -> Figure 3 panel C
  - cif_categ_before.csv / cif_categ_during.csv        -> Figure 3 panel D

Output: Figure1_race.tiff, Figure2_structural.tiff, Figure3_individual.tiff
        All at >= 300 dpi (PLOS ONE requirement)

Install: pip install matplotlib pandas numpy
"""

import pandas as pd
import numpy as np
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
from pathlib import Path

# -----------------------------------------------------------------------
# Configuration
# -----------------------------------------------------------------------
INPUT_DIR  = Path("./cif_data")   # update to path of exported SAS CIF CSVs
OUTPUT_DIR = Path("./figures")
OUTPUT_DIR.mkdir(exist_ok=True)

DPI = 300   # PLOS ONE requires >= 300 dpi

# Colorblind-safe palette (Wong 2011 - 8 colors)
COLORS = {
    "NHW":       "#0072B2",   # blue
    "NHB":       "#D55E00",   # vermilion
    "Hispanic":  "#009E73",   # green
    "Other":     "#CC79A7",   # pink/purple
    "18-34":     "#0072B2",
    "35-49":     "#56B4E9",
    "50-64":     "#E69F00",
    "65+":       "#D55E00",
    "Suppressed":   "#0072B2",
    "Unsuppressed": "#D55E00",
    "Urban":     "#0072B2",
    "Rural":     "#D55E00",
    "Low SVI":   "#009E73",
    "Medium SVI":"#E69F00",
    "High SVI":  "#D55E00",
    "Male":      "#0072B2",
    "Female":    "#D55E00",
    "Yes":       "#0072B2",
    "No":        "#D55E00",
    "MSM":       "#0072B2",
    "IDU":       "#D55E00",
    "Heterosexual": "#009E73",
    "Other cat": "#CC79A7",
}

# Line style: solid = before vaccine; dashed = during vaccine
LINESTYLE = {"Before": "-", "During": "--"}

BEFORE_LABEL = "Before vaccine availability\n(March 2020\u2013April 2021)"
DURING_LABEL = "During vaccine availability\n(May 2021\u2013December 2021)"


def load_cif(filename):
    """Load CIF CSV; return DataFrame or empty if file missing."""
    path = INPUT_DIR / filename
    if not path.exists():
        print(f"  WARNING: {filename} not found. Skipping.")
        return pd.DataFrame()
    return pd.read_csv(path)


def plot_cif_panel(ax, before_df, during_df, groups, title,
                   xlabel="Months since March 2020",
                   ylabel="Cumulative incidence"):
    """Plot one CIF panel with before (solid) and during (dashed) lines."""
    if before_df.empty and during_df.empty:
        ax.set_visible(False)
        return

    for grp in groups:
        color = COLORS.get(grp, "#333333")

        for df, period in [(before_df, "Before"), (during_df, "During")]:
            if df.empty:
                continue
            sub = df[df["group"] == grp]
            if sub.empty:
                continue
            ls = LINESTYLE[period]
            ax.step(sub["time"], sub["cif"], where="post",
                    color=color, linestyle=ls, linewidth=1.5)
            # Confidence interval shading
            if "lower_cl" in sub.columns and "upper_cl" in sub.columns:
                ax.fill_between(sub["time"], sub["lower_cl"], sub["upper_cl"],
                                step="post", alpha=0.10, color=color)

    ax.set_title(title, fontsize=10, fontweight="bold")
    ax.set_xlabel(xlabel, fontsize=9)
    ax.set_ylabel(ylabel, fontsize=9)
    ax.tick_params(labelsize=8)
    ax.set_xlim(left=0)
    ax.set_ylim(bottom=0)
    ax.spines["top"].set_visible(False)
    ax.spines["right"].set_visible(False)

    # Period legend (line style)
    solid_line  = plt.Line2D([0], [0], color="gray", linestyle="-",  lw=1.5, label=BEFORE_LABEL)
    dashed_line = plt.Line2D([0], [0], color="gray", linestyle="--", lw=1.5, label=DURING_LABEL)

    # Group legend (color patches)
    group_patches = [mpatches.Patch(color=COLORS.get(g, "#333333"), label=g) for g in groups]

    first_legend  = ax.legend(handles=[solid_line, dashed_line],
                               fontsize=7, loc="upper left", framealpha=0.7)
    ax.add_artist(first_legend)
    ax.legend(handles=group_patches, fontsize=7, loc="lower right", framealpha=0.7)


# -----------------------------------------------------------------------
# FIGURE 1: Race/Ethnicity
# -----------------------------------------------------------------------
def make_figure1():
    print("Building Figure 1: Race/Ethnicity CIF...")
    race_b = load_cif("cif_race_before.csv")
    race_d = load_cif("cif_race_during.csv")

    fig, ax = plt.subplots(1, 1, figsize=(7, 5))
    groups = ["NHW", "NHB", "Hispanic", "Other"]
    plot_cif_panel(ax, race_b, race_d, groups,
                   title="Cumulative incidence of COVID-19 death by race/ethnicity")

    fig.suptitle(
        "Figure 1. Cumulative incidence of COVID-19 deaths among PWH\n"
        "by race/ethnicity before and during vaccine availability, Florida, 2020\u20132021.",
        fontsize=9, y=1.01
    )
    plt.tight_layout()
    out = OUTPUT_DIR / "Figure1_race_ethnicity.tiff"
    fig.savefig(out, dpi=DPI, bbox_inches="tight", format="tiff")
    print(f"  Saved: {out}")
    plt.close(fig)


# -----------------------------------------------------------------------
# FIGURE 2: Structural/community factors (3-panel)
# -----------------------------------------------------------------------
def make_figure2():
    print("Building Figure 2: Viral suppression, rurality, SVI...")
    vl_b    = load_cif("cif_vl_before.csv")
    vl_d    = load_cif("cif_vl_during.csv")
    rural_b = load_cif("cif_rural_before.csv")
    rural_d = load_cif("cif_rural_during.csv")
    svi_b   = load_cif("cif_svi_before.csv")
    svi_d   = load_cif("cif_svi_during.csv")

    fig, axes = plt.subplots(1, 3, figsize=(14, 5))

    plot_cif_panel(axes[0], vl_b, vl_d,
                   ["Suppressed", "Unsuppressed"],
                   title="A. Viral suppression status")
    plot_cif_panel(axes[1], rural_b, rural_d,
                   ["Urban", "Rural"],
                   title="B. Rural-urban residence")
    plot_cif_panel(axes[2], svi_b, svi_d,
                   ["Low SVI", "Medium SVI", "High SVI"],
                   title="C. Social Vulnerability Index (overall)")

    fig.suptitle(
        "Figure 2. Cumulative incidence of COVID-19 deaths among PWH by structural and community\n"
        "characteristics before and during COVID-19 vaccine availability, Florida, 2020\u20132021.",
        fontsize=9
    )
    plt.tight_layout()
    out = OUTPUT_DIR / "Figure2_structural_community.tiff"
    fig.savefig(out, dpi=DPI, bbox_inches="tight", format="tiff")
    print(f"  Saved: {out}")
    plt.close(fig)


# -----------------------------------------------------------------------
# FIGURE 3: Individual characteristics (4-panel)
# -----------------------------------------------------------------------
def make_figure3():
    print("Building Figure 3: Age, sex, US-born, transmission...")
    age_b   = load_cif("cif_age_before.csv")
    age_d   = load_cif("cif_age_during.csv")
    sex_b   = load_cif("cif_sex_before.csv")
    sex_d   = load_cif("cif_sex_during.csv")
    born_b  = load_cif("cif_usborn_before.csv")
    born_d  = load_cif("cif_usborn_during.csv")
    cat_b   = load_cif("cif_categ_before.csv")
    cat_d   = load_cif("cif_categ_during.csv")

    fig, axes = plt.subplots(2, 2, figsize=(12, 10))
    axes = axes.flatten()

    plot_cif_panel(axes[0], age_b, age_d,
                   ["18-34", "35-49", "50-64", "65+"],
                   title="A. Age group (years)")
    plot_cif_panel(axes[1], sex_b, sex_d,
                   ["Male", "Female"],
                   title="B. Birth sex")
    plot_cif_panel(axes[2], born_b, born_d,
                   ["Yes", "No"],
                   title="C. Born in US (Yes / No)")
    plot_cif_panel(axes[3], cat_b, cat_d,
                   ["MSM", "IDU", "Heterosexual", "Other cat"],
                   title="D. HIV transmission category")

    fig.suptitle(
        "Figure 3. Cumulative incidence of COVID-19 deaths among PWH by individual characteristics\n"
        "before and during COVID-19 vaccine availability, Florida, 2020\u20132021.\n"
        "Solid lines = before vaccine availability (March 1, 2020\u2013April 30, 2021);\n"
        "Dashed lines = during vaccine availability (May 1\u2013December 31, 2021).",
        fontsize=9
    )
    plt.tight_layout()
    out = OUTPUT_DIR / "Figure3_individual_characteristics.tiff"
    fig.savefig(out, dpi=DPI, bbox_inches="tight", format="tiff")
    print(f"  Saved: {out}")
    plt.close(fig)


# -----------------------------------------------------------------------
# Run all figures
# -----------------------------------------------------------------------
if __name__ == "__main__":
    print(f"Output directory: {OUTPUT_DIR.resolve()}")
    make_figure1()
    make_figure2()
    make_figure3()
    print("\nAll figures complete. Check /figures/ directory.")
    print("Verify each figure at >= 300 dpi before PLOS ONE submission.")
