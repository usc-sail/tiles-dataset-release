# Feature Extraction Scripts
This folder contains two files:

 - `days_at_work.py`
 - `x_previous_days_at_work.py`

 The first file takes input streams (`{'omsignal', 'owlinone', 'surveys'}`) and infers the days at work from these streams. For help and usage directions, please type:
 
 ```
	python days_at_work.py --help
 ```
 
 `x_previous_days_at_work.py` takes the files written by `days_at_work.py` and computes a merged version of the files to get a better estimate of the days at work. This file can also be used to generate a file that counts the number of previous days at work for a given participant.