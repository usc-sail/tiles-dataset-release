############################NOTICE#######################################################################################
#This software (or technical data) was produced for the U.S. Government under contract 
#2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14 , 
#ALT IV (MAY 2014) or (DEC 2007).
#©2019 The MITRE Corporation. All Rights Reserved. ######################################################################
####Approved for Public Release; Distribution Unlimited. Case Number 19-2656####

##########################################################################################################################
##############################################  Between-Subjects Convergent Validity #####################################
###############################################  Nonparametric Analysis using GeMM    ####################################
##########################################################################################################################

#############################################################  NOTES #########################################################################
## see "GEMM_METRIC_README.docx" for general information on running this code
## GeMM Must be installed prior to running this code
## please see "GEMM_METRIC_igtb.aligned_variables.xlsx" and  "GEMM_METRIC_sens.aligned_variables.xlsx" for  variable names and df structure required to run this code
###############################################################################################################################################

library(gemmR)
library(boot)
require(psych)


#Set root/working directory, then create subfolders for inputs and outputs (next)
setwd("C:\\YOURPATH\\ ")

#create subfolders in working directory for input (igtb and sensory derived score data) and output (validity metric results)
dir.create("data") #put input data in this folder
dir.create("output") #all results from this analysis will go here

#(optional)Load previous worksession (includes all df's)
#load("./output/GeMM_Convergent.RData")

##############################################################################################################################
############################### Import data and prepare df's for GeMM and bootsrap CI output #################################

# Import Ground Truth Data as the first command line argument
igtb <- read.csv("./data/igtb.aligned.csv")

# Import Corresponding Sensor Data as the first command line argument
sens <- read.csv("./data/sens.aligned.csv")

# Merge IGTB and sensor composites data sets by ID  
igtb_sens <- merge(igtb, sens, by="ID")

#reorder columns and keep relevant variables:
igtb_sens <- igtb_sens[c( "ID",
                                "igtb_shipley.vocab",    "sens_shipley.vocab",
                                "igtb_shipley.abs",      "sens_shipley.abs",
                                "igtb_extraversion",     "sens_extraversion",
                                "igtb_agreeableness",    "sens_agreeableness",
                                "igtb_conscientiousness","sens_conscientiousness",
                                "igtb_neuroticism",      "sens_neuroticism",
                                "igtb_openness",         "sens_openness",
                                "igtb_pos.affect",       "sens_pos.affect",
                                "igtb_neg.affect",       "sens_neg.affect",
                                "igtb_stai.trait",       "sens_stai.trait",
                                "igtb_audit",            "sens_audit",
                                "igtb_gats.status",     "sens_gats.status",
                                "igtb_gats.quantity",   "sens_gats.quantity",
                                "igtb_ipaq",            "sens_ipaq",
                                "igtb_psqi",            "sens_psqi"         )]


#Check all variables for out of range values etc. (optional)
summary(igtb_sens)

#Get descriptive statistics including skewness and kurtosis for each measure (optional)
descriptives<-describe(igtb_sens)
write.csv(descriptives, file = "./output/descriptives_convergent.csv")


# Make list of all variables needed for GeMM models/looping below
my_vars <- c("shipley.vocab", "shipley.abs", "extraversion", "agreeableness", "conscientiousness", 
  "neuroticism", "openness", "pos.affect", "neg.affect", "stai.trait", "audit", "gats.quantity", "ipaq",
  "psqi")


# Define data frame for GeMM and CI output - these are empty to be filled with GeMM and bootstrap results while going through the loops below
result_summaries <- data.frame(
  GeMM.Tau.A=rep(0.0, length(my_vars)),
  GeMM.Beta=rep(0.0, length(my_vars)),
  lower.CI=rep(0.0, length(my_vars)),
  upper.CI=rep(0.0, length(my_vars)),
  GeMM.r=rep(0.0, length(my_vars)),
  Boot.r=rep(0.0, length(my_vars)))
rownames(result_summaries) <- my_vars

####################################################################################################################
########################################## Run GeMM  and bootstrap CI's ############################################
#NOTE: All looping and 1,000 iterations for bootstrapping (see R= below) will start here#

