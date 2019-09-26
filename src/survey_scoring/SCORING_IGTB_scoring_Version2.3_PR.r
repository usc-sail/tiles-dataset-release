# NOTICE
# This software (or technical data) was produced for the U.S. Government under contract 
# 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14, 
# ALT IV (MAY 2014) or (DEC 2007).
# ©2019 The MITRE Corporation. All Rights Reserved. Approved for Public Release; Distribution Unlimited. Case Number 19-2656



####################################################
#Version 2.3 - 12 Aug 2019

#Prior version: 2.2 - 25 Feb 2019
#Prior version: 2.1 - 1 Nov 2018

# Changes since version 2.2:
# * added copyright information
# * deleted scoring code for Shipley Abstraction and Shipley Vocabulary (licensing constraints)
# * updated downstream references to Shipley data elements
# Changes from version 2.1 to 2.2:
# * Added code to reverse response scale coding on PSQI item 9 (psqi9); original
#   survey had response coding in wrong order for that item

#Changes from version 2.0 to 2.1:
# * bug fix in mode imputation code for iod-od and panas-negative scores
####################################################



#####################Data Import####################

#Install packages "readr", plyr", "dplyr" if not already installed. 
#Optionally, install package "summarytools" to facilitate validation

#install.packages("readr")
#install.packages("plyr")
#install.packages("dplyr")
#install.packages("summarytools")

library(readr)
library(plyr)
library(dplyr)
library(summarytools)

################# USER INPUTS ######################

#Set working directory path
#This directory should contain (in csv format) the IGTB file(s) that you wish to score 
setwd("Directory path (minus file name(s)")

###Define a name for the output file subdirectory (name only, in quotes, not the full path)###
OutputDir <- "Output12Aug2019"

########### End User Inputs #######################



# Create a list of all csv files in the working directory that include the string "IGTB" in their filenames
# Note: update the pattern matching details, as necessary, to specify relevant filenames in your local setting
files <- list.files(pattern = "IGTB.+?csv")

#Create an output file subdirectory within the current working directory, using the 
#name defined in OutputDir variable
dir.create(OutputDir)

#Read in LEGACY format Qualtrics IGTB file(s) in csv format. Note: this process will only work over legacy csv files, 
#as legacy csv file structure is assumed when parsing out column labels. If you are working with 
#IGTB data pulled via API or other means, you will need to update the ingest process accordingly to account 
#for structural differences.

#Read in column labels from first and second rows of each input file; replace labels from Row1 with labels from Row2 for 
#first 10 columns (i.e., replace Row1 label values "V1" through "V10" with corresponding text labels;
#read in data, starting with Row 3

csvfilelist <- lapply(files, function(x){
                   col_names_row1 <- names(read_csv(x, n_max = 0))
                   col_names_row2 <- names(read_csv(x, skip = 1, n_max = 0))
                   col_names_merged <- col_names_row1
                   col_names_merged[1:10] = col_names_row2[1:10]
                   read.csv(x,col.names = col_names_merged, skip = 1, stringsAsFactors=FALSE)
                   }
                   )
names(csvfilelist) <- files

#Create master IGTB data table containing all raw Qualtrics item-level responses
test <- rbind.fill(csvfilelist)  



#########Begin data processing and scoring ##########

#Create a new variable to flag incomplete IGTB sessions
test$igtb.incomplete <- ifelse(test$Finished!=1,1,"")

## version 2.3 update ##
####Shipley Vocabulary and Shipley Abstraction scoring code has been omitted from 
####version 2.3 of the scoring code, to allow the code to be publicly released without
####violating Shipley licensing restrictions


##########################  IRB  ########################
# TASK PERFORMANCE
# Williams & Anderson (1991) in-role behavior (IRB)  

#irb1	1	Adequately completes assigned duties.
#irb2	2	Fulfills responsibilities specified in job description.
#irb3	3	Performs tasks that are expected of you.
#irb4	4	Meets formal performance requirements of the job.
#irb5	5	Engages in activities that will directly affect your performance evaluation.
#irb6	6	Neglects aspects of the job you are obligated to perform.
#irb7	7	Fails to perform essential duties.

#Create IRB data frame
irb_orig <- data.frame(test$Name,test$irb1,test$irb2,test$irb3,test$irb4,test$irb5,test$irb6,test$irb7)

names(irb_orig) <- c('ID',
              'irb1','irb2','irb3','irb4','irb5','irb6','irb7') 

#(Optional)Check value ranges
apply(irb_orig[c('irb1','irb2','irb3','irb4','irb5','irb6','irb7')], 2, table,exclude=NULL)


#################### MODE imputation #####################

#Define mode imputation function
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
  #Note: when rouding off a 5, R uses the IEC 60559 standard, which stipulates
  #that 5's should be rounded to the nearest even digit. Thus,  a value of 
  #2.5 will be rounded down to 2, whereas a value of 3.5 will be rounded up to 4
  
  if (nmodes!=1){
    avemode <- round(mean(ux[modes]))
    return(avemode)
  } else {
    return(ux[modes])
  }
}

irb_mode = irb_orig #Create a copy of the data frame for use in running missing item-level imputation logic

#Reverse scores for irb6 and irb7
irb_mode$irb6R = 8 - irb_mode$irb6
irb_mode$irb7R = 8 - irb_mode$irb7

#(Optional)Check recodes
table(irb_mode$irb6,irb_mode$irb6R)
table(irb_mode$irb7,irb_mode$irb7R)

#Rename
irb_mode$irb6=irb_mode$irb6R
irb_mode$irb7=irb_mode$irb7R

#(Optional)Check values
table(irb_mode$irb6)
table(irb_mode$irb7)


#For each participant/row, carry out imputation of missing item-level responses using 'getmode' function (see above),
#according to the following logic:
  #1. If 50% or more of the item-level responses for the measure are missing for a participant, do no imputation
  #2. Else, compute modal value(s) over remaining (non-missing) item-level responses
  #3. If number of modal values = 1, replace missing item-level values with modal value
  #4. Else, replace missing item-level values with the average modal value, after rounding to nearest integer
#Note: When rounding off a 5, R rounds to the nearest even digit (thus, 2.5 is rounded down to 2, while 3.5 is rounded up to 4),
#consistent with IEC 60559 standard. See R documentation for more details.


# Get all the locations where there is an NA
ind.irb <- which(is.na(irb_mode), arr.ind=TRUE)

if(NROW(ind.irb)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
irb_mode[ind.irb] <- apply(irb_mode[c('irb1','irb2','irb3','irb4','irb5','irb6','irb7')],MARGIN=1,FUN=getmode)[ind.irb[,1]]
}


#Create a new copy of the IRB data frame, including mode imputations of missing item-level responses
irb <- irb_mode 

#Explicitly label reverse-coded items
irb$neg.irb6 = irb$irb6
irb$neg.irb7 = irb$irb7

irb$neg.irb = irb$neg.irb6 + irb$neg.irb7 
irb$pos.irb = irb$irb1 + irb$irb2 + irb$irb3 + irb$irb4 + irb$irb5

#Compute count of missing item-level reponses remaining after mode imputation. Store value in a new column ('na_count')
irb$na_count <- apply(is.na(irb[c('irb1','irb2','irb3','irb4','irb5','irb6','irb7')]), 1, sum)

#If na_count value is >=1, set composite irb score to NA, else sum subcomponent values
irb$irb = ifelse(irb$na_count>=1,NA,irb$pos.irb + irb$neg.irb)


#(Optional)Check range (7-49)
table(irb$irb,exclude=NULL)

#(Optional) Check #NAs should match number in irb columns 2-8, after mode imputation
table(irb$na_count,exclude=NULL)

#Create composite score data frame from IRB
irbcomposites <- data.frame(irb$ID,irb$irb)
names(irbcomposites) <- c('ID','irb')


#########################  ITP   ##########################

# TASK PERFORMANCE
# Griffin et al. (2007) individual task proficiency (ITP)

#1.	Carried out the core parts of your job well
#2.	Completed your core tasks well using the standard procedures
#3.	Ensured your tasks were completed properly

#Create ITP data frame
itp = data.frame(test$Name,test$itp1,test$itp2,test$itp3)

names(itp) <- c('ID','itp1','itp2','itp3') 

#(Optional)Check value ranges
apply(itp[c('itp1','itp2','itp3')], 2, table,exclude=NULL)

#### REMOVE
#Define number of rows/participants
#itp.obs <- nrow(itp)
#### /REMOVE

#Compute count of missing item-level responses per participant. Store value in a new column ('na_count').
itp$na_count <- apply(is.na(itp[c('itp1','itp2','itp3')]), 1, sum)

#Compute summary scores based on mean item-level values. Generate summary score of NA if 2 or more (i.e., >= 50%)
#of item-level responses are NA
itp$itp <- ifelse(itp$na_count>=2,NA, 
                           apply(itp[c('itp1','itp2','itp3')], 1, mean, na.rm=TRUE))

#(Optional)Check range (1-5) #NAs (should match number #<=2 in na_count)
summary(itp$itp,exclude=NULL)
table(itp$na_count,exclude=NULL)

#Create composite score data frame for ITP
itpcomposites = data.frame(itp$ID,itp$itp)
names(itpcomposites)<-c('ID','itp')


#########################  OCB ##########################

# Organizational Citizenship Behaviors
# Fox et al.'s (2012) Organizational Citizenship Behavior Checklist (OCB-C)

#1.	  Picked up a meal for others at work.
#2.	  Took time to advise, coach, or mentor a co-worker.
#3.	  Helped a co-worker learn new skills or shared job knowledge.
#4.	  Helped new employees get oriented to the job.
#5.	  Lent a compassionate ear when someone had a work problem.
#6.	  Lent a compassionate ear when someone had a personal problem.
#7.	  Changed vacation schedule, workdays, or shifts to accommodate co-worker's needs.
#8.	  Offered suggestions to improve how work is done.
#9.	  Offered suggestions for improving the work environment.
#10.	Finished something for co-worker who had to leave early.
#11.	Helped a less capable co-worker lift a heavy box or other object.
#12.	Helped a co-worker who had too much to do.
#13.	Volunteered for extra work assignments.
#14.	Took phone messages for absent or busy co-worker.
#15.	Said good things about your employer in front of others.
#16.	Gave up meal and other breaks to complete work.
#17.	Volunteered to help a co-worker deal with a difficult customer, vendor, or co-worker.
#18.	Went out of the way to give co-worker encouragement or express appreciation.
#19.	Decorated, straightened up, or otherwise beautified common work space.
#20.	Defended a co-worker who was being 'put-down' or spoken ill of by other co-workers or supervisor.

#Create OCB data frame
ocb_orig = data.frame(test$Name,test$ocb1,test$ocb2,test$ocb3,test$ocb4,test$ocb5,test$ocb6,test$ocb7,test$ocb8,test$ocb9,
      test$ocb10,test$ocb11,test$ocb12,test$ocb13,test$ocb14,test$ocb15,test$ocb16,test$ocb17,test$ocb18,
      test$ocb19,test$ocb20)

names(ocb_orig) <- c('ID','ocb1','ocb2','ocb3','ocb4','ocb5','ocb6','ocb7','ocb8','ocb9','ocb10',
      'ocb11','ocb12','ocb13','ocb14','ocb15','ocb16','ocb17','ocb18','ocb19','ocb20')

