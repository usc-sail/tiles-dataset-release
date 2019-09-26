# NOTICE
# This software (or technical data) was produced for the U.S. Government under contract 
# 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14, 
# ALT IV (MAY 2014) or (DEC 2007).
# ©2019 The MITRE Corporation. All Rights Reserved. Approved for Public Release; Distribution Unlimited. Case Number 19-2656


#################################################################
#Version 2.0 - 17 April 2018
#################################################################

#install.packages("readr")
library(readr)

######################      User Inputs    ######################

#Read in merged daily survey results file (specify full path, including file name)
#set "guess_max" argument value at or above the number of rows in your input file, to increase the
#likelihood that variable types will be correctly assigned from observations
test <- read_csv ("Full directory path, including file name", guess_max = 20000)

##Set working directory to the directory/subdirectory into which you'd like to save output files 
##(make sure it's an existing directory)
setwd("Full path for directory into which outputs should be saved")

###################### End User Inputs ##########################







################### Begin Data Processing #######################

#Create 'ID' variable from 'Name'
test$ID <- test$Name

#convert test$Date variable to R-recognized date format, to facilitate sorting on date values
test$Date <- as.Date(test$Date, format = "%m/%d/%Y")

#(OPTIONAL) check list of variables and variable types in test
str(test)
names(test)


## Begin Measure-Specific Data Processing and Scoring ###

#########################    Stress      ########################

#Overall, how would you rate your current level of stress?
#1. No stress at all
#2. Very little stress
#3. Some stress
#4. A lot of stress
#5. A great deal of stress

#stress.d <- data.frame(test$ID,test$surveytype,test$Date,test$StartTime,test$EndTime,test$stress)
#names(stress.d)<-c('ID','surveytype','date','start','end','stress.d')

#Create measure-specific subset
stress.d <- subset(test, select=c(ID,surveytype,Date,StartDate,EndDate,stress,Finished))
names(stress.d)<-c('ID','surveytype','date','start','end','stress.d','Finished')

#sort by ID, then date
stress.d.sorted <- stress.d[order(stress.d$ID,stress.d$date),]

#(OPTIONAL) check values
summary(stress.d.sorted)
table(stress.d.sorted$stress.d,exclude=NULL)

#Make a copy
stress.d.final <- stress.d.sorted

#export sorted data
write.csv(stress.d.final, file="stress.d.csv", row.names = FALSE)



##########################  Anxiety  ############################

#Please select the response that shows how anxious you feel at the moment
#1. Not at all anxious
#2. A little anxious
#3. Moderately anxious
#4. Very anxious
#5. Extremely anxious

#Create measure-specific subset
anxiety.d <- subset(test, select=c(ID,surveytype,Date,StartDate,EndDate,anxiety,Finished))
names(anxiety.d) <- c('ID','surveytype','date','start','end','anxiety.d','Finished')

#sort by ID then date
anxiety.d.sorted <- anxiety.d[order(anxiety.d$ID,anxiety.d$date),]

#(OPTIONAL) check values
summary(anxiety.d.sorted)
table(anxiety.d.sorted$anxiety.d,exclude=NULL)

#Make a copy
anxiety.d.final <- anxiety.d.sorted

#export sorted data
write.csv(anxiety.d.final, file="anxiety.d.csv", row.names = FALSE)


############################  Sleep #############################

#sleep: how many hours of actual sleep did you get last night?
#(not to be confused with the number of hours slept in bed)
#Response choice: enter hours

#Create measure-specific subset
sleep.d <- subset(test, select = c(ID,surveytype,Date,StartDate,EndDate,sleep_1,Finished))
names(sleep.d)<-c('ID','surveytype','date','start','end','sleep.d','Finished')

#sort by ID, then date
sleep.d.sorted <- sleep.d[order(sleep.d$ID,sleep.d$date),]

#If value is 999, set score to NA
sleep.d.sorted$sleep.d <- ifelse(sleep.d.sorted$sleep.d==999,NA,sleep.d.sorted$sleep.d)

#(OPTIONAL) check number of 'health' rows before subsetting
table(sleep.d.sorted$surveytype,exclude=NULL)

#Subset to only 'health' surveys
sleep.d.final <- subset(sleep.d.sorted, surveytype == "health") 

#(OPTIONAL) check that only health surveys remain
table(sleep.d.final$surveytype,exclude=NULL)

#(OPTIONAL) check values (should not be any 999s, range is 0-24 hrs, NAs are possible)
table(sleep.d.final$sleep.d,exclude=NULL)

#export short data
write.csv(sleep.d.final, file="sleep.d.csv", row.names = FALSE)




######################  Physical Activity  #####################

#ex1: how many minutes did you spend on vig. PA yesterday? Examples of vig. PA could include power lifting, sprinting, and rope jumping
#Response choice: enter minutes
#ex2: how many minutes did you spend on moderate PA yesterday? Examples of moderate PA coudl include jogging, biking, and swimming
#Response choice: enter minutes

#Create measure-specific subset
exercise.d <- subset(test, select=c(ID,surveytype,Date,StartDate,EndDate,ex1_1,ex2_1,Finished)) 
names(exercise.d)<-c('ID','surveytype','date','start','end','exercise.d1','exercise.d2','Finished')

