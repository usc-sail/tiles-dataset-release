# tiles-dataset-release
Code accompanying the TILES dataset paper and data release

### Proposed Data Record folder structure
(all files are in csv.gz format)

```
├── data_record
│   ├── fitbit
│   ├── owlinone
│   │   ├── owls-rssi (per day)
│   │   ├── jelly-rssi (per participant)
│   │   ├── minew-rssi (per day)
│   │   └── minew-data (per stream)
│   ├── omsignal
│   │   ├── features (per participant)
│   │   └── ecg-snippets (per participant)
│   ├── surveys
│   │   ├── pre-study
│   │   ├── IGTB
│   │   ├── MGT
│   │   ├── MGT-supplemental
│   │   └── post-study
│   ├── realizd
│   └── participant-info
│       ├── demographics
│       ├── id-mapping
│       ├── days_at_work
│       └── start_end_work_times (per participant -- inferred)
│   ├── extracted_features (?)
```