#(Optional)Check value ranges
apply(ocb_orig[c('ocb1','ocb2','ocb3','ocb4','ocb5','ocb6','ocb7','ocb8','ocb9','ocb10',
                 'ocb11','ocb12','ocb13','ocb14','ocb15','ocb16','ocb17','ocb18','ocb19','ocb20')], 2, table,exclude=NULL)


###################### MODE imputation ######################

ocb_mode = ocb_orig #Create a copy of the dataframe for use in carrying out missing item-level value imputations

# Get all the locations where there is an NA
ind.ocb <- which(is.na(ocb_mode), arr.ind=TRUE)

if(NROW(ind.ocb)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
ocb_mode[ind.ocb] = apply(ocb_mode[c('ocb1','ocb2','ocb3','ocb4','ocb5','ocb6','ocb7',
                                     'ocb8','ocb9','ocb10','ocb11','ocb12','ocb13','ocb14',
                                     'ocb15','ocb16','ocb17','ocb18','ocb19','ocb20')],MARGIN=1,FUN=getmode)[ind.ocb[,1]]
}

#Create a new copy of the data frame, incorporating mode imputation outputs
ocb = ocb_mode

#Compute count of missing item-level reponses that remain after mode imputation. Store value in a new column ('na_count')
ocb$na_count <- rowSums(is.na(ocb[,-1]))

#(Optional)Check number of NAs
table(ocb$na_count,exclude=NULL)

#If na_count value is >=1, set composite ocb score to NA, else score by summing item-level values
ocb$ocb = ifelse(ocb$na_count>=1, NA, ocb$ocb1 + ocb$ocb2 + ocb$ocb3 + ocb$ocb4 + ocb$ocb5 + ocb$ocb6 + ocb$ocb7 + ocb$ocb8 + ocb$ocb9 + ocb$ocb10 + 
                   ocb$ocb11 + ocb$ocb12 + ocb$ocb13 + ocb$ocb14 + ocb$ocb15 + ocb$ocb16 + ocb$ocb17 + ocb$ocb18 + ocb$ocb19 + ocb$ocb20)

#(Optional)Check range (20-100) and number of NAs v na_count
table(ocb$ocb,exclude=NULL)

#Create composite score data framee for OCB
ocbcomposites = data.frame(ocb$ID,ocb$ocb)
names(ocbcomposites)<-c('ID','ocb')

#########################  IOD  ###########################

# Counterproductive Work Behaviors
# Interpersonal and Organizational Deviance Scale Items (iod) (Bennett & Robinson, 2000)

#1.	(I) Made fun of someone at work 
#2.	(I) Said something hurtful to someone at work
#3.	(I) Made an ethnic, religious, or racial remark or joke at work
#4.	(I) Cursed at someone at work
#5.	(I) Played a mean prank on someone at work
#6.	(I) Acted rudely toward someone at work
#7.	(I) Publicly embarrassed someone at work
#8.	  (O) Taken property from work without permission
#9.	  (O) Spent too much time fantasizing or daydreaming instead of working
#10.	(O) Falsified a receipt to get reimbursed for more money than you spent on business expenses
#11.	(O) Taken an additional or a longer break than is acceptable at your workplace
#12.	(O) Come in late to work without permission
#13.	(O) Littered your work environment
#14.	(O) Neglected to follow your boss's instructions
#15.	(O) Intentionally worked slower than you could have worked
#16.	(O) Discussed confidential company information with an unauthorized person
#17.	(O) Used an illegal drug or consumed alcohol on the job
#18.	(O) Put little effort into your work
#19.	(O) Dragged out work in order to get overtime

# organizational deviance = 12 items
# interpersonal deviance = 7 items

#Create IOD data frame
iod_orig = data.frame(test$Name,test$iod1,test$iod2,test$iod3,test$iod4,test$iod5,test$iod6,test$iod7,test$iod8,
                 test$iod9,test$iod10,test$iod11,test$iod12,test$iod13,test$iod14,test$iod15,test$iod16,test$iod17,
                 test$iod18,test$iod19)

names(iod_orig) <- c('ID',
              'iod1','iod2','iod3','iod4','iod5','iod6','iod7','iod8','iod9','iod10',
              'iod11','iod12','iod13','iod14','iod15','iod16','iod17','iod18','iod19')

#(Optional) Check response value ranges
apply(iod_orig[c('iod1','iod2','iod3','iod4','iod5','iod6','iod7','iod8','iod9','iod10',
                  'iod11','iod12','iod13','iod14','iod15','iod16','iod17','iod18','iod19')], 2, table,exclude=NULL)


######################### MODE imputation #####################

#Create subscale-specific data frames for interpersonal deviance (ID) and organizational deviance (OD) subscales
iod_id_mode <- iod_orig[,c("ID", "iod1", "iod2", "iod3", "iod4", "iod5", "iod6", "iod7")]
iod_od_mode <- iod_orig[,c("ID", "iod8", "iod9", "iod10", "iod11", "iod12","iod13","iod14","iod15","iod16", "iod17","iod18","iod19")]


# Get all the locations where there is an NA
ind.iod.id <- which(is.na(iod_id_mode), arr.ind=TRUE)

if(NROW(ind.iod.id)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
iod_id_mode[ind.iod.id] = apply(iod_id_mode[c('iod1', 'iod2', 'iod3', 'iod4', 'iod5', 'iod6', 'iod7')],MARGIN=1,FUN=getmode)[ind.iod.id[,1]]
}


# Get all the locations where there is an NA
ind.iod.od <- which(is.na(iod_od_mode), arr.ind=TRUE)

if(NROW(ind.iod.od)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
iod_od_mode[ind.iod.od] = apply(iod_od_mode[c('iod8', 'iod9', 'iod10', 'iod11', 'iod12','iod13',
                                              'iod14','iod15','iod16', 'iod17','iod18','iod19')],MARGIN=1,FUN=getmode)[ind.iod.od[,1]]
}


#Create new data frames that now incorporate imputed missing values
iod_id <- iod_id_mode
iod_od <- iod_od_mode

#Compute count of missing item-level reponses that remain after imputation. Store value in a new column ('na_count')
iod_id$na_count <- apply(is.na(iod_id), 1, sum)
iod_od$na_count <- apply(is.na(iod_od), 1, sum)

#If na_count value is >=1, set composite iod scores to NA, else score by summing over item-level values
iod_id$inter.deviance = ifelse(iod_id$na_count>=1,NA, iod_id$iod1 + iod_id$iod2 + iod_id$iod3 + 
                                 iod_id$iod4 + iod_id$iod5 + iod_id$iod6 + iod_id$iod7)
iod_od$org.deviance = ifelse(iod_od$na_count>=1,NA, iod_od$iod8 + iod_od$iod9 + iod_od$iod10 + 
                               iod_od$iod11 + iod_od$iod12 + iod_od$iod13 + iod_od$iod14 + iod_od$iod15 + 
                               iod_od$iod16 + iod_od$iod17 + iod_od$iod18 + iod_od$iod19)

#(Optional) Check # of nas
table(iod_id$na_count,exclude=NULL)
table(iod_od$na_count,exclude=NULL)

#Merge composite scores from iod_id and iod_od into a single data frame, merging based on ID value
iodcomposites <- merge(iod_id[ , c("ID","inter.deviance")], iod_od[ , c("ID", "org.deviance")], by = "ID")
names(iodcomposites)<-c('ID','inter.deviance','org.deviance')

#(Optional) Check number of rows of merged file
iod_od_id.obs <- nrow(iodcomposites)

#(Optional)Check inter and org deviance ranges (7-49 and 12-84 respectively) and compare to na_count above
summary(iodcomposites)



########################## BFI-2 ##############################

#extraversion: 1, 6, 11R, 16R, 21, 26R, 31R, 36R, 41, 46, 51R, 56
#agreeableness: 2, 7, 12R, 17R, 22R, 27, 32, 37R, 42R, 47R, 52, 57
#conscientiousness: 3R, 8R, 13, 18, 23R, 28R, 33, 38, 43, 48R, 53, 58R
#neuroticism: 4R, 9R, 14, 19, 24R, 29R, 34, 39, 44R, 49R, 54, 59
#openness: 5R, 10, 15, 20, 25R, 30R, 35, 40, 45R, 50R, 55R, 60  

#1=disagree strongly
#2=disagree a little
#3=neutral; no opinion
#4=agree a little
#5=agree strongly

#Create BFI data frame

bfi = data.frame(test$Name,test$bfi1,test$bfi2,test$bfi3,test$bfi4,test$bfi5,test$bfi6,test$bfi7,
      test$bfi8,test$bfi9,test$bfi10,test$bfi11,test$bfi12,test$bfi13,test$bfi14,test$bfi15,test$bfi16,
      test$bfi17,test$bfi18,test$bfi19,test$bfi20,test$bfi21,test$bfi22,test$bfi23,test$bfi24,test$bfi25,
      test$bfi26,test$bfi27,test$bfi28,test$bfi29,test$bfi30,test$bfi31,test$bfi32,test$bfi33,test$bfi34,
      test$bfi35,test$bfi36,test$bfi37,test$bfi38,test$bfi39,test$bfi40,test$bfi41,test$bfi42,test$bfi43,
      test$bfi44,test$bfi45,test$bfi46,test$bfi47,test$bfi48,test$bfi49,test$bfi50,test$bfi51,test$bfi52,
      test$bfi53,test$bfi54,test$bfi55,test$bfi56,test$bfi57,test$bfi58,test$bfi59,test$bfi60)

names(bfi) <- c('ID',
              'bfi1','bfi2','bfi3','bfi4','bfi5','bfi6','bfi7','bfi8','bfi9','bfi10','bfi11','bfi12','bfi13','bfi14',
              'bfi15','bfi16','bfi17','bfi18','bfi19','bfi20','bfi21','bfi22','bfi23','bfi24','bfi25','bfi26','bfi27','bfi28',
              'bfi29','bfi30','bfi31','bfi32','bfi33','bfi34','bfi35','bfi36','bfi37','bfi38','bfi39','bfi40','bfi41','bfi42',
              'bfi43','bfi44','bfi45','bfi46','bfi47','bfi48','bfi49','bfi50','bfi51','bfi52','bfi53','bfi54','bfi55','bfi56',
              'bfi57','bfi58','bfi59','bfi60')

#Create a new data frame into which we will insert transposed values for items with reversed response scales 
bfi.rev <- bfi

#(Optional) Check response values
apply(bfi[c('bfi1','bfi2','bfi3','bfi4','bfi5','bfi6','bfi7','bfi8','bfi9','bfi10','bfi11','bfi12','bfi13','bfi14',
                  'bfi15','bfi16','bfi17','bfi18','bfi19','bfi20','bfi21','bfi22','bfi23','bfi24','bfi25','bfi26','bfi27','bfi28',
                  'bfi29','bfi30','bfi31','bfi32','bfi33','bfi34','bfi35','bfi36','bfi37','bfi38','bfi39','bfi40','bfi41','bfi42',
                  'bfi43','bfi44','bfi45','bfi46','bfi47','bfi48','bfi49','bfi50','bfi51','bfi52','bfi53','bfi54','bfi55','bfi56',
                  'bfi57','bfi58','bfi59','bfi60')], 2, table)


