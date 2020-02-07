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

## This code will read all files contained in a user-specified directory that match user-specified file name
## conventions, merging the files vertically (i.e., row-wise) into a single table;
## it is designed to accommodate cases where the input file structures are inconsistent;
## specifically, it allows for the input files to have a mixture of shared and unique columns/variables,
## which will be merged into a single output table (and, optionally, file) that preserves all unique columns/variables
## from all input files.

## Columns are matched by name, and values for any missing columns are filled with "NA".
## A new variable is created to report source file names for each observation.

## Revisions ##

## 201804 * Updated to take as inputs API-exported daily ground truth survey results in csv format
##          Original version was designed to take manually-exported 
##          "legacy' format Qualtrics survey results as inputs
##        * Fixed sort function not recognizing and sorting on date values
##        * Now checking for and deleting duplicate observations 
##        * Now setting stringsAsFactors argument to FALSE when files are read in
##        * Revised protocol for generating a file list (looks only for .csv files with matching filename patterns)
##        * Revised protocol for specifying output directory (output dir name stored in a variable, now)

#######################################################################################################






################# USER INPUTS ######################

#Set working directory path

#This directory should include the daily survey file(s) that you wish to merge (in csv format)
setwd("Full Directory Path")

###Define a name for the output file subdirectory (name only, in quotes, not the full path)###
OutputDir <- "output"

############  END USER INPUTS #####################







# Load tidyverse library [install first, if necessary]
#install.packages("tidyverse") 
library(tidyverse)

# Create a list of all csv files found in the specified working directory that contain in their 
# filenames the string '_health_', '_job_', or '_personality_'. Revise the match pattern accordingly if
# using locally-customized file naming conventions.
filelist <- list.files(pattern = "(_health_|_job_|_personality_).+?.csv")

#Create an output file subdirectory within the specified working directory, using the 
#name defined in OutputDir variable
dir.create(OutputDir)


# Read all files into a new list of data frames.
#NOte: if you should see error, "Error in read.table(file = file, header = header, sep = sep, quote = quote,  : 
#no lines available in input", confirm that you are not attempting to merge any empty files (size=0kb)
all_csv <- lapply(filelist,read.csv, stringsAsFactors=FALSE)

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
# inserting values of NA where there are no relevant observations, and creating a new data column to record
# source file names

# NOTE: R may report warnings at this step. This occurs because the values that are being merged may be of  
# of inconsistent types (i.e., may reflect a mixture of strings and numerical values). The merge will still proceed, 
# in spite of the warnings, but where value formats are inconsistent over merged values for a given variable, the variable
# type will be coerced to a character string format. 

merged1 <- bind_rows(all_csv, .id="sourcefile")

# Check for and drop duplicate rows
merged2 <- merged1 %>% distinct(ResponseID,Date,Name, .keep_all = TRUE)

# Drop variables containing Qualtrics timing data 
merged3 <- merged2[ ,grep("Time_", names(merged2), value = TRUE, invert = TRUE)]

# Rename variable names from API-exported files to match variable names from 'legacy' format csv files
names(merged3) = gsub(pattern = "pand_|irbd_|itpd_|dalal_|bfid_", replacement = "", x = names(merged3))

# Drop observations (rows) if 'Name' variable value is NULL

# Note: The 'Name' field contains unique ParticipantID values.
# NULL values may be encountered here during pilot testing, due to administrative debugging and/or testing actions, but
# should not be encountered otherwise
merged4 <- subset(merged3, Name != "", select=(colnames(merged3)))

# Derive new variables for day of week (Day), StartTime, and EndTime
merged4$Day <- gsub( "^(.+),.*" , "\\1" , merged4$DayWeek ) 
merged4$StartTime <- merged4$Timestamp
merged4$EndTime <- gsub("^.+ (.*)" , "\\1" ,merged4$EndDate)

# Create derivative date value for sorting 
merged4$TempDate <- as.Date(merged4$Date, format = "%m/%d/%Y")

# Sort table in ascending order by TempDate and then Participant ID (i.e. "Name") variable, and then drop temp date field
merged.sorted0 <- merged4[order(merged4$TempDate,merged4$Name),] 
merged.sorted <- subset(merged.sorted0, select = -c(TempDate))

# Optional:

# Reorder columns for easier navigation and review.
# CAUTION: this column reorder function is brittle; it relies on literal references to column names and
# will thus only work if the listed names exactly match those extracted from the source files. Should the names or 
# number of columns change, the list specified in the col_order variable will need to be updated accordingly. 

col_order <- c("sourcefile","surveytype","Name","Date","Day","StartDate","EndDate","Timesent","Timestamp","StartTime","EndTime","Finished",
               "context1","context2","context2_TEXT","context3","context3_TEXT","context4","context4_TEXT","stress","anxiety",
               "pand1","pand2","pand3","pand4","pand5","pand6","pand7","pand8","pand9","pand10",
               "bfid1","bfid2","bfid3","bfid4","bfid5","bfid6","bfid7","bfid8","bfid9","bfid10",
               "sleep_1","ex1_1","ex2_1","tob1","tob2_1","tob2_2","tob2_3","tob2_4","tob2_5","tob2_6","tob2_7",
               "alc1","alc2_1","alc2_2","alc2_3",
               "work","itpd1","itpd2","itpd3","irbd1","irbd2","irbd3","irbd4","irbd5","irbd6","irbd7",
               "dalal1","dalal2","dalal3","dalal4","dalal5","dalal6","dalal7","dalal8",
               "dalal9","dalal10","dalal11","dalal12","dalal13","dalal14","dalal15","dalal16",
               "DayWeek","ResponseID","ResponseSet","Q_TotalDuration",
               "RO.BR.FL_9","RO.BR.FL_12","RO.BR.FL_15","RO.BR.FL_18","RO.BR.FL_20","DO.Q.pand")

merged.sorted <- merged.sorted[, col_order]

# Export the merged data file in .csv format (into a subdirectory with name specified, above, in OutputDir variable)
write.csv(merged.sorted, file = paste("./",OutputDir,"/","merged.daily.csv", sep=""),row.names = FALSE)

