
#NOTICE
#This software (or technical data) was produced for the U.S. Government under contract 
#2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14 , 
#ALT IV (MAY 2014) or (DEC 2007).
#©2019 The MITRE Corporation. All Rights Reserved. Approved for Public Release; Distribution Unlimited. Case Number 19-2656

####################################################################################################
###################################Within-Subjects##################################################
####################################################################################################

##Packages##
library("nlme")
library("lme4")
library("mitml")
library("boot")

##Functions##

  #Function to extract only within (level-1) R-squared
  rsqW <- function(.) {multilevelR2(.,print=c("RB1"))}

  
#Set working directory.  Note: This will vary by machine and user.
setwd("C:/xxx/xxx/xxx/xxx/xxx/xxx")


#Read data into R 
team_data <- read.csv("yourFileName.csv", header=TRUE)

###Example code below is for one measure: extraversion.d###
###You will need to rerun this code for each of your measures###


###########################
#Unconditional means model# 
###########################

  #model_extra1 <- lmer(GroundTruth~ 1 + (1|ID), data=subset(team_data, variable.name=="extraversion.d"), na.action=na.omit, REML=FALSE)
  #summary(model_extra1)
  
  #Bootstrap Standard errors. Can check significance of the variance components with this and/or
  #calculate ICC if needed. Caluclation of ICC is useful to test whether there is sufficient within-person
  #variability to to run the conditional model below. 
  
  #set.seed(3210)
  #confint(model_extra1, method="boot", boot.type = c("perc"), nsim=1000)


###########################################################
#Conditional Model with Sensor as a time varying predictor#
###########################################################
  
  #Model with random sensor effect the default
  model_extra2 <- lmer(GroundTruth ~ ScoreEstimate + (ScoreEstimate|ID), data=subset(team_data, variable.name=="extraversion.d"), na.action=na.omit, REML=FALSE)
  summary(model_extra2)
  
  #Bootstrap CIs.
  set.seed(3210)
  confint(model_extra2, method="boot", boot.type = c("perc"), nsim=1000)

    #Model with sensor as a fixed effect only (only necessary if we run into estimation problems with the above)
    #modelUT2 <- lmer(out~ sensor + (1|ID), data=MOSAIC_data, na.action=na.omit, REML=FALSE)
    #summary(modelUT2)
    #Residual = .X.XXX
  
    #Bootstrap CIs.
    #set.seed(321)
    #confint(modelUT2, method="boot", boot.type = c("perc"), nsim=1000)
  
    #Model test to compare fixed sensor vs random sensor models  
    #anova(modelUT2,modelUTR2)
  
  #Calculating bootstrapped confidence intervals around estimates 
  #of within-person variance explained from fitted LMER model
  
  #Bootstrapping with 1000 replications
  rsq_out_extra <- bootMer(model_extra2, rsqW, nsim=1000, seed=3210)  
  rsq_out_extra#Look at results
    bootData <- as.data.frame(rsq_out_extra)#Save each bootstrap estimate to a data frame if needed for future
    plot(rsq_out_extra)#plot bootstrapped estimates
    boot.ci(rsq_out_extra, type=c("perc"))#Calculate bootstrap CIs


    ###############################
    ##Assessing model assumptions##
    ###############################
    plot(model_extra2)   
    hist(residuals(model_extra2))
    qqnorm(resid(model_extra2))  
    plot(model_extra2, ID~resid(.))
    
    
    
    
  ##################################
  ###Analyses below are commented out. You
  ###can run by just changing out the variables names in the code below.
  ###These are supplementary analyses and the MI analysis should not be run without full data
  ###with all covariates, etc.   
  ##################################
      
  ######################################################
  #Decomposing within and between effects of the sensor#
  ######################################################
  
  #Separating the between and within-subject time varying effects.  Example with fixed within sensor effect.
  #modeldev <- lmer(out~ sensor_m + sensor_dev + (1|ID), data=MOSAIC_data, na.action=na.omit, REML=FALSE)
  #summary(modeldev)
  #Residual = 2.4173
  
  #Example with random sensor effect.
  #modeldevR <- lmer(out~ sensor_m + sensor_dev + (sensor_dev|ID), data=MOSAIC_data, na.action=na.omit, REML=FALSE)
  #summary(modeldevR)

  #Testing to see if there are any differences between the the standard model (where we assume the between and 
  #within effects are equal) and the dev model (that does not make this assumption).
  #anova(modelUT2,modeldev)
  
  
  ############################################
  ##Unconditional/COnditional Models with MI##
  ############################################
  
  #Imputation with mitml package
  #Read data into R 
  #MOSAIC_data_missing <- read.csv("MOSAIC_mock_data_missing.csv", header=TRUE)
  
  #Specifying the imputation model (include all variables a) part of the model of interest,
  #b) related to variables in model, and c) related to missingness in model variables. In this
  #limited mock dataset we only include out and sensor to demonstrate procedure.
  #MI1 <- out + sensor ~ 1 + (1|ID) 
  
  #Imputation procedure (requesting 100 imputed datasets)
  #imp <- jomoImpute(MOSAIC_data_missing, formula=MI1, n.burn=5000, n.iter=100, m=100)
  
  #Assessing convergence of MI procedure. Check that "potential scale reduction factor" is ~1 for 
  #each parameter.  If inflated by more than 5% then run again with longer burn in period.
  #summary(imp)
  
  #Complete the datasets with the imputations generated above
  #implist <- mitmlComplete(imp, "all")
  
  #Unconditional model on the 100 imputed data sets pooling results
  #modelU2_I <- with(implist, lmer(out~ 1 + (1 |ID), REML=FALSE))
  #testEstimates(modelU2_I, var.comp=TRUE)
  
  #Conditional model on the 100 imputed data sets pooling results
  #modelUTR2_I <- with(implist, lmer(out~ sensor + (sensor|ID), REML=FALSE))
  #testEstimates(modelUTR2_I, var.comp=TRUE)
  
  #Calculate within explained variance. Percentage residual reduction after adding predictor of 
  #sensor.
  #multilevelR2(modelUTR2_I, print=c("RB1"))
  
  