######################## Item-level score reversals ##########################

#Reverse scores for the 30 items with reverse coding
bfi.rev$bfi3R = (6 - bfi.rev$bfi3)
bfi.rev$bfi4R = (6 - bfi.rev$bfi4)
bfi.rev$bfi5R = (6 - bfi.rev$bfi5)
bfi.rev$bfi8R = (6 - bfi.rev$bfi8)
bfi.rev$bfi9R = (6 - bfi.rev$bfi9)
bfi.rev$bfi11R = (6 - bfi.rev$bfi11)
bfi.rev$bfi12R = (6 - bfi.rev$bfi12)
bfi.rev$bfi16R = (6 - bfi.rev$bfi16)
bfi.rev$bfi17R = (6 - bfi.rev$bfi17)
bfi.rev$bfi22R = (6 - bfi.rev$bfi22)
bfi.rev$bfi23R = (6 - bfi.rev$bfi23)
bfi.rev$bfi24R = (6 - bfi.rev$bfi24)
bfi.rev$bfi25R = (6 - bfi.rev$bfi25)
bfi.rev$bfi26R = (6 - bfi.rev$bfi26)
bfi.rev$bfi28R = (6 - bfi.rev$bfi28)
bfi.rev$bfi29R = (6 - bfi.rev$bfi29)
bfi.rev$bfi30R = (6 - bfi.rev$bfi30)
bfi.rev$bfi31R = (6 - bfi.rev$bfi31)
bfi.rev$bfi36R = (6 - bfi.rev$bfi36)
bfi.rev$bfi37R = (6 - bfi.rev$bfi37)
bfi.rev$bfi42R = (6 - bfi.rev$bfi42)
bfi.rev$bfi44R = (6 - bfi.rev$bfi44)
bfi.rev$bfi45R = (6 - bfi.rev$bfi45)
bfi.rev$bfi47R = (6 - bfi.rev$bfi47)
bfi.rev$bfi48R = (6 - bfi.rev$bfi48)
bfi.rev$bfi49R = (6 - bfi.rev$bfi49)
bfi.rev$bfi50R = (6 - bfi.rev$bfi50)
bfi.rev$bfi51R = (6 - bfi.rev$bfi51)
bfi.rev$bfi55R = (6 - bfi.rev$bfi55)
bfi.rev$bfi58R = (6 - bfi.rev$bfi58)

#Create a new data frame that combines the native and reversed items
bfi.new = data.frame(bfi.rev$ID,bfi.rev$bfi1,bfi.rev$bfi2,bfi.rev$bfi3R,bfi.rev$bfi4R,bfi.rev$bfi5R,
      bfi.rev$bfi6,bfi.rev$bfi7,bfi.rev$bfi8R,bfi.rev$bfi9R,bfi.rev$bfi10,bfi.rev$bfi11R,
      bfi.rev$bfi12R,bfi.rev$bfi13,bfi.rev$bfi14,bfi.rev$bfi15,bfi.rev$bfi16R,bfi.rev$bfi17R,
      bfi.rev$bfi18,bfi.rev$bfi19,bfi.rev$bfi20,bfi.rev$bfi21,bfi.rev$bfi22R,bfi.rev$bfi23R,
      bfi.rev$bfi24R,bfi.rev$bfi25R,bfi.rev$bfi26R,bfi.rev$bfi27,bfi.rev$bfi28R,bfi.rev$bfi29R,
      bfi.rev$bfi30R,bfi.rev$bfi31R,bfi.rev$bfi32,bfi.rev$bfi33,bfi.rev$bfi34,bfi.rev$bfi35,
      bfi.rev$bfi36R,bfi.rev$bfi37R,bfi.rev$bfi38,bfi.rev$bfi39,bfi.rev$bfi40,bfi.rev$bfi41, 
      bfi.rev$bfi42R,bfi.rev$bfi43,bfi.rev$bfi44R,bfi.rev$bfi45R,bfi.rev$bfi46,bfi.rev$bfi47R, 
      bfi.rev$bfi48R,bfi.rev$bfi49R,bfi.rev$bfi50R,bfi.rev$bfi51R,bfi.rev$bfi52,bfi.rev$bfi53,
      bfi.rev$bfi54,bfi.rev$bfi55R,bfi.rev$bfi56,bfi.rev$bfi57,bfi.rev$bfi58R,bfi.rev$bfi59, 
      bfi.rev$bfi60)

names(bfi.new) <- c('ID','bfi1','bfi2','bfi3R','bfi4R','bfi5R','bfi6','bfi7','bfi8R','bfi9R','bfi10','bfi11R',
      'bfi12R','bfi13','bfi14','bfi15','bfi16R','bfi17R','bfi18','bfi19','bfi20','bfi21','bfi22R','bfi23R', 
      'bfi24R','bfi25R','bfi26R','bfi27','bfi28R','bfi29R','bfi30R','bfi31R','bfi32','bfi33','bfi34',
      'bfi35','bfi36R','bfi37R','bfi38','bfi39','bfi40','bfi41','bfi42R','bfi43','bfi44R','bfi45R',
      'bfi46','bfi47R','bfi48R','bfi49R','bfi50R','bfi51R','bfi52','bfi53','bfi54','bfi55R','bfi56',
      'bfi57','bfi58R','bfi59','bfi60')

#extraversion: 1, 6, 11R, 16R, 21, 26R, 31R, 36R, 41, 46, 51R, 56
#agreeableness: 2, 7, 12R, 17R, 22R, 27, 32, 37R, 42R, 47R, 52, 57
#conscientiousness: 3R, 8R, 13, 18, 23R, 28R, 33, 38, 43, 48R, 53, 58R
#neuroticism: 4R, 9R, 14, 19, 24R, 29R, 34, 39, 44R, 49R, 54, 59
#openness: 5R, 10, 15, 20, 25R, 30R, 35, 40, 45R, 50R, 55R, 60  

#Create columns (place holders) for future mean values for n participants, where n=num observations in bfi.new
bfi.new.obs <- nrow(bfi.new)
bfi.new$extraversion = rep(0,bfi.new.obs)
bfi.new$agreeableness = rep(0,bfi.new.obs)
bfi.new$conscientiousness = rep(0,bfi.new.obs)
bfi.new$neuroticism = rep(0,bfi.new.obs)
bfi.new$openness = rep(0,bfi.new.obs)

#Compute number of NAs for each BFI subscale and store computed values in new columns
bfi.new$extraversion_nas <- apply(is.na(bfi.new[,c('bfi1','bfi6','bfi11R','bfi16R','bfi21','bfi26R','bfi31R',
                                                   'bfi36R','bfi41','bfi46','bfi51R','bfi56')]), 1, sum)
bfi.new$agreeableness_nas <- apply(is.na(bfi.new[,c('bfi2', 'bfi7', 'bfi12R', 'bfi17R', 'bfi22R', 'bfi27', 
                                                    'bfi32', 'bfi37R', 'bfi42R', 'bfi47R', 'bfi52', 'bfi57')]),1,sum)
bfi.new$conscientiousness_nas <- apply(is.na(bfi.new[,c('bfi3R', 'bfi8R', 'bfi13', 'bfi18', 'bfi23R', 'bfi28R', 
                                                        'bfi33', 'bfi38', 'bfi43', 'bfi48R', 'bfi53', 'bfi58R')]),1,sum)
bfi.new$neuroticism_nas <- apply(is.na(bfi.new[,c('bfi4R', 'bfi9R', 'bfi14', 'bfi19', 'bfi24R', 'bfi29R', 'bfi34', 
                                                  'bfi39', 'bfi44R', 'bfi49R', 'bfi54', 'bfi59')]),1,sum)
bfi.new$openness_nas <- apply(is.na(bfi.new[,c('bfi5R', 'bfi10', 'bfi15', 'bfi20', 'bfi25R', 'bfi30R', 'bfi35', 
                                              'bfi40', 'bfi45R', 'bfi50R', 'bfi55R', 'bfi60')]),1,sum)

#Compute per-subscale summary scores. Score=NA if >=50% of item-level responses in the subscale are missing.NAs are otherwise
#ignored when computing mean.
bfi.new$extraversion <- ifelse(bfi.new$extraversion_nas >= 6,NA, apply(bfi.new[c('bfi1','bfi6','bfi11R','bfi16R','bfi21','bfi26R','bfi31R',
                                                   'bfi36R','bfi41','bfi46','bfi51R','bfi56')], 1, mean, na.rm=TRUE))
bfi.new$agreeableness <- ifelse(bfi.new$agreeableness_nas >= 6,NA, apply(bfi.new[c('bfi2', 'bfi7', 'bfi12R', 'bfi17R', 'bfi22R', 'bfi27', 
                                                    'bfi32', 'bfi37R', 'bfi42R', 'bfi47R', 'bfi52', 'bfi57')], 1, mean, na.rm=TRUE))
bfi.new$conscientiousness <- ifelse(bfi.new$conscientiousness_nas >= 6,NA, apply(bfi.new[c('bfi3R', 'bfi8R', 'bfi13', 'bfi18', 'bfi23R', 'bfi28R', 
                                                        'bfi33', 'bfi38', 'bfi43', 'bfi48R', 'bfi53', 'bfi58R')], 1, mean, na.rm=TRUE))
bfi.new$neuroticism <- ifelse(bfi.new$neuroticism_nas >= 6,NA, apply(bfi.new[c('bfi4R', 'bfi9R', 'bfi14', 'bfi19', 'bfi24R', 'bfi29R', 'bfi34', 
                                                  'bfi39', 'bfi44R', 'bfi49R', 'bfi54', 'bfi59')], 1, mean, na.rm=TRUE))
bfi.new$openness <- ifelse(bfi.new$openness_nas >= 6,NA, apply(bfi.new[c('bfi5R', 'bfi10', 'bfi15', 'bfi20', 'bfi25R', 'bfi30R', 'bfi35', 
                                               'bfi40', 'bfi45R', 'bfi50R', 'bfi55R', 'bfi60')], 1, mean, na.rm=TRUE))


#(Optional)Check summary score ranges (1-5) and compare to na_counts

table(bfi.new$extraversion_nas,exclude=NULL)
summary(bfi.new$extraversion)

table(bfi.new$agreeableness_nas,exclude=NULL)
summary(bfi.new$agreeableness)

table(bfi.new$conscientiousness_nas,exclude=NULL)
summary(bfi.new$conscientiousness)

table(bfi.new$neuroticism_nas,exclude=NULL)
summary(bfi.new$neuroticism)

table(bfi.new$openness_nas,exclude=NULL)
summary(bfi.new$openness)

#Create composite score data frame for BFI-2
bficomposites = data.frame(bfi.new$ID,bfi.new$extraversion,bfi.new$agreeableness,bfi.new$conscientiousness,
                bfi.new$neuroticism,bfi.new$openness)

names(bficomposites) <- c('ID','extraversion','agreeableness','conscientiousness',
                'neuroticism','openness')
                             

##########################  PANAS-X  #########################

