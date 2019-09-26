############################NOTICE#######################################################################################
#This software (or technical data) was produced for the U.S. Government under contract 
#2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14 , 
#ALT IV (MAY 2014) or (DEC 2007).
#©2019 The MITRE Corporation. All Rights Reserved. ######################################################################
#Approved for Public Release; Distribution Unlimited. Case Number 19-2656#############

##############################################################################################
################################   Incremental Criterion  Validity    ########################
#################################  Nonparametric Analysis using GeMM    ######################
##############################################################################################


#############################################################  NOTES #########################################################################
## see "GEMM_METRIC_README.docx" for general information on running this code
## GeMM Must be installed prior to running this code
## please see "GEMM_METRIC_igtb.aligned_variables.xlsx" and  "GEMM_METRIC_sens.aligned_variables.xlsx" for  variable names and df structure required to run this code
###############################################################################################################################################

library(gemmR)
require(psych)
library(boot)

#Set root/working directory, then create subfolders for inputs and outputs (next)
setwd("C:\\YOURPATH")

#create subfolders in working directory for input (igtb and sensor-derived score data) and output (validity metric results)
dir.create("data") #put input data in this folder
dir.create("output") #all results from this analysis will go here

#(optional)Load previous worksession (includes all df's)
#load("./output/GeMM_Incremental.RData")

#Importing IGTB composite scores and Sensor derived composite scores

#Import ground truth 
igtb <- read.csv("./data/igtb.aligned.csv")

#Import corresponding sensor data
sens <- read.csv("./data/sens.aligned.csv")

#merge IGTB and sensor composites data sets by ID  
igtb_sens <- merge(igtb, sens, by="ID")  #igtb and sens scores must match by ID

#Create a data frame with only necessary variables (job performance, shipley vocab and abs, neuroticism, conscientiousness)
incremental <- igtb_sens          [c("ID",
                                "igtb_irb",              "sens_irb",
                                "igtb_itp",              "sens_itp",
                                "igtb_ocb",              "sens_ocb",
                                "igtb_inter.deviance",   "sens_inter.deviance",
                                "igtb_org.deviance",     "sens_org.deviance",   
                                "igtb_shipley.vocab",    "sens_shipley.vocab",
                                "igtb_shipley.abs",      "sens_shipley.abs",
                                "igtb_conscientiousness","sens_conscientiousness",
                                "igtb_neuroticism",      "sens_neuroticism")]

#Check all variables for out of range values etc. (optional)
summary(incremental)

#Get descriptive statistics for each measure (optional)
descriptives<-describe(incremental)
write.csv(descriptives, file = "./output/descriptives_incremental.csv")

# Make list of all variables/measures needed for GeMM models/looping below
my_vars <- c("irb", "itp", "ocb", "inter.deviance", "org.deviance")

# Define data frame for GeMM incremental r-square and CI output
#these are empty now, to be filled with GeMM and bootstrap results while going through the loops below

result_summaries <- data.frame(
  r2.incr=rep(0.0, length(my_vars)),
  lower.CI=rep(0.0, length(my_vars)),
  upper.CI=rep(0.0, length(my_vars)))
rownames(result_summaries) <- my_vars

#################################################################################################################
#Run all gemm models and bootstrap CI's (looping will start automatically at this point and will take some time to run)

