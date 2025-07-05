# NTDB-TBI-whole-blood
Analysis code for NTDB TBI whole blood transfusion project

This is a project from ChristianaCare Health System evaluating the effect of whole blood + component blood transfusion versus only component blood transfusion in the first 4 hours of arrival among patients with traumatic brain injury. The outcome is mortality which includes withdrawal of life-supporting treatment. National Trauma Data Base data from years 2020 and 2021 were the source data. The spreadsheet shows the sequence of running SAS programs to extract data, then R programs to create an analysis dataset and, finally, analyze the data.


| program | input | output |  
| -------- | ------ | ------ |  
| create.2021.transfusion.codes.sas | puf_ICDprocedure.sas7bdat | transfusion_codes_2021.csv |
|                                   | puf_ICDprocedure_lookup.sas7bdat | transfused_patients_2021.sas7bdat |
