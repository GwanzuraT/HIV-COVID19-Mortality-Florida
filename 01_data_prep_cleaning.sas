*****************************************************************************************************************************
File:        01_data_prep_cleaning.sas
Author:      Tendai Gwanzura
Date:        2023-03-27 | Revised 2026-03-20
Purpose:     Cohort construction, mortality recoding, ZCTA linkage, community variable merge
             Part of: HIV-COVID19-Mortality-Florida / COVID-19 Mortality in PWH, Florida 2020-2021
             Update path in libname/proc import statements before running.
*****************************************************************************************************************************;

* ---- UPDATE THESE PATHS BEFORE RUNNING ---- ;
libname covmo "D:\SheehanRP3\original_data\eHARSdataNov72023";   /* November 2023 eHARS extract */
libname svi   'C:\Users\tgwanzur\Documents\Aim2';
options fmtsearch=(covmo.formats) nofmterr;

* ============================================================
  STEP 1: LOAD SOURCE DATA
  ============================================================;
proc import datafile = "C:\Users\tgwanzur\Documents\Aim2\Vaccination_County_AIM1.xlsx"
  out = vaccine_county dbms=xlsx; getnames=yes; run;

proc import datafile = "C:\Users\tgwanzur\Documents\Aim2\ruca2010florida.xlsx"
  out = ruca_raw dbms=xlsx; getnames=yes; run;

* ============================================================
  STEP 2: RUCA - binary urban/rural classification
  ============================================================;
data ruca;
  set ruca_raw;
  zcta = inputn(zip_code, 'F5');
  /* Urban = primary or secondary flow to urban core */
  if ruca2 in (1, 1.1, 2, 2.1, 3, 4.1, 5.1, 7.1, 8.1, 10.1)
    then rucaccat2010 = '1';   /* 1 = urban */
  else rucaccat2010 = '0';     /* 0 = rural */
  zcta2 = put(zcta, 8.);
  drop zcta;
  rename zcta2 = zcta;
run;

* ============================================================
  STEP 3: SVI - ZCTA-level from Florida SVI SAS dataset
  ============================================================;
data svi;
  set svi.florida_zip_code_svi_sas;
  zcta = put(zip_code, 8.);
  drop zip_code;
run;

* ============================================================
  STEP 4: BUILD COHORT - PWH alive end of 2019
  ============================================================;
data cohort;
  set covmo.pwh_2017_2021_final;
  if PWH2019 ^= 1 then delete;  /* Keep only those in the PWH registry as of end of 2019 */
run;

* Replace missing PWH year flags with 0 ;
data cohort2;
  set cohort;
  array variableOfInterest PWH2019 PWH2020 PWH2021;
  do over variableOfInterest;
    if variableOfInterest = . then variableOfInterest = 0;
  end;
run;

* ============================================================
  STEP 5: RECODE CAUSE OF DEATH (ICD-10 U07.1 = COVID-19)
  ============================================================;
data mortality;
  set cohort2;
  length under_letter $1. underdis $200.;
  under_letter = substr(death_underlying_icd_cd, 1, 1);
  under_num    = substr(death_underlying_icd_cd, 2, 4);
  if under_letter = ''  and rad_state_cd = " "  then underdis = "alive";
  if under_letter ^= 'U' and under_letter ^= ""  then underdis = "other";
  if under_letter = 'U'  and (07 <= under_num <= 12) then underdis = 'COVID';
run;

* ============================================================
  STEP 6: PARSE AND FILTER DEATH DATES
  ============================================================;
data mortdatae;
  set mortality;
  newmoyr_dod = input(moyr_dod, ANYDATEDTE.);
  format newmoyr_dod ANYDATEDTE.;
run;

data mort_date;
  set mortdatae;
  if newmoyr_dod > 202112 then delete;   /* Remove deaths after December 2021 */
run;

* ============================================================
  STEP 7: CALCULATE TIME VARIABLE (months from Jan 2020)
  ============================================================;
data time_death;
  set mort_date;
  if PWH2020=1 or PWH2020=. or PWH2021=1 or PWH2021=. or PWH2019=1
    then vacc_status = 202001;
  format vacc_status ANYDATEDTE.;