for (v in my_vars){

  print(paste("Running analysis for: ", v))

  # Define the columns to be used here as m and n for the igtb and sensor data versions
  m <- paste("igtb_", v, sep="")
  n <- paste("sens_", v, sep="")

  # Create a new data-frame with the correct columns
  df <- igtb_sens[,c(m,n)]
  names(df)<-c("igtb","sens")

  gem <- gemm(igtb ~ sens, data=df, fit.metric="tau" )
  gemsum<-summary(gem) 

  #(optional) look at tau-to-r results from GeMM (GeMM.r) and compare to bootstrap point estimates (t*) to make sure they match
  #this is also provided in final df

  GeMM.r <-sin(pi*.5*gem$tau[1])*sign(gem$metric.betas[1])
  print(paste("GeMM_r_estimate=",GeMM.r)) 
  
  #  Bootstrap CI's #
  
  #Define function to extract tau from fitted gemm object and tranform into r for bootstrapping
  tauR <- function(formula, data, indices) {
    d <- data[indices,] # allows boot to select sample 
    fit <- gemm(formula, data=d, fit.metric="tau" )
    return(sin(pi*.5*fit$tau[1])*sign(fit$metric.betas[1]))
  } 

  #Run bootstrapping function 
  tauR(igtb ~ sens, df)
 
  boot_tauR <- boot(data=df, statistic=tauR, R=1000, formula=igtb ~ sens, parallel="multicore") 

  #(optional) Look at bootstrap results and confirm that it gives the same point estimate (t1 from boot_TauR) as GeMM code above (GeMM.r).
  print(boot_tauR)

  # (optional) Plot bootstrap estimates and save the file (output files will go to working directory)
  plot_file_name <- paste(v,'.png', sep="")
  png(plot_file_name)
  plot(boot_tauR)
  dev.off()
  
  #Calculate bootstrap CIs (3 methods)
  CI<-boot.ci(boot_tauR, type=c("norm", "basic", "perc"))  
  
  # Add results to records (report percentile method)
  result_summaries[v,] <- c(gemsum$tau.a[1], gemsum$metric.beta, CI$percent[4], CI$percent[5], GeMM.r,CI$t0[1]) 
#NOTE: last entry, CI$t0[1], is Boot.r

}

#view all GeMM and CI results (optional)
#Note: GeMM.r and Boot.r should be the same or very close, check here and then keep Boot.r below
print(result_summaries)
############################################################################################################

##############################  Prepare GeMM and CI Results File ###########################################

#add directional sign for easy reference
result_summaries$tau.dir<-sign(result_summaries$GeMM.Beta) #get sign, -1=negative, 1=positive, 0=0

#drop unnecessary variables for output and rename
gemm_summaries<-result_summaries[c("Boot.r","lower.CI","upper.CI")]
gemm_summaries<-setNames(cbind(rownames(gemm_summaries),gemm_summaries,row.names=NULL),c("Variable","r","Lower.CI","Upper.CI"))


#calculate summary metrics
SummaryTable <- data.frame(Mean=round(mean(gemm_summaries[,"r"]),2),
                           SD=round(sd(gemm_summaries[,"r"]),2),
                           MAD=round(mad(gemm_summaries[,"r"]),2),
                           TrimMean=round(mean(gemm_summaries[,"r"],trim=.2),2),
                           Min=round(min(gemm_summaries[,"r"]),2),
                           Max=round(max(gemm_summaries[,"r"]),2))

#NOTE: R implements the following approach for rounding off a 5, for further information on rounding, refer to R help "rounding of numbers":
#"the IEC 60559 standard is expected to be used, 'go to the even digit'. Therefore round(0.5) is 0 and round(-1.5) is -2.
#However, this is dependent on OS services and on representation error (since e.g. 0.15 is not represented exactly, 
#the rounding rule applies to the represented number and not to the printed number, and so round(0.15, 1) could be either 0.1 or 0.2). 

SummaryTable

#output results to csv
write.csv(gemm_summaries,"./output/GeMM_between_subj_convergent_constructs.csv") #construct level results
write.csv(SummaryTable,"./output/GeMM_between_subj_convergent_summary.csv") #summary metric

#save workspace (optional, saves all df's)
save.image("./output/GeMM_Convergent.RData")





