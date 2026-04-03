*****************************************************************************************************************************
File:        07_sensitivity_4wk_8wk.sas
Author:      Tendai Gwanzura
Date:        Revised 2026-03-20
Purpose:     Sensitivity analyses shifting vaccine-availability start date
             4-week window: April 1, 2021 (202104) -- Table 4
             8-week window: June 1,  2021 (202106) -- Table 5
             Addresses Reviewer 1, Comment 1 (PLOS ONE PONE-D-26-01190)

REQUIRES: comm_vacc3_march from 05_finegray_primary_6wk.sas

CRITICAL: Both before and during models use same SuppressedVL coding as Table 2:
  Before models: SuppressedVL2020 (ref="1")  -- suppressed = reference
  During models: SuppressedVL2021 (ref="1")  -- suppressed = reference
  DO NOT mix SuppressedVL2020/2021 or use ref="0" -- this caused direction flip in original analysis
*****************************************************************************************************************************;

%let outpath = C:\Users\tgwanzur\Documents\Aim2;

* ============================================================
  SENSITIVITY 4-WEEK: Vaccine period starts April 1, 2021 (202104)
  Before: March 2020 - March 2021
  During: April 2021 - December 2021
  ============================================================;

data before_group_4wk_march;
  set comm_vacc3_march;
  if      underdis = "alive"                                         then censor1 = 0;
  else if underdis = "other" or underdis = " " or
          newmoyr_dod >= 202104                                      then censor1 = 2;
  else if underdis = "COVID" and newmoyr_dod < 202104                then censor1 = 1;
run;

data nedeath_4wk_march;
  set comm_vacc3_march;
  if newmoyr_dod < 202104 and newmoyr_dod ^= . then delete;
run;

data after_group_4wk_march;
  set nedeath_4wk_march;
  if      underdis = "alive"                   then censor1 = 0;
  else if underdis = "other" or underdis = " " then censor1 = 2;
  else if underdis = "COVID"                   then censor1 = 1;
run;

proc freq data=before_group_4wk_march; tables censor1; title "4-wk sensitivity: before vaccine censor distribution"; run;
proc freq data=after_group_4wk_march;  tables censor1; title "4-wk sensitivity: during vaccine censor distribution"; run;

/* Table 4: Before vaccine - Model 1 */
title "Table 4 (4-wk): Before vaccine - Model 1";
proc phreg data = before_group_4wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2020
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t4_before_m1 Type3=t4_before_m1_type3;
run;

/* Table 4: Before vaccine - Final Model */
title "Table 4 (4-wk): Before vaccine - Final Model";
proc phreg data = before_group_4wk_march;
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
  ods output ParameterEstimates=t4_before_final Type3=t4_before_final_type3;
run;

/* Table 4: During vaccine - Model 1 */
title "Table 4 (4-wk): During vaccine - Model 1";
proc phreg data = after_group_4wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2021 (ref="1");          /* IMPORTANT: use SuppressedVL2021, ref="1" */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2021
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t4_during_m1 Type3=t4_during_m1_type3;
run;

/* Table 4: During vaccine - Final Model */
title "Table 4 (4-wk): During vaccine - Final Model";
proc phreg data = after_group_4wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new  (ref='urban')
        theme            (ref='low')
        SuppressedVL2021 (ref="1");          /* IMPORTANT: ref="1" not ref="0" */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t4_during_final Type3=t4_during_final_type3;
run;

* ============================================================
  SENSITIVITY 8-WEEK: Vaccine period starts June 1, 2021 (202106)
  Before: March 2020 - May 2021
  During: June 2021 - December 2021
  ============================================================;

data before_group_8wk_march;
  set comm_vacc3_march;
  if      underdis = "alive"                                         then censor1 = 0;
  else if underdis = "other" or underdis = " " or
          newmoyr_dod >= 202106                                      then censor1 = 2;
  else if underdis = "COVID" and newmoyr_dod < 202106                then censor1 = 1;
run;

data nedeath_8wk_march;
  set comm_vacc3_march;
  if newmoyr_dod < 202106 and newmoyr_dod ^= . then delete;