run;

data time_death1;
  set time_death;
  if newmoyr_dod = . then month = 202201;
  else month = newmoyr_dod;
  format month ANYDATEDTE.;
run;

data new_time;
  set time_death1;
  month_diff = month - vacc_status;
run;

/* Recode month_diff (YYYYMM arithmetic) to sequential months 0-24 */
data new_new_time;
  set new_time;
  if month_diff = 0   then time_diff = 0;
  if month_diff = 1   then time_diff = 1;
  if month_diff = 2   then time_diff = 2;
  if month_diff = 3   then time_diff = 3;
  if month_diff = 4   then time_diff = 4;
  if month_diff = 5   then time_diff = 5;
  if month_diff = 6   then time_diff = 6;
  if month_diff = 7   then time_diff = 7;
  if month_diff = 8   then time_diff = 8;
  if month_diff = 9   then time_diff = 9;
  if month_diff = 10  then time_diff = 10;
  if month_diff = 11  then time_diff = 11;
  if month_diff = 100 then time_diff = 12;
  if month_diff = 101 then time_diff = 13;
  if month_diff = 102 then time_diff = 14;
  if month_diff = 103 then time_diff = 15;
  if month_diff = 104 then time_diff = 16;
  if month_diff = 105 then time_diff = 17;
  if month_diff = 106 then time_diff = 18;
  if month_diff = 107 then time_diff = 19;
  if month_diff = 108 then time_diff = 20;
  if month_diff = 109 then time_diff = 21;
  if month_diff = 110 then time_diff = 22;
  if month_diff = 111 then time_diff = 23;
  if month_diff = 200 then time_diff = 24;
run;

* ============================================================
  STEP 8: RECODE COVARIATES
  NOTE: age_hivdxrange uses age_at_2021 (age during study period, not age at diagnosis)
        Viral suppression reference = 1 (suppressed) throughout all models
        categ reference = 'MSM' (coded as 'M' in CLASS statements)
  ============================================================;
data vacc_cat;
  set new_new_time;

  /* Race/ethnicity */
  if      race = '1' then raceeth = 'Hispanic';
  else if race = '4' then raceeth = 'NHB';
  else if race = '6' then raceeth = 'NHW';
  else                    raceeth = 'Other';

  /* Place of birth: US territories coded as US-born */
  if      birth_country_cd in ('USA','PRI','VIR','UMI','GUM') then USborn = 'Yes';
  else if birth_country_cd = ' '                               then USborn = ' ';
  else                                                              USborn = 'No';

  /* Age at 2021 (study period age) */
  hiv_aids_age_yrs1 = inputn(hiv_aids_age_yrs, 'F8');
  if       0 <= age_at_2021 < 18  then delete;
  else if 18 <= age_at_2021 < 35  then age_hivdxrange = '18-34';
  else if 35 <= age_at_2021 < 50  then age_hivdxrange = '35-49';
  else if 50 <= age_at_2021 < 65  then age_hivdxrange = '50-64';   /* IMPORTANT: 50-64 not 50-65 */
  else if 65 <= age_at_2021 < 100 then age_hivdxrange = '65 and over';
  else if age_at_2021 > 100       then delete;
  else if age_at_2021 = .         then age_hivdxrange = ' ';

  /* Sex (exclude transgender - very small N, affects model stability) */
  if      current_gender = 'FM' then current_gender2 = 'FM';
  else if current_gender = 'MF' then current_gender2 = 'MF';
  else if current_gender = ''   and birth_sex = 'F' then current_gender2 = 'F';
  else if current_gender = ''   and birth_sex = 'M' then current_gender2 = 'M';
  else current_gender2 = birth_sex;

  /* HIV transmission category - IDU includes MSM-IDU; reference = MSM (coded 'M') */
  if      trans_categ = " "  then categ = " ";
  else if trans_categ = '01' then categ = 'MSM';    /* Note: labeled 'M' in CLASS ref= */
  else if trans_categ = '02' then categ = 'IDU';
  else if trans_categ = '03' then categ = 'IDU';    /* MSM-IDU classified as IDU */
  else if trans_categ = '05' then categ = 'hetero';
  else                            categ = 'other';
