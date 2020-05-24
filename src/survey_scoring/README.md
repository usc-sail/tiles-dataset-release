# NOTICE

This software (or technical data) was produced for the U.S. Government under contract 2015-14120200002-002, and is subject to the Rights in Data-General Clause 52.227-14 , ALT IV (MAY 2014) or (DEC 2007).
©2019 The MITRE Corporation. All Rights Reserved.
 
Approved for Public Release; Distribution Unlimited. Case Number 19-2656

There are four R scripts in the present collection that are used for processing and scoring Qualtrics survey responses. 

They are:

1. SCORING_IGTB_scoring_Version2.3_PR.r

Reads in raw Qualtrics survey responses from the Initial Ground Truth Battery (IGTB) survey and generates scored "ground truth" survey outputs for each IGTB instrument.

2. SCORING_Sample_Daily_Data_Merge_Legacy_PR.r

Reads in multiple "Daily" Qualtrics survey response files (one per unique calendar date per unique study cohort) and merges them into a single tabular file, to facilitate downstream data processing. There are two versions. This version (with "Legacy" in the filename) operates over Qualtrics survey results in Qualtrics' so-called "Legacy" file format.
 
3. SCORING_Sample_Daily_Data_Merge_API_PR.r

Substantively equivalent to the file, "SCORING_Sample_Daily_Data_Merge_Legacy_20180417_PR.r", but operates over Qualtrics survey results exported via API (which have a slightly different structure).

4. SCORING_Daily_scoring_Version2.0_PR.r

Reads in Daily Qualtrics results, as output by one of the "SCORING_Sample_Daily_Data_Merge" scripts (see 2 and 3, above) and generates scored "ground truth" survey outputs for each instrument included in the Daily surveys.
