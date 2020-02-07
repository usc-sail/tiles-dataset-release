# NOTICE
# This software (or technical data) was produced for the U.S. Government under contract 
# 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14, 
# ALT IV (MAY 2014) or (DEC 2007).
# ?2019 The MITRE Corporation. All Rights Reserved. Approved for Public Release; Distribution Unlimited. Case Number 19-2656


######################################################################################################

## This code takes as inputs a directory of csv-formatted MOSAIC daily ground truth survey results (one 
## csv file for each survey date), which it then merges into a single, aggregated csv file that can be used to
## support summary scoring of daily ground truth measures

## DETAILS ##

## This code will read in files contained in a user-specified directory and will merge them vertically into a single table;
## it is designed to accommodate cases where the input file structures are inconsistent;
## specifically, it allows for the input files to have a mixture of shared and unique columns/variables,
## which will be merged into a single output table (and, optionally, file) that preserves all unique columns/variables
## from all input files.

## Columns are matched by name, and any missing columns are filled with "NA".
## A new variable is created to report source file names for each observation.

## Revisions ##

## 201804 * Fixed sort function not recognizing and sorting on date values
##        * Now checking for and deleting duplicate observations 
##        * Now setting stringsAsFactors argument to FALSE when files are read in
##        * Revised protocol for generating a file list (looks only for .csv files with matching filename patterns)
##        * Revised protocol for specifying output directory (output dir name stored in a variable, now)

#######################################################################################################




################# USER INPUTS ######################

#Set working directory path

#This directory should include the daily survey file(s) that you wish to merge (in csv format)
setwd("/USC/TILES/tiles-careless-responses/raw_survey_data_with_index/mgt/")

###Define a name for the output file subdirectory (name only, in quotes, not the full path)###
OutputDir <- "Merged"

############  END USER INPUTS #####################





# Load tidyverse library [install first, if necessary]
#install.packages("tidyverse") 
library(tidyverse)

# Create a list of all csv files found in the specified working directory that contain in their 
# filenames the string '_health_', '_job_', or '_personality_'. Revise the match pattern accordingly if
# using locally customized file naming conventions.

filelist <- list.files(pattern = "(_health_|_job_|_personality_).+?.csv")

#Create an output file subdirectory within the specified working directory, using the 
#name defined in OutputDir variable
dir.create(OutputDir)

# Read all files into a new list of data frames.
# Specify UTF-8-BOM file encoding format, so R knows to strip the UTF Byte Order Marker
# from the beginning of UTF-8-formatted Qualtrics csv files
#NOte: if you should see error, "Error in read.table(file = file, header = header, sep = sep, quote = quote,  : 
#no lines available in input", confirm that you are not attempting to merge any empty files (size=0kb)
all_csv <- lapply(filelist,read.csv, fileEncoding="UTF-8-BOM", stringsAsFactors=FALSE)

#Set the name of each list element to its respective source file name
names(all_csv) <- filelist

# Export a list of source file names (in the"output" subdirectory)
file_list <- as.data.frame(filelist)
write.csv(file_list, file = paste("./",OutputDir,"/","file_list.csv", sep=""),row.names = FALSE)


# OPTIONAL:
# Break out discrete data frames for each imported file, so that they are accessible via the R console;
# this step may be commented out if not needed 

#lapply(names(all_csv), function(x) assign(x,all_csv[[x]],envir=.GlobalEnv))


##############################################################################

# Combine data into a single master table, preserving all columns from all source files,
# inserting values of NA where there are no matching columns in a given input file, and creating a new data column to record
# source file names

# NOTE: R may report warnings at this step. This occurs because the values that are being merged may be of  
# of inconsistent types (i.e., may reflect a mixture of strings and numerical values). The merge will still proceed, 
# in spite of the warnings, but where value formats are inconsistent over merged values for a given variable, the variable
# type will be coerced to a character string format. 

merged1 <- bind_rows(all_csv, .id="sourcefile")

# Remove redundant Qualtrics table rows;
# uses matching on literal Qualtrics file column and row values, so may fail if Qualtrics column names or values change 

