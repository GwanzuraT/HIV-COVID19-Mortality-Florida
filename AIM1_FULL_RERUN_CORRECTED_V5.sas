*****************************************************************************************************************************
Author: Tendai Gwanzura
Date created: 2023-03-27
Date modified: 2026-04-02 (V5 — length and Unknown flag fixes)
Purpose: AIM1 analysis — COVID-19 mortality among PWH in Florida before and after vaccine availability

CHANGES IN V5 (April 2026):
  1. LENGTH statements added for all character covariates — prevents 'Unknown' truncation
     (V4 bug: categ length=1 stored 'U', theme length=3 stored 'Unk', etc.
      model_eligible flag checked 'Unknown' and never matched → everyone = model_eligible=1)
  2. age_hivdxrange expanded to length 12 — fixes '65 and over' truncating to '65 an'
  3. Defensive raceeth = 'Other' added for any blank race (1 person observed)
  4. rucaccat2010new Unknown assignment moved to comm_vacc where variable is created
  5. All prior V4 fixes retained:
     - birth_sex used directly for current_gender2
     - USborn = 'Unknown' for missing (now stores correctly with length 7)
     - Age label '50-64' (was '50-65')
     - County cascade: full else-if across 2021→2020→2019, stray else removed
     - Table 1 macros: PROC SQL with time_diff * mi_weight (fixes intck bug)
     - All PROC PHREG: weight mi_weight + where=(model_eligible=1) + SuppressedVL ref="1"
     - Tables 4, 5, Supporting Table 1b
*****************************************************************************************************************************;

libname covmo "D:\SheehanRP3\original_data\eHARSdataNov72023";
libname svi 'C:\Users\tgwanzur\Documents\Aim2';
options fmtsearch=(covmo.formats);
options nofmterr; run;

*Reading in vaccination rates by county;
proc import
  datafile = "C:\Users\tgwanzur\Documents\Aim2\Vaccination_County_AIM1.xlsx"
  out = vaccine_county dbms=xlsx; getnames = yes;
run;
proc import
  datafile = "C:\Users\tgwanzur\Documents\Aim2\ruca2010florida.xlsx"
  out = ruca_raw dbms=xlsx; getnames = yes;
run;

*Loading and visualizing data — create PWH2019 cohort;
proc contents data= covmo.pwh_2017_2021_final; run;
proc freq data = covmo.pwh_2017_2021_final; table PWH2019 PWH2020 PWH2021; run;
proc freq data = covmo.pwh_2017_2021_final; table PWH2019*rs20191231_state_cd; run;
proc freq data= covmo.pwh_2017_2021_final; tables SuppressedVL2021; run;
proc freq data= covmo.pwh_2017_2021_final; tables SuppressedVL2020; run;
proc freq data= covmo.pwh_2017_2021_final; tables vital_status; run;
proc freq data= covmo.pwh_2017_2021_final; tables rs20191231_state_cd rad_state_cd; run;

*Import SVI and RUCA;
data ruca; 
  set ruca_raw; 
  zcta = inputn(zip_code, 'F5');
  if ruca2 in (1, 1.1, 2, 2.1, 3, 4.1, 5.1, 7.1, 8.1, 10.1) then rucaccat2010 = '1'; 
  else rucaccat2010 = '0'; 
  zcta2 = put(zcta, 8.);
  drop zcta; 
  rename zcta2=zcta;
run; 
data svi;
  set svi.florida_zip_code_svi_sas;
  zcta = put(zip_code, 8.);
  drop zip_code;
run;

*Create starting cohort — PWH alive in Florida through end of 2019;
data cohort;
  set covmo.pwh_2017_2021_final;
  if PWH2019 ^= 1 then delete;
run;
*N=129,770 (Nov 2023 extract). FDOH public figure=116,689 (frozen Jun 2020).
 Difference due to 3 additional annual reconciliation cycles;
proc contents data= cohort; run;

*Replace missing PWH flags with 0;
data cohort2;
  set cohort;
  array variableOfInterest PWH2019 PWH2020 PWH2021;
  do over variableOfInterest;
    if variableOfInterest=. then variableOfInterest=0;
  end;
run;
*Nov 2023: 7161 total deaths, 564 COVID deaths in full cohort;
proc freq data = cohort2; tables vital_status; where rad_state_cd = "FL"; run;

*Recode underlying cause of death;
Data Mortality;
  set cohort2;
  length under_letter $1. underdis $200.;
  under_letter = substr(death_underlying_icd_cd, 1, 1);
  under_num    = substr(death_underlying_icd_cd, 2, 4);
  if under_letter = '' and rad_state_cd = " " then underdis="alive";
  if under_letter ^= 'U' and under_letter ^= ""  then underdis="other";
  if under_letter = 'U' and (07 <= under_num <= 12) then underdis='COVID';
run;
proc freq data=mortality; tables underdis; run;
proc freq data=mortality; tables underdis; where rad_state_cd="FL"; run;

*Create month-of-death date variable;
data mortdatae;
  set mortality;
  newmoyr_dod = input(moyr_dod, ANYDATEDTE.);
  format newmoyr_dod ANYDATEDTE.;
run;

*Remove records with death after December 2021;
DATA MORT_DATE;
  SET mortdatae;
  if newmoyr_dod > 202112 then delete;
run;

*Assign study start date (Jan 2020 = 202001) to all cohort members;
data time_death;
  set MORT_DATE;
  if PWH2020=1 or PWH2020=. or PWH2021=1 or PWH2021=. or PWH2019=1 then vacc_status=202001;
  format vacc_status ANYDATEDTE.;
run;

*Assign end-of-study month for those still alive;
data time_death1;
  set time_death;
  if newmoyr_dod = . then month = 202201;
  else month = newmoyr_dod;
  format month ANYDATEDTE.;
run;

*Calculate raw month difference (YYYYMM arithmetic);
data new_time;
  set time_death1;
  month_diff = month - vacc_status;
run;

*=============================================================
 RECODE month_diff to sequential time_diff (0=Jan2020 ... 23=Dec2021)
 YYYYMM arithmetic jumps at year boundaries (e.g. Dec2020→Jan2021 is 89 not 1)
 time_diff=24 = alive/censored at study end
=============================================================;
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
proc freq data=new_new_time; tables time_diff; run;
proc freq data=new_new_time; tables time_diff*underdis; title "time_diff by outcome"; run;

*=============================================================
 CREATING COVARIATES — vacc_cat data step
 V5 CRITICAL: LENGTH statements defined BEFORE assignments so 'Unknown'
   does NOT get truncated. Without these, SAS uses shortest observed value
   to set variable length (e.g. categ='M'→length 1, 'Unknown'→stored as 'U')