#Create PANAS-X data frame
panas_orig = data.frame(test$Name,test$pan1,test$pan2,test$pan3,test$pan4,test$pan5,test$pan6,test$pan7,
                   test$pan8,test$pan9,test$pan10,test$pan11,test$pan12,test$pan13,test$pan14,test$pan15,test$pan16,
                   test$pan17,test$pan18,test$pan19,test$pan20,test$pan21,test$pan22,test$pan23,test$pan24,
                   test$pan25,test$pan26,test$pan27,test$pan28,test$pan29,test$pan30,test$pan31,test$pan32,
                   test$pan33,test$pan34,test$pan35,test$pan36,test$pan37,test$pan38,test$pan39,test$pan40,
                   test$pan41,test$pan42,test$pan43,test$pan44,test$pan45,test$pan46,test$pan47,
                   test$pan48,test$pan49,test$pan50,test$pan51,test$pan52,test$pan53,test$pan54,test$pan55,
                   test$pan56,test$pan57,test$pan58,test$pan59,test$pan60)

names(panas_orig) <- c('ID',
              'pan1','pan2','pan3','pan4','pan5','pan6','pan7','pan8','pan9','pan10','pan11','pan12','pan13','pan14','pan15','pan16','pan17','pan18','pan19','pan20',
              'pan21','pan22','pan23','pan24','pan25','pan26','pan27','pan28','pan29','pan30','pan31','pan32','pan33','pan34','pan35','pan36','pan37','pan38','pan39','pan40',
              'pan41','pan42','pan43','pan44','pan45','pan46','pan47','pan48','pan49','pan50','pan51','pan52','pan53','pan54','pan55','pan56','pan57','pan58','pan59','pan60')

#(Optional) Check response values
apply(panas_orig[c('pan1','pan2','pan3','pan4','pan5','pan6','pan7','pan8','pan9','pan10','pan11','pan12','pan13','pan14','pan15','pan16','pan17','pan18','pan19','pan20',
                   'pan21','pan22','pan23','pan24','pan25','pan26','pan27','pan28','pan29','pan30','pan31','pan32','pan33','pan34','pan35','pan36','pan37','pan38','pan39','pan40',
                   'pan41','pan42','pan43','pan44','pan45','pan46','pan47','pan48','pan49','pan50','pan51','pan52','pan53','pan54','pan55','pan56','pan57','pan58','pan59','pan60')], 2, table)


###################### MODE imputation #########################

#Create subscale-specific data frames for positive and negative PANAS subscales/scores
panas_pos_mode <- panas_orig[,c('ID', 'pan31', 'pan25', 'pan3', 'pan52', 'pan47', 'pan37', 'pan13', 'pan55', 'pan39', 'pan8')]
panas_neg_mode <- panas_orig[,c('ID', 'pan18', 'pan44', 'pan34', 'pan40', 'pan11', 'pan38', 'pan32', 'pan42', 'pan26', 'pan50')]


# Impute for panas_pos
# Get all the locations where there is an NA
ind.pan.pos <- which(is.na(panas_pos_mode), arr.ind=TRUE)

if(NROW(ind.pan.pos)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
panas_pos_mode[ind.pan.pos] = apply(panas_pos_mode[c('pan31','pan25','pan3','pan52','pan47',
                                                     'pan37','pan13','pan55','pan39','pan8')],MARGIN=1,FUN=getmode)[ind.pan.pos[,1]]
}

# Impute for panas_neg
# Get all the locations where there is an NA
ind.pan.neg <- which(is.na(panas_neg_mode), arr.ind=TRUE)

if(NROW(ind.pan.neg)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
panas_neg_mode[ind.pan.neg] = apply(panas_neg_mode[c('pan18','pan44','pan34','pan40','pan11',
                                                     'pan38','pan32','pan42','pan26','pan50')],MARGIN=1,FUN=getmode)[ind.pan.neg[,1]]
}

#Create data frame copies that now incorporate imputed values for missing item-level responses
panas_pos <- panas_pos_mode
panas_neg <- panas_neg_mode

#negative affect: 10 items
#positive affect: 10 items
#fear:             6 items
#hostility:        6 items
#guilt:            6 items
#sadness:          5 items
#joviality:        8 items
#self-assurance:   6 items
#attentiveness:    4 items
#shyness:          4 items
#fatigue:          4 items
#serenity:         3 items
#surpise:          3 items

#pan1 = cheerful
#pan2 = disgusted
#pan3 = attentive
#pan4 = bashful
#pan5 = sluggish
#pan6 = daring
#pan7 = suprised
#pan8 = strong
#pan9 = scornful
#pan10 = relaxed
#pan11 = irratable
#pan12 = delighted
#pan13 = inspired
#pan14 = fearless
#pan15 = disgusted with self
#pan16 = sad
#pan17 = calm
#pan18 = afraid
#pan19 = tired
#pan20 = amazed
#pan21 = shaky
#pan22 = happy
#pan23 = timid
#pan24 = alone
#pan25 = alert
#pan26 = upset
#pan27 = angry
#pan28 = bold
#pan29 = blue
#pan30 = shy
#pan31 = active
#pan32 = guilty
#pan33 = joyful
#pan34 = nervous
#pan35 = lonely
#pan36 = sleepy
#pan37 = excited
#pan38 = hostile
#pan39 = proud
#pan40 = jittery
#pan41 = lively
#pan42 = ashamed
#pan43 = at ease
#pan44 = scared
#pan45 = drowsy
#pan46 = angry at self
#pan47 = enthusiastic
#pan48 = downhearted
#pan49 = sheepish
#pan50 = distressed
#pan51 = blameworthy
#pan52 = determined
#pan53 = frightened
#pan54 = astonished
#pan55 = interested
#pan56 = loathing
#pan57 = confident
#pan58 = energetic
#pan59 = concentrating
#pan60 = dissatisfied with self

#Compute count of missing item-level reponses that remain after imputation. Store value in a new column ('na_count')
panas_pos$na_count <- apply(is.na(panas_pos), 1, sum)
panas_neg$na_count <- apply(is.na(panas_neg), 1, sum)

#If na_count value is >=1, set composite panas scores to NA, otherwise score by summing over item-level values
panas_pos$pos.affect = ifelse(panas_pos$na_count>=1,NA, panas_pos$pan31 + panas_pos$pan25 + panas_pos$pan3 + 
                                panas_pos$pan52 + panas_pos$pan47 + panas_pos$pan37 + panas_pos$pan13 + 
                                panas_pos$pan55 + panas_pos$pan39 + panas_pos$pan8)
panas_neg$neg.affect = ifelse(panas_neg$na_count>=1,NA, panas_neg$pan18 + panas_neg$pan44 + panas_neg$pan34 + 
                                panas_neg$pan40 + panas_neg$pan11 + panas_neg$pan38 + panas_neg$pan32 + 
                                panas_neg$pan42 + panas_neg$pan26 + panas_neg$pan50)

#(Optional) Check summary score ranges (10-50) and compare to na_counts
table(panas_pos$na_count,exclude=NULL)
summary(panas_pos$pos.affect)

table(panas_neg$na_count,exclude=NULL)
summary(panas_neg$neg.affect)


#Merge composite scores from panas_pos and panas_neg into a single data frame, merging based on ID value
panascomposites <- merge(panas_pos[ , c("ID","pos.affect")], panas_neg[ , c("ID", "neg.affect")], by = "ID")

#(Optional) Check number of rows in merged file
panas.obs <- nrow(panascomposites)

summary(panascomposites$pos.affect)
summary(panascomposites$neg.affect)

############################## STAI ###############################

#STAI
#TRAIT: scale 1-4 (almost never, sometimes, often, almost always)

#Create STAI-Trait data frame
stai_orig = data.frame(test$Name,test$tr1,test$tr2,test$tr3,test$tr4,test$tr5,test$tr6,test$tr7,test$tr8,test$tr9,test$tr10,
                  test$tr11,test$tr12,test$tr13,test$tr14,test$tr15,test$tr16,test$tr17,test$tr18,test$tr19,
                  test$tr20)

names(stai_orig) <- c('ID',
              'tr1','tr2','tr3','tr4','tr5','tr6','tr7','tr8','tr9','tr10',
              'tr11','tr12','tr13','tr14','tr15','tr16','tr17','tr18','tr19','tr20') 

#(Optional) Check response values
apply(stai_orig[c('tr1','tr2','tr3','tr4','tr5','tr6','tr7','tr8','tr9','tr10',
                   'tr11','tr12','tr13','tr14','tr15','tr16','tr17','tr18','tr19','tr20')], 2, table)

######################## MODE imputation ##########################

#Create a copy of the stai data frame for use in item-level mode imputations
stai_mode <- stai_orig

#Reverse scores for reverse-coded items
stai_mode$tr1R <- 5-stai_mode$tr1 
stai_mode$tr3R <- 5-stai_mode$tr3
stai_mode$tr6R <- 5-stai_mode$tr6
stai_mode$tr7R <- 5-stai_mode$tr7
stai_mode$tr10R <- 5-stai_mode$tr10
stai_mode$tr13R <- 5-stai_mode$tr13
stai_mode$tr14R <- 5-stai_mode$tr14
stai_mode$tr16R <- 5-stai_mode$tr16
stai_mode$tr19R <- 5-stai_mode$tr19

#Drop non-reversed item variants 
stai_mode <- subset(stai_mode, select = -c(tr1,tr3,tr6,tr7,tr10,tr13,tr14,tr16,tr19))

# Get all the locations where there is an NA
ind.stai <- which(is.na(stai_mode), arr.ind=TRUE)

if(NROW(ind.stai)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
stai_mode[ind.stai] = apply(stai_mode[c('tr1R','tr2','tr3R','tr4','tr5','tr6R','tr7R',
                                        'tr8','tr9','tr10R','tr11','tr12','tr13R','tr14R',
                                        'tr15','tr16R','tr17','tr18','tr19R','tr20')],MARGIN=1,FUN=getmode)[ind.stai[,1]]
}

#Create a new data frame copy that now incorporates imputed item-level values
stai = stai_mode

#Compute count of missing item-level reponses that remain after imputation. Store value in a new column ('na_count')
stai$na_count <- apply(is.na(stai), 1, sum)

#(Optional) Check number NAs
table(stai$na_count,exclude=NULL)

#Compute composite stai.trait score. If na_count value is >=1, set composite stai score to NA, else sum over item-level vavlues
stai$stai.trait = ifelse(stai$na_count>=1, NA, (stai$tr1R + stai$tr3R + stai$tr6R + stai$tr7R + stai$tr10R + stai$tr13R + stai$tr14R + stai$tr16R + stai$tr19R +
  stai$tr2 + stai$tr4 + stai$tr5 + stai$tr8 + stai$tr9 + stai$tr11 + stai$tr12 + stai$tr15 + stai$tr17 + stai$tr18 + stai$tr20))

#Create a composite score data frame for STAI Trait
staicomposites = data.frame(stai$ID,stai$stai.trait)
names(staicomposites)<-c('ID','stai.trait')

#(Optional)Check range (20-80) and number of NAs
summary(staicomposites)

###########################  AUDIT  #############################

# ALCOHOL USE
# Alcohol Use Disorders Identification Test (AUDIT; WHO, 1989)