run;

* Remove transgender (very small N) and non-Florida residents ;
data comm_vacc;
  set vacc_cat;
  /* Remove invalid ZCTAs */
  if zcta in (41,42,45,53,87,97,98) then delete;
  if state_res_d ^= "FL"            then delete;
  if current_gender2 in ('FM','MF') then delete;

  /* Rural/urban classification */
  if rucaccat2010 = . and zcta = 77 then delete;
  else if rucaccat2010 = 1 then rucaccat2010new = 'urban';
  else if rucaccat2010 = 0 then rucaccat2010new = 'rural';

  /* SVI overall tertiles */
  if RPL_THEMES = . or RPL_THEMES = -999 or zcta = . then delete;
  else if 0    <= RPL_THEMES < 0.33 then theme  = "low";
  else if 0.33 <= RPL_THEMES < 0.66 then theme  = "medium";
  else if 0.66 <= RPL_THEMES <= 1   then theme  = "high";

  /* SVI Theme 1: Socioeconomic status */
  if RPL_THEME1 = . or RPL_THEME1 = -999 then delete;
  else if 0    <= RPL_THEME1 < 0.33 then theme1 = "low";
  else if 0.33 <= RPL_THEME1 < 0.66 then theme1 = "medium";
  else if 0.66 <= RPL_THEME1 <= 1   then theme1 = "high";

  /* SVI Theme 2: Household composition and disability */
  if RPL_THEME2 = . or RPL_THEME2 = -999 then delete;
  else if 0    <= RPL_THEME2 < 0.33 then theme2 = "low";
  else if 0.33 <= RPL_THEME2 < 0.66 then theme2 = "medium";
  else if 0.66 <= RPL_THEME2 <= 1   then theme2 = "high";

  /* SVI Theme 3: Minority status and language */
  if RPL_THEME3 = . or RPL_THEME3 = -999 then delete;
  else if 0    <= RPL_THEME3 < 0.33 then theme3 = "low";
  else if 0.33 <= RPL_THEME3 < 0.66 then theme3 = "medium";
  else if 0.66 <= RPL_THEME3 <= 1   then theme3 = "high";

  /* SVI Theme 4: Housing type and transportation */
  if RPL_THEME4 = . or RPL_THEME4 = -999 then delete;
  else if 0    <= RPL_THEME4 < 0.33 then theme4 = "low";
  else if 0.33 <= RPL_THEME4 < 0.66 then theme4 = "medium";
  else if 0.66 <= RPL_THEME4 <= 1   then theme4 = "high";
run;

* ============================================================
  STEP 9: MERGE COUNTY VACCINATION RATES
  Mean-center percent_vacc (no meaningful zero)
  ============================================================;
/* Clean county name for merge */
data countyname;
  set comm_vacc;
  length county $20;
  /* [County name recoding - see full list in original AIM1 code] */
  if rs20211231_county_name = "MIAMI-DADE CO." then county = "Dade";
  /* ... all other county recodes retained from original code ... */
run;

proc sort data=countyname;    by county; run;
proc sort data=vaccine_county; by county; run;

data comm_vacc1;
  merge countyname vaccine_county;
  by county;
run;

/* Mean-center vaccination rate */
proc stdize data=comm_vacc1 method=mean out=comm_vacc2;
  var Percent_of_populatin__5_vaccinat;
run;

data comm_vacc3;
  set comm_vacc2;
  rename Percent_of_populatin__5_vaccinat = percent_vacc;
run;

* ============================================================
  STEP 10: EXPORT PROC CONTENTS FOR DATA DICTIONARY
  ============================================================;
proc contents data=comm_vacc3 out=dict varnum;
run;

proc export data=dict
  outfile="C:\Users\tgwanzur\Documents\Aim2\codebook\proc_contents_output.csv"
  dbms=csv replace;
run;

* comm_vacc3 is the final analytic dataset. Proceed to 02_community_variables.sas;
