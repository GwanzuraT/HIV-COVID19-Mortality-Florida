# HIV-COVID19-Mortality-Florida

## COVID-19 Mortality Risk Among People With HIV in Florida Before and After the Introduction of COVID-19 Vaccines: A Population-Based Study

**Authors:** Tendai Gwanzura, Mary Jo Trepka, Tan Li, Levente Juhasz, Giselle A. Barreto, Shelbie Burchfield, Diana M. Sheehan  
**Affiliation:** Florida International University, Robert Stempel College of Public Health and Social Work  
**Journal:** PLOS ONE (under review — Manuscript ID: PONE-D-26-01190)  
**Corresponding author:** Tendai Gwanzura · tgwanzur@fiu.edu

---

## Study Summary

This retrospective cohort study examined COVID-19 mortality risk among 120,201 people with HIV (PWH) in Florida from March 2020 through December 2021, comparing the period before vaccine availability (March 1, 2020–April 30, 2021) with the period during vaccine availability (May 1, 2021–December 31, 2021). Using Fine–Gray competing-risks subdistribution hazard models, we assessed the role of individual-level factors (age, sex, race/ethnicity, transmission category, viral suppression, place of birth) and community-level factors (Social Vulnerability Index, rural-urban status, county vaccination rates) in shaping COVID-19 mortality differences across subgroups.

**Key findings:**
- Overall mortality rates were similar before and during vaccine availability
- Racial/ethnic disparities persisted for Non-Hispanic Black PWH but attenuated for Hispanic PWH
- Virally unsuppressed PWH had significantly higher hazard during (but not before) vaccine availability
- Higher socioeconomic vulnerability (SVI Theme 1) was associated with elevated mortality during vaccine availability

**Data source:** Florida Department of Health enhanced HIV/AIDS Reporting System (eHARS), November 2023 extract

---

## Repository Contents

### `/code/`
| File | Description |
|------|-------------|
| `01_data_prep_cleaning.sas` | Cohort construction, exclusion criteria, mortality recoding, ZCTA linkage, community variable merge |
| `02_community_variables.sas` | ZCTA-level SVI construction from 2020 ACS (replicating CDC four-theme methodology); RUCA code linkage; county vaccination rate merge and mean-centering |
| `03_before_after_groups.sas` | Creation of before-vaccine and during-vaccine analytic datasets; competing-risk censoring setup (censor1: 0=alive, 1=COVID death, 2=non-COVID death) |
| `04_descriptive_table1.sas` | Weighted person-time calculation, COVID-19 mortality rates by subgroup (Table 1) using mi_weight |
| `05_finegray_primary_6wk.sas` | Primary Fine–Gray models — before and during vaccine availability (6-week window, May 1, 2021 start); Model 1 (individual factors) and Final Model (+ community factors); Table 2 |
| `06_finegray_svi_themes_table3.sas` | Fine–Gray models by each SVI theme (Themes 1–4) for before and during periods; Table 3 |
| `07_sensitivity_4wk_8wk.sas` | Sensitivity analyses: 4-week (April 1, 2021) and 8-week (June 1, 2021) vaccine-period definitions; Tables 4–5 |
| `08_univariate_shr_table1b.sas` | Univariate (crude) subdistribution hazard ratios for all covariates — both periods; Supporting Table 1b |
| `09_age65_verification.sas` | Age ≥65 event count verification and parameter export for both Model 1 and Final Model |
| `10_cif_figures_matplotlib.py` | Python script (matplotlib) to generate cumulative incidence function (CIF) figures (Figures 1–3): race/ethnicity, viral suppression/SVI/rurality, age/sex/transmission |
| `AIM1_revision_full.sas` | Combined revision code integrating March at-risk start, sensitivity analyses, univariate sHR, and age-65 verification (addresses PLOS ONE reviewer comments) |

### `/codebook/`
| File | Description |
|------|-------------|
| `variable_codebook.csv` | All analytic variables: name, definition, source, type, coding, reference category for models, notes |
| `proc_contents_output.csv` | SAS PROC CONTENTS output from the final analytic dataset (comm_vacc3); variable names, labels, formats, lengths |
| `inclusion_exclusion_flowchart.md` | Step-by-step cohort construction with N at each step (127,258 → 120,201) |

### `/community_data/`
| File | Description |
|------|-------------|
| `svi_zcta_florida_2020.csv` | Derived ZCTA-level SVI scores for Florida (overall + 4 themes), calculated from 2020 ACS 5-year estimates using CDC methodology. No individual-level data. |
| `ruca_florida_zcta.csv` | Rural-Urban Commuting Area (RUCA) codes by ZCTA for Florida; binary urban/rural classification |
| `county_vax_rates_dec2021.csv` | County-level COVID-19 vaccination rates (% population ≥5 vaccinated by Dec 31, 2021); mean-centered for modeling |
| `acs_variables_used.md` | ACS table and variable IDs used to construct each SVI theme; methodology notes |

