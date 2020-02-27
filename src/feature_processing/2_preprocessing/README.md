# Preprocessing Scripts
The scripts in this folder are for the second stage of processing.  Each script is named after the sensor data stream it is intended for (e.g., *fitbit\_preprocess.py* operates on the raw Fitbit data extracted to csv format from stage one), and each lightly processes the raw csv-formatted data from stage one and outputs a csv file with the same format.  Each sensor stream is processed differently, but in general these scripts identify artifacts and replace them either with sensible values or *NaNs*.

## Execution
Each script is intended to execute from the command line. The instructions for running each script are printed out when users attempt to run the script with no parameters.  Further instructions are given below.

### Python
Each python script contains a Unix-style header allowing it to be executed from the command line on most modern Linux distributions.  For example, to run the fitbit script, type this into the command line:

`./fitbit_preprocess.py`

The output will read:

```
Please provide the following command line arguments:
 1) Path to folder containing fitbit CSV files
 2) Output folder path for preprocessed fitbit CSVs
```

One example proper command (borrowing the example output folder from the README in stage one) would look like this:

```
./fitbit_preprocess.py ~/Desktop/tiles_data/raw_csv/fitbit ~/Desktop/tiles_data/preprocessed_csv/fitbit
```

Each script will create any folders in the output path that do not already exist.

### Julia

There are Julia scripts under the folder `owlinone/`. This folder contains the scripts to process the CSV files generated using the file:

```
tiles-dataset-release/src/feature_processing/1_raw_json_to_csv/owlinone_jsonl_to_csv.sh
```

The script `process_csv.jl` has been developed and tested using Julia 1.2. Running `julia process_csv.jl --help` will give you the following instructions:

```
usage: process_csv.jl -r DATA_FOLDER -w WRITE_FOLDER -s SENSOR
                      [-i DEVICEIDS] [-d DIRECTORIES] [-f FILES] [-h]

optional arguments:
  -r, --data_folder DATA_FOLDER
                        Path to the data folder containing csv.gz
                        files.
  -w, --write_folder WRITE_FOLDER
                        Path to the folder into which the files are
                        written.
  -s, --sensor SENSOR   Sensor information to parse from {owl, jelly, minew}.
  -i, --deviceids DEVICEIDS
                        DeviceIDs for each Owl-in-One. (default:
                        "deviceIDs.csv")
  -d, --directories DIRECTORIES
                        Directory <-> receiverId mapping for each wave
                        of data (default:
                        "directories_by_date_wav123.csv")
  -f, --files FILES     CSV file(s) to process in data_folder. It can
                        be a regex such as *.csv.gz (default)
                        (default: "*.csv.gz")
  -h, --help            show this help message and exit
```