=============================================================;
data vacc_cat;
  set new_new_time;

  /* V5 FIX: Define lengths FIRST before any assignment */
  length raceeth         $8;   /* Hispanic=8 chars */
  length USborn          $7;   /* Unknown=7, Yes=3, No=2 */
  length age_hivdxrange  $12;  /* '65 and over'=11, 'Unknown'=7 */
  length current_gender2 $7;   /* F=1, M=1, Unknown=7 */
  length categ           $7;   /* M=1, I=1, h=1, o=1, Unknown=7 */

  /* Race/ethnicity — no Unknown needed (catch-all 'Other') */
  if      race = '1' then raceeth = 'Hispanic';
  else if race = '4' then raceeth = 'NHB';
  else if race = '6' then raceeth = 'NHW';
  else                    raceeth = 'Other';
  /* Defensive: blank race → Other (1 observed in data) */
  if raceeth = '' then raceeth = 'Other';

  /* US-born status — 'Unknown' for missing birth_country_cd
     Persons with Unknown appear in Table 1 but are excluded from
     regression via model_eligible=0 */
  if birth_country_cd in ('USA','PRI','VIR','UMI','GUM') then USborn = 'Yes';
  else if birth_country_cd = ' ' then USborn = 'Unknown';
  else USborn = 'No';

  /* Age at 2021 — V4 corrected label: '50-64' (was '50-65')
     V5: length 12 so '65 and over' stores in full (was '65 an' at length 5) */
  hiv_aids_age_yrs1 = inputn(hiv_aids_age_yrs, 'F8');
  if      0  <= age_at_2021 < 18  then delete;
  else if 18 <= age_at_2021 < 35  then age_hivdxrange = '18-34';
  else if 35 <= age_at_2021 < 50  then age_hivdxrange = '35-49';
  else if 50 <= age_at_2021 < 65  then age_hivdxrange = '50-64';
  else if 65 <= age_at_2021 < 100 then age_hivdxrange = '65 and over';
  else if age_at_2021 > 100 then delete;
  else if age_at_2021 = .   then age_hivdxrange = 'Unknown';

  /* Sex — birth_sex only (F/M). Unknown for any other value.
     FM/MF deleted in V3 via current_gender2; V4+ uses birth_sex directly
     so transgender persons do not appear */
  if upcase(strip(birth_sex)) in ('F','M') then
      current_gender2 = upcase(strip(birth_sex));
  else
      current_gender2 = 'Unknown';

  /* Transmission category
     categ length=7 so 'Unknown' stores correctly (was length 1 → 'U') */
  if      trans_categ = " "  then categ = 'Unknown';
  else if trans_categ = '01' then categ = 'MSM';
  else if trans_categ = '02' then categ = 'IDU';
  else if trans_categ = '03' then categ = 'IDU';   /* MSM-IDU → IDU */
  else if trans_categ = '05' then categ = 'hetero';
  else                            categ = 'other';
  /* Note: categ length=7. Values MSM→'M', IDU→'I', hetero→'h', other→'o'
     do NOT apply here — SAS does NOT auto-truncate when length=7.
     Values will be full strings. Update ref= and class statements accordingly:
     ref='MSM' for categ in all PHREG models */

  prisonhivdx = (doch in ('DOC','FCI'));

run;

proc freq data=vacc_cat; tables age_hivdxrange raceeth USborn current_gender2 categ; run;
proc freq data=vacc_cat; tables birth_sex*current_gender2; run;
proc freq data=vacc_cat; tables trans_categ*categ; run;
proc freq data=vacc_cat; tables birth_country_cd*USborn; run;
proc freq data=vacc_cat; tables race*raceeth; run;
proc freq data=vacc_cat; tables age_hivdxrange; run;
proc contents data=vacc_cat; run;

*ZCTA assignment — priority: 2021 > 2019 > death ZCTA;
data hivsort;
  length rs20211231_zip_cd $5 rs20191231_zip_cd $5 rad_zip_cd $5;
  set vacc_cat;

  if rs20211231_zip_cd=328083439 then rsd_zip_cd2=32808;
  else if rs20211231_zip_cd=99999 then rsd_zip_cd2=77;
  else rsd_zip_cd2=rs20211231_zip_cd;

  if rs20191231_zip_cd=328083439 then rsd_zip_cd3=32808;
  else if rs20191231_zip_cd=99999 then rsd_zip_cd3=77;
  else rsd_zip_cd3=rs20191231_zip_cd;

  if rad_zip_cd=328083439 then rsd_zip_cd4=32808;
  else if rad_zip_cd=99999 then rsd_zip_cd4=77;
  else rsd_zip_cd4=rad_zip_cd;

  rsd_zip_cd5=put(rsd_zip_cd2,8.); rename rsd_zip_cd5=zcta1;
  rsd_zip_cd6=put(rsd_zip_cd3,8.); rename rsd_zip_cd6=zcta2;
  rsd_zip_cd7=put(rsd_zip_cd4,8.); rename rsd_zip_cd7=zcta3;
run; 

Data zip_living;
  set hivsort;
  if      zcta1=. and zcta2^=. and zcta3^=. then zcta=zcta3;
  else if zcta1=. and zcta2^=. and zcta3=.  then zcta=zcta2;
  else if zcta1^=.                           then zcta=zcta1;
run;

proc sort data=zip_living; by zcta; run; 
proc sort data=ruca;       by zcta; run;
proc sort data=svi;        by zcta; run;

data merged_data;
  merge zip_living ruca svi; by zcta;
run; 

*State of residence — assign from 2021 or 2019 res, fallback to death state;
data merged_data2;
  set merged_data;
  if      rs20211231_state_cd="" and rs20191231_state_cd^=" " and rad_state_cd^=" " then state_res_d=rad_state_cd;
  else if rs20211231_state_cd="" and rs20191231_state_cd^=" " and rad_state_cd=" "  then state_res_d=rs20191231_state_cd;
  else if rs20211231_state_cd^=" " then state_res_d=rs20211231_state_cd;
  else if state_res_d=" " then delete; /* unknown residence → exclude */
run;

*=============================================================
 ANALYTIC SAMPLE EXCLUSIONS (comm_vacc)
 V5: LENGTH statements for SVI theme and rucaccat2010new so 'Unknown'
     stores correctly. Also removed FM/MF deletes (birth_sex → no transgender)
