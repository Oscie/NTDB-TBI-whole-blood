# Combine 2020 & 2021
# Use ICD procedure codes & volume to define transfusion
# Exclude transfers

# Input:  
#         df2020.rds
#         df2021.rds
# Output: df

library(tidyverse)
library(janitor)

source("create.2021.v10.r")
source("create.2020.v6.r")

df2020 <- 
  readRDS("df2020.rds") %>% 
  mutate(Year = "2020")
df2021 <- 
  readRDS("df2021.rds") %>% 
  mutate(Year = "2021")

dftransfer <- 
  bind_rows(df2021, df2020) %>% 
  filter(interfacilitytransfer == "Yes")

df <- 
  bind_rows(df2021, df2020) %>% 
  filter(interfacilitytransfer == "No")

transfusion_codes <- 
  read.csv("transfusion_codes_2018.csv") %>% 
  clean_names()