for (v in my_vars){

  print(paste("Running analysis for: ", v))
  
  # Define the columns to be used here as m and n for the igtb and sensor data versions
  m <- paste("igtb_", v, sep="")
  n <- paste("sens_", v, sep="")

  # Create a new data-frame with the correct columns
  df <- igtb_sens[,c(m, n, "igtb_shipley.vocab", "igtb_shipley.abs", 
    "igtb_neuroticism", "igtb_conscientiousness")]
  
  # Rename all
  names(df)<-c("igtb","sens","igtb_shipley.vocab", "igtb_shipley.abs", 
    "igtb_neuroticism", "igtb_conscientiousness")

  #Create subset dfs by predicted variable, limiting to cases (IDs) for which we have complete observations across
  #all relevant modeled variables
  incremental_subset <- subset(df,
                          !is.na(igtb)&
                          !is.na(sens)&
                          !is.na(igtb_shipley.vocab)&
                          !is.na(igtb_shipley.abs)&
                          !is.na(igtb_neuroticism)&
                          !is.na(igtb_conscientiousness))

  ########################################################################################################
  ######################################  Run GeMM and Bootstrap CIs  ####################################
  ########################################################################################################

  #Define function to extract tau from two fitted gemm objects, tranform each into R2, 
  #and then subtract model2-model1 to get incremental R2.
  tauRincr <- function(model1, model2, data, indices) {
    d <- data[indices,] # allows boot to select sample 
    fit1 <- gemm(model1, data=d, fit.metric="tau",n.beta=10000)
    fit2 <- gemm(model2, data=d, fit.metric="tau",n.beta=10000)
    return(sin(pi*.5*max(fit2$tau))^2 - sin(pi*.5*max(fit1$tau))^2)
  } 

  #Run bootstrapping function 
  #(NOTE: 1,000 replications should be used for official analysis but will take a long time to run.  
  #R can be set to 10 for testing this code, but confidence intervals will not be as precise)
  boot_tauR2incr <- boot(data=incremental_subset, statistic=tauRincr, 
                           R=1000, model1=igtb~igtb_shipley.vocab + igtb_shipley.abs +
                             igtb_neuroticism + igtb_conscientiousness, model2=igtb~igtb_shipley.vocab + igtb_shipley.abs +
                             igtb_neuroticism + igtb_conscientiousness + sens,parallel="multicore") 

  # (optional) view incremental R2 from boot function (t0 from bootstrap statistics) 
  
  print("incremental R2 from boot function:")
  print(boot_tauR2incr)
  
  # (optional) Plot bootstrap estimates and save the file (output files will go to working directory)
  plot_file_name <- paste('./output/streamlined/incremental-',v,'.png', sep="")
  png(plot_file_name)
  plot(boot_tauR2incr)
  dev.off()

  #Calculate bootstrap CIs (3 methods, report percentile)
  CI<-boot.ci(boot_tauR2incr, type=c("norm", "basic", "perc"))

  # Add bootstrap results to GeMM results df (report percentile method for CIs)
  result_summaries[v,c("r2.incr","lower.CI","upper.CI")] <- c(CI$t0[1],CI$percent[4], CI$percent[5])

}

#view all GeMM and CI results (optional)
print(result_summaries)
##############################################################################################

##############################  Prepare GeMM/incremental r-square and CI Results File ###########################################
#rename variables
gemm_summaries<-setNames(cbind(rownames(result_summaries),result_summaries,row.names=NULL),c("Variable","r2.incr","Lower.CI","Upper.CI"))

#calculate summary metric for incremental r-square
SummaryTable <- data.frame(Mean=round(mean(gemm_summaries[,"r2.incr"]),3),
                           SD=round(sd(gemm_summaries[,"r2.incr"]),3),
                           MAD=round(mad(gemm_summaries[,"r2.incr"]),3),
                           TrimMean=round(mean(gemm_summaries[,"r2.incr"],trim=.2),3),
                           Min=round(min(gemm_summaries[,"r2.incr"]),3),
                           Max=round(max(gemm_summaries[,"r2.incr"]),3))

#NOTE: R implements the following approach for rounding off a 5, for further information on rounding, refer to R help "rounding of numbers":
#"the IEC 60559 standard is expected to be used, 'go to the even digit'. Therefore round(0.5) is 0 and round(-1.5) is -2.
#However, this is dependent on OS services and on representation error (since e.g. 0.15 is not represented exactly, 
#the rounding rule applies to the represented number and not to the printed number, and so round(0.15, 1) could be either 0.1 or 0.2). 

#view summary metric stats
SummaryTable

#output results to csv
write.csv(gemm_summaries,"./output/GeMM_incremental_constructs.csv") #construct level results
write.csv(SummaryTable,"./output/GeMM_incremental_summary.csv") #summary metric

#save workspace (optional, saves all df's)
save.image("./GeMM_Incremental.RData")