=============================================================;
data comm_vacc;
  set merged_data2;

  /* V5 FIX: Define lengths BEFORE SVI theme and ruca assignments */
  length rucaccat2010new $7;   /* urban=5, rural=5, Unknown=7 */
  length theme           $7;   /* low=3, medium=6, high=4, Unknown=7 */
  length theme1 theme2 theme3 theme4 $7;

  /* Invalid ZCTAs */
  if zcta in (41,42,45,53,87,97,98) then delete;

  /* Non-Florida residents */
  if state_res_d ^="FL" then delete;

  /* FM/MF deletes REMOVED (V4+): birth_sex only ever F/M, no transgender */

  /* Rural-urban classification */
  if rucaccat2010=. and zcta=77 then delete;
  else if rucaccat2010=1 then rucaccat2010new='urban'; 
  else if rucaccat2010=0 then rucaccat2010new='rural';
  /* V5: Unknown assigned for any remaining blank */
  else if rucaccat2010new='' then rucaccat2010new='Unknown';

  /* SVI overall — delete missing/invalid, assign tertiles */
  if RPL_THEMES=. or zcta=. then delete;
  else if RPL_THEMES=. and zcta=77 then delete;
  else if RPL_THEMES=-999 then delete;
  else if 0    <= RPL_THEMES < 0.33 then theme='low';
  else if 0.33 <= RPL_THEMES < 0.66 then theme='medium';
  else if 0.66 <= RPL_THEMES <= 1   then theme='high';

  /* SVI Theme 1 — socioeconomic */
  if RPL_THEME1=. or zcta=. then delete;
  else if RPL_THEME1=-999 then delete;
  else if 0    <= RPL_THEME1 < 0.33 then theme1='low';
  else if 0.33 <= RPL_THEME1 < 0.66 then theme1='medium';
  else if 0.66 <= RPL_THEME1 <= 1   then theme1='high';

  /* SVI Theme 2 — household characteristics */
  if RPL_THEME2=. or zcta=. then delete;
  else if RPL_THEME2=-999 then delete;
  else if 0    <= RPL_THEME2 < 0.33 then theme2='low';
  else if 0.33 <= RPL_THEME2 < 0.66 then theme2='medium';
  else if 0.66 <= RPL_THEME2 <= 1   then theme2='high';

  /* SVI Theme 3 — minority status/language */
  if RPL_THEME3=. or zcta=. then delete;
  else if RPL_THEME3=-999 then delete;
  else if 0    <= RPL_THEME3 < 0.33 then theme3='low';
  else if 0.33 <= RPL_THEME3 < 0.66 then theme3='medium';
  else if 0.66 <= RPL_THEME3 <= 1   then theme3='high';

  /* SVI Theme 4 — housing/transportation */
  if RPL_THEME4=. or zcta=. then delete;
  else if RPL_THEME4=-999 then delete;
  else if 0    <= RPL_THEME4 < 0.33 then theme4='low';
  else if 0.33 <= RPL_THEME4 < 0.66 then theme4='medium';
  else if 0.66 <= RPL_THEME4 <= 1   then theme4='high';
run; 

proc freq data=comm_vacc; tables rucaccat2010*rucaccat2010new/missprint; run;
proc freq data=comm_vacc; tables RPL_THEMES/missprint; run;
proc freq data=comm_vacc; tables underdis; run;
proc freq data=comm_vacc; tables age_hivdxrange raceeth USborn current_gender2 categ; run;

*=============================================================
 COUNTY NAME CLEANING (V4 critical fix: else-if cascade, stray else removed)
 Priority: 2021 county → 2020 county → 2019 county
