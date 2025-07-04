# Read 2020 datasets output from SAS

# Input:    trauma2020v3.csv  
#           transfusion_codes_2020.csv
# Output:   df = compute dataset used in analyses == df_select
#           df_select = subset of more important variables to be viewed
#             transfusion_codes
#           df2020.rds

library(tidyverse)
library(janitor)

df <- 
  read.csv("trauma2020v3.csv") %>% 
  clean_names() %>% 
  rename( age = ag_eyears,
          embolizationhrs = embolization) %>% 
  mutate(embolization_flag = !is.na(embolizationhrs),
         crany_flg = factor(crany_flg, levels=0:1, labels=c("No","Yes")),
         ais_abd = ifelse( is.na(ais_abd), 0, ais_abd ),
         ais_chest = ifelse( is.na(ais_chest), 0, ais_chest ),
         ais_ext = ifelse( is.na(ais_ext), 0, ais_ext ),
         ais_extrem = ifelse( is.na(ais_extrem), 0, ais_extrem ),
         ais_face = ifelse( is.na(ais_face), 0, ais_face ),
         ais_head = ifelse( is.na(ais_head), 0, ais_head ),
         
         # create missing category
         cirrhosis_x = cirrhosis,
         cirrhosis = ifelse( cirrhosis=="", "Unk", cirrhosis ),
         chronic_renal_failure_x = chronic_renal_failure,
         chronic_renal_failure = ifelse( chronic_renal_failure == "", "Unk", chronic_renal_failure),
         diabetes_mellitus_x = diabetes_mellitus,
         diabetes_mellitus = ifelse( diabetes_mellitus == "", "Unk", diabetes_mellitus ),
         anticoagulant_therapy_x = anticoagulant_therapy,
         anticoagulant_therapy = ifelse( anticoagulant_therapy == "", "Unk", anticoagulant_therapy),
         cerebrovascular_accident_x = cerebrovascular_accident,
         cerebrovascular_accident = ifelse(cerebrovascular_accident == "", "Unk", cerebrovascular_accident),
         bleeding_disorder_x = bleeding_disorder,
         bleeding_disorder = ifelse(bleeding_disorder == "", "Unk", bleeding_disorder),
         dementia_x = dementia,
         dementia = ifelse(dementia == "", "Unk", dementia),
         
         across(c(cirrhosis_x, chronic_renal_failure_x, diabetes_mellitus_x,
                  anticoagulant_therapy_x, cerebrovascular_accident_x,
                  bleeding_disorder_x, dementia_x),
                ~ ifelse(.x == "", NA, .x)),
         
         ratio_rbc_plasma = blood4hours/plasma4hours,
         blood4x = ifelse( is.na(blood4hours), 0, blood4hours),
         plasma4x = ifelse( is.na(plasma4hours), 0, plasma4hours),
         ratio_flag = case_when( blood4x==0 & plasma4x==0 ~ "No RBC no FFP",
                                 (blood4x == 0) | (is.na(blood4x)) ~ "FFP but no RBC",
                                 (plasma4x == 0) | (is.na(plasma4x)) ~ "RBC but no FFP",
                                 ratio_rbc_plasma < 0.03 ~ "Mismatched transfusion units",
                                 ratio_rbc_plasma > 100 ~ "Mismatched transfusion units",
                                 .default = "Ratio valid"
         ),
         ratio_group = case_when( (ratio_flag == "Ratio valid") &
                                    (ratio_rbc_plasma <= 1) ~ "Good ratio",
                                  .default = "Bad ratio" ),
         
         # wb_transfused set in SAS program
         wb_flag = case_when(wb_transfused==1 ~ "Yes",
                             TRUE ~ "No"),
         wb_group = ifelse( wb_flag=='Yes', 
                            'WB+CB', 
                            'CB only'),
         WB_GROUP = ifelse( wb_flag=='Yes', 
                            1, 
                            0),
         
         age_cat = ifelse( age >= 65, "65+", "<65"),
         insurance = case_when(primarymethodpayment=="Medicaid" ~ "Medicaid",
                               primarymethodpayment=="Medicare" ~ "Medicare",
                               primarymethodpayment=="Private/Commercial Insurance" ~ "Private",
                               primarymethodpayment=="Self-Pay" ~ "Self-Pay",
                               primarymethodpayment=="Other" ~ "Other",
                               primarymethodpayment=="Other Government" ~ "Other",
                               primarymethodpayment=="Not Billed (for any reason)" ~ "Other",
                               TRUE ~ NA),
         
         discharge_collapsed =
           case_when(hospdischargedisposition==
                       "Discharged to home or self-care (routine discharge)" ~ "Home",
                     hospdischargedisposition==
                       "Discharged/Transferred to home under care of organized home health service" ~ "Home", 
                     hospdischargedisposition==
                       "Discharged/Transferred to a psychiatric hospital or psychiatric distinct part unit of a hospital" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to a short-term general hospital for inpatient care" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to an Intermediate Care Facility (ICF)" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to another type of institution not defined elsewhere" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to court/law enforcement." ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to inpatient rehab or designated unit" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to Long Term Care Hospital (LTCH)" ~ "Facility",
                     hospdischargedisposition==
                       "Discharged/Transferred to Skilled Nursing Facility (SNF)" ~ "Facility",
                     hospdischargedisposition==
                       "Deceased/Expired" ~ "Hospice or deceased",
                     hospdischargedisposition==
                       "Discharged/Transferred to hospice care" ~ "Hospice or deceased",
                     hospdischargedisposition==
                       "Left against medical advice or discontinued care" ~ "AMA",
                     .default = "Missing"  ),
         
         
         # set empty cells to missing
         across( c(sex, ethnicity,bleeding_disorder, 
                   wb_flag, hmrrhgctrlsurgtype, vteprophylaxistype, 
                   chronic_renal_failure_x, cerebrovascular_accident,
                   diabetes_mellitus_x, cirrhosis_x, dementia, anticoagulant_therapy_x,
                   traumatype, acute_kidney_injury, acute_respiratory_distress_syndr,
                   myocardial_infarction, stroke_cva, unplanned_admission_to_icu,
                   severe_sepsis, ventilator_associated_pneumonia, unplanned_visit_to_or,
                   eddischargedisposition, hospdischargedisposition), 
                   ~ ifelse(.x=="",NA,.x)),
         # redefine pre_existing_conditions from SAS
         pre_existing_conditions = case_when(bleeding_disorder=='Yes'~"Yes",
                                             chronic_renal_failure=='Yes'~"Yes",
                                             cerebrovascular_accident=='Yes'~"Yes",
                                             diabetes_mellitus=='Yes'~"Yes",
                                             cirrhosis=='Yes'~"Yes",
                                             dementia=='Yes'~"Yes",
                                             anticoagulant_therapy=='Yes'~"Yes",
                                             is.na(cerebrovascular_accident)~NA,
                                             TRUE ~ "No"),
         # redefine complications from SAS
         complications = case_when(acute_kidney_injury=='Yes'~'Yes',
                                   acute_respiratory_distress_syndr=='Yes'~'Yes',
                                   myocardial_infarction=='Yes'~'Yes',
                                   stroke_cva=='Yes'~'Yes',
                                   unplanned_admission_to_icu=='Yes'~'Yes',
                                   severe_sepsis=='Yes'~'Yes',
                                   ventilator_associated_pneumonia=='Yes'~'Yes',
                                   unplanned_visit_to_or=='Yes'~'Yes',
                                   is.na(unplanned_visit_to_or)~NA,
                                   TRUE~'No'),
         
         # redefine outcome variables from SAS to correct NTDB missingness
         dead = case_when(hospdischargedisposition == "Deceased/Expired" ~ "Yes",
                          withdrawallst == "Yes" ~ "Yes",
                          hospdischargedisposition == "" ~ NA,
                          TRUE ~ "No"),
         dead_withdraw_care = case_when(hospdischargedisposition == "Deceased/Expired" ~ "Yes",
                                        hospdischargedisposition == "Discharged/Transferred to hospice care" ~ "Yes",
                                        withdrawallst == "Yes" ~ "Yes",
                                        hospdischargedisposition == "" ~ NA,
                                        TRUE ~ "No"),
         withdraw_care = case_when(hospdischargedisposition == "Discharged/Transferred to hospice care" ~ "Yes",
                                   withdrawallst == "Yes" ~ "Yes",
                                   hospdischargedisposition == "" ~ NA,
                                   TRUE ~ "No"),
         interfacilitytransfer = ifelse(interfacilitytransfer=="", NA, interfacilitytransfer)
         ) %>% 
  mutate( status = case_when(dead == "Yes" ~ 1,
                             dead == "No" ~ 0,
                             TRUE ~ NA),
          status_care = case_when( dead_withdraw_care == 'Yes' ~ 1,
                                   dead_withdraw_care == 'No' ~ 0,
                                   TRUE ~ NA),
          sex_f = ifelse(sex == 'Male', 1, 0),
          sex_f = factor(sex_f, levels=0:1, labels=c('Female','Male')),
          race_f = ifelse( race == "Unkno", NA, race),
          race_f = factor(race_f),
          
          # quantiles
          
          age_f = case_when( age<30 ~ 1,
                             age>=30 & age<47 ~ 2,
                             age>=47 & age<65 ~ 3,
                             age>=65 ~ 4),
          age_f = factor( age_f, levels=1:4, 
                          labels=c("<30", "[30,47)", "[47,65)", "65+")),
          
          sbp_f = case_when( sbp<93 ~ 1,
                             sbp>=93 & sbp<116 ~ 2,
                             sbp>=116 & sbp<141 ~ 3,
                             sbp>=141 ~ 4 ),
          sbp_f = factor (sbp_f, levels=1:4,
                          labels=c("<93", "[93,116)", "[116,141)", "141+") ),
          
          pulserate_f = case_when( pulserate<83 ~ 1,
                                   pulserate>=83 & pulserate<102 ~ 2,
                                   pulserate>=102 & pulserate<124 ~ 3,
                                   pulserate>=124 ~ 4),
          pulserate_f = factor(pulserate_f, levels=1:4,
                               labels=c("<83", "[83,102)", "[102,124)", "124+")),
          
          # updated 2024-03-25 for survival outcome
          age_1 = I((age/100)^0.5),
          age_2 = I((age/100)^1),
          sbp_1 = I(((sbp + 1)/100)^1),
          sbp_2 = I(((sbp + 1)/100)^2),
          pulserate_1 = I(((pulserate + 1)/100)^1),
          pulserate_2 = I(((pulserate + 1)/100)^1 * log(((pulserate + 1)/100))),
          year = "2020"
  )

