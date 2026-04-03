# Cohort Inclusion/Exclusion Flowchart
## HIV-COVID19-Mortality-Florida
## COVID-19 Mortality in PWH, Florida 2020–2021

```
Florida eHARS November 2023 extract (all years)
        |
        | Keep PWH2019 = 1 (alive, in HIV registry end of 2019)
        v
  N = 127,258  ← Starting cohort: PWH in Florida, alive end of 2019
        |
        | Exclude: age < 18 at study period start
        | (not eligible for vaccination at defined period start)
        |
        | Exclude: missing/unknown place of birth OR missing ZCTA
        | preventing US-/foreign-born classification
        | (n = 3,537 removed)
        |
        | Exclude among those who died:
        | - Died outside Florida
        | - Lacked valid ZCTA at time of death
        | - Including 3 COVID-19 deaths with no recorded ZCTA or state at death
        | (n = 2,682 removed)
        |
        | Exclude: no valid ZCTA (n = 803, 0.6%)
        | Exclude: age > 90 (n = 131, 0.1%) — data quality
        | (misclassified deceased individuals)
        |
        | Exclude: transgender (FM/MF) — very small N, model instability
        |
        | Exclude: non-Florida state of residence (state_res_d ^= "FL")
        |
        | Exclude: invalid ZCTA codes (41,42,45,53,87,97,98)
        |
        | Exclude: missing SVI (RPL_THEMES = . or -999)
        | Exclude: missing RUCA classification
        v
  N = 120,201  ← Final analytic cohort (94.5% of starting cohort)
        |
        +-----------------------------------------------+
        |                                               |
        v                                               v
  BEFORE VACCINE GROUP                       DURING VACCINE GROUP
  March 1, 2020 – April 30, 2021            May 1, 2021 – December 31, 2021
  N at risk = 118,845 (weighted)            N at risk = 116,323 (weighted)
        |                                               |
  COVID-19 deaths:  350 (weighted)          COVID-19 deaths:  291 (weighted)
  Non-COVID deaths: competing events         Non-COVID deaths: competing events
  (censor1=2)                                (censor1=2)
        |                                               |
  Unweighted raw:   328 COVID deaths        Unweighted raw:   275 COVID deaths
  (Table 1)                                 (Table 1)
```

## Notes

**Table 1 vs. Table 2 event counts:** Table 1 reports unweighted raw COVID-19 deaths (328 before / 275 during). Tables 2–5 report MI-weighted event counts (350 before / 291 during). The difference reflects multiple imputation weights (`mi_weight`) applied consistently in all Fine–Gray models. A footnote in Table 2 explains this distinction.

**ZCTA assignment priority:**
1. `rs20211231_zip_cd` — ZIP Code at end of 2021
2. `rs20191231_zip_cd` — ZIP Code at end of 2019 (if 2021 missing)
3. `rad_zip_cd` — ZIP Code at time of death
4. For PWH alive at end of 2021 with missing 2021 ZCTA: 2020 ZCTA used

**March at-risk start:** Individuals with non-COVID competing deaths in January–February 2020 are excluded from the risk set. For all others, time is rebased: `time_diff = max(0, time_diff - 2)`, where month 0 = March 2020.

**Data source:** Florida Department of Health eHARS, November 2023 extract. Death ascertainment via routine linkage to FDOH Vital Records, SSA Death Master File, and National Death Index (annual reconciliation cycle).