=============================================================;
data countyname;
  set comm_vacc; 
  length county $20;

  /* PRIORITY 1: 2021 residence county */
  if      rs20211231_county_name="ALACHUA CO."     then county="Alachua";
  else if rs20211231_county_name="BAKER CO."       then county="Baker";
  else if rs20211231_county_name="BAY CO."         then county="Bay";
  else if rs20211231_county_name="BRADFORD CO."    then county="Bradford";
  else if rs20211231_county_name="BREVARD CO."     then county="Brevard";
  else if rs20211231_county_name="BROWARD CO."     then county="Broward";
  else if rs20211231_county_name="CALHOUN CO."     then county="Calhoun";
  else if rs20211231_county_name="CHARLOTTE CO."   then county="Charlotte";
  else if rs20211231_county_name="CITRUS CO."      then county="Citrus";
  else if rs20211231_county_name="CLAY CO."        then county="Clay";
  else if rs20211231_county_name="COLLIER CO."     then county="Collier";
  else if rs20211231_county_name="COLUMBIA CO."    then county="Columbia";
  else if rs20211231_county_name="DE SOTO CO."     then county="Desoto";
  else if rs20211231_county_name="DIXIE CO."       then county="Dixie";
  else if rs20211231_county_name="DUVAL CO."       then county="Duval";
  else if rs20211231_county_name="ESCAMBIA CO."    then county="Escambia";
  else if rs20211231_county_name="FLAGLER CO."     then county="Flagler";
  else if rs20211231_county_name="FRANKLIN CO."    then county="Franklin";
  else if rs20211231_county_name="GADSDEN CO."     then county="Gadsden";
  else if rs20211231_county_name="GILCHRIST CO."   then county="Gilchrist";
  else if rs20211231_county_name="GLADES CO."      then county="Glades";
  else if rs20211231_county_name="GULF CO."        then county="Gulf";
  else if rs20211231_county_name="HAMILTON CO."    then county="Hamilton";
  else if rs20211231_county_name="HARDEE CO."      then county="Hardee";
  else if rs20211231_county_name="HENDRY CO."      then county="Hendry";
  else if rs20211231_county_name="HERNANDO CO."    then county="Hernando";
  else if rs20211231_county_name="HIGHLANDS CO."   then county="Highlands";
  else if rs20211231_county_name="HILLSBOROUGH CO." then county="Hillsborough";
  else if rs20211231_county_name="HOLMES CO."      then county="Holmes";
  else if rs20211231_county_name="INDIAN RIVER CO." then county="Indian River";
  else if rs20211231_county_name="JACKSON CO."     then county="Jackson";
  else if rs20211231_county_name="JEFFERSON CO."   then county="Jefferson";
  else if rs20211231_county_name="LAFAYETTE CO."   then county="Lafayette";
  else if rs20211231_county_name="LAKE CO."        then county="Lake";
  else if rs20211231_county_name="LEE CO."         then county="Lee";
  else if rs20211231_county_name="LEON CO."        then county="Leon";
  else if rs20211231_county_name="LEVY CO."        then county="Levy";
  else if rs20211231_county_name="LIBERTY CO."     then county="Liberty";
  else if rs20211231_county_name="MADISON CO."     then county="Madison";
  else if rs20211231_county_name="MANATEE CO."     then county="Manatee";
  else if rs20211231_county_name="MARION CO."      then county="Marion";
  else if rs20211231_county_name="MARTIN CO."      then county="Martin";
  else if rs20211231_county_name="MIAMI-DADE CO."  then county="Dade";
  else if rs20211231_county_name="MONROE CO."      then county="Monroe";
  else if rs20211231_county_name="NASSAU CO."      then county="Nassau";
  else if rs20211231_county_name="OKALOOSA CO."    then county="Okaloosa";
  else if rs20211231_county_name="OKEECHOBEE CO."  then county="Okeechobee";
  else if rs20211231_county_name="ORANGE CO."      then county="Orange";
  else if rs20211231_county_name="OSCEOLA CO."     then county="Osceola";
  else if rs20211231_county_name="PALM BEACH CO."  then county="Palm Beach";
  else if rs20211231_county_name="PASCO CO."       then county="Pasco";
  else if rs20211231_county_name="PINELLAS CO."    then county="Pinellas";
  else if rs20211231_county_name="POLK CO."        then county="Polk";
  else if rs20211231_county_name="PUTNAM CO."      then county="Putnam";
  else if rs20211231_county_name="SANTA ROSA CO."  then county="Santa Rosa";
  else if rs20211231_county_name="SARASOTA CO."    then county="Sarasota";
  else if rs20211231_county_name="SEMINOLE CO."    then county="Seminole";
  else if rs20211231_county_name="ST JOHNS CO."    then county="St. Johns";
  else if rs20211231_county_name="ST LUCIE CO."    then county="St. Lucie";
  else if rs20211231_county_name="SUMTER CO."      then county="Sumter";
  else if rs20211231_county_name="SUWANNEE CO."    then county="Suwannee";
  else if rs20211231_county_name="TAYLOR CO."      then county="Taylor";
  else if rs20211231_county_name="UNION CO."       then county="Union";
  else if rs20211231_county_name="VOLUSIA CO."     then county="Volusia";
  else if rs20211231_county_name="WAKULLA CO."     then county="Wakulla";
  else if rs20211231_county_name="WALTON CO."      then county="Walton";
  else if rs20211231_county_name="WASHINGTON CO."  then county="Washington";

  /* PRIORITY 2: 2020 county (if 2021 missing) */
  if county="" then do;
    if      rs20201231_county_name="ALACHUA CO."     then county="Alachua";
    else if rs20201231_county_name="BAKER CO."       then county="Baker";
    else if rs20201231_county_name="BAY CO."         then county="Bay";
    else if rs20201231_county_name="BRADFORD CO."    then county="Bradford";
    else if rs20201231_county_name="BREVARD CO."     then county="Brevard";
    else if rs20201231_county_name="BROWARD CO."     then county="Broward";
    else if rs20201231_county_name="CALHOUN CO."     then county="Calhoun";
    else if rs20201231_county_name="CHARLOTTE CO."   then county="Charlotte";
    else if rs20201231_county_name="CITRUS CO."      then county="Citrus";
    else if rs20201231_county_name="CLAY CO."        then county="Clay";
    else if rs20201231_county_name="COLLIER CO."     then county="Collier";
    else if rs20201231_county_name="COLUMBIA CO."    then county="Columbia";
    else if rs20201231_county_name="DE SOTO CO."     then county="Desoto";
    else if rs20201231_county_name="DIXIE CO."       then county="Dixie";
    else if rs20201231_county_name="DUVAL CO."       then county="Duval";
    else if rs20201231_county_name="ESCAMBIA CO."    then county="Escambia";
    else if rs20201231_county_name="FLAGLER CO."     then county="Flagler";
    else if rs20201231_county_name="FRANKLIN CO."    then county="Franklin";
    else if rs20201231_county_name="GADSDEN CO."     then county="Gadsden";
    else if rs20201231_county_name="GILCHRIST CO."   then county="Gilchrist";
    else if rs20201231_county_name="GLADES CO."      then county="Glades";
    else if rs20201231_county_name="GULF CO."        then county="Gulf";
    else if rs20201231_county_name="HAMILTON CO."    then county="Hamilton";
    else if rs20201231_county_name="HARDEE CO."      then county="Hardee";
    else if rs20201231_county_name="HENDRY CO."      then county="Hendry";
    else if rs20201231_county_name="HERNANDO CO."    then county="Hernando";
    else if rs20201231_county_name="HIGHLANDS CO."   then county="Highlands";
    else if rs20201231_county_name="HILLSBOROUGH CO." then county="Hillsborough";
    else if rs20201231_county_name="HOLMES CO."      then county="Holmes";
    else if rs20201231_county_name="INDIAN RIVER CO." then county="Indian River";
    else if rs20201231_county_name="JACKSON CO."     then county="Jackson";
    else if rs20201231_county_name="JEFFERSON CO."   then county="Jefferson";
    else if rs20201231_county_name="LAFAYETTE CO."   then county="Lafayette";
    else if rs20201231_county_name="LAKE CO."        then county="Lake";
    else if rs20201231_county_name="LEE CO."         then county="Lee";
    else if rs20201231_county_name="LEON CO."        then county="Leon";
    else if rs20201231_county_name="LEVY CO."        then county="Levy";
    else if rs20201231_county_name="LIBERTY CO."     then county="Liberty";
    else if rs20201231_county_name="MADISON CO."     then county="Madison";
    else if rs20201231_county_name="MANATEE CO."     then county="Manatee";
    else if rs20201231_county_name="MARION CO."      then county="Marion";
    else if rs20201231_county_name="MARTIN CO."      then county="Martin";
    else if rs20201231_county_name="MIAMI-DADE CO."  then county="Dade";
    else if rs20201231_county_name="MONROE CO."      then county="Monroe";
    else if rs20201231_county_name="NASSAU CO."      then county="Nassau";
    else if rs20201231_county_name="OKALOOSA CO."    then county="Okaloosa";
    else if rs20201231_county_name="OKEECHOBEE CO."  then county="Okeechobee";
    else if rs20201231_county_name="ORANGE CO."      then county="Orange";
    else if rs20201231_county_name="OSCEOLA CO."     then county="Osceola";
    else if rs20201231_county_name="PALM BEACH CO."  then county="Palm Beach";
    else if rs20201231_county_name="PASCO CO."       then county="Pasco";
    else if rs20201231_county_name="PINELLAS CO."    then county="Pinellas";
    else if rs20201231_county_name="POLK CO."        then county="Polk";
    else if rs20201231_county_name="PUTNAM CO."      then county="Putnam";
    else if rs20201231_county_name="SANTA ROSA CO."  then county="Santa Rosa";
    else if rs20201231_county_name="SARASOTA CO."    then county="Sarasota";
    else if rs20201231_county_name="SEMINOLE CO."    then county="Seminole";
    else if rs20201231_county_name="ST JOHNS CO."    then county="St. Johns";
    else if rs20201231_county_name="ST LUCIE CO."    then county="St. Lucie";
    else if rs20201231_county_name="SUMTER CO."      then county="Sumter";
    else if rs20201231_county_name="SUWANNEE CO."    then county="Suwannee";
    else if rs20201231_county_name="TAYLOR CO."      then county="Taylor";
    else if rs20201231_county_name="UNION CO."       then county="Union";
    else if rs20201231_county_name="VOLUSIA CO."     then county="Volusia";
    else if rs20201231_county_name="WAKULLA CO."     then county="Wakulla";
    else if rs20201231_county_name="WALTON CO."      then county="Walton";
    else if rs20201231_county_name="WASHINGTON CO."  then county="Washington";
  end;

  /* PRIORITY 3: 2019 county */
  if county="" then do;
    if      rs20191231_county_name="ALACHUA CO."     then county="Alachua";
    else if rs20191231_county_name="BAKER CO."       then county="Baker";
    else if rs20191231_county_name="BAY CO."         then county="Bay";
    else if rs20191231_county_name="BRADFORD CO."    then county="Bradford";
    else if rs20191231_county_name="BREVARD CO."     then county="Brevard";
    else if rs20191231_county_name="BROWARD CO."     then county="Broward";
    else if rs20191231_county_name="CALHOUN CO."     then county="Calhoun";
    else if rs20191231_county_name="CHARLOTTE CO."   then county="Charlotte";
    else if rs20191231_county_name="CITRUS CO."      then county="Citrus";
    else if rs20191231_county_name="CLAY CO."        then county="Clay";
    else if rs20191231_county_name="COLLIER CO."     then county="Collier";
    else if rs20191231_county_name="COLUMBIA CO."    then county="Columbia";
    else if rs20191231_county_name="DE SOTO CO."     then county="Desoto";
    else if rs20191231_county_name="DIXIE CO."       then county="Dixie";
    else if rs20191231_county_name="DUVAL CO."       then county="Duval";
    else if rs20191231_county_name="ESCAMBIA CO."    then county="Escambia";
    else if rs20191231_county_name="FLAGLER CO."     then county="Flagler";
    else if rs20191231_county_name="FRANKLIN CO."    then county="Franklin";
    else if rs20191231_county_name="GADSDEN CO."     then county="Gadsden";
    else if rs20191231_county_name="GILCHRIST CO."   then county="Gilchrist";
    else if rs20191231_county_name="GLADES CO."      then county="Glades";
    else if rs20191231_county_name="GULF CO."        then county="Gulf";
    else if rs20191231_county_name="HAMILTON CO."    then county="Hamilton";
    else if rs20191231_county_name="HARDEE CO."      then county="Hardee";
    else if rs20191231_county_name="HENDRY CO."      then county="Hendry";
    else if rs20191231_county_name="HERNANDO CO."    then county="Hernando";
    else if rs20191231_county_name="HIGHLANDS CO."   then county="Highlands";
    else if rs20191231_county_name="HILLSBOROUGH CO." then county="Hillsborough";
    else if rs20191231_county_name="HOLMES CO."      then county="Holmes";
    else if rs20191231_county_name="INDIAN RIVER CO." then county="Indian River";
    else if rs20191231_county_name="JACKSON CO."     then county="Jackson";
    else if rs20191231_county_name="JEFFERSON CO."   then county="Jefferson";
    else if rs20191231_county_name="LAFAYETTE CO."   then county="Lafayette";
    else if rs20191231_county_name="LAKE CO."        then county="Lake";
    else if rs20191231_county_name="LEE CO."         then county="Lee";
    else if rs20191231_county_name="LEON CO."        then county="Leon";
    else if rs20191231_county_name="LEVY CO."        then county="Levy";
    else if rs20191231_county_name="LIBERTY CO."     then county="Liberty";
    else if rs20191231_county_name="MADISON CO."     then county="Madison";
    else if rs20191231_county_name="MANATEE CO."     then county="Manatee";
    else if rs20191231_county_name="MARION CO."      then county="Marion";
    else if rs20191231_county_name="MARTIN CO."      then county="Martin";
    else if rs20191231_county_name="MIAMI-DADE CO."  then county="Dade";
    else if rs20191231_county_name="MONROE CO."      then county="Monroe";
    else if rs20191231_county_name="NASSAU CO."      then county="Nassau";
    else if rs20191231_county_name="OKALOOSA CO."    then county="Okaloosa";
    else if rs20191231_county_name="OKEECHOBEE CO."  then county="Okeechobee";
    else if rs20191231_county_name="ORANGE CO."      then county="Orange";
    else if rs20191231_county_name="OSCEOLA CO."     then county="Osceola";
    else if rs20191231_county_name="PALM BEACH CO."  then county="Palm Beach";
    else if rs20191231_county_name="PASCO CO."       then county="Pasco";
    else if rs20191231_county_name="PINELLAS CO."    then county="Pinellas";
    else if rs20191231_county_name="POLK CO."        then county="Polk";
    else if rs20191231_county_name="PUTNAM CO."      then county="Putnam";
    else if rs20191231_county_name="SANTA ROSA CO."  then county="Santa Rosa";
    else if rs20191231_county_name="SARASOTA CO."    then county="Sarasota";
    else if rs20191231_county_name="SEMINOLE CO."    then county="Seminole";
    else if rs20191231_county_name="ST JOHNS CO."    then county="St. Johns";
    else if rs20191231_county_name="ST LUCIE CO."    then county="St. Lucie";
    else if rs20191231_county_name="SUMTER CO."      then county="Sumter";
    else if rs20191231_county_name="SUWANNEE CO."    then county="Suwannee";
    else if rs20191231_county_name="TAYLOR CO."      then county="Taylor";
    else if rs20191231_county_name="UNION CO."       then county="Union";
    else if rs20191231_county_name="VOLUSIA CO."     then county="Volusia";
    else if rs20191231_county_name="WAKULLA CO."     then county="Wakulla";
    else if rs20191231_county_name="WALTON CO."      then county="Walton";
    else if rs20191231_county_name="WASHINGTON CO."  then county="Washington";
  end;
  /* V4: stray [else rs20211231_county_name=.;] removed */
