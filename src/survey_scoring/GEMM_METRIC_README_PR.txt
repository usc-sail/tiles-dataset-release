NOTICE
This software (or technical data) was produced for the U.S. Government under contract 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14 , ALT IV (MAY 2014) or (DEC 2007).
©2019 The MITRE Corporation. All Rights Reserved.
Approved for Public Release; Distribution Unlimited. Case Number 19-2656

MOSAIC Phase 1 Data Analysis 
Revised R Code to Calculate Validity Metrics and Bootstrapped Confidence Intervals
General Instructions

The following list summarizes the R code and associated files needed to calculate between subjects convergent validity and bivariate and incremental criterion validity metrics using the nonparametric, GeMM approach. This code also includes confidence interval calculations using a bootstrapping approach. 
Please note:
* Prior to running the R code below, the GeMM package for R must be installed and data files must be configured according to the data layout files listed.
* Confidence intervals (CIs) are bootstrapped using the R package ‘boot’ which may take a long time to run depending on your computing resources.
* CI calculations are only an approximation and are not part of the formal program metrics.
* Bootstrapping replications should be set to at least R=1,000 for official runs.  This will take a long time to run so the number of iterations (R in the boot function call) can be adjusted to 5-10 runs for testing purposes, if desired.
* For incremental criterion validity there may slight variability (SD = .001-.003) in the estimated construct-level incremental r-square from one run to the next.  This variability is to be expected given GeMM’s computational methods for estimating the coefficients that are used to optimize tau and, by extension, calculate incremental r-square.  In MITRE’s testing, construct-level metrics only varied at the thousandth decimal place. This construct-level variability did not extend to variability in the summary metrics. 

1) R code File Name: GEMM_METRIC_Between_subjects_with_CIs_PR.r
R code Purpose: Between-Subjects Convergent Validity
Corresponding Data Layout File: GEMM_METRIC_igtb.aligned_variables.csv; GEMM_METRIC_sens.aligned_variables.csv

2) R code File Name: GEMM_METRIC_Bivariate_criterion_with_CIs_PR.r
R code Purpose: Bivariate Criterion Validity
Corresponding Data Layout File: GEMM_METRIC_igtb.aligned_variables.csv; GEMM_METRIC_sens.aligned_variables.csv

3) R code File Name: GEMM_METRIC_Incremental_criterion_with_CIs_PR.r
R code Purpose: Incremental Criterion Validity
Corresponding Data Layout File: GEMM_METRIC_igtb.aligned_variables.csv; GEMM_METRIC_sens.aligned_variables.csv