#Sort on ID value, then on date value
exercise.d.sorted <- exercise.d[order(exercise.d$ID,exercise.d$date),]

#Subset by surveytype
exercise.d.short <- subset(exercise.d.sorted, surveytype=="health")

#(optional) check that only health surveys remain
table(exercise.d.short$surveytype)

#(OPTIONAL) check ranges. allowable range is 0-1440 mins, NOTE: there could be NAs or 999s, 999S will be converted to NA later
summary(exercise.d.short$exercise.d1)
summary(exercise.d.short$exercise.d2)

#Calculate MET_vig, MET_mod if there are no 999s in d1 or d2, 
#set to missing if there is a 999 (automatically set to missing if there is an NA)

exercise.d.short$MET_vig_daily <- ifelse(exercise.d.short$exercise.d1==999,NA, (8.0 * exercise.d.short$exercise.d1))
exercise.d.short$MET_mod_daily <- ifelse(exercise.d.short$exercise.d2==999,NA, (4.0 * exercise.d.short$exercise.d2))

#total.pa.d will be NA if either exercise.d1 or exercise.d2 was an NA or 999
exercise.d.short$total.pa.d = exercise.d.short$MET_vig_daily + exercise.d.short$MET_mod_daily

#: check ranges and for expected/unexpected NAs in  total.pa.d
summary(exercise.d.short)

#keep only relevant variables
exercise.d.final <- subset(exercise.d.short, select=c(ID,surveytype,date,start,end,total.pa.d,Finished))

#export sorted data
write.csv(exercise.d.final, file="exercise.d.csv", row.names = FALSE)


##########################  Tobacco  ###########################

#tob1: did you use/consume tobacco products yesterday?
#1. Yes
#2. No

#tob2: how many of each of the following product types did you use/consume yesterday?
#tob2_1: individual cigarettes
#tob2_2: individual clove cigarettes
#tob2_3: individual cigars
#tob2_4: e-cigarette cartridges
#tob2_5: pipe sessions
#tob2_6: chewing/smokeless tobacco dips or chews
#tob2_7: any other tobacco products


#Create measure-specific subset
tob.d <- subset (test, select=c(ID,surveytype,Date,StartDate,EndDate,tob1,tob2_1,tob2_2,tob2_3,tob2_4,
                                tob2_5,tob2_6,tob2_7,Finished))
names(tob.d)<- c('ID','surveytype','date','start','end','tob.d1','tob.d2_1','tob.d2_2','tob.d2_3','tob.d2_4',
                       'tob.d2_5','tob.d2_6','tob.d2_7','Finished')


#Sort on ID value, then on date value
tob.d.sorted <- tob.d[order(exercise.d$ID,exercise.d$date),]

#Subset by surveytype
tob.d.short <- subset(tob.d.sorted, surveytype=="health")

#(OPTIONAL) check that only health surveys remain
table(tob.d.short$surveytype)

#(OPTIONAL) check ranges
summary(tob.d.short)
table(tob.d.short$tob.d1,exclude=NULL)

#Create tobacco use status yes/no variable
#1=yes, 2=no
tob.d.short$tob_status<-ifelse(tob.d.short$tob.d1==1,'yes','no') 

#(OPTIONAL)check recode 
table(tob.d.short$tob.d1,tob.d.short$tob_status, exclude = NULL)


#TOBACCO QUANTITY: How many units  of nicotine do you use yesterday? 

#We sum tobacco products for ALL the users (irrespective of smoking status, sum gets set to 0 for non-smokers later

# Add a flag to identify surveys that were administered between 3/27/2018 and 4/4/2018 (inclusive).
# During this time period, undocumented changes to the Qualtrics system caused the pre-population
# of zeroes to cease for tob2 variables , increasing the likelihood
# that participants would proceed while leaving these fields blank. Over just this span, we 
# invoke a special rule for NA-handling (treating NAs as zeroes)

tob.d.short$variantNArule <- ifelse(tob.d.short$date >= as.Date('2018-03-27') & tob.d.short$date <= as.Date('2018-04-04'),
                             1,0)

table(tob.d.short$variantNArule,tob.d.short$date)

#Check for Qualtrics 999 values (used in Qualtrics survey as indication that a participant
#wishes to skip a question).     
tob.d.short$tob.d2_has999 <-ifelse( (tob.d.short$tob.d2_1==999 & !is.na(tob.d.short$tob.d2_1)) | 
                                    (tob.d.short$tob.d2_2==999 & !is.na(tob.d.short$tob.d2_2)) | 
                                    (tob.d.short$tob.d2_3==999 & !is.na(tob.d.short$tob.d2_3)) | 
                                    (tob.d.short$tob.d2_4==999 & !is.na(tob.d.short$tob.d2_4)) | 
                                    (tob.d.short$tob.d2_5==999 & !is.na(tob.d.short$tob.d2_5)) | 
                                    (tob.d.short$tob.d2_6==999 & !is.na(tob.d.short$tob.d2_6)) |
                                    (tob.d.short$tob.d2_7==999 & !is.na(tob.d.short$tob.d2_7)),1,0)

#(OPTIONAL) Check results 
table(tob.d.short$tob_status,tob.d.short$tob.d2_has999,exclude=NULL)