run; 

proc freq data=countyname; tables county/missing; title "County — expect ~1 missing"; run;
proc freq data=countyname; tables underdis; run;

*Merge county vaccination rates;
proc sort data=vaccine_county; by county; run;
proc sort data=countyname;     by county; run;

data comm_vacc1; 
  merge countyname vaccine_county; by county;
run;

*Verify: expect N=123,011, N_miss=1 (not ~34,000 as with the old flat-if county bug);
proc means data=comm_vacc1 n nmiss mean min max;
  var Percent_of_populatin__5_vaccinat;
  title "Vaccination rate — N_miss should be 1";
run;

*Mean-center vaccination rate;
proc stdize data=comm_vacc1 method=mean out=comm_vacc2;
  var Percent_of_populatin__5_vaccinat;
run;

*=============================================================
 comm_vacc3 — rename vaccination variable and set model_eligible flag
 V5 CRITICAL FIX: model_eligible now correctly uses full 'Unknown' string
   because LENGTH statements above ensure variables are wide enough.
   After fix model_eligible=0 should be ~3,360 (USborn Unknown)
   not 0 as seen in V4 output.
=============================================================;
data comm_vacc3;
  set comm_vacc2;
  rename Percent_of_populatin__5_vaccinat = percent_vacc;

  /* MODEL ELIGIBILITY FLAG
     =1: all regression covariates non-missing → include in PHREG
     =0: has at least one Unknown covariate → Table 1 only, not PHREG
     NOTE: theme not included — SVI deletion already removed anyone with missing theme */
  model_eligible = (
    USborn          ^= 'Unknown' and
    categ           ^= 'Unknown' and
    age_hivdxrange  ^= 'Unknown' and
    current_gender2 ^= 'Unknown' and
    rucaccat2010new ^= 'Unknown'
  );
