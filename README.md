# tiles-dataset-release
Code accompanying the TILES dataset paper and data release

### Proposed Data Record folder structure
(all files are in csv.gz format)

```
├── data_record
│   ├── fitbit
│   │   ├── daily-summary (per participant)
│   │   ├── heart-rate (per participant)
│   │   └── step-count (per participant)
│   ├── omsignal
│   │   ├── features (per participant)
│   │   └── ecg-snippets (per participant)
│   ├── owlinone
│   │   ├── owls-rssi (per day)
│   │   ├── jelly-rssi (per participant)
│   │   ├── minew-rssi (per day)
│   │   └── minew-data (per stream)
│   ├── surveys
│   │   ├── pre-study-raw
│   │   ├── IGTB-raw
│   │   ├── MGT-raw
│   │   ├── S-MGT-raw
│   │   ├── post-study-raw
│   │   ├── pre-study-scored
│   │   ├── IGTB-scored
│   │   ├── MGT-scored
│   │   ├── S-MGT-scored
│   │   └── post-study-scored
│   ├── realizd
│   └── participant-info
│       ├── id-mapping
│       └── days-at-work
```
There is one `README` file per sub-folder, describing the `csv.gz` files.