#Compute intermediate tobacco guantity value, checking for presence of 999s and checking also for
#need to invoke variant NA handling rule (See above). If 999s are present, set value to NA. 
#If variant scoring rule is being invoked, treat NAs as zeroes when summing.

tob.d.short$tobQuantity1 <- ifelse(tob.d.short$tob.d2_has999==1,NA,
                             ifelse(tob.d.short$variantNArule==1,
                                    rowSums(tob.d.short[,c('tob.d2_1','tob.d2_2','tob.d2_3','tob.d2_4','tob.d2_5','tob.d2_6','tob.d2_7')], na.rm=TRUE),
                                    rowSums(tob.d.short[,c('tob.d2_1','tob.d2_2','tob.d2_3','tob.d2_4','tob.d2_5','tob.d2_6','tob.d2_7')])))


#(OPTIONAL) Check that NAs have been properly assigned                          
table(tob.d.short$tob.d2_has999,tob.d.short$tobQuantity1, exclude=NULL)


#Compute final tob.quantity scores, setting tob.quantity value to 0 for participants whose smoking status is 'no'
#NOTE: if tob_status is NA, then quantity is NA
tob.d.short$tob.quantity.d <- ifelse(tob.d.short$tob_status=='yes',tob.d.short$tobQuantity1,0)

#(OPTIONAL) check recodes
table(tob.d.short$tob_status,tob.d.short$tob.quantity.d,exclude=NULL)

### Optional Code to keep scores only for participants with tob_status value of "yes" on at least one date### 

#Create a list of IDs that are associated with one or more dates with tob_status value of 'yes'
#tob.status.yes <- subset(tob.d.short,
#                         tob_status=="yes", 
#                         select = c(ID,tob.d1)
#                        )
#names(tob.status.yes) <- c('ID','tob.d1.y')
#tob.status.yes <- tob.status.yes[!duplicated(tob.status.yes), ]

#Create a new variable in tob.d.short to flag IDs for which there are one or more dates with tob_status='yes' value
#tob.d.short <- merge(x = tob.d.short, y = tob.status.yes, by = "ID", all.x = TRUE)

#Create a variant tob.quantity.d score (tob.quantity.d.sub) in which we keep quantity.d scores only if the ID
#value in question was associated with a tob_status value of "yes" on one or more dates (else, set tob.quantity.d.sub
#score to NA)

#tob.d.short$tob.quantity.d.sub <- ifelse(tob.d.short$tob.d1.y==1,tob.d.short$tob.quantity.d,NA)

### End optional code block for computing tob.quantity.d.sub ###

#Keep only relevant variables
tob.d.final <- subset(tob.d.short, select=c("ID","surveytype","date","start","end","tob_status","tob.quantity.d","Finished"))

#Export data 
write.csv(tob.d.final, file="tob.d.csv", row.names = FALSE)


###########################   Alcohol   ############################

#alc1: did you consume any alcoholic beverages yesterday?
#1. Yes
#2. No
#alc2: how many of each of the following beverage types did you consume yesterday?
#alc2_1: beer
#alc2_2: wine
#alc2_3: spirits

#Create measure-specific subset
alc.d <- subset(test, select=c(ID,surveytype,Date,StartDate,EndDate,alc1,alc2_1,alc2_2,alc2_3,Finished)) 
names(alc.d)<- c('ID','surveytype','date','start','end','alc.d1','alc.d2_1','alc.d2_2','alc.d2_3','Finished')

#Sort on ID values and then on date values
alc.d.sorted <- alc.d[order(alc.d$ID,alc.d$date),]

#Subset by surveytype
alc.d.short <- subset(alc.d.sorted, surveytype=="health")

#(OPTIONAL) check that only health surveys remain
table(alc.d.short$surveytype)

#Create alcohol status variable, 1=yes, 2=no
alc.d.short$alc_status <- ifelse(alc.d.short$alc.d1==1,'yes','no') 

#(OPTIONAL) check recodes
table(alc.d.short$alc_status,alc.d.short$alc.d1, exclude=NULL)

#(OPTIONAL) check ranges of alc.d2
summary(alc.d.short)


#ALCOHOL QUANTITY: How many units  of alcohol did you consume yesterday? 

# Add a flag to identify surveys that were administered between 3/27/2018 and 4/4/2018 (inclusive).
# During this time period, undocumented changes to the Qualtrics system caused the pre-population
# of zeroes to cease for alcohol quantity variables, increasing the likelihood
# that participants would proceed while leaving these fields blank. Over just this span, we 
# invoke a special rule for NA-handling (treating NAs as zeroes)

alc.d.short$variantNArule <- ifelse(alc.d.short$date >= as.Date('2018-03-27') & alc.d.short$date <= as.Date('2018-04-04'),
                                    1,0)

#(OPTIONAL) check recode
table(alc.d.short$variantNArule,alc.d.short$date)

#Check for Qualtrics 999 values (used in Qualtrics survey as indication that a participant
#wishes to skip a quesetion).     
alc.d.short$alc2_has999 <-ifelse(
                           (alc.d.short$alc.d2_1==999 & !is.na(alc.d.short$alc.d2_1)) | 
                           (alc.d.short$alc.d2_2==999 & !is.na(alc.d.short$alc.d2_2)) | 
                           (alc.d.short$alc.d2_3==999 & !is.na(alc.d.short$alc.d2_3)),1,0)

