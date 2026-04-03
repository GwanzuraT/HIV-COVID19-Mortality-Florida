*****************************************************************************************************************************
File:        05_finegray_primary_6wk.sas
Author:      Tendai Gwanzura
Date:        Revised 2026-03-20
Purpose:     Primary Fine-Gray subdistribution hazard models for Table 2
             Before (March 1, 2020 - April 30, 2021) and during (May 1, 2021 - Dec 31, 2021)
             vaccine availability. March at-risk start, mi_weight applied throughout.

CRITICAL CODING NOTES:
  - SuppressedVL2020 (ref="1") = suppressed is reference for BEFORE models
  - SuppressedVL2021 (ref="1") = suppressed is reference for DURING models
  - rucaccat2010new (ref='urban') = urban is reference throughout
  - categ (ref='MSM') -- NOTE: in original code categ ref='M', update if your values use 'MSM'
  - age_hivdxrange must have '50-64' not '50-65' -- check vacc_cat step in 01_data_prep
  - weight mi_weight applied to all PHREG models
  - Event counts in output (350 before / 291 during) are MI-weighted; Table 1 shows
    unweighted raw counts (328/275) -- add footnote to Table 2 explaining this
*****************************************************************************************************************************;

%let outpath = C:\Users\tgwanzur\Documents\Aim2;

* ============================================================
  PART 1: MARCH AT-RISK START ADJUSTMENT
  Exclude competing deaths Jan/Feb 2020; rebase time to March 2020
  ============================================================;
data comm_vacc3_march;
  set comm_vacc3;
  /* Exclude non-COVID deaths in Jan/Feb 2020 (before COVID present in FL) */
  if (underdis = "other" or underdis = " ") and
     newmoyr_dod in (202001, 202002) then delete;
  /* Shift time origin: month 0 = March 2020 */
  time_diff = max(0, time_diff - 2);
run;

proc sql;
  select count(*) as n_excluded
  from comm_vacc3
  where (underdis = "other" or underdis = " ")
    and newmoyr_dod in (202001, 202002);
quit;

* ============================================================
  PART 2: CREATE BEFORE / DURING DATASETS (6-week primary)
  Vaccine period start = May 1, 2021 (202105)
  Censoring: 0=alive, 1=COVID death, 2=non-COVID death (competing event)
  ============================================================;

/* BEFORE VACCINE GROUP */
data before_group_march;
  set comm_vacc3_march;
  if      underdis = "alive"                                          then censor1 = 0;
  else if underdis = "other" or underdis = " " or
          newmoyr_dod >= 202105                                       then censor1 = 2;
  else if underdis = "COVID" and newmoyr_dod < 202105                 then censor1 = 1;
run;

/* DURING VACCINE GROUP: remove those who had COVID/non-COVID death before May 2021 */
data nedeath_6wk_march;
  set comm_vacc3_march;
  if newmoyr_dod < 202105 and newmoyr_dod ^= . then delete;
run;

data after_group_march;
  set nedeath_6wk_march;
  if      underdis = "alive"                    then censor1 = 0;
  else if underdis = "other" or underdis = " "  then censor1 = 2;
  else if underdis = "COVID"                    then censor1 = 1;
run;

/* Verify event counts */
proc freq data=before_group_march; tables censor1; title "Before vaccine censoring distribution"; run;
proc freq data=after_group_march;  tables censor1; title "During vaccine censoring distribution"; run;

* ============================================================
  PART 3: TABLE 2 - PRIMARY 6-WEEK MODELS
  Model 1: individual-level factors only
  Final Model: + community-level factors (rucaccat2010new, theme, percent_vacc)
  ============================================================;

/* --- BEFORE VACCINE: Model 1 (individual factors) --- */
title "Table 2: Before vaccine - Model 1 (individual factors only)";
proc phreg data = before_group_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2020 (ref="1");          /* 1 = suppressed = reference */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2020
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates = t2_before_m1_pe
             Type3               = t2_before_m1_type3;
run;

/* --- BEFORE VACCINE: Final Model (+ community factors) --- */
title "Table 2: Before vaccine - Final Model (individual + community)";
proc phreg data = before_group_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new  (ref='urban')
        theme            (ref='low')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2020 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates = t2_before_final_pe
             Type3               = t2_before_final_type3;
run;

/* --- DURING VACCINE: Model 1 (individual factors) --- */
title "Table 2: During vaccine - Model 1 (individual factors only)";
proc phreg data = after_group_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2021 (ref="1");          /* 1 = suppressed = reference */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2021
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates = t2_during_m1_pe
             Type3               = t2_during_m1_type3;
run;

/* --- DURING VACCINE: Final Model (+ community factors) --- */
title "Table 2: During vaccine - Final Model (individual + community)";
proc phreg data = after_group_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new  (ref='urban')
        theme            (ref='low')
        SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates = t2_during_final_pe
             Type3               = t2_during_final_type3;
run;

* ============================================================
  PART 4: AGE >=65 VERIFICATION (addresses Reviewer 1 Comment 3)
  ============================================================;
title "Age >=65 verification: Model 1 - During vaccine";
proc print data=t2_during_m1_pe;
  where upcase(Parameter) contains "65";
run;

title "Age >=65 verification: Final Model - During vaccine";
proc print data=t2_during_final_pe;
  where upcase(Parameter) contains "65";
run;

title "COVID-19 death counts by age group - During vaccine";
proc freq data=after_group_march;
  tables age_hivdxrange*censor1 / nocol nocum nopercent;
  where censor1 in (0,1);
run;

* ============================================================
  PART 5: EXPORT TABLE 2 RESULTS TO CSV
  ============================================================;
proc export data=t2_before_m1_pe     outfile="&outpath.\t2_before_model1.csv"    dbms=csv replace; run;
proc export data=t2_before_final_pe  outfile="&outpath.\t2_before_final.csv"     dbms=csv replace; run;
proc export data=t2_during_m1_pe     outfile="&outpath.\t2_during_model1.csv"    dbms=csv replace; run;
proc export data=t2_during_final_pe  outfile="&outpath.\t2_during_final.csv"     dbms=csv replace; run;
proc export data=t2_before_m1_type3  outfile="&outpath.\t2_before_model1_type3.csv" dbms=csv replace; run;
proc export data=t2_before_final_type3 outfile="&outpath.\t2_before_final_type3.csv" dbms=csv replace; run;
proc export data=t2_during_m1_type3  outfile="&outpath.\t2_during_model1_type3.csv" dbms=csv replace; run;
proc export data=t2_during_final_type3 outfile="&outpath.\t2_during_final_type3.csv" dbms=csv replace; run;

/* NOTE: before_group_march and after_group_march are used by subsequent scripts:
   06_finegray_svi_themes_table3.sas
   07_sensitivity_4wk_8wk.sas
   08_univariate_shr_table1b.sas
   09_age65_verification.sas
   Keep them in the SAS work library or save to a libname. */