run;

/* Verify Unknown counts and model_eligible flag
   Expected: USborn Unknown ~3,359, ruca Unknown 1, categ Unknown 1, etc.
   model_eligible=0 should = ~3,361, model_eligible=1 should = ~119,650 */
proc freq data=comm_vacc3;
  tables USborn rucaccat2010new categ age_hivdxrange current_gender2 / missing;
  title "V5 CHECK: Unknown counts — values should be full 'Unknown' not truncated";
run;
proc freq data=comm_vacc3;
  tables model_eligible / missing;
  title "V5 CHECK: model_eligible=0 should be ~3,361 (USborn Unknown + others)";
run;

proc freq data=comm_vacc3; tables SuppressedVL2019 SuppressedVL2020 SuppressedVL2021; run;
proc freq data=comm_vacc3; tables SuppressedVL2020*underdis; run;
proc freq data=comm_vacc3; tables SuppressedVL2021*underdis; run;

*=============================================================
 MARCH REBASE — remove Jan/Feb 2020 competing deaths
 Rebase time: time_diff = max(0, time_diff-2)
 After rebase: 0=March2020, 13=April2021(end of before), 14=May2021(start of during)
=============================================================;
data comm_vacc3_march;
  set comm_vacc3;
  if (underdis="other" or underdis=" ") and newmoyr_dod in (202001,202002) then delete;
  time_diff = max(0, time_diff - 2);
run;
proc freq data=comm_vacc3_march; tables underdis;
  title "After March rebase — expect ~122,673"; run;

*=============================================================
 PRIMARY PERIOD DATASETS — 6-week cutoff
 Before: March 2020 – April 2021 (time_diff 0-13 after rebase)
 During: May 2021  – December 2021 (time_diff 14-22 after rebase)
=============================================================;
data before_group_march;
  set comm_vacc3_march;
  if  underdis="alive"                                         then censor1=0;
  else if underdis="other" or underdis=" " or newmoyr_dod>=202105 then censor1=2;
  else if underdis="COVID" and newmoyr_dod<202105               then censor1=1;
run;
proc freq data=before_group_march; tables censor1;
  title "Before 6-wk — expect COVID=353"; run;
proc freq data=before_group_march; tables newmoyr_dod; where censor1=1;
  title "COVID deaths before — all should be <202105"; run;

data nedeath_march;
  set comm_vacc3_march;
  if newmoyr_dod < 202105 and newmoyr_dod^=. then delete;
run;
data after_group_march;
  set nedeath_march;
  if  underdis="alive"                       then censor1=0;
  else if underdis="other" or underdis=" "   then censor1=2;
  else if underdis="COVID"                   then censor1=1;
run;
proc freq data=after_group_march; tables censor1;
  title "During 6-wk — expect COVID=294"; run;

/* Legacy aliases for CIF macro calls */
data before_group; set before_group_march; run;
data after_group;  set after_group_march;  run;

*=============================================================
 TABLE 1 MACROS — CORRECTED (V4 fix: use time_diff * mi_weight)
 Before period: cap person-time at time_diff=13 (April 2021 after rebase)
 During period: person-time = max(0, time_diff-13)
 Table 1 macros run WITHOUT model_eligible filter so Unknown rows appear.
 V5 NOTE: categ values are now full strings ('MSM', 'IDU', 'hetero', 'other').
   Table 1 will show these full labels.
=============================================================;
%macro t1_before(variable=);
  proc sql;
    create table _b_&variable. as
    select
      &variable.                                                       as level,
      'Before'                                                         as period length=10,
      sum(min(time_diff,13) * mi_weight)                               as wtd_person_time,
      count(case when censor1=1 then 1 end)                            as raw_covid_deaths,
      sum(case when censor1=1 then mi_weight else 0 end)               as wtd_covid_deaths,
      calculated wtd_covid_deaths / calculated wtd_person_time * 100000 as rate_per_100k
    from before_group_march
    group by &variable.;
  quit;
  proc print data=_b_&variable. noobs; title "TABLE 1 Before: &variable."; run;
%mend;

%macro t1_during(variable=);
  proc sql;
    create table _d_&variable. as
    select
      &variable.                                                       as level,
      'During'                                                         as period length=10,
      sum(max(0,time_diff-13) * mi_weight)                             as wtd_person_time,
      count(case when censor1=1 then 1 end)                            as raw_covid_deaths,
      sum(case when censor1=1 then mi_weight else 0 end)               as wtd_covid_deaths,
      calculated wtd_covid_deaths / calculated wtd_person_time * 100000 as rate_per_100k
    from after_group_march
    group by &variable.;
  quit;
  proc print data=_d_&variable. noobs; title "TABLE 1 During: &variable."; run;
%mend;

/* Overall totals */
proc sql;
  create table _t1_overall_b as
  select 'Total' as level, 'Before' as period,
    sum(min(time_diff,13)*mi_weight) as wtd_person_time,
    count(case when censor1=1 then 1 end) as raw_covid_deaths,
    sum(case when censor1=1 then mi_weight else 0 end) as wtd_covid_deaths,
    calculated wtd_covid_deaths / calculated wtd_person_time * 100000 as rate_per_100k
  from before_group_march;
  create table _t1_overall_d as
  select 'Total' as level, 'During' as period,
    sum(max(0,time_diff-13)*mi_weight) as wtd_person_time,
    count(case when censor1=1 then 1 end) as raw_covid_deaths,
    sum(case when censor1=1 then mi_weight else 0 end) as wtd_covid_deaths,
    calculated wtd_covid_deaths / calculated wtd_person_time * 100000 as rate_per_100k
  from after_group_march;