#(OPTIONAL) Check results 
table(alc.d.short$alc_status,alc.d.short$alc2_has999,exclude=NULL)

#Compute intermediate alcohol guantity value, checking for presence of 999s and checking also for
#need to invoke variant NA handling rule (See above). If 999s are present, set value to NA. 
#If variant scoring rule is being invoked, treat NAs as zeroes when summing.
alc.d.short$alcQuantity1 <- ifelse(alc.d.short$alc2_has999==1, NA,
                             ifelse(alc.d.short$variantNArule==1,
                                    rowSums(alc.d.short[,c("alc.d2_1","alc.d2_2","alc.d2_3")], na.rm=TRUE),
                                    rowSums(alc.d.short[,c("alc.d2_1","alc.d2_2","alc.d2_3")])))


#(OPTIONAL) Check that NAs have been properly assigned                           
table(alc.d.short$alc2_has999,alc.d.short$alcQuantity1, exclude=NULL)

#For participants who answered "no" to alcohol status question, quantity is set to 0
#If alc_status is NA, then quantity is NA
alc.d.short$alc.quantity.d = ifelse(alc.d.short$alc_status=='yes',alc.d.short$alcQuantity1,0)


#(OPTIONAL)Check values
table(alc.d.short$alc_status,alc.d.short$alc.quantity.d,exclude=NULL)



### Optional Code to keep scores only for participants with alc_status value of "yes" on at least one date### 

#Create a list of IDs that are associated with one or more dates with alc_status value of 'yes'
#alc.status.yes <- subset(alc.d.short,
#                         alc_status=="yes", 
#                         select = c(ID,alc.d1)
#                         )
#names(tob.status.yes) <- c('ID','alc.d1.y')   ####JRB: this gives me an error message######
#alc.status.yes <- alc.status.yes[!duplicated(alc.status.yes), ]

#Create a new variable in alc.d.short to flag IDs for which there are one or more dates with tob_status='yes' value
#alc.d.short <- merge(x = alc.d.short, y = alc.status.yes, by = "ID", all.x = TRUE)

#Create a variant alc.quantity.d score (alc.quantity.d.sub) in which we keep the alc.quantity.d scores only if the ID
#value in question was associated with a alc_status value of "yes" on one or more dates (else, set alc.quantity.d.sub
#score to NA)
#alc.d.short$alc.quantity.d.sub <- ifelse(alc.d.short$alc.d1.y==1,alc.d.short$alc.quantity.d,NA)

### End optional code block for computing alc.quantity.d.sub ###


#Keep select variables
alc.d.final <-subset(alc.d.short, select=c('ID','surveytype','date','start','end','alc_status','alc.quantity.d',
                                           'Finished'))

#export short data
write.csv(alc.d.final, file="alc.d.csv", row.names = FALSE)



##########################  PANAS-S  ###########################

#pan1 through pan10:
#alert [PA]
#excited [PA]
#enthusiastic [PA]
#inspired [PA]
#determined [PA]
#distressed [NA]
#upset [NA]
#scared [NA]
#afraid [NA]
#nervous [NA]

#(5)pt scale:
#1 (very slightly or not at all), 
#2 (a little), 
#3 (moderately), 
#4 (quite a bit), 
#5 (extremely)


#Create a measure-specific subset
pan.d.orig <- subset(test, select = c(ID,surveytype,Date,StartDate,EndDate,pand1,pand2,pand3,pand4,pand5,
                                pand6,pand7,pand8,pand9,pand10,Finished))
names(pan.d.orig)<-c('ID','surveytype','date','start','end','pand1','pand2','pand3','pand4','pand5',
               'pand6','pand7','pand8','pand9','pand10','Finished')

#(OPTIONAL) check response value ranges
apply(pan.d.orig[c('pand1','pand2','pand3','pand4','pand5','pand6',
             'pand7','pand8','pand9','pand10')], 2, table,exclude=NULL)


#Sort on ID, then on date
pan.d.sorted <- pan.d.orig[order(pan.d.orig$ID,pan.d.orig$date),]


###########   Define 'getmode' mode imputation function   ###########

getmode <- function(x) {
  x <- unlist(x)
  nacount <- sum(is.na(x)) #Count the number of NA values
  varcount <- length(x) #Compute the number of items
  
  #Do not impute mode if >= 50% of items have NA values
  if (2*nacount >= varcount){
    return(NA)
  }
  #Otherwise, ignore NAs when computing modes over remaining non-missing values
  x <- x[!is.na(x)]
  
  ux <- unique(x) #compute vector of unique values
  freq <- tabulate(match(x, ux)) #compute frequencies for each unique value
  modes <- which(freq==max(freq)) #compute modes
  nmodes <- sum(modes) #compute the number of modal values
  
  #If the number of modal values is greater than 1, take the average of
  #the modal values and round to the nearest integer; return this rounded
  #average value as modal value for imputation purposes; 
  #else, report the single modal value
  #(Note: when rouding off a 5, R uses the IEC 60559 standard, which stipulates
  #that 5's should be rounded to the nearest even digit. Thus,  a value of 
  #2.5 will be rounded down to 2, whereas a value of 3.5 will be rounded up to 4)
  
  if (nmodes!=1){
    avemode <- round(mean(ux[modes]))
    return(avemode)
  } else {
    return(ux[modes])
  }
}