#1. How often do you have a drink containing alcohol?
#2. How many drinks containing alcohol do you have on a typical day when you are drinking?
#3. How often do you have six ir more drinks on one occasion?
#4. How often during the last year have you found that you were not able to stop drinking once you had started?
#5. How often during the last year have you failed to do what was normally expected of you because of drinking?
#6. How often during the last year have you needed a drink in the morning to get yourself going after a heavy drinking session?
#7. How often during the last year have you had a feeling of guilt or remorse after drinking?
#8. How often during the last year have you been unable to remember what happened the night before because of your drinking?
#9. Have you or someone else been injured because of your drinking?
#10. Has a relative, friend, doctor, or other health care worker been concerned about your drinking or suggested you cut down?

#Note: Qualtrics instrument codes Likert scale values as: 1-5 for Q1-Q8, 1-3 for Q9-Q10. Scales will be recoded, below.

#Create AUDIT data frame
audit_qualtrics = data.frame(test$Name,test$audit1,test$audit2,test$audit3,test$audit4,test$audit5,test$audit6,
                    test$audit7,test$audit8,test$audit9,test$audit10)

names(audit_qualtrics) <- c('ID',
              'audit1','audit2','audit3','audit4','audit5','audit6','audit7','audit8','audit9','audit10')

#(Optional) Check response values
apply(audit_qualtrics[c('audit1','audit2','audit3','audit4','audit5','audit6','audit7','audit8','audit9','audit10')], 2, table)

#Recode to 0-4 from 1-5 (items 1-8) and to 0, 2, or 4 from 1-3 (items 9,10)
audit_qualtrics$audit1new=audit_qualtrics$audit1-1
audit_qualtrics$audit2new=audit_qualtrics$audit2-1
audit_qualtrics$audit3new=audit_qualtrics$audit3-1
audit_qualtrics$audit4new=audit_qualtrics$audit4-1
audit_qualtrics$audit5new=audit_qualtrics$audit5-1
audit_qualtrics$audit6new=audit_qualtrics$audit6-1
audit_qualtrics$audit7new=audit_qualtrics$audit7-1
audit_qualtrics$audit8new=audit_qualtrics$audit8-1


audit_qualtrics$audit9new<-ifelse(audit_qualtrics$audit9==1, 0, 
                                   ifelse(audit_qualtrics$audit9==3, 4, 2))

audit_qualtrics$audit10new<-ifelse(audit_qualtrics$audit10==1, 0, 
                                         ifelse(audit_qualtrics$audit10==3, 4, 2))

#(Optional) Check recodes
table(audit_qualtrics$audit9,audit_qualtrics$audit9new)
table(audit_qualtrics$audit10,audit_qualtrics$audit10new)

#Create dataframe copy containing recoded values
audit_orig = data.frame (audit_qualtrics$ID,audit_qualtrics$audit1new,audit_qualtrics$audit2new,
        audit_qualtrics$audit3new,audit_qualtrics$audit4new,audit_qualtrics$audit5new,
        audit_qualtrics$audit6new,audit_qualtrics$audit7new,audit_qualtrics$audit8new,
        audit_qualtrics$audit9new,audit_qualtrics$audit10new)

names(audit_orig) <- c('ID',
      'audit1','audit2','audit3','audit4','audit5','audit6','audit7','audit8','audit9','audit10')


#######################  Mode Imputation ##########################

audit_mode = audit_orig #Create a copy of the data frame for use in missing item-level value imputations

# Get all the locations where there is an NA
ind.audit <- which(is.na(audit_mode), arr.ind=TRUE)

if(NROW(ind.audit)!=0) {
# Impute the values of missing item-level responses using "getmode", for each row 
audit_mode[ind.audit] = apply(audit_mode[c('audit1','audit2','audit3','audit4','audit5',
                                           'audit6','audit7','audit8','audit9','audit10')],MARGIN=1,FUN=getmode)[ind.audit[,1]]
}

#Create a new data frame copy that incorporates imputed item-level values
audit = audit_mode

#Compute count of missing item-level reponses that remain after imputation. Store value in a new column ('na_count')
audit$na_count <- apply(is.na(audit), 1, sum)

#(Optional) Check NA count
table(audit$na_count)

#Compute composite audit score. If na_count is >=1 after mode imputation process, composite audit score is set to NA. Sum otherwise.
audit$audit = ifelse(audit$na_count>=1, NA,(audit$audit1 + audit$audit2 + audit$audit3 + audit$audit4 + audit$audit5 + 
                                              audit$audit6 + audit$audit7 + audit$audit8 + audit$audit9 + audit$audit10))

#Create a composite score data frame for AUDIT
auditcomposites = data.frame(audit$ID,audit$audit)
names(auditcomposites)<-c('ID','audit')

#(Optional) Check range (0-40) and number of NAs
summary(auditcomposites)

######################### Modified GATS #############################

#Current Smoking
#1.    Do you currently use any tobacco product(s) on a daily basis, less than daily, or not at all?
#a.    Daily  
#b.    Less than daily            
#c.    Not at all   

#Past Smoking
#2.    In the past, have you used tobacco product(s) on a daily basis, less than daily, or not at all?
#a.    Daily  
#b.    Less than Daily            
#c.    Not at all   

#3.    How many units of each of the following product types do you use/consume in a typical week?
#1.    Individual cigarettes 
#2.    E-cigarette cartridges
#3.    Individual clove cigarettes
#4.    Individual cigars
#5.    Pipe sessions
#6.    Chewing/smokeless tobacco sessions
#7.    Any others

#Create GATS data frame


gats = data.frame(test$Name,test$Date,test$gats1,test$gats2,test$gats3Week_1,test$gats3Week_2,
                  test$gats3Week_3,
                  test$gats3Week_4,test$gats3Week_5,test$gats3Week_6,test$gats3Week_7)

names(gats)<- c('ID','Date','gats1','gats2','gats3Week_1','gats3Week_2','gats3Week_3','gats3Week_4','gats3Week_5',
                'gats3Week_6','gats3Week_7')

#(Optional) Check item values/ranges
apply(gats[c('gats1','gats2')], 2, table,exclude=NULL)

apply(gats[c('gats3Week_1','gats3Week_2','gats3Week_3','gats3Week_4','gats3Week_5',
             'gats3Week_6','gats3Week_7')], 2, summary)


#TOBACCO USE

#PRESENT SMOKING STATUS
#1.    Do you currently use any tobacco product(s) on a daily basis, less than daily, or not at all?
#a.    Daily  (1)
#b.    Less than daily   (2)         
#c.    Not at all  (3)

########if (answer to q1 <3) = current

#####Current Smoking Status#############
#1=current smoker, 2 = current nonsmoker

#Ensure that gats3Week_* variables are typed as numeric, to avoid failure upon summation
gats$gats3Week_1 <- as.numeric(as.character(gats$gats3Week_1))
gats$gats3Week_2 <- as.numeric(as.character(gats$gats3Week_2))
gats$gats3Week_3 <- as.numeric(as.character(gats$gats3Week_3))
gats$gats3Week_4 <- as.numeric(as.character(gats$gats3Week_4))
gats$gats3Week_5 <- as.numeric(as.character(gats$gats3Week_5))
gats$gats3Week_6 <- as.numeric(as.character(gats$gats3Week_6))
gats$gats3Week_7 <- as.numeric(as.character(gats$gats3Week_7))

#Check recodes against previous summary
apply(gats[c('gats3Week_1','gats3Week_2','gats3Week_3','gats3Week_4','gats3Week_5',
             'gats3Week_6','gats3Week_7')], 2, summary)

#Compute gatscurrent numerical status
gats$gatscurrent<-ifelse(gats$gats1==1 | gats$gats1==2, 1,2)

#(Optional) Check results
table(gats$gats1,gats$gatscurrent,exclude=NULL)


########Past Smoker Status################
#PAST SMOKING STATUS
#2.    In the past, have you used tobacco product(s) on a daily basis, less than daily, or not at all?
#a.    Daily  
#b.    Less than Daily            
#c.    Not at all

#1=past smoker, 2 = past nonsmoker

#Set numerical gatspast status value (NA in either gats1 or gats2 triggers NA for gatspast)
gats$gatspast<-ifelse(is.na(gats$gats1) | is.na(gats$gats2),NA,
                      ifelse(gats$gats1==3 & gats$gats2<3,1,2))

#(Optional) Check results
mytable <- table(gats$gats1,gats$gats2,gats$gatspast,exclude = NULL) 
ftable(mytable) 

############GATS Smoking Status##############
#Now converting to categorical values: Current, Past, or Never
#Note: if either gatscurrent or gatspast is NA, gats.status is also NA
 gats$gats.status<-ifelse(is.na(gats$gatscurrent) | is.na(gats$gatspast),NA,
                           ifelse(gats$gatscurrent==1,'current', 
                                  ifelse(gats$gatscurrent==2 & gats$gatspast==1,'past', 'never')))
 
#(Optional) Check results
 mytable <- table(gats$gatscurrent,gats$gatspast,gats$gats.status,exclude = NULL) 
 ftable(mytable) 
 
##########################################################
 #TOBACCO QUANTITY: How many units  of nicotine do you use per day? 
 
 #We sum tobacco products for ALL the users (irrespective of current status)
 
# Convert Date variable to to R-recognized date format 
gats$Date <- as.Date(gats$Date, format = "%m/%d/%Y")
 
# Add a flag to identify surveys that were administered between 3/27/2018 and 4/4/2018 (inclusive).
# During this time period, undocumented changes to the Qualtrics system caused the pre-population
# of zeroes to cease for GATS variables gats3Week_1 through gats3Week_7, increasing the likelihood
# that participants would proceed while leaving these fields blank. Over just this span, we 
# invoke a special rule for NA-handling (treating NAs as zeroes)

gats$variantNArule <- ifelse(gats$Date >= as.Date('2018-03-27') & gats$Date <= as.Date('2018-04-04'),
                                   1,0)

#Check for Qualtrics 999 values (999s are used in the Qualtrics survey as indication that a participant
#wishes not to respond to a question) 
gats$gats3_has999 <-ifelse(
      gats$gats3Week_1==999 | 
			gats$gats3Week_2==999 | 
			gats$gats3Week_3==999 | 
			gats$gats3Week_4==999 | 
			gats$gats3Week_5==999 | 
			gats$gats3Week_6==999 |  
			gats$gats3Week_7==999,1,0)

#(Optional) Check results (here, and in gats data frame using all gats3 variables)
table(gats$gats3_has999,exclude=NULL)


#Compute intermediate GATS guantity value, checking for presence of 999s and checking also for
#need to invoke variant NA handling rule (See above). If 999s are present, set value to NA. 
#If variant scoring rule is being invoked, treat NAs as zeroes when summing.

gats$gatsQuantity1 <- ifelse(gats$gats3_has999==1 & !is.na(gats$gats3_has999),NA,
                             ifelse(gats$variantNArule==1,
                                    rowSums(gats[,c("gats3Week_1", "gats3Week_2", 
                                        "gats3Week_3", "gats3Week_4", "gats3Week_5", "gats3Week_6",
                                        "gats3Week_7")], na.rm=TRUE),
                                    rowSums(gats[,c("gats3Week_1", "gats3Week_2", 
                                        "gats3Week_3", "gats3Week_4", "gats3Week_5", "gats3Week_6",
                                        "gats3Week_7")])))


#(Optional) Check that NAs have been properly assigned, check data frame that gats 3 have been properly summed                            
table(gats$gats3_has999,gats$gatsQuantity1, exclude=NULL)