quit;
proc print data=_t1_overall_b noobs; title "TABLE 1 OVERALL Before"; run;
proc print data=_t1_overall_d noobs; title "TABLE 1 OVERALL During"; run;

%t1_before(variable=age_hivdxrange);
%t1_during(variable=age_hivdxrange);
%t1_before(variable=current_gender2);
%t1_during(variable=current_gender2);
%t1_before(variable=raceeth);
%t1_during(variable=raceeth);
%t1_before(variable=USborn);
%t1_during(variable=USborn);
%t1_before(variable=rucaccat2010new);
%t1_during(variable=rucaccat2010new);
%t1_before(variable=categ);
%t1_during(variable=categ);
%t1_before(variable=SuppressedVL2020);
%t1_during(variable=SuppressedVL2021);
%t1_before(variable=theme);
%t1_during(variable=theme);
%t1_before(variable=theme1);
%t1_during(variable=theme1);
%t1_before(variable=theme2);
%t1_during(variable=theme2);
%t1_before(variable=theme3);
%t1_during(variable=theme3);
%t1_before(variable=theme4);
%t1_during(variable=theme4);

/* Verify Unknown rows appear in Table 1 descriptive output */
proc freq data=before_group_march;
  tables USborn rucaccat2010new categ age_hivdxrange / missing;
  title "Table 1 covariate distribution including Unknown rows (before period)";
run;
proc freq data=after_group_march;
  tables USborn rucaccat2010new categ age_hivdxrange / missing;
  title "Table 1 covariate distribution including Unknown rows (during period)";
run;

*=============================================================
 CIF PLOTS
 V5 NOTE: categ ref for CIF = 'MSM' (full string, not 'M')
=============================================================;
ods graphics on;
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=age_hivdxrange,title=CIF Before by age);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=USborn,title=CIF Before by US-born);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=raceeth,title=CIF Before by race/ethnicity);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=current_gender2,title=CIF Before by sex);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=categ,title=CIF Before by transmission category);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=SuppressedVL2020,title=CIF Before by viral suppression);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=rucaccat2010new,title=CIF Before by rurality);
%CIF(data=before_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=theme,title=CIF Before by SVI);

%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=age_hivdxrange,title=CIF During by age);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=USborn,title=CIF During by US-born);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=raceeth,title=CIF During by race/ethnicity);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=current_gender2,title=CIF During by sex);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=categ,title=CIF During by transmission category);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=SuppressedVL2021,title=CIF During by viral suppression);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=rucaccat2010new,title=CIF During by rurality);
%CIF(data=after_group_march,out=agecif,time=time_diff,status=censor1,event=1,censored=0,group=theme,title=CIF During by SVI);

proc corr data=comm_vacc3; var RPL_THEME1 RPL_THEME2 RPL_THEME3 RPL_THEME4; run;

*=============================================================
 TABLE 2 — PRIMARY FINE-GRAY MODELS (6-week cutoff)
 V5 CHANGES:
   - categ ref='MSM' (full string — was 'M' when length=1)
   - All other ref values unchanged (low, urban, NHW, 18-34, Yes, F, M, 1)
   - where=(model_eligible=1) — now correctly excludes ~3,361 Unknown persons
   - weight mi_weight added to all models
   - SuppressedVL ref="1" (suppressed as reference) in all models
=============================================================;

/* MODEL 1 — Individual factors only */
title "TABLE 2: Before vaccine — Model 1 (individual factors)";
proc phreg data=before_group_march (where=(model_eligible=1));
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')   /* V5: full string */
        USborn          (ref='Yes')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2020
        / eventcode=1 rl;
  weight mi_weight;
run;

title "TABLE 2: During vaccine — Model 1 (individual factors)";
proc phreg data=after_group_march (where=(model_eligible=1));
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2021
        / eventcode=1 rl;
  weight mi_weight;
run;

/* FINAL MODEL — Individual + community */
title "TABLE 2: Before vaccine — Final Model (individual + community)";
proc phreg data=before_group_march (where=(model_eligible=1));
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new (ref='urban')
        theme           (ref='low')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2020 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
run;

title "TABLE 2: During vaccine — Final Model (individual + community)";
proc phreg data=after_group_march (where=(model_eligible=1));
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new (ref='urban')
        theme           (ref='low')
        SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
run;

*=============================================================
 TABLE 3 — SVI THEMES (4 separate theme models each period)
=============================================================;
%macro theme_models(data=, vl_var=, title_sfx=);
  %do t = 1 %to 4;
    title "TABLE 3: &title_sfx — theme&t.";
    proc phreg data=&data (where=(model_eligible=1));
      class age_hivdxrange  (ref='18-34') current_gender2 (ref='M')
            raceeth (ref='NHW') categ (ref='MSM') USborn (ref='Yes')
            rucaccat2010new (ref='urban') theme&t (ref='low')
            &vl_var (ref="1");
      model time_diff*censor1(0) =
            age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
            categ &vl_var theme&t percent_vacc / eventcode=1 rl;
      weight mi_weight;
    run;
  %end;
%mend;
%theme_models(data=before_group_march, vl_var=SuppressedVL2020, title_sfx=Before vaccine);
%theme_models(data=after_group_march,  vl_var=SuppressedVL2021, title_sfx=During vaccine);

*=============================================================
 SUPPORTING TABLE 1b — UNIVARIATE CRUDE FINE-GRAY SHRs
 (Reviewer 1 Comment 2)
=============================================================;
%macro univar(data=, period=, var=, ref=);
  proc phreg data=&data (where=(model_eligible=1));
    class &var (ref=&ref);
    model time_diff*censor1(0) = &var / eventcode=1 rl;
    weight mi_weight;
    ods output ParameterEstimates=_upe;
  run;
  data _upe; set _upe;
    length period $10 varname $40;
    period="&period"; varname="&var";
    keep period varname ClassVal0 HazardRatio HRLowerCL HRUpperCL ProbChiSq;
  run;
  proc append base=_univar data=_upe; run;
%mend;
proc datasets lib=work nolist; delete _univar; run;

%univar(data=before_group_march, period=Before, var=age_hivdxrange,   ref='18-34');
%univar(data=before_group_march, period=Before, var=current_gender2,  ref='M');
%univar(data=before_group_march, period=Before, var=raceeth,          ref='NHW');
%univar(data=before_group_march, period=Before, var=USborn,           ref='Yes');
%univar(data=before_group_march, period=Before, var=categ,            ref='MSM');
%univar(data=before_group_march, period=Before, var=SuppressedVL2020, ref='1');
%univar(data=before_group_march, period=Before, var=rucaccat2010new,  ref='urban');
%univar(data=before_group_march, period=Before, var=theme,            ref='low');

