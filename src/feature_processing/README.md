# Data Processing Pipeline Overview
All of the code used to convert the raw sensor data into the published dataset format is provided here.  The code is provided as documentation for reproducibility and curious investigators, but the fully processed dataset is conveniently available for download at <https://tiles-data.isi.edu>.

The processing is split into three stages:

 - Stage 1: Raw JSONL format conversion to tabular CSV format
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

#### Owls (RSSI data)
There instructions are meant to extract the RSSI information from the raw JSONL files from Owl-in-One to Owl-in-One interactions, Jelly to Owl-in-One interactions, and Minew to Owl-in-One interactions.

 1. Download the Owl-in-One data and store in the `<raw_owlinone_path>` folder
 2. Copy the file `1_raw_json_to_csv/owlinone_jsonl_to_csv.sh` file into the `<raw_owlinone_path>` folder. Change directory into the `<raw_owlinone_path>` folder and run (from the command line) the `owlinone_jsonl_to_csv.sh` file using:
```
$ ./owlinone_jsonl_to_csv.sh
```
This will generate three folders: `hoots/`, `minew`, `jelly` with the RSSI data from each stream.
 3. Process the raw CSV files generated in `<raw_owlinone_path>/hoots`, `<raw_owlinone_path>/minew`, and `<raw_owlinone_path>/jelly`. These files can be processed using the `2_preprocessing/owlinone/process_csv.jl` file as such:
```
julia process_csv.jl -r <raw_owlinone_path/stream> -w WRITE_FOLDER -s SENSOR
```
where sensor can be any of `owl`, `jelly`, `minew`. For more information on running this script, please run
```
julia process_csv.jl --help
```

#### Minew
 1. Download the raw Owl-in-One data and store in the `<raw_owl_path>` folder
 1. `1_raw_json_to_csv/minew_owl_json_to_csv.py <raw_owl_path> <minew_csv_path>`
 1. `2_preprocessing/minew_preprocess.py <minew_csv_path> <data_record_path>/owlinone/minew/data`

#### Jelly
1. See above (Owls - RSSI data)
2. Run `2_preprocessing/owlinone/split_jelly_events_by_participant.jl`:
```
julia split_jelly_events_by_participant.jl -r DATA_FOLDER -i MAPPING
                        [-w WRITE_FOLDER] [-f FILES]
```

### RealizD
 1. Download the raw RealizD data and store in the `<raw_realizd_path>` folder
 1. `1_raw_json_to_csv/realizd_preprocessor.py <data_record_path>/realizd`

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