#Compute final gats.quantity scores, setting GATS quantity value to 0 for participants who were not presented
#with GATS Question 3 because they self-identified as #non-current tobacco users
gats$gats.quantity<-ifelse(gats$gats.status!="current",0,gats$gatsQuantity1)


#(Optional) Check recodes
table(gats$gats.status,gats$gats.quantity)
                            
#Create an alternative GATS quantity value (gats.quantity.sub) that only considers participants
# who are self-identified CURRENT users
gats$gats.quantity.sub<-ifelse(gats$gats.status=='past'| gats$gats.status=='never',NA,gats$gatsQuantity1)

#(Optional) Check recodes
table(gats$gats.status,gats$gats.quantity.sub)

#Create a data table for composite GATS scores                        
gatscomposites = data.frame(gats$ID,gats$gats.status,gats$gats.quantity,gats$gats.quantity.sub)
names(gatscomposites)<-c('ID','gats.status','gats.quantity','gats.quantity.sub')
                            

##########################  IPAQ   ##########################

#IPAQ time is reported in minutes

#ipaq1	Do you currently have a job or do any unpaid work outside your home? 
#Yes/no
#ipaq2	During the last 7 days, on how many days did you do vigorous physical activities like heavy lifting, digging, heavy construction, or climbing up stairs as part of your work? Think about only those physical activities that you did for at least 10 minutes at a time. 
#Days per week
#ipaq3	How much time did you usually spend on one of those days doing vigorous physical activities as part of your work? 
#Minutes per day
#ipaq4	Again, think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do moderate physical activities like carrying light loads as part of your work? Please do not include walking. 
#Days per week
#ipaq5	How much time did you usually spend on one of those days doing moderate physical activities as part of your work? 
#Minutes per day
#ipaq6	During the last 7 days, on how many days did you walk for at least 10 minutes at a time as part of your work? Please do not count any walking you did to travel to or from work. 
#Days per week
#ipaq7	How much time did you usually spend on one of those days walking as part of your work? 
#Minutes per day
#ipaq8	During the last 7 days, on how many days did you travel in a motor vehicle like a train, bus, car, or tram? 
#Days per week
#ipaq9	How much time did you usually spend on one of those days traveling in a train, bus, car, tram, or other kind of motor vehicle? 
#Minutes per day
#ipaq10	During the last 7 days, on how many days did you bicycle for at least 10 minutes at a time to go from place to place? 
#Days per week
#ipaq11	How much time did you usually spend on one of those days to bicycle from place to place? 
#Minutes per week
#ipaq12	During the last 7 days, on how many days did you walk for at least 10 minutes at a time to go from place to place? 
#Days per week
#ipaq13	How much time did you usually spend on one of those days walking from place to place? 
#Minutes per day
#ipaq14	 Think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do vigorous physical activities like heavy lifting, chopping wood, shoveling snow, or digging in the garden or yard? 
#Days per week
#ipaq15	How much time did you usually spend on one of those days doing vigorous physical activities in the garden or yard? 
#Minutes per day
#ipaq16	Again, think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do moderate activities like carrying light loads, sweeping, washing windows, and raking in the garden or yard? 
#Days per week
#ipaq17	How much time did you usually spend on one of those days doing moderate physical activities in the garden or yard? 
#Minutes per day
#ipaq18	Once again, think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do moderate activities like carrying light loads, washing windows, scrubbing floors, and sweeping inside your home? 
#Days per week
#ipaq19 	How much time did you usually spend on one of those days doing moderate physical activities inside your home? 
#Minutes per day
#ipaq20	Not counting any walking you have already mentioned, during the last 7 days, on how many days did you walk for at least 10 minutes at a time in your leisure time? 
#Days per week
#ipaq21 	How much time did you usually spend on one of those days walking in your leisure time? 
#Minutes per day
#ipaq22	Think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do vigorous physical activities like aerobics, running, fast bicycling, or fast swimming in your leisure time? 
#Days per week
#ipaq23 	How much time did you usually spend on one of those days doing vigorous physical activities in your leisure time? 
#Minutes per day
#ipaq24	Again, think about only those physical activities that you did for at least 10 minutes at a time. During the last 7 days, on how many days did you do moderate physical activities like bicycling at a regular pace, swimming at a regular pace, and doubles tennis in your leisure time? 
#Days per week
#ipaq25 	How much time did you usually spend on one of those days doing moderate physical activities in your leisure time? 
#Minutes per day
#ipaq26 	During the last 7 days, how much time did you usually spend sitting on a weekday? 
#Minutes per day
#ipaq27 	During the last 7 days, how much time did you usually spend sitting on a weekend day? 
#Minutes per day

#Create IPAQ data frame
ipaq_orig = data.frame(test$Name,test$ipaq1,test$ipaq2,test$ipaq3,test$ipaq4,test$ipaq5,test$ipaq6,test$ipaq7,test$ipaq8,
                       test$ipaq9,test$ipaq10,test$ipaq11,test$ipaq12,test$ipaq13,test$ipaq14,
                       test$ipaq15,test$ipaq16,test$ipaq17,test$ipaq18,test$ipaq19,test$ipaq20,test$ipaq21,
                       test$ipaq22,test$ipaq23,test$ipaq24,test$ipaq25,test$ipaq26,test$ipaq27)

names(ipaq_orig) <- c('ID','ipaq1','ipaq2','ipaq3','ipaq4','ipaq5','ipaq6','ipaq7','ipaq8',
                      'ipaq9','ipaq10','ipaq11','ipaq12','ipaq13','ipaq14','ipaq15',
                      'ipaq16','ipaq17','ipaq18','ipaq19','ipaq20','ipaq21','ipaq22',
                      'ipaq23','ipaq24','ipaq25','ipaq26','ipaq27')

#Part 1: Job Related PA, Q1-Q7
#Part 2: Transportation Related PA, Q8-Q13
#Part 3: Housework, house maintainance, caring for family PA, Q14-Q19
#Part 4: Recreation, sport, and leasure time PA, Q20-Q25
#Part 5: Time spent sitting, Q26-Q27

#Create a copy of original data frame
ipaq <- ipaq_orig

#Explicitly recode variable types to 'numeric' for ipaq1 through ipaq27 to avoid possibility
#of errors if R mis-types variables as factors 
ipaq[,2:28] <- data.frame(lapply(ipaq[,2:28], function(x) as.numeric(as.character(x))))

#(Optional) Check that values are in correct value ranges
summary(ipaq)
table(ipaq$ipaq1,exclude=NULL)


#ipaq1: 1 = Yes, 2=No, NA=skipped by participant

ipaq$ipaq2new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq2)
ipaq$ipaq3new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq3) 
ipaq$ipaq4new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq4)
ipaq$ipaq5new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq5)
ipaq$ipaq6new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq6)
ipaq$ipaq7new<-ifelse(ipaq$ipaq1==2,0,ipaq$ipaq7)

#(Optional) Check recode for one item
mytable <- table(ipaq$ipaq1,ipaq$ipaq2,ipaq$ipaq2new) 
ftable(mytable) 

#If response to "how many days per week..." question is 0, set value for 
#paired "how many minutes per day..." question to 0. This effectively eliminates
#NA values that were created due to valid IPAQ survey skip logic
ipaq$ipaq3V<-ifelse(ipaq$ipaq2new==0,0,ipaq$ipaq3)
ipaq$ipaq5V<-ifelse(ipaq$ipaq4new==0,0,ipaq$ipaq5)
ipaq$ipaq7V<-ifelse(ipaq$ipaq6new==0,0,ipaq$ipaq7)
ipaq$ipaq9new<-ifelse(ipaq$ipaq8==0,0,ipaq$ipaq9)
ipaq$ipaq11new<-ifelse(ipaq$ipaq10==0,0,ipaq$ipaq11)
ipaq$ipaq13new<-ifelse(ipaq$ipaq12==0,0,ipaq$ipaq13)
ipaq$ipaq15new<-ifelse(ipaq$ipaq14==0,0,ipaq$ipaq15)
ipaq$ipaq17new<-ifelse(ipaq$ipaq16==0,0,ipaq$ipaq17)
ipaq$ipaq19new<-ifelse(ipaq$ipaq18==0,0,ipaq$ipaq19)
ipaq$ipaq21new<-ifelse(ipaq$ipaq20==0,0,ipaq$ipaq21)
ipaq$ipaq23new<-ifelse(ipaq$ipaq22==0,0,ipaq$ipaq23)
ipaq$ipaq25new<-ifelse(ipaq$ipaq24==0,0,ipaq$ipaq25)  

#Check data file for recodes

#Create a new data set with Q1, 2new,3V,4new,5V,6new,7V,8,9new,10,11new,12,13new,14,15new,16,
#17new,18,19new,20,21new,22,23new,24,25new,26,27

ipaqV = data.frame(ipaq$ID,ipaq$ipaq1,ipaq$ipaq2new,ipaq$ipaq3V,ipaq$ipaq4new,ipaq$ipaq5V,ipaq$ipaq6new,ipaq$ipaq7V,
                   ipaq$ipaq8,ipaq$ipaq9new,ipaq$ipaq10,ipaq$ipaq11new,ipaq$ipaq12,ipaq$ipaq13new,ipaq$ipaq14,
                   ipaq$ipaq15new,ipaq$ipaq16,ipaq$ipaq17new,ipaq$ipaq18,ipaq$ipaq19new,ipaq$ipaq20,ipaq$ipaq21new,
                   ipaq$ipaq22,ipaq$ipaq23new,ipaq$ipaq24,ipaq$ipaq25new,ipaq$ipaq26,ipaq$ipaq27)

names(ipaqV) <- c('ID','ipaq1','ipaq2','ipaq3','ipaq4','ipaq5','ipaq6','ipaq7','ipaq8',
                  'ipaq9','ipaq10','ipaq11','ipaq12','ipaq13','ipaq14','ipaq15',
                  'ipaq16','ipaq17','ipaq18','ipaq19','ipaq20','ipaq21','ipaq22',
                  'ipaq23','ipaq24','ipaq25','ipaq26','ipaq27')

#(Otional) Review all new variables
summary(ipaqV)


#Create MET minute conversions for Work Domain
ipaqV$walkmindayW = ipaqV$ipaq7
ipaqV$modmindayW = ipaqV$ipaq5 
ipaqV$vigmindayW = ipaqV$ipaq3

ipaqV$WalkMETmins_W = 3.3 * ipaqV$walkmindayW * ipaqV$ipaq6
ipaqV$ModMETmins_W = 4.0 * ipaqV$modmindayW * ipaqV$ipaq4
ipaqV$VigMETmins_W = 8.0 * ipaqV$vigmindayW * ipaqV$ipaq2
ipaqV$TotalWork = ipaqV$WalkMETmins_W + ipaqV$ModMETmins_W + ipaqV$VigMETmins_W

#Check calculations
ipaq_work=data.frame(ipaqV$ipaq7,ipaqV$walkmindayW,ipaqV$ipaq6,ipaqV$WalkMETmins_W,ipaqV$ipaq5,ipaqV$modmindayW,ipaqV$ipaq4,ipaqV$ModMETmins_W
                     ,ipaqV$ipaq3,ipaqV$vigmindayW,ipaqV$ipaq2,ipaqV$VigMETmins_W,ipaqV$TotalWork)