df_select <- 
  df %>% 
  select(inc_key, sex, age, age_cat, race, ethnicity, sex_f, race_f, age_f, 
           wb_flag , wb_group, WB_GROUP,
           pre_existing_conditions ,
           bleeding_disorder,  bleeding_disorder_x,
           chronic_renal_failure , chronic_renal_failure_x, 
           cerebrovascular_accident, cerebrovascular_accident_x,
           diabetes_mellitus, diabetes_mellitus_x, 
           cirrhosis, cirrhosis_x, 
           dementia, dementia_x, 
           anticoagulant_therapy, anticoagulant_therapy_x,
           mechanism , traumatype , prehospitalcardiacarrest,
           interfacilitytransfer , primarymethodpayment, insurance,
           sbp , pulserate , totalgcs , sbp_f, pulserate_f, 
           iss , ais_head , ais_chest , ais_abd , ais_extrem , 
           ais_ext , ais_face ,
           crany_flg , crany_hrs ,
           tbicerebralmonitorhrs ,
           icpevdrain , icpjvbulb , icpo2monitor , icpparench ,
           blood4hours, plasma4hours, platelets4hours, wholeblood4hours,
           ratio_rbc_plasma, ratio_flag,
           red_cells4hours_flag,  
           plasma4hours_flag , 
           platelets4hours_flag , 
           whole_blood4hours_flag , 
           moi,
           hospitalarrivalhrs , 
           hem_flg , hem_hrs , 
           hmrrhgctrlsurgtype , hmrrhgctrlsurghrs , embolizationhrs , embolization_flag,
           vteprophylaxistype ,
           dead , dead_withdraw_care , withdraw_care,
           finaldischargehrs ,
           eddischargehrs ,
           complications ,
           acute_kidney_injury , acute_respiratory_distress_syndr ,
           myocardial_infarction , stroke_cva , unplanned_admission_to_icu ,
           severe_sepsis , ventilator_associated_pneumonia , 
           unplanned_visit_to_or , discharge_collapsed,
           hospdischargedisposition , eddischargedisposition, status, status_care,
           ratio_group
  )

# new

df <- df_select

saveRDS(df, "df2020.rds")

transfusion_codes <- 
  read.csv("transfusion_codes_2020.csv") %>% 
  clean_names()
