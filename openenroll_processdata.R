
#Script for processing open enrollment by race data
#Before running this, import the new data into the openenroll_byrace table in mySQL/Schools database

#Note: starting with the 18-19 school year data, MDE will no longer provide this data broken down by just these 5 race variables
#We will need to switch to the larger batch of categories, including multi-race, that they added in about 2015
#as a result, we won't be able to go back in time very far; or at minimum, there will be a break in the trend lines




#install.packages(c("rmarkdown", "kableExtra", "lubridate", "knitr", "car", "aws.s3", "dplyr", "rehsape2", "ggplot2", "readr", "janitor", "scales", "tidyr", "htmltools", "tidyverse", "readxl", "ggthemes", "waffle", "RMySQL", "foreign", "kableextra", "DT"))

#install.packages("usethis")


library(readr) #importing csv files
library(dplyr) #general analysis 
library(ggplot2) #making charts
library(lubridate) #date functions
library(reshape2) #use this for melt function to create one record for each team
library(tidyr)
library(janitor) #use this for doing crosstabs
library(scales) #needed for stacked bar chart axis labels
library(knitr) #needed for making tables in markdown page
library(htmltools)#this is needed for Rstudio to display kable and other html code
library(rmarkdown)
library(kableExtra)
library(ggthemes)
library(RMySQL)
library(usethis)



#connect to the database; credentials are stored in .Renviron file on this computer
con <- dbConnect(RMySQL::MySQL(), host = Sys.getenv("host"), dbname="Schools",user= Sys.getenv("userid"), password=Sys.getenv("pwd"))



#This gets all the data from openenroll_byrace table in the Schools database
data1 <- dbSendQuery(con, "select * from openenroll_byrace")

openenroll <- fetch(data1, n=-1)

dbClearResult(data1)


#This gets just pertinent overall enrollment by race (at the district level) for non-charter schools since 99-00 school year
data2 <- dbSendQuery(con, "select * from enroll_race_district where districttype<>'07'  and (datayear like '0%' or datayear like '1%' or datayear='99-00')")

enroll_original <- fetch(data2, n=-1)

dbClearResult(data2)


#This gets the districtlist table, which has key info on districts such as whether they are in the metro 
data3 <- dbSendQuery(con, "select * from DistrictList")

districtlist <- fetch(data3, n=-1)

dbClearResult(data3)


#disconnect connection
dbDisconnect(con)







#limit down the enrollment data to only fields we need
enroll <- enroll_original %>%
  filter(districtType=='01' | districtType=='03' | districtType=='08') %>%
  select(DataYear, yr, districtid, districtType, amIndian, Asian, Black, white, Hispanic) %>%
  rename(`AMERICAN INDIAN`=amIndian,ASIAN=Asian,BLACK=Black, WHITE=white, HISPANIC=Hispanic)

#normalize the enroll file so it matches the open enrollment data
enroll_melt <-  melt(enroll, id=c("DataYear", "yr", "districtid", "districtType")) %>% rename(enrolled=value, studentgroup=variable)




#group and summarise the open enroll data for those who are open enrolling elsewhere
#note this groups by the residentdistrictid (where kid lives)
openenroll_trad <-  openenroll %>%
  filter(charterflag=='trad') %>%
  group_by(datayear, residentdistrictid, StudentGroup) %>%
  summarise(LeavingToTrad=sum(CountOfStudentsEnrolled))


#group and summarise the open enroll data for those who are going to charters
#note this groups by the residentdistrictid (where kid lives)
openenroll_charter <-  openenroll%>%
  filter(charterflag=='charter') %>%
  group_by(datayear, residentdistrictid, StudentGroup) %>% summarise(LeavingToCharter=sum(CountOfStudentsEnrolled))

#group and summarise open enroll data to count number of kids coming into district via open enrollment
#note this groups by the districtID (which is the district kid is attending)
openenroll_comingin <- openenroll%>%
  filter(charterflag=='trad') %>%
  group_by(datayear, districtid, StudentGroup) %>% summarise(ComingIn=sum(CountOfStudentsEnrolled))



#Join these pieces together
#enroll_melt needs to be base table to retain all the districts

openenroll_bydistrict <- left_join(enroll_melt, openenroll_trad, by=c("DataYear"="datayear", "districtid"="residentdistrictid", "studentgroup"="StudentGroup"))

#populate new field with 0 where it is null
openenroll_bydistrict$LeavingToTrad[is.na(openenroll_bydistrict$LeavingToTrad)]  <- 0






#keep adding to the new table, creating a new data frame
openenroll_bydistrict_2 <- left_join(openenroll_bydistrict, openenroll_charter, by=c("DataYear"="datayear", "districtid"="residentdistrictid", "studentgroup"="StudentGroup"))

#populate new field with 0 where it is null
openenroll_bydistrict_2$LeavingToCharter[is.na(openenroll_bydistrict_2$LeavingToCharter)]  <- 0

#keep adding to the new table, creating a new data frame
openenroll_bydistrict_final <-  left_join(openenroll_bydistrict_2, openenroll_comingin, by=c("DataYear"="datayear", "districtid"="districtid", "studentgroup"="StudentGroup"))

#populate new field with 0 where it is null
openenroll_bydistrict_final$ComingIn[is.na(openenroll_bydistrict_final$ComingIn)]  <- 0

#add district information from the districtlist table
openenroll_bydistrict_final <-  left_join(openenroll_bydistrict_final, districtlist %>% select(IDNumber, Organization, County, Metro7County, Location), by=c("districtid"="IDNumber"))

#remove data frames we don't need
rm(data1)
rm(data2)
rm(data3)
rm(openenroll_bydistrict)
rm(openenroll_bydistrict_2)


#remove an old district that doesn't have open enrollment
#(IDNumber=='0604-01-000')

openenroll_bydistrict_final <-  openenroll_bydistrict_final %>% filter(districtid!='0604-01-000')


#convert yr variable to numeric so we can use it in the plots as a continuous variable
openenroll_bydistrict_final$yr <- as.numeric(openenroll_bydistrict_final$yr)

#create residents variable
#This estimates the number of kids who live in the district
#From the total enrolled, it subtracts off the kids who are coming in from elsewhere via open enrollment
#Then it adds the kids who are leaving for other districts/charters
#This estimate is a conservative estimate of all kids because it's missing private school and home school kids

openenroll_bydistrict_final <- openenroll_bydistrict_final %>%
  mutate(residents=(enrolled-ComingIn)+(LeavingToTrad+LeavingToCharter))