#Create MET minute conversions for Active Transportation Domain
ipaqV$WalkmindayTr = ipaqV$ipaq13
ipaqV$CyclemindayTr = ipaqV$ipaq11

ipaqV$WalkMETmins_Tr = 3.3 * ipaqV$WalkmindayTr * ipaqV$ipaq12
ipaqV$CycleMETmins_Tr= 6.0 * ipaqV$CyclemindayTr * ipaqV$ipaq10
ipaqV$TotalTransport = ipaqV$WalkMETmins_Tr + ipaqV$CycleMETmins_Tr

#Create MET minute conversions for Domestic and Garden [Yard Work] Domain
ipaqV$vigmindayYard = ipaqV$ipaq15
ipaqV$modmindayYard = ipaqV$ipaq17
ipaqV$modmindayInside = ipaqV$ipaq19

ipaqV$VigMETmins_Yard = 5.5 * ipaqV$vigmindayYard * ipaqV$ipaq14
ipaqV$ModMETmins_Yard = 4.0 * ipaqV$modmindayYard * ipaqV$ipaq16
ipaqV$ModMETmins_Inside = 3.0 * ipaqV$modmindayInside * ipaqV$ipaq18
ipaqV$TotalYard_Inside = ipaqV$VigMETmins_Yard + ipaqV$ModMETmins_Yard + ipaqV$ModMETmins_Inside

#Create MET minute conversions for Leisure-Time Domain
ipaqV$walkmindayLeis = ipaqV$ipaq21
ipaqV$modmindayLeis = ipaqV$ipaq25
ipaqV$vigmindayLeis = ipaqV$ipaq23

ipaqV$WalkMETmins_Leis = 3.3 * ipaqV$walkmindayLeis * ipaqV$ipaq20
ipaqV$ModMETmins_Leis = 4.0 * ipaqV$modmindayLeis * ipaqV$ipaq24
ipaqV$VigMETmins_Leis = 8.0 * ipaqV$vigmindayLeis * ipaqV$ipaq22
ipaqV$TotalLeisure = ipaqV$WalkMETmins_Leis + ipaqV$ModMETmins_Leis + ipaqV$VigMETmins_Leis


#Total Scores for Walking, Moderate and Vigorous Physical Activities
#WALKING
ipaqV$TotalWalkMETs = ipaqV$WalkMETmins_W + ipaqV$WalkMETmins_Tr + ipaqV$WalkMETmins_Leis

#MODERATE
ipaqV$TotalModMETs = ipaqV$ModMETmins_W + ipaqV$ModMETmins_Yard + ipaqV$ModMETmins_Inside + ipaqV$ModMETmins_Leis +
  ipaqV$CycleMETmins_Tr + ipaqV$VigMETmins_Yard 

#VIGOROUS
ipaqV$TotalVigMETs = ipaqV$VigMETmins_W + ipaqV$VigMETmins_Leis
#Note: Cycling MET value and Vigorous garden/yard work MET value fall within the coding range of moderate-intensity activities

#Total Physical Activity Scores
ipaqV$TotalPA = ipaqV$TotalWalkMETs + ipaqV$TotalModMETs + ipaqV$TotalVigMETs


#Compute overall IPAQ composite score. If any response is '999' for a # of days or # of minutes question, 
#then 'no total PA score' (as per IPAQ scoring instructions)
ipaqV$ipaq<-ifelse(ipaqV$ipaq2==999 | ipaqV$ipaq3==999 | ipaqV$ipaq4==999 | ipaqV$ipaq5==999 |
                     ipaqV$ipaq6==999 | ipaqV$ipaq7==999 | ipaqV$ipaq8==999 | ipaqV$ipaq9==999 | ipaqV$ipaq10==999 |
                     ipaqV$ipaq11==999 | ipaqV$ipaq12==999 | ipaqV$ipaq13==999 | ipaqV$ipaq14==999 | ipaqV$ipaq15==999 |
                     ipaqV$ipaq16==999 | ipaqV$ipaq17==999 | ipaqV$ipaq18==999 | ipaqV$ipaq19==999 | ipaqV$ipaq20==999 |
                     ipaqV$ipaq21==999 | ipaqV$ipaq22==999 | ipaqV$ipaq23==999 | ipaqV$ipaq24==999 | ipaqV$ipaq25==999 |
                     ipaqV$ipaq26==999 | ipaqV$ipaq27==999, NA,ipaqV$TotalPA)

#(Optional) Review all new variables
summary(ipaqV)

#Create composite score data frame for IPAQ
ipaqcomposites = data.frame(ipaqV$ID,ipaqV$ipaq)
names(ipaqcomposites) <- c('ID', 'ipaq')

############################  PSQI  ##############################
# PSQI

# 1-4: open ended

#1. psqi1 When have you usually gone to bed?
#2. psqi2 How long (in minutes) has it usually taken you to fall asleep each night?
#3. psqi3 When have you usually gotten up in the morning?
#4. psqi4 How many hours of actual sleep do you get at night? (This may be different than the number of hours you spend in bed).

#5a-5j, 6, 7, 8: Likert Scale: 1-4
#(0)not during the past month
#(1)less than once a week
#(2)once or twice a week
#(3)three or more times a week

#5a   psqi5a -- cannot get to sleep within 30 minutes?
#5b.  psqi5b -- wake up in the middle of the night or early morning?
#5c.  psqi5c -- have to get up to use the bathroom?
#5d.  psqi5d -- cannot breathe comfortably?
#5e.  psqi5e -- cough or snore loudly?
#5f.  psqi5f -- feel too cold?
#5g.  psqi5g -- feel too hot?
#5h.  psqi5h -- have bad dreams?
#5i.  psqi5i -- have pain?
#5ja. psqi5ja	Other reasons..
#5jb. psqi5jb	 How often?

#6. psqi6   How often have you taken medicine (prescribed or "over the counter") to help you sleep?
#7. psqi7   How often have you had trouble staying awake while driving, eating meals, or engaging in social activity?

#6, 7: 
#(0)not during the past month
#(1)less than once a week
#(2)once or twice a week
#(3)three or more times a week

#8. psqi8   How much of a problem has it been for you to keep up enthusiasm to get things done?
#8. #(0)no problem at all
#(1)only a slight problem
#(2)somewhat a problem
#(3)a big problem

#9. psqi9   During the past month, how would you rate your sleep quality overall?
##201902 v2.2 update: the coding was reversed in the survey; originally-fielded
##survey used:
#9. Likert Scale: 
#1 (0)very bad; 
#2 (1)fairly bad; 
#3 (2)fairly good; 
#4 (3) very good
##201902 v2.2 update: new (corrected) response coding:
#9. Likert Scale: 
#1 (3)very bad; 
#2 (2)fairly bad; 
#3 (1)fairly good; 
#4 (0) very good


#Create a PSQI data frame
psqi_orig <- data.frame(test$Name,test$psqi1,test$psqi1ampm,test$psqi2,test$psqi3,test$psqi3ampm,test$psqi4,
                        test$psqi5a,test$psqi5b,test$psqi5c,test$psqi5d,test$psqi5e,test$psqi5f,
                        test$psqi5g,test$psqi5h,test$psqi5i,test$psqi5ja,test$psqi5jb,
                        test$psqi6,test$psqi7,test$psqi8,test$psqi9)

names(psqi_orig) <- c('ID','psqi1','psqi1ampm','psqi2','psqi3','psqi3ampm','psqi4',
                      'psqi5a','psqi5b','psqi5c','psqi5d','psqi5e','psqi5f',
                      'psqi5g','psqi5h','psqi5i','psqi5ja','psqi5jb',
                      'psqi6','psqi7','psqi8','psqi9')

#Create a copy of the orignal psqi data
psqifake <- psqi_orig

#(Optional) Check item response values
summary(psqifake)

#(Optional) To check frequencies across all categories:
summarytools::freq(psqifake$psqi1)
summarytools::freq(psqifake$psqi1ampm)
summarytools::freq(psqifake$psqi2)
summarytools::freq(psqifake$psqi3)
summarytools::freq(psqifake$psqi3ampm)
summarytools::freq(psqifake$psqi5jb)
summarytools::freq(psqifake$psqi6)
summarytools::freq(psqifake$psqi7)
summarytools::freq(psqifake$psqi8)
summarytools::freq(psqifake$psqi9)

#Recode into 0-3 from 1-4 for item 9 
psqifake$psqi9new <- psqifake$psqi9-1

    #version 2.2 fix, 20190225 - Reverse coding for psqi9 (original survey had wrong order)
    psqifake$psqi9newR <- 3-(psqifake$psqi9new)
    
    #(Optional) Check recode
    table(psqifake$psqi9,psqifake$psqi9new)
    table(psqifake$psqi9new,psqifake$psqi9newR)
    
    #Overwrite psqi9 after checking recodes
    # old: psqifake$psqi9 <- psqifake$psqi9new
    # updated 201902:
    psqifake$psqi9 <- psqifake$psqi9newR
    
    #(Optional) Check recode
    table(psqifake$psqi9)

#Recode Q5ja and Q5jb to 0 if NA 
#Convert psqi5ja variable type from factor to character
psqifake$psqi5ja <- as.character(psqifake$psqi5ja)

psqifake$psqi5jaN <- ifelse(is.na(psqifake$psqi5ja),0,psqifake$psqi5ja)
psqifake$psqi5jbN <- ifelse(is.na(psqifake$psqi5jb),0,psqifake$psqi5jb)

#(Optional) Check recodes
table(psqifake$psqi5jb,psqifake$psqi5jbN,exclude=NULL)

#Recode Q5jb to 0 if 5ja is 0
psqifake$psqi5jbN2 <-ifelse (psqifake$psqi5jaN==0,0, psqifake$psqi5jbN)

#Overwrite psqi5ja and psqi5jb values 
psqifake$psqi5ja <- psqifake$psqi5jaN
psqifake$psqi5jb <- psqifake$psqi5jbN2


#(Optional) Check item response values
summary(psqifake)

#(Optional) To check values in all categories:
summarytools::freq(psqifake$psqi1)
summarytools::freq(psqifake$psqi1ampm)
summarytools::freq(psqifake$psqi2)
summarytools::freq(psqifake$psqi3)
summarytools::freq(psqifake$psqi3ampm)
summarytools::freq(psqifake$psqi5jb)
summarytools::freq(psqifake$psqi6)
summarytools::freq(psqifake$psqi7)
summarytools::freq(psqifake$psqi8)
summarytools::freq(psqifake$psqi9)

#Detect and count 999s in psqi2 or psqi4. Store count in new variable, 'count_999s'
psqifake$count_999s <- rowSums(psqifake[,c('psqi2','psqi4')] == 999)

#If psqi1 or psqi4 is 999, recode as NA, store recodes in new variables
psqifake$psqi2x <- ifelse(psqifake$psqi2==999,NA,psqifake$psqi2)
psqifake$psqi4x <- ifelse(psqifake$psqi4==999,NA,psqifake$psqi4)

#(Optional) Test recodes
table(psqifake$psqi2,psqifake$psqi2x, exclude=NULL)
table(psqifake$psqi4,psqifake$psqi4x, exclude=NULL)

