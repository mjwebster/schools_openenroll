Open enrollment by race

Data source: Minnesota Department of Education
Contact person: Emily Bisek or Josh Collins

We asked for data showing the number of kids, from each racial group, open enrolling or attending a charter school, grouped by their home district. The department of education provided us two files -- one that shows the open enrollment side, the other showing the charter school enrollment. They don't track these things together. Collectively they are referred to as school choice. 

In each file, MDE multiple records for each resident district. Each record represented a racial group leaving that district, going to another district. A record was included only in cases where there were more than 3 students in the racial group going to that particular other school district. So for example, one record shows that 10 white students left the Minneapolis school district to attend Minnetonka School district. Then another record shows that 15 black students left the Minneapolis school district to attend Best Academy. 

We got data going back to the 1999-2000 school year through the 2016-17 school year to use for the Students in Flight project that was published in 2017. Late in 2018, we got the 17-18 school year data and added it in. That's when this R project was created. 

All of that data has the students broken down into 5 racial groups -black, asian, hispanic, american indian and white. 

A couple years ago, the state started tracking students in different racial groups, including a new "multi-race" category. MDE helped us out by converting this open enrollment data (and the overall enrollment files) back to the 5 buckets for the most recent years. 

However, they have told me that starting with the 18-19 data, we will have to switch to the new race groups. We won't be able to go back in time and convert the old data into the new buckets. So this will make it harder to look at this over time. 

It also means that some of this code will likely need to be updated. 

However, the main objective of how this is set up is to collapsing the original data (one record for each group coming from one district, going to another) into records that just show how many kids from each racial group are leaving each district (and coming into it), regardless of what that other district is. 

It's nice to have that detailed info though, about where they are going or where they come from, so I wouldn't want to change the request to MDE. 

It's just that starting next year, the racial groups will be different and when we make a line chart, for example, the lines won't match up. 

The script in this project - openenroll_processdata.R -- pulls 3 data files from mySQL server on Amazon. So when you get new open enrollment by race data from MDE, you'll first have to import it to mySQL and append it to the existing table (openenroll_byrace).  You'll also need to make sure you have updated overall enrollment by race data for every district (the table called "enroll_race_district" has the 5 race buckets. The one called "enroll_race_district_new" has the new format).  You'll also need to make sure the "districtlist" table is up to date and doesn't have duplicates.

Once the data is in R, the script does some slicing and normalizes (melts) the enrollment by race table so that it matches the open enrollment by race table. 

Then it makes dataframes that count up the number of kids in each district and student group, in each year, are leaving for open enrollment (leavingToTrad), and how many are leaving for charter schools (LeavingForCharter) and then how many are coming in from elsewhere (ComingIn)

Then it joins all these things together, starting with the enroll_melt table as the base (to ensure we capture districts even if they don't have open enrollment).  At the end it creates a "residents" variable to estimate the number of kids who live in each district. This ends up being the denominator for calculating the percentage of kids leaving a district. 


The openenroll.Rmd file generates some charts and tables to share with reporters/editors about the latest trends. 