merged2 <- subset(merged1, V5 != "Finished",select=(colnames(merged1)))

# Now check for and drop duplicate rows

merged2 <- merged2 %>% distinct(ResponseID,Date,Name, .keep_all = TRUE)

# With redundant rows removed, attempt to reassign variable types to variables, most of which will have been
# coerced into character strings during application of the bind_rows function

merged3 <- merged2 %>% mutate_all(funs(type.convert(as.character(.))))

# Rename V1 - V5 variable names 

names(merged3)[names(merged3)=="V1"] <- "ResponseID" 
names(merged3)[names(merged3)=="V2"] <- "ResponseSet"
names(merged3)[names(merged3)=="V3"] <- "StartDate"
names(merged3)[names(merged3)=="V4"] <- "EndDate"
names(merged3)[names(merged3)=="V5"] <- "Finished"

# Drop variables containing Qualtrics timing data 

merged4 <- merged3[ ,grep("Time_", names(merged3), value = TRUE, invert = TRUE)]

# Drop observations (rows) if 'Name' variable value is NULL

# Note: The 'Name' field contains unique ParticipantID values.
# NULL values may be encountered here during pilot testing, due to administrative debugging and/or testing actions, but
# should not be encountered otherwise

merged5 <- subset(merged4, Name != "", select=(colnames(merged4)))

# Drop extraneous "X" variable;
# Other extraneous variables can be dropped here, by name, by adding them to the vector along with "X"

exclude <- names(merged5) %in% c("X")
merged6 <- merged5[!exclude]

# Derive new variables for day of week (Day), StartTime, and EndTime

merged6$Day <- gsub( "^(.+),.*" , "\\1" , merged6$DayWeek ) 
merged6$StartTime <- merged6$Timestamp
merged6$EndTime <- gsub("^.+ (.*)" , "\\1" ,merged6$EndDate)


# Create derivative date value for sorting 

merged6$TempDate <- as.Date(merged6$Date, format = "%m/%d/%Y")

# Sort table in ascending order by Date and then Participant ID (i.e. "Name") variable, and then drop temp date field

merged.sorted0 <- merged6[order(merged6$TempDate,merged6$Name),] 
merged.sorted <- subset(merged.sorted0, select = -c(TempDate))


# Optional:

# Reorder columns for easier navigation and review.
# CAUTION: this column reorder function is brittle; it relies on literal references to column names and
# will thus only work if the listed names exactly match those extracted from the source files. Should the names or 
# number of columns change, the list specified in the col_order variable will need to be updated accordingly. 

col_order <- c("sourcefile","surveytype","Name","Timesent","Date","Day","Timestamp","StartDate","EndDate","StartTime","EndTime","Finished",
               "context1","context2","context2_TEXT","context3","context3_TEXT","context4","context4_TEXT","stress","anxiety",
               "pand1","pand2","pand3","pand4","pand5","pand6","pand7","pand8","pand9","pand10",
               "bfid1","bfid2","bfid3","bfid4","bfid5","bfid6","bfid7","bfid8","bfid9","bfid10",
               "sleep_1","ex1_1","ex2_1","tob1","tob2_1","tob2_2","tob2_3","tob2_4","tob2_5","tob2_6","tob2_7",
               "alc1","alc2_1","alc2_2","alc2_3",
               "work","itpd1","itpd2","itpd3","irbd1","irbd2","irbd3","irbd4","irbd5","irbd6","irbd7",
               "dalal1","dalal2","dalal3","dalal4","dalal5","dalal6","dalal7","dalal8",
               "dalal9","dalal10","dalal11","dalal12","dalal13","dalal14","dalal15","dalal16",
               "DayWeek","ResponseID","ResponseSet","Q_TotalDuration","WaveIndex","PerParticipantSurveyTypeIndex","PerParticipantSurveyIndex")

merged.sorted <- merged.sorted[, col_order]


# Export the merged data file in .csv format (into a subdirectory with name specified, above, in OutputDir variable)
write.csv(merged.sorted, file = paste("./",OutputDir,"/","merged.daily.csv", sep=""),row.names = FALSE)