#Overwrite psqi1 and psq4 with post-999-conversion values
psqifake$psqi2 <- psqifake$psqi2x
psqifake$psqi4 <- psqifake$psqi4x

#(Optional) Check
summarytools::freq(psqifake$psqi2)
summarytools::freq(psqifake$psqi4)


#Create flag to indicate any cases with missing data for items 1-9 ('na_count').
#This will include both "native" NAs (items with null Qualtrics responses) and (for psqi2 and psqi4)
#NAs that we have generated because participants input 999 to signal a desire to skip an item.
#We will use this flag to later exclude cases with any NAs on items 1-9 from getting an overall PSQI score.
#(NOTE: this test does not apply in the case of 5j, where NAs have been recoded as zeroes)
psqifake$na_count <- apply(is.na(psqifake[,2:22]), 1, sum)

#(Optional)check na_count (look at data frame)
summarytools::freq(psqifake$na_count)


#Component 1 (SUBJECTIVE SLEEP QUALITY - PSQISLPQUAL)
#9. During the past month, how would you rate your sleep quality overall?

##########component 1 score###########
psqifake$component1 = psqifake$psqi9


##########Component 2 (SLEEP LATENCY - PSQILATEN )###########
#2. During the past month, how long (in minutes) has it usually taken you to fall asleep each night?

psqifake$psqi2new <- psqifake$psqi2

#Categorize responses for item 2
psqifake$psqi2cat <- ifelse(psqifake$psqi2new<=15,0, ifelse(psqifake$psqi2new<=30,1, ifelse(psqifake$psqi2new<=60,2,3)))

#(Optional) Check recode
table(psqifake$psqi2,psqifake$psqi2cat,exclude = NULL)
table(psqifake$psqi2cat,exclude = NULL)

#Convert back into psqi2new 
psqifake$psqi2new <- psqifake$psqi2cat

#(Optional) Check
table(psqifake$psqi2cat,psqifake$psqi2new,exclude = NULL)


#5a During the past month,  how often have you had trouble sleeping because you -- cannot get to sleep within 30 minutes?

#Compute sum of 2new and 5a
psqifake$psqi_2and5a = psqifake$psqi2new + psqifake$psqi5a

#(Optional) Check
summarytools::freq(psqifake$psqi2new)
summarytools::freq(psqifake$psqi5a)
summarytools::freq(psqifake$psqi_2and5a)

                  
#Calculate component 2 score (SLEEP LATENCY)
psqifake$component2<-ifelse(psqifake$psqi_2and5a==1 | psqifake$psqi_2and5a==2, 1, 
              ifelse(psqifake$psqi_2and5a==3 | psqifake$psqi_2and5a==4, 2,
              ifelse(psqifake$psqi_2and5a==5 | psqifake$psqi_2and5a==6,3, 0)))

#Check categories
table(psqifake$psqi_2and5a,psqifake$component2)

#########Component 3 (SLEEP DURATION - PSQIDURAT)##########

#4. During the past month,how many hours of actual sleep do you get at night? (This may be different than the number of hours you spend in bed).

psqifake$component3 <- ifelse(psqifake$psqi4<5,3, ifelse(psqifake$psqi4<6,2, ifelse(psqifake$psqi4<7,1,0)))

#(Optional) Check
table(psqifake$psqi4,psqifake$component3)

########Component 4 (SLEEP EFFICIENCY - PSQIHSE)##########
#4. During the past month,how many hours of actual sleep do you get at night? (This may be different than the number of hours you spend in bed).
#3. During the past month,when have you usually gotten up in the morning?
#1. During the past month,when have you usually gone to bed?


##########Calculate hrs in bed########

#1.	Convert original psqi1 and psq3 variables to 24-hour equivalents

psqifake$psqi1_24 <- 
  ifelse(psqifake$psqi1==1200 & psqifake$psqi1ampm==0,0,
         ifelse(psqifake$psqi1==1230 & psqifake$psqi1ampm==0,30,
                ifelse(psqifake$psqi1==1200 & psqifake$psqi1ampm==1200,1200,
                       ifelse(psqifake$psqi1==1230 & psqifake$psqi1ampm==1200,1230,
                              ifelse(psqifake$psqi1ampm==0,psqifake$psqi1,psqifake$psqi1+1200)))))
#(Optional) Check recoding
table(psqifake$psqi1_24,psqifake$psqi1,psqifake$psqi1ampm)

psqifake$psqi3_24 <- 
  ifelse(psqifake$psqi3==1200 & psqifake$psqi3ampm==0,0,
         ifelse(psqifake$psqi3==1230 & psqifake$psqi3ampm==0,30,
                ifelse(psqifake$psqi3==1200 & psqifake$psqi3ampm==1200,1200,
                       ifelse(psqifake$psqi3==1230 & psqifake$psqi3ampm==1200,1230,
                              ifelse(psqifake$psqi3ampm==0,psqifake$psqi3,psqifake$psqi3+1200)))))

#(Optional) Check recoding
table(psqifake$psqi3_24,psqifake$psqi3,psqifake$psqi3ampm)

#2.	Create a dummy variable that stores the difference between 2400 and psqi1_24

psqifake$psqi1_24diff <- 2400-psqifake$psqi1_24

#(Optional)Check new values
table(psqifake$psqi1_24diff,psqifake$psqi1_24)

#3.	Compute difference between psqi3_24 and psqi1_24

psqifake$hrs_inbed_pos <- 
  ifelse(psqifake$psqi1_24diff+psqifake$psqi3_24>2400, psqifake$psqi3_24-psqifake$psqi1_24,psqifake$psqi3_24+psqifake$psqi1_24diff)


#Convert  630, to 6.5 etc.

psqifake$hrs_inbed <- round_any((psqifake$hrs_inbed_pos/100), 0.5)

#(Optional)Check conversions
table(psqifake$hrs_inbed_pos,psqifake$hrs_inbed)


#4. Compute habitual sleep efficiency value

psqifake$component4perc = ((psqifake$psqi4)/(psqifake$hrs_inbed))*100


#5. Compute Component 4 score
psqifake$component4<-ifelse(psqifake$component4perc>=85,0, ifelse(psqifake$component4perc>=75,1, ifelse(psqifake$component4perc>=65,2, 3)))

#(Optional) Check calculations
table(psqifake$component4,psqifake$component4perc)


#Create data frame to check all recodes for component4
psqifake_comp4 = data.frame(psqifake$psqi4,psqifake$psqi3,psqifake$psqi3ampm,psqifake$psqi3_24,psqifake$psqi1,
                            psqifake$psqi1ampm,psqifake$psqi1_24,psqifake$psqi1_24diff,psqifake$hrs_inbed_pos,psqifake$hrs_inbed,
                            psqifake$component4perc,psqifake$component4)


##########Component 5 score total (SLEEP DISTURBANCES - PSQIDISTB)###########

#Compute sum of Component 5 constituent items
psqifake$component5total= (psqifake$psqi5b + psqifake$psqi5c + psqifake$psqi5d + psqifake$psqi5e + 
            psqifake$psqi5f + psqifake$psqi5g + psqifake$psqi5h + psqifake$psqi5i + 
            psqifake$psqi5jb)

#Compute Component 5 score
psqifake$component5<-ifelse(psqifake$component5total<1,0, 
            ifelse(psqifake$component5total<=9,1, 
            ifelse(psqifake$component5total<=18,2, 3)))

#(Optional) Check component5total to component5 recode
table(psqifake$component5total,psqifake$component5)

#Create data frame to check all recodes for component 5 

psqifake_comp5 = data.frame(psqifake$psqi5b,psqifake$psqi5c,psqifake$psqi5d,psqifake$psqi5e,
                            psqifake$psqi5f,psqifake$psqi5g,psqifake$psqi5h,psqifake$psqi5i,
                            psqifake$psqi5jb,psqifake$component5total,psqifake$component5)



##########Calculate Component 6 score (USE OF SLEEPING MEDICATIONS - PSQIMEDS)###########

#6. During the past month, how often have you taken medicine (prescribed or "over the counter") to help you sleep?
# in the original, this is question #7 as we decided to move the overall quality of sleep question from #6 to #9

psqifake$component6 = psqifake$psqi6

#(Optional) Check
table(psqifake$component6,psqifake$psqi6)

###########Calculate component 7 score (DAYTIME DYSFUNCTION)#############

#7. During the past month, how often have you had trouble staying awake while driving, eating meals, or engaging in social activity?
#8. During the past month, how much of a problem has it been for you to keep up enthusiasm to get things done?
#Note: in the original instrument, these are questions #8 and #9

#Sum constituent elements
psqifake$component7total = psqifake$psqi7 + psqifake$psqi8

#Convert sums to Component 7 score
psqifake$component7<-ifelse(psqifake$component7total==1 | psqifake$component7total==2, 1, 
            ifelse(psqifake$component7total==3 | psqifake$component7total==4, 2,
            ifelse(psqifake$component7total==5 | psqifake$component7total==6,3, 0)))

#(Optional) Check
table(psqifake$component7total,psqifake$component7)

##########PSQI GLOBAL Score#############

##NOTE: We only compute a global score if na_count=0 (i.e., no missing data for items 1-9; Q5J excluded)

psqifake$psqi<-ifelse(psqifake$na_count==0,psqifake$component1 + psqifake$component2 + psqifake$component3 + psqifake$component4 + 
  psqifake$component5 + psqifake$component6 + psqifake$component7,NA)


psqi_global <- data.frame(psqifake$ID,psqifake$component1,psqifake$component2,psqifake$component3,psqifake$component4,psqifake$component5,
                         psqifake$component6,psqifake$component7,psqifake$na_count,psqifake$psqi)

names(psqi_global) <- c('ID','component1','component2','component3','component4','component5','component6','component7','na_count','psqi')


#Create a composite score data frame for PSQI
psqicomposites = data.frame(psqifake$ID,psqifake$psqi)
names(psqicomposites)<-c('ID','psqi')



######### Combine Composite Scores into a single data frame  #############

testIDs <- data.frame(test$Name,test$StartDate,test$igtb.incomplete)
names(testIDs) <- c('ID','date_time','igtb_incomplete')

igtb_composites <- Reduce(function(x, y) merge(x, y, by ='ID'), 
                          list(testIDs,#vocabcomposites,#abstractcomposites, ##version 2.3 update
                               irbcomposites,itpcomposites,
                               ocbcomposites,iodcomposites,bficomposites,panascomposites,staicomposites,
                               auditcomposites,gatscomposites,ipaqcomposites,psqicomposites))

#Reorder columns for consistency with early versions (move 'igtb.incomplete' to last column)
igtb_composites <- igtb_composites[,c(1:2,4:22,#24, ##version 2.3 update
                                      3)]

## version 2.3 update: please note that Shipley scores (Abstraction and Vocabulary) are, 
## by design, excluded from this version, due to licensing restrictions governing the
## public redistribution of Shipley instrument data (i.e., answers and questions/prompts)

#Export composite score csv file to previously-defined output directory ('OutputDir')
write.csv(igtb_composites, file = paste("./",OutputDir,"/","igtb_composites.csv", sep=""),row.names = FALSE)

# NOTICE
# This software (or technical data) was produced for the U.S. Government under contract 
# 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14, 
# ALT IV (MAY 2014) or (DEC 2007).
# ©2019 The MITRE Corporation. All Rights Reserved.