################ End getmode function definition #################


#Create dataframe copies to use when imputing missing item-level responses (one each for positive and negative affect variables)
pan.d.mode.pa <- subset(pan.d.sorted, select=c('ID','surveytype','date','start','end','pand1','pand2','pand3','pand4','pand5','Finished'))
pan.d.mode.na <- subset(pan.d.sorted, select=c('ID','surveytype','date','start','end','pand6','pand7','pand8','pand9','pand10','Finished'))

### Mode imputation ###

# Indentify the index values for all locations where there is an NA 
ind.pan.pa <- which(is.na(pan.d.mode.pa), arr.ind=TRUE)
ind.pan.na <- which(is.na(pan.d.mode.na), arr.ind=TRUE)

if(NROW(ind.pan.pa)!=0) {
# If a value is NA, impute using the output of the "getmode" function 
pan.d.mode.pa[ind.pan.pa] = apply(pan.d.mode.pa[c('pand1','pand2','pand3','pand4','pand5')],MARGIN=1,FUN=getmode)[ind.pan.pa[,1]]
}
if(NROW(ind.pan.na)!=0) {
# If a value is NA, impute using the output of the "getmode" function
pan.d.mode.na[ind.pan.na] = apply(pan.d.mode.na[c('pand6','pand7','pand8','pand9','pand10')],MARGIN=1,FUN=getmode)[ind.pan.na[,1]]
}


#Merge positive and negative affect results, now with imputed values
pand <- merge(pan.d.mode.pa, pan.d.mode.na, by=c('ID','surveytype','date','Finished','start','end'))

###calculate composites: if any individual item-level responses remain as NA after imputation step,
#composite will be NA

pand$pos.affect.d = pand$pand1 + pand$pand2 + pand$pand3 + pand$pand4 + pand$pand5
pand$neg.affect.d = pand$pand6 + pand$pand7 + pand$pand8 + pand$pand9 + pand$pand10 

#(OPTIONAL) check ranges (and check calculations manually in pand dataframe)
table(pand$pos.affect.d,exclude=NULL)
table(pand$neg.affect.d,exclude=NULL)

#Keep just relevant variables
pand.final = subset(pand, select = c('ID','surveytype','date','start','end','pos.affect.d','neg.affect.d','Finished'))

#export data
write.csv(pand.final, file="pan.d.csv", row.names = FALSE)


###########################   BFI-10   #############################

#How well do the following statements describe your personality?
#bfid1 through bfid10

#1. is reserved (E),(R)
#2. is generally trusting (A)
#3. tends to be lazy (C),(R)
#4. is relaxed, handles stress well (N),(R)
#5. has few artistic interests (O),(R)
#6. is outgoing, sociable(E)
#7. tends to find fault with others (A),(R)
#8. does a thorough job (C)
#9. gets nervous easily (N)
#10. has an active imigination (O)

#(5) point scale:
#1. disagree strongly
#2. disagree a little
#3. neither agree nor disagree
#4. agree a little
#5. agree strongly

#Extraversion: 1R,6
#Agreeableness: 2,7R
#Conscientiousness: 3R,8
#Negative Emotionality: 4R,9
#Open-Mindedness: 5R,10

#Create measure-specific subset
bfid.orig <- subset(test, select = c(ID,surveytype,Date,StartDate,EndDate,bfid1,bfid2,bfid3,bfid4,bfid5,
                  bfid6,bfid7,bfid8,bfid9,bfid10,Finished))
names(bfid.orig)<-c('ID','surveytype','date','start','end','bfid1','bfid2','bfid3','bfid4','bfid5','bfid6','bfid7','bfid8',
               'bfid9','bfid10','Finished')

#Sort on ID, then on date
bfid.sorted <- bfid.orig[order(bfid.orig$ID,bfid.orig$date),]

#Subset based on surveytype
bfid <- subset(bfid.sorted, surveytype == "personality")

#(OPTIONAL) check that only personality surveys remain
table(bfid$surveytype)

#(OPTIONAL)check response value ranges
apply(bfid[c('bfid1','bfid2','bfid3','bfid4','bfid5','bfid6','bfid7','bfid8',
             'bfid9','bfid10')], 2, table,exclude=NULL)


#create a new data frame into which we will insert transposed values for items with reversed response scales 
bfid.rev <- bfid

#Recoding reverse coded items
bfid.rev$bfid1R = (6 - bfid.rev$bfid1)
bfid.rev$bfid3R = (6 - bfid.rev$bfid3)
bfid.rev$bfid4R = (6 - bfid.rev$bfid4)
bfid.rev$bfid5R = (6 - bfid.rev$bfid5)
bfid.rev$bfid7R = (6 - bfid.rev$bfid7)

#(OPTIONAL) check recodes
table(bfid.rev$bfid1,bfid.rev$bfid1R,exclude=NULL)
table(bfid.rev$bfid3,bfid.rev$bfid3R,exclude=NULL)
table(bfid.rev$bfid4,bfid.rev$bfid4R,exclude=NULL)
table(bfid.rev$bfid5,bfid.rev$bfid5R,exclude=NULL)
table(bfid.rev$bfid7,bfid.rev$bfid7R,exclude=NULL)