### `/outputs/`
| File | Description |
|------|-------------|
| `table1_mortality_rates_by_subgroup.csv` | Aggregate Table 1 data — COVID-19 deaths, person-time (months), and rates per 100,000 person-months by subgroup and period. No individual-level data. |
| `table4_sensitivity_4wk_summary.csv` | Sensitivity analysis (4-week) key HR estimates by covariate |
| `table5_sensitivity_8wk_summary.csv` | Sensitivity analysis (8-week) key HR estimates by covariate |
| `univariate_shr_table1b.csv` | Crude subdistribution hazard ratios for all covariates (Supporting Table 1b) |

---

## How to Run the Code

### Prerequisites
- **SAS 9.4** (SAS Institute, Cary, NC) — all `.sas` files
- **Python ≥ 3.8** — figure generation (`10_cif_figures_matplotlib.py`)
  - Required packages: `matplotlib`, `pandas`, `numpy`
  - Install: `pip install matplotlib pandas numpy`

### Data Access
The individual-level eHARS surveillance data **cannot be shared publicly** due to legal and ethical restrictions under Florida law and the FDOH Data Use Agreement. To request access:

1. Email a brief project summary to: **DCHPDataRequest@FLHealth.gov**
2. If approved, the FDOH Bureau of Epidemiology (BOE) will initiate a Data Use Agreement (DUA)
3. A Research Collaboration and Project Framework (RCPF) approval is required before applying for FDOH IRB review
4. Full guidance: https://www.floridahealth.gov/diseases-and-conditions/aids/Surveillance/index.html

The community-level datasets in `/community_data/` are derived from publicly available sources and can be used independently.

### Running Order
```
1. 01_data_prep_cleaning.sas       ← requires eHARS data access
2. 02_community_variables.sas      ← can run with public ACS/RUCA data
3. 03_before_after_groups.sas
4. 04_descriptive_table1.sas       → outputs/table1_mortality_rates_by_subgroup.csv
5. 05_finegray_primary_6wk.sas     → Table 2
6. 06_finegray_svi_themes_table3.sas → Table 3
7. 07_sensitivity_4wk_8wk.sas      → Tables 4-5
8. 08_univariate_shr_table1b.sas   → Supporting Table 1b
9. 09_age65_verification.sas       → verification output
10. 10_cif_figures_matplotlib.py   → Figures 1-3
```

**Update the `libname` and file paths** at the top of each SAS script to match your local environment before running.

---

## Key Variable Notes

| Variable | Coding | Reference category in models |
|----------|--------|-------------------------------|
| `SuppressedVL2020` | 1 = suppressed (<200 copies/mL); 0 = unsuppressed | **1 (suppressed)** |
| `SuppressedVL2021` | 1 = suppressed (<200 copies/mL); 0 = unsuppressed | **1 (suppressed)** |
| `censor1` | 0 = alive/censored; 1 = COVID-19 death; 2 = non-COVID death | — |
| `rucaccat2010new` | 'urban' / 'rural' | **'urban'** |
| `theme` | 'low' / 'medium' / 'high' (SVI overall tertiles: 0–0.333 / 0.334–0.666 / 0.667–1) | **'low'** |
| `categ` | 'MSM' / 'IDU' / 'hetero' / 'other' | **'MSM'** (coded as 'M' in CLASS statement) |
| `age_hivdxrange` | '18-34' / '35-49' / '50-64' / '65 and over' | **'18-34'** |
| `raceeth` | 'Hispanic' / 'NHB' / 'NHW' / 'Other' | **'NHW'** |

> **Important:** Models use `weight mi_weight` throughout. Event counts in Tables 2–5 are imputation-weighted and will differ from unweighted descriptive counts in Table 1.

---

## Vaccine Period Definitions

| Definition | Before period | During (vaccine) period |
|---|---|---|
| Primary 6-week (Table 2) | March 1, 2020 – April 30, 2021 | May 1, 2021 – December 31, 2021 |
| Sensitivity 4-week (Table 4) | March 1, 2020 – March 31, 2021 | April 1, 2021 – December 31, 2021 |
| Sensitivity 8-week (Table 5) | March 1, 2020 – May 31, 2021 | June 1, 2021 – December 31, 2021 |

At-risk time origin = March 1, 2020. Individuals with competing (non-COVID) deaths in January–February 2020 were excluded from the risk set.

---

## Citation

> Gwanzura T, Trepka MJ, Li T, Juhasz L, Barreto GA, Burchfield S, Sheehan DM. COVID-19 Mortality Risk Among People With HIV in Florida Before and After the Introduction of COVID-19 Vaccines: A Population-Based Study. *PLOS ONE* (under review, 2026). Manuscript ID: PONE-D-26-01190.

*DOI will be added upon publication.*

---

## Funding

Research reported in this manuscript was supported by the National Institute on Minority Health and Health Disparities of the National Institutes of Health (NIH). T.G. received support under Award Number F31MD018550 and D.S. received support under Award Number U54MD012393. There was no additional external funding received for this study. The funders had no role in study design, data collection and analysis, decision to publish, or preparation of the manuscript.

---

## License

Code and derived community data: [MIT License](LICENSE.txt)  
The eHARS individual-level data are property of the Florida Department of Health and are not included in this repository.
