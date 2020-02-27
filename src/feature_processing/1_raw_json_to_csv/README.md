# Raw Data Processing Scripts
The scripts in this folder are for the first stage of processing.  Each script is named after the sensor data stream it is intended for (e.g., *fitbit\_json\_to\_csv.py* operates on the raw Fitbit data), and each simply transforms the information in its raw form (e.g., json format) into a more readable tabular format (e.g., csv format).

## Execution
Each script is either written in Python or Bash and is intended to execute from the command line. The instructions for running each script are printed out when users attempt to run the script with no parameters.  Further instructions for each type of script are given below.

### Python
Each python script contains a Unix-style header allowing it to be executed from the command line on most modern Linux distributions.  For example, to run the fitbit script, type this into the command line:

`./fitbit_json_to_csv.py`

The output will read:

```
Please provide the following command line arguments:
 1) Fitbit json file to parse or folder containing json files
 2) Output folder path
```

One example proper command would look like this:

```
./fitbit_json_to_csv.py /tmp/tiles_data/data_record/fitbit/ ~/Desktop/tiles_data/raw_csv/fitbit
```

Each Python script will create any folders in the output path that do not already exist.

### Bash

The bash script `owlinone_jsonl_to_csv.sh` contains three different blocks of code, each processing the `.jsonl` files differently. This file can be copied into the raw `.jsonl` owlinone folder. When run, it will create three folders: `hoots`, `jelly`, and `minew`, with corresponding `csv` files.

Each block of code can also be run independently in the corresponding raw owlinone data directory.