bfid.new <- subset(bfid.rev, select=c(ID,surveytype,date,start,end,bfid1R,bfid2,
                      bfid3R,bfid4R,bfid5R,bfid6,bfid7R,
                      bfid8,bfid9,bfid10,Finished))
names(bfid.new) <- c('ID','surveytype','date','start','end','bfid1R','bfid2','bfid3R','bfid4R','bfid5R','bfid6',
                     'bfid7R','bfid8','bfid9','bfid10','Finished')

#Composite will be NA if one or two of the items is NA, this is desired behavior

bfid.new$extraversion.d = (bfid.new$bfid1R + bfid.new$bfid6)/2
bfid.new$agreeableness.d = (bfid.new$bfid2 + bfid.new$bfid7R)/2
bfid.new$conscientiousness.d = (bfid.new$bfid3R + bfid.new$bfid8)/2
bfid.new$neuroticism.d = (bfid.new$bfid4R + bfid.new$bfid9)/2
bfid.new$openness.d = (bfid.new$bfid5R + bfid.new$bfid10)/2


#Keep select variables
bfid.final <- subset(bfid.new, select = c(ID,surveytype,date,start,end,extraversion.d,agreeableness.d,conscientiousness.d,
                            neuroticism.d,openness.d,Finished))

#(OPTIONAL), check ranges
apply(bfid.final[c('extraversion.d','agreeableness.d','conscientiousness.d',
                 'neuroticism.d','openness.d')], 2, table,exclude=NULL)

#Export data
write.csv(bfid.final, file="bfi.d.csv", row.names = FALSE)


###########################   Work    ###############################

#Work: did you work one or more hours today?
#1. Yes
#2. No


#Create measure-specific subset
worktoday <- subset(test, surveytype == "job",
                          select=c(ID,surveytype,Date,StartDate, EndDate,work,Finished)) 
names(worktoday) <- c('ID','surveytype','date','start','end','work','Finished')

#(OPTIONAL):check that only job surveys remain
table(worktoday$surveytype)

#1=yes, 2=no
worktoday$work_status<-ifelse(worktoday$work==1,'yes','no') 

#(OPTIONAL): check new var
table(worktoday$work,worktoday$work_status,exclude=NULL)

#sort by ID, then date
worktoday <- worktoday[order(worktoday$ID,worktoday$date),]

#Keep just relevant variables
worktoday.final <- subset(worktoday, select = c(ID,surveytype,date,start,end,work_status,Finished))

#export data
write.csv(worktoday.final, file="worktoday.csv", row.names = FALSE)



#############################  ITP  #################################


#itpd1: carried out the core parts of your job well
#itpd2: completed your core tasks well using the standard procedures
#itpd3: ensured your tasks were completed properly

#(5) point scale:
#1. very little
#2. somewhat
#3. moderately
#4. considerably
#5. a great deal

#Create measure-specific subset
itp.d.orig <- subset(test, select=c('ID','surveytype','Date','StartDate','EndDate','itpd1','itpd2','itpd3','work','Finished')) 
names(itp.d.orig) <- c('ID','surveytype','date','start','end','itp.d1','itp.d2','itp.d3','work','Finished')

#Sort by ID values, then by date values
itp.d.sorted <- itp.d.orig[order(itp.d.orig$ID,itp.d.orig$date),]

#Subset by surveytype
itp.d <- subset(itp.d.sorted, surveytype=="job")
  
#(OPTIONAL) check that only job surveys remain
table(itp.d$surveytype)

#Recreate work_status here 
#1=yes, 2=no
itp.d$work_status <- ifelse(itp.d$work==1,'yes','no') 

#(OPTIONAL) check new var
table(itp.d$work,itp.d$work_status,exclude=NULL)

#(OPTIONAL) check ranges
apply(itp.d[c('itp.d1','itp.d2','itp.d3')], 2, table,exclude=NULL)


#Compute count of missing item-level responses per participant. Store value in a new column ('na_count').
itp.d$na_count <- apply(is.na(itp.d[,c('itp.d1','itp.d2','itp.d3')]), 1, sum)  

#Compute summary scores based on mean item-level values. Generate summary score of NA if 2 or more (i.e., >= 50%)
#of item-level responses are NA

itp.d$itp.d.mean <- ifelse(itp.d$na_count>=2,NA, 
                     apply(itp.d[c('itp.d1','itp.d2','itp.d3')], 1, FUN=mean, na.rm=TRUE))


#(OPTIONAL)Check range (1-5) #NAs (should match number #<=2 in na_count)
table(itp.d$itp.d.mean,exclude=NULL)
table(itp.d$na_count,exclude=NULL)

#Final score reported as 'DNW' (Did Now Work) if 'work_status' value is 'no' 
#Note: work_status of NA will yield score of NA, which is the desired behavior
itp.d$itp.d <- ifelse(itp.d$work_status=='no','DNW',itp.d$itp.d.mean)

#(OPTIONAL) check recode
table(itp.d$work_status,itp.d$itp.d,exclude=NULL)

#Keep select variables
itp.d.final = subset(itp.d,select=c(ID,surveytype,date,start,end,work_status,itp.d,Finished))

#export  data
write.csv(itp.d.final, file="itp.d.csv", row.names = FALSE)



##############################  IRB  #################################


