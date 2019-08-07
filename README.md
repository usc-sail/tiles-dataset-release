# tiles-dataset-release
Code accompanying the TILES dataset paper and data release

### Data Record folder structure
(all files are in csv.gz format)

```
├── data_record
│   ├── fitbit
│   │   ├── daily-summary (per participant)
│   │   ├── heart-rate (per participant)
│   │   └── step-count (per participant)
│   ├── metadata
│   │   ├── days-at-work (per participant)
│   │   └── participant-info (single file)
│   ├── omsignal
│   │   ├── features (per participant)
│   │   ├── ecg (per participant)
│   │   └── metadata (per participant)
│   ├── owlinone
│   │   ├── jelly (per participant)
│   │   ├── minew
│   │   │   │── data (single file -- per stream)
│   │   │   │── locations (single file)
│   │   │   └── rssi (per day)
│   │   ├── owls
│   │   │   │── locations (single file)
│   │   │   └── rssi (per day)
│   ├── realizd
│   ├── surveys
│   │   ├── raw
│   │   │   ├── pre-study
│   │   │   ├── IGTB
│   │   │   ├── MGT
│   │   │   ├── S-MGT
│   │   │   └── post-study
│   │   ├── scored
│   │   │   ├── pre-study
│   │   │   ├── IGTB
│   │   │   ├── MGT
│   │   │   ├── S-MGT
│   │   │   └── post-study

```
There is one `README` file per sub-folder, describing the `csv.gz` files.
