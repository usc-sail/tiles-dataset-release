# Data Processing Pipeline Overview
All of the code used to convert the raw sensor data into the published dataset format is provided here.  The code is provided as documentation for reproducibility and curious investigators, but the fully processed dataset is conveniently available for download at <https://tiles-data.isi.edu>.

The processing is split into three stages:
 - Stage 1: Raw JSON format conversion to tabular CSV format
 - Stage 2: Preprocessing to fix or mark artifacts in the data
 - Stage 3: Feature extraction

Each sensor stream is processed separately using a sequence of corresponding scripts.  Each sensor stream's raw data varies in the amount of preprocessing that occurred before it was recorded.  Thus, not every stream requires processing at all three stages.  The sequence of scripts necessary to process each stream is given below.

## Sensor Data Processing
This section provides the sequence of scripts that need to be executed to convert the raw (typically JSON-formatted) data into the CSV data.  Please see the dataset paper for details about the raw data collection and formatting.

### Fitbit
 1. Download the raw Fitbit data and store in the `<raw_fitbit_path>` folder
 1. `1_raw_json_to_csv/fitbit_json_to_csv.py <raw_fitbit_path> <fitbit_csv_path>`
 1. `2_preprocessing/fitbit_preprocess.py <fitbit_csv_path> <data_record_path>/fitbit`

### OMSignal
 1. Download the raw OMsignal data and store in the `<raw_omsignal_path>` folder
 1. `1_raw_json_to_csv/omsignal_json_to_csv.py <raw_omsignal_path> <omsignal_csv_path>`
 1. `2_preprocessing/omsignal_preprocess.py <omsignal_csv_path> <data_record_path>/omsignal/features`

### Owl-in-One
The Owl-in-One sensors are hubs that aggregated Bluetooth transmissions from other sensors.  The Minew (environmental sensors), Jelly (proximity tracking), and other Owl-in-One (localization) are all included in the raw JSON data.  Different scripts parse the raw data to extract each sensor stream.  Details are below.

#### Owls
***TODO - @Karel, please split up the Julia code so it runs in two stages: (1) raw data tabulation and (2) preprocessing. Also, please remove the dependency on the `jelly_id_mapping_wav*.csv` files by allowing users to pass in a path to those files on the command line, then make sure these files are included in the dataset.***
 1. ***TODO - @Karel, please include instructions on running the code.***

#### Minew
 1. Download the raw Owl-in-One data and store in the `<raw_owl_path>` folder
 1. `1_raw_json_to_csv/minew_owl_json_to_csv.py <raw_owl_path> <minew_csv_path>`
 1. `2_preprocessing/minew_preprocess.py <minew_csv_path> <data_record_path>/owlinone/minew/data`

#### Jelly
***TODO - @Karel, please split up the Julia code so it runs in two stages: (1) raw data tabulation and (2) preprocessing. Also, please remove the dependency on the `jelly_id_mapping_wav*.csv` files by allowing users to pass in a path to those files on the command line, then make sure these files are included in the dataset.***
 1. ***TODO - @Karel, please include instructions on running the code.***

### RealizD
 1. Download the raw RealizD data and store in the `<raw_realizd_path>` folder
 1. `1_raw_json_to_csv/realizd_preocessor.py <data_record_path>/realizd`

### Surveys
***TODO - @Brandon, add the scoring R code once IARPA releases and approves it***
 1. ***TODO - @Brandon, include instructions for running the code***

### Days at Work
 1. Download the OMsignal data, the Owl-in-One data, and the survey data.
 2. Run the script as follows:

 ```
	python days_at_work.py -s stream -i stream_data_directory -o write_folder
 ```
 3. To merge the files, run

 ```
	python x_previous_days_at_work.py -x 1 -f data_folder
 ```
 where `data_folder` is the same folder as `write_folder` in the previous step.