#irbd1: Adequately completed your assigned duties
#irbd2. Fulfilled your responsibilities specified in job description
#irbd3. Performed tasks that are expected of you
#irbd4. Met formal performance requirements of your job
#irbd5. Engaged in activities that directly affected your performance evaluation
#irbd6. Neglected aspects of the job you are obligated to perform
#irbd7. Failed to perform your essential duties

#(7) point scale:
#1. strongly disagree
#2. moderately disagree
#3. slightly disagree
#4. neutral
#5. slightly agree
#6. moderately agree
#7. strongly agree


#Create measure-specific subset
irb.d.orig <- subset(test, select=c('ID','surveytype','Date','StartDate','EndDate',
                                    'irbd1','irbd2','irbd3','irbd4','irbd5','irbd6','irbd7','work','Finished')) 
names(irb.d.orig)<-c('ID','surveytype','date','start','end','irb.d1','irb.d2','irb.d3','irb.d4','irb.d5','irb.d6','irb.d7',
                'work','Finished')

#Sort by ID value, then by date value
irb.d.sorted <- irb.d.orig[order(irb.d.orig$ID,irb.d.orig$date),]

#Subset by surveytype
irb.d <- subset(irb.d.sorted, surveytype=="job")

#(OPTIONAL) check that only job surveys remain
table(irb.d$surveytype)

#Create work_status here
#1=yes, 2=no
irb.d$work_status<-ifelse(irb.d$work==1,'yes','no')

#(OPTIONAL) check new var
table(irb.d$work,irb.d$work_status,exclude=NULL)


#(OPTIONAL) check ranges
apply(irb.d[c('surveytype','irb.d1','irb.d2','irb.d3','irb.d4','irb.d5','irb.d6','irb.d7',
              'work','work_status')], 2, table,exclude=NULL)

#neg.irbd = 6,7
#pos.irbd = 1,2,3,4,5

#Reverse scores for irb6 and irb7
irb.d$irb.d6R = 8 - irb.d$irb.d6
irb.d$irb.d7R = 8 - irb.d$irb.d7

#check recodes
table(irb.d$irb.d6,irb.d$irb.d6R)
table(irb.d$irb.d7,irb.d$irb.d7R)

#Subset to drop pre-reversed items
irb.d <- subset(irb.d, select = c(ID, surveytype, date, start, end,
                                  irb.d1, irb.d2, irb.d3, irb.d4, irb.d5, irb.d6R, irb.d7R, work_status, Finished))


#Create a copy to use when imputing missing item-level responses
irb.d.mode <- irb.d


#### Mode imputation ####

# Run mode imputation step to replace missing item-level responses with modal value, subject to 'getmode' thresholding rules
# Get index values for all locations where there is an NA
ind.irb.d <- which(is.na(irb.d.mode), arr.ind=TRUE)

if(NROW(ind.irb.d)!=0) {
# Impute missing item-level responses using output of "getmode" function if 
irb.d.mode[ind.irb.d] = apply(irb.d.mode[c('irb.d1','irb.d2','irb.d3','irb.d4',
                                         'irb.d5','irb.d6R','irb.d7R')],MARGIN=1,FUN=getmode)[ind.irb.d[,1]]
}


#Create summary score
#Note: NA in 'work_status' will result in final score of NA, which is the desired behavior
irb.d.mode$irb.d <- ifelse(irb.d.mode$work_status=='no', 'DNW', 
                            rowSums(irb.d.mode[,c('irb.d1','irb.d2','irb.d3','irb.d4','irb.d5',
                                                   'irb.d6R','irb.d7R')]))
#(OPTIONAL) check values
table(irb.d.mode$irb.d,exclude=NULL)

#Keep select variables
irb.d.final <- subset(irb.d.mode, select = c(ID, surveytype, date, start, end,work_status, irb.d, Finished))

#Export data
write.csv(irb.d.final, file="irb.d.csv", row.names = FALSE)


#############################   OCB-CWB   ###############################


#Today I...
#dalal1: went out of my way to be a good employee         (OCB)
#dalal2: was respectful of other people's needs           (OCB)
#dalal3: displayed loyalty to my organization             (OCB)  
#dalal4: praised or encouraged someone                    (OCB)
#dalal5: volunteered to do something that was not required(OCB)
#dalal6: showed genuine concern for others                (OCB)
#dalal7: tried to uphold the values of my organization    (OCB)
#dalal8: tried to be considerate to others                (OCB)
#dalal9: spent time on tasks unrelated to work            (CWB)
#dalal10: gossiped about people at my organization        (CWB)
#dalal11: did not work to the best of my ability          (CWB)
#dalal12: said or did something that was unpleasant       (CWB)
#dalal13: did not fully comply with a supervisor's instructions(CWB)
#dalal14: bahaved in an unfriendly manner                 (CWB)
#dalal15: spoke poorly about my organization to others    (CWB)
#dalal16: talked badly about people behind their backs    (CWB)

#Response choices:
#1. Yes
#2. No

#Create measure-specific subset
dalal.orig <- subset(test, 
                select=c('ID','surveytype','Date','StartDate','EndDate','dalal1','dalal2','dalal3','dalal4','dalal5',
                         'dalal6','dalal7','dalal8','dalal9','dalal10','dalal11','dalal12','dalal13','dalal14','dalal15','dalal16',
                         'work','Finished'))