run;

data after_group_8wk_march;
  set nedeath_8wk_march;
  if      underdis = "alive"                   then censor1 = 0;
  else if underdis = "other" or underdis = " " then censor1 = 2;
  else if underdis = "COVID"                   then censor1 = 1;
run;

/* Table 5: Before vaccine - Model 1 */
title "Table 5 (8-wk): Before vaccine - Model 1";
proc phreg data = before_group_8wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2020 (ref="1");
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2020
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t5_before_m1 Type3=t5_before_m1_type3;
run;

/* Table 5: Before vaccine - Final Model */
title "Table 5 (8-wk): Before vaccine - Final Model";
proc phreg data = before_group_8wk_march;
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
  ods output ParameterEstimates=t5_before_final Type3=t5_before_final_type3;
run;

/* Table 5: During vaccine - Model 1 */
title "Table 5 (8-wk): During vaccine - Model 1";
proc phreg data = after_group_8wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        SuppressedVL2021 (ref="1");          /* IMPORTANT: ref="1" */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn categ SuppressedVL2021
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t5_during_m1 Type3=t5_during_m1_type3;
run;

/* Table 5: During vaccine - Final Model */
title "Table 5 (8-wk): During vaccine - Final Model";
proc phreg data = after_group_8wk_march;
  class age_hivdxrange  (ref='18-34')
        current_gender2 (ref='M')
        raceeth         (ref='NHW')
        categ           (ref='MSM')
        USborn          (ref='Yes')
        rucaccat2010new  (ref='urban')
        theme            (ref='low')
        SuppressedVL2021 (ref="1");          /* IMPORTANT: ref="1" not ref="0" */
  model time_diff*censor1(0) =
        age_hivdxrange current_gender2 raceeth USborn rucaccat2010new
        categ SuppressedVL2021 theme percent_vacc
        / eventcode=1 rl;
  weight mi_weight;
  ods output ParameterEstimates=t5_during_final Type3=t5_during_final_type3;
run;

/* Verify age 65 consistency across sensitivity tables */
title "Age >=65 check across all sensitivity models";
proc print data=t4_during_m1;    where upcase(Parameter) contains "65"; run;
proc print data=t4_during_final; where upcase(Parameter) contains "65"; run;
proc print data=t5_during_m1;    where upcase(Parameter) contains "65"; run;
proc print data=t5_during_final; where upcase(Parameter) contains "65"; run;

/* Verify viral suppression direction (should be >1 during vaccine, ~1 before) */
title "Viral suppression HR check - should be >1 during vaccine (unsuppressed = higher risk)";
proc print data=t4_during_m1;    where upcase(Parameter) contains "SUPPRESS"; run;
proc print data=t4_during_final; where upcase(Parameter) contains "SUPPRESS"; run;
proc print data=t5_during_m1;    where upcase(Parameter) contains "SUPPRESS"; run;
proc print data=t5_during_final; where upcase(Parameter) contains "SUPPRESS"; run;

/* Export */
proc export data=t4_before_m1    outfile="&outpath.\t4_4wk_before_m1.csv"    dbms=csv replace; run;
proc export data=t4_before_final outfile="&outpath.\t4_4wk_before_final.csv"  dbms=csv replace; run;
proc export data=t4_during_m1    outfile="&outpath.\t4_4wk_during_m1.csv"    dbms=csv replace; run;
proc export data=t4_during_final outfile="&outpath.\t4_4wk_during_final.csv"  dbms=csv replace; run;
proc export data=t5_before_m1    outfile="&outpath.\t5_8wk_before_m1.csv"    dbms=csv replace; run;
proc export data=t5_before_final outfile="&outpath.\t5_8wk_before_final.csv"  dbms=csv replace; run;
proc export data=t5_during_m1    outfile="&outpath.\t5_8wk_during_m1.csv"    dbms=csv replace; run;
proc export data=t5_during_final outfile="&outpath.\t5_8wk_during_final.csv"  dbms=csv replace; run;