%univar(data=after_group_march, period=During, var=age_hivdxrange,   ref='18-34');
%univar(data=after_group_march, period=During, var=current_gender2,  ref='M');
%univar(data=after_group_march, period=During, var=raceeth,          ref='NHW');
%univar(data=after_group_march, period=During, var=USborn,           ref='Yes');
%univar(data=after_group_march, period=During, var=categ,            ref='MSM');
%univar(data=after_group_march, period=During, var=SuppressedVL2021, ref='1');
%univar(data=after_group_march, period=During, var=rucaccat2010new,  ref='urban');
%univar(data=after_group_march, period=During, var=theme,            ref='low');

proc print data=_univar noobs;
  title "Supporting Table 1b: Univariate crude sub-distribution HRs"; run;

*=============================================================
 TABLE 4 — SENSITIVITY ANALYSIS: 4-WEEK CUTOFF
 Vaccine period starts April 1, 2021 (time_diff=12 after rebase)
 Expected: Before ~343 COVID deaths, During ~304
=============================================================;
data before_group_4wk;
  set comm_vacc3_march;
  if  underdis="alive"                                          then censor1=0;
  else if underdis="other" or underdis=" " or newmoyr_dod>=202104 then censor1=2;
  else if underdis="COVID" and newmoyr_dod<202104               then censor1=1;
run;
proc freq data=before_group_4wk; tables censor1;
  title "4-WK Before (expect COVID=343)"; run;

data nedeath_4wk;
  set comm_vacc3_march;
  if newmoyr_dod < 202104 and newmoyr_dod^=. then delete;
run;
data after_group_4wk;
  set nedeath_4wk;
  if  underdis="alive"                       then censor1=0;
  else if underdis="other" or underdis=" "   then censor1=2;
  else if underdis="COVID"                   then censor1=1;
run;
proc freq data=after_group_4wk; tables censor1;
  title "4-WK During (expect COVID=304)"; run;

title "TABLE 4: Before vaccine — Final Model (4-week sensitivity)";
proc phreg data=before_group_4wk (where=(model_eligible=1));
  class age_hivdxrange (ref='18-34') current_gender2 (ref='M')
        raceeth (ref='NHW') categ (ref='MSM') USborn (ref='Yes')
        rucaccat2010new (ref='urban') theme (ref='low')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2020 theme percent_vacc / eventcode=1 rl;
  weight mi_weight;
run;

title "TABLE 4: During vaccine — Final Model (4-week sensitivity)";
proc phreg data=after_group_4wk (where=(model_eligible=1));
  class age_hivdxrange (ref='18-34') current_gender2 (ref='M')
        raceeth (ref='NHW') categ (ref='MSM') USborn (ref='Yes')
        rucaccat2010new (ref='urban') theme (ref='low')
        SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc / eventcode=1 rl;
  weight mi_weight;
run;

/* Quick VL check — HR must be >1 (unsuppressed higher risk) */
title "CHECK Table 4 VL during — HR must be >1";
proc phreg data=after_group_4wk (where=(model_eligible=1));
  class SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) = SuppressedVL2021 / eventcode=1 rl;
  weight mi_weight;
run;

*=============================================================
 TABLE 5 — SENSITIVITY ANALYSIS: 8-WEEK CUTOFF
 Vaccine period starts June 1, 2021 (time_diff=15 after rebase)
 Expected: Before ~363 COVID deaths, During ~284
=============================================================;
data before_group_8wk;
  set comm_vacc3_march;
  if  underdis="alive"                                          then censor1=0;
  else if underdis="other" or underdis=" " or newmoyr_dod>=202106 then censor1=2;
  else if underdis="COVID" and newmoyr_dod<202106               then censor1=1;
run;
proc freq data=before_group_8wk; tables censor1;
  title "8-WK Before (expect COVID=363)"; run;

data nedeath_8wk;
  set comm_vacc3_march;
  if newmoyr_dod < 202106 and newmoyr_dod^=. then delete;
run;
data after_group_8wk;
  set nedeath_8wk;
  if  underdis="alive"                       then censor1=0;
  else if underdis="other" or underdis=" "   then censor1=2;
  else if underdis="COVID"                   then censor1=1;
run;
proc freq data=after_group_8wk; tables censor1;
  title "8-WK During (expect COVID=284)"; run;

title "TABLE 5: Before vaccine — Final Model (8-week sensitivity)";
proc phreg data=before_group_8wk (where=(model_eligible=1));
  class age_hivdxrange (ref='18-34') current_gender2 (ref='M')
        raceeth (ref='NHW') categ (ref='MSM') USborn (ref='Yes')
        rucaccat2010new (ref='urban') theme (ref='low')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2020 theme percent_vacc / eventcode=1 rl;
  weight mi_weight;
run;

title "TABLE 5: During vaccine — Final Model (8-week sensitivity)";
proc phreg data=after_group_8wk (where=(model_eligible=1));
  class age_hivdxrange (ref='18-34') current_gender2 (ref='M')
        raceeth (ref='NHW') categ (ref='MSM') USborn (ref='Yes')
        rucaccat2010new (ref='urban') theme (ref='low')
        SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc / eventcode=1 rl;
  weight mi_weight;
run;

title "CHECK Table 5 VL during — HR must be >1";
proc phreg data=after_group_8wk (where=(model_eligible=1));
  class SuppressedVL2021 (ref="1");
  model time_diff*censor1(0) = SuppressedVL2021 / eventcode=1 rl;
  weight mi_weight;
run;

*=============================================================
 FINAL VERIFICATION CHECKS
=============================================================;
/* Event count cross-check — all definitions sum to 647 */
proc freq data=before_group_march; tables censor1; title "PRIMARY 6-wk Before (expect 353)"; run;
proc freq data=after_group_march;  tables censor1; title "PRIMARY 6-wk During (expect 294)"; run;
proc freq data=before_group_4wk;   tables censor1; title "4-WK Before (expect 343)"; run;
proc freq data=after_group_4wk;    tables censor1; title "4-WK During (expect 304)"; run;
proc freq data=before_group_8wk;   tables censor1; title "8-WK Before (expect 363)"; run;
proc freq data=after_group_8wk;    tables censor1; title "8-WK During (expect 284)"; run;

/* Vaccination rate missingness — should be 1, not ~34000 */
proc means data=before_group_march n nmiss; var percent_vacc;
  title "percent_vacc missingness before period (should be ~1)"; run;

/* Analytic N */
proc freq data=comm_vacc3; tables underdis;
  title "Final analytic N (should be ~123,011)"; run;

/* V5 final check: model_eligible distribution */
proc freq data=before_group_march;
  tables model_eligible;
  title "V5 FINAL CHECK: model_eligible=0 should be ~3,361 not 0"; run;