names(dalal.orig) <- c('ID','surveytype','date','start','end','dalal1','dalal2','dalal3','dalal4','dalal5',
                  'dalal6','dalal7','dalal8','dalal9','dalal10','dalal11','dalal12','dalal13','dalal14','dalal15','dalal16',
                  'work','Finished')

#Sort on ID, then on date
dalal.sorted <- dalal.orig[order(dalal.orig$ID,dalal.orig$date),]

#Subset by surveytype
dalal <- subset(dalal.sorted, surveytype=="job")

#(OPTIONAL) check that only job surveys remain
table(dalal$surveytype)


#Create work_status variable
#1=yes, 2=no
dalal$work_status<-ifelse(dalal$work==1,'yes','no') 

#(OPTIONAL) check new var
table(dalal$work,dalal$work_status,exclude=NULL)

#(OPTIONAL) check ranges
apply(dalal[c('surveytype','dalal1','dalal2','dalal3','dalal4','dalal5','dalal6','dalal7','dalal8',
              'dalal9','dalal10','dalal11','dalal12','dalal13','dalal14','dalal15','dalal16',
              'work','work_status')], 2, table,exclude=NULL)


#recoding 'no' to 0
dalal$dalal1n <-ifelse(dalal$dalal1==2,0,dalal$dalal1)
dalal$dalal2n <-ifelse(dalal$dalal2==2,0,dalal$dalal2)
dalal$dalal3n <-ifelse(dalal$dalal3==2,0,dalal$dalal3)
dalal$dalal4n <-ifelse(dalal$dalal4==2,0,dalal$dalal4)
dalal$dalal5n <-ifelse(dalal$dalal5==2,0,dalal$dalal5)
dalal$dalal6n <-ifelse(dalal$dalal6==2,0,dalal$dalal6)
dalal$dalal7n <-ifelse(dalal$dalal7==2,0,dalal$dalal7)
dalal$dalal8n <-ifelse(dalal$dalal8==2,0,dalal$dalal8)
dalal$dalal9n <-ifelse(dalal$dalal9==2,0,dalal$dalal9)
dalal$dalal10n <-ifelse(dalal$dalal10==2,0,dalal$dalal10)
dalal$dalal11n <-ifelse(dalal$dalal11==2,0,dalal$dalal11)
dalal$dalal12n <-ifelse(dalal$dalal12==2,0,dalal$dalal12)
dalal$dalal13n <-ifelse(dalal$dalal13==2,0,dalal$dalal13)
dalal$dalal14n <-ifelse(dalal$dalal14==2,0,dalal$dalal14)
dalal$dalal15n <-ifelse(dalal$dalal15==2,0,dalal$dalal15)
dalal$dalal16n <-ifelse(dalal$dalal16==2,0,dalal$dalal16)

#(OPTIONAL) check recodes
table(dalal$dalal1,dalal$dalal1n,exclude=NULL)
table(dalal$dalal2,dalal$dalal2n,exclude=NULL)
table(dalal$dalal3,dalal$dalal3n,exclude=NULL)
table(dalal$dalal4,dalal$dalal4n,exclude=NULL)
table(dalal$dalal5,dalal$dalal5n,exclude=NULL)
table(dalal$dalal6,dalal$dalal6n,exclude=NULL)
table(dalal$dalal7,dalal$dalal7n,exclude=NULL)
table(dalal$dalal8,dalal$dalal8n,exclude=NULL)
table(dalal$dalal9,dalal$dalal9n,exclude=NULL)
table(dalal$dalal10,dalal$dalal10n,exclude=NULL)
table(dalal$dalal11,dalal$dalal11n,exclude=NULL)
table(dalal$dalal12,dalal$dalal12n,exclude=NULL)
table(dalal$dalal13,dalal$dalal13n,exclude=NULL)
table(dalal$dalal14,dalal$dalal14n,exclude=NULL)
table(dalal$dalal15,dalal$dalal15n,exclude=NULL)
table(dalal$dalal16,dalal$dalal16n,exclude=NULL)

###Total ocb/cwb will be NA if any individual item is missing, this is the desired behavior####
#An NA value for 'work_status' will also result in a final score of NA

dalal$ocb.d <-ifelse(dalal$work_status=='yes', (dalal$dalal1n + dalal$dalal2n + dalal$dalal3n + dalal$dalal4n + 
                                                  dalal$dalal5n + dalal$dalal6n + dalal$dalal7n + dalal$dalal8n),'DNW')
dalal$cwb.d <-ifelse(dalal$work_status=='yes', (dalal$dalal9n + dalal$dalal10n + dalal$dalal11n + dalal$dalal12n + 
                                                  dalal$dalal13n + dalal$dalal14n + dalal$dalal15n + dalal$dalal16n),'DNW')

#(OPTIONAL) check ranges and recodes

table (dalal$work_status,dalal$ocb.d,exclude=NULL)
table(dalal$work_status,dalal$cwb.d,exclude=NULL)

#Keep select variables
dalal.final <- subset(dalal, select=c('ID','surveytype','date','start','end','work_status','ocb.d','cwb.d','Finished'))

#Export data
write.csv(dalal.final, file="dalal.csv", row.names = FALSE)




