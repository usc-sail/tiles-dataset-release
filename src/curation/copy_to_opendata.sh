#!/bin/bash

if [[ ! "$#" -eq 3 ]]
then
    printf "Please provide the correct arguments\n"
    printf "Usage: %s <raw data bucket> <processed data bucket> <target bucket>\n" "$0"
    exit 1
fi

RAW_BUCKET="$1"
PROCESSED_BUCKET="$2"
TARGET_BUCKET="$3"


mkdir tmp
cd tmp

## Copying Fitbit

aws s3 cp --exclude '*heartRate*' --exclude '*stepCount*' --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/fitbit/ s3://${TARGET_BUCKET}/fitbit/daily-summary/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/fitbit/daily-summary/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/fitbit/daily-summary/$f" "s3://${TARGET_BUCKET}/fitbit/daily-summary/${f//_dailySummary/}"
done

aws s3 cp --exclude '*dailySummary*' --exclude '*stepCount*' --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/fitbit/ s3://${TARGET_BUCKET}/fitbit/heart-rate/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/fitbit/heart-rate/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/fitbit/heart-rate/$f" "s3://${TARGET_BUCKET}/fitbit/heart-rate/${f//_heartRate/}"
done

aws s3 cp --exclude '*heartRate*' --exclude '*dailySummary*' --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/fitbit/ s3://${TARGET_BUCKET}/fitbit/step-count/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/fitbit/step-count/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/fitbit/step-count/$f" "s3://${TARGET_BUCKET}/fitbit/step-count/${f//_stepCount/}"
done


## Days at Work

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/4_extracted_features/days_at_work/ s3://${TARGET_BUCKET}/metadata/days-at-work/


## Participant Info

aws s3 cp s3://${PROCESSED_BUCKET}/participant_info/participant_info.csv .
gzip participant_info.csv
mv participant_info.csv.gz participant-info.csv.gz
aws s3 cp participant-info.csv.gz s3://${TARGET_BUCKET}/metadata/participant-info/


## OMSignal Features

for f in $(aws s3 ls s3://${PROCESSED_BUCKET}/3_preprocessed_data/omsignal/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 cp "s3://${PROCESSED_BUCKET}/3_preprocessed_data/omsignal/$f" "s3://${TARGET_BUCKET}/omsignal/features/${f//_omsignal/}"
done


## OWL-in-One: Jelly
# FIXME: remove participant_id
# FIXME: remove mac address

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/owl_in_one/ s3://${TARGET_BUCKET}/owlinone/jelly/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/owlinone/jelly/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/owlinone/jelly/$f" "s3://${TARGET_BUCKET}/owlinone/jelly/${f//_bleProximity/}"
done


## OWL-in-One: Minew Data
# FIXME: remove mac address

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/minew/ s3://${TARGET_BUCKET}/owlinone/minew/data/


## OWL-in-One: Minew Locations

aws s3 cp s3://${PROCESSED_BUCKET}/owl_locations/minew_locations_keck.csv.gz s3://${TARGET_BUCKET}/owlinone/minew/locations/


## OWL-in-One: Minew RSSI
# FIXME: remove mac address

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/2_raw_csv_data/minew_rssi/ s3://${TARGET_BUCKET}/owlinone/minew/rssi/


## OWL-in-One: OWL Locations

aws s3 cp s3://${PROCESSED_BUCKET}/owl_locations/owl_locations_keck.csv.gz s3://${TARGET_BUCKET}/owlinone/owls/locations/


## OWL-in-One: OWL RSSI

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/2_raw_csv_data/hoots/ s3://${TARGET_BUCKET}/owlinone/owls/rssi/


## RealizD

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/2_raw_csv_data/realizd/ s3://${TARGET_BUCKET}/realizd/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/realizd/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/realizd/$f" "s3://${TARGET_BUCKET}/realizd/${f//_realizd/}"
done

aws s3 sync s3://${TARGET_BUCKET}/realizd/ .
mkdir sorted
for f in *.csv.gz
do
    cat \
      <(zcat "$f" | head -n1) \
      <(zcat "$f" | \
          tail -n +2 | \
          sed -e 's/\.000//' | \
          sort) | \
      gzip > "sorted/$f"
done
aws s3 sync sorted/ s3://${TARGET_BUCKET}/realizd/


## Surveys: RAW / MGT
# Note: weird files with “July” in the name!!
# Note: PILOT data removed

# for f in $(aws s3 ls s3://${RAW_BUCKET}/ground_truth/MGT/ | sed -e 's/^.*[0-9] \(USC.*\)$/\1/' | grep -E '(DAY|NIGHT)' | grep -v 'July')
# do
#     aws s3 cp "s3://${RAW_BUCKET}/ground_truth/MGT/$f" "s3://${TARGET_BUCKET}/surveys/raw/MGT/$(echo "$f" | sed -e 's/USC_\([A-Z]*\)_\([0-9]\{4\}\)\([0-9]\{2\}\)\([0-9]\{2\}\)_\(.*\)_\(.*\)\.csv/\2-\3-\4-\6-\1-\5.csv/')"
# done
# mkdir tmp
# cd tmp
# aws s3 cp --recursive s3://${TARGET_BUCKET}/surveys/raw/MGT/ .
# find . -name "*csv" -print0 | xargs -0 -P 8 -I % gzip %
# aws s3 sync . s3://${TARGET_BUCKET}/surveys/raw/MGT/ --delete --dryrun


aws s3 cp s3://${PROCESSED_BUCKET}/2_raw_csv_data/ground_truth/MGT/MGT.csv.gz .
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

cat > remove_quotes.awk <<EOF
BEGIN {
  OFS=",";
  FS=",";
  FPAT="([^,]*)|(\"[^\"]+\")"
}
{
  for (i=1; i<=NF; i++) {
    if ($(zcat MGT.csv.gz | head -n1 | tr , '\n' | grep -nE '(TEXT|DayWeek)' | cut -d: -f1 | sed -e 's/^/i!=/' -e 's/$/ \&\&/' | tr '\n' ' ' | sed -e 's/ && $//')) {
      \$(i) = gensub(/^\"(.*)\"$/, "\\\\1", "1", \$(i))
    }
  }
  print
}
EOF

#   print $(zcat MGT.csv.gz | head -n1 | sed -e 's/,/\n/g'  | grep -ivn -E "(sourcefile|context.*_TEXT|DayWeek|ResponseID|ResponseSet)"  | cut -f1 -d: | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')
cat > subset.awk <<EOF
BEGIN {
  OFS=",";
  FS=",";
  FPAT="([^,]*)|(\"[^\"]+\")"
}
{
  print $(zcat MGT.csv.gz | head -n1 | sed -e 's/,/\n/g'  | grep -ivn -E "(sourcefile|DayWeek|ResponseID|ResponseSet)"  | cut -f1 -d: | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')
}
EOF

cat > fix_missing_sent_time.awk <<EOF
BEGIN {
  FS=",";
  OFS=",";
  FPAT="([^,]*)|(\"[^\"]+\")"
}
length(\$4) == 0 && \$1 ~ /6am/ {
  \$4 = "6:00am";
  print
}
length(\$4) == 0 && \$1 ~ /6pm/ {
  \$4 = "6:00pm";
  print
}
length(\$4) == 0 && \$1 ~ /12am/ {
  \$4 = "12:00am";
  print
}
length(\$4) == 0 && \$1 ~ /12pm/ {
  \$4 = "12:00pm"; print
}
{
  print
}
EOF

cat > reorder.awk <<EOF
BEGIN {
  FS=",";
  OFS=",";
  FPAT="([^,]*)|(\"[^\"]+\")"
}
length(\$2) > 0 {
  \$3 = \$4 "T" \$3;
  print \$2,\$1,\$3,\$7,\$8,\$83,$(for i in $(seq 11 82); do echo -n "\$$i,"; done | sed -e 's/,$//')
}
EOF


zcat MGT.csv.gz | \
  grep --binary-files=text -v '"SY' | \
  sed 's/\r$//' | \
  gawk -f remove_quotes.awk | \
  sed -e 's/""//g' | \
  gawk -f fix_missing_sent_time.awk | \
  grep -E "(sourcefile|NIGHT|DAY)" | \
  gawk -f subset.awk | \
  sed -e 's/NA//g' -e 's@,\([0-9]\{1,2\}\)/\([0-9]\{1,2\}\)/\([0-9]\{4\}\)@,\3-\1-\2@g' -e 's/\([0-9]\{2\}\) \([0-9]\{2\}\)/\1T\2/g' | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/surveytype/survey_type/' -e 's/Name/participant_id/' -e 's/6:00pm/18:00:00/' -e 's/6:00am/06:00:00/' -e 's/12:00pm/12:00:00/' -e 's/12:00am/00:00:00/' | \
  gawk -f reorder.awk | \
  sed -e 's/-\([0-9]\)-/-0\1-/' -e 's/-\([0-9]\)T/-0\1T/' | \
  sed -e 's/DateTTimesent/sent_ts/' -e 's/StartDate/start_ts/' -e 's/EndDate/completed_ts/' -e 's/Finished/has_finished/' -e 's/Q_TotalDuration/duration/' | \
  gzip > job_personality_health.csv.gz

cat \
  <(zcat job_personality_health.csv.gz | head -n1) \
  <(zcat job_personality_health.csv.gz | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/EMAs/job_personality_health.csv.gz


## Surveys: RAW / Supplemental MGT

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/2_raw_csv_data/ground_truth/S-MGT/ .

cat > remove_strings_psycap.py <<EOF
import sys
import pandas as pd
data = pd.read_csv('psychological_capital_raw.csv.gz')
for i in range(len(data)):
    if i > 0:
        l = data.iloc[i]["Location"]
        act15 = data.iloc[i]["Activity15"]
        if isinstance(l, str) and len(l) > 1:
            data.at[i, "Location"] = r'\n'.join(filter(None, l.split('\n')))
        if isinstance(act15, str) and len(act15) > 1:
            data.at[i, "Activity15"] = r'\n'.join(filter(None, act15.split('\n')))
data.to_csv(sys.stdout, index = False)
EOF

cat > fix_dates_and_fields_psycap.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}

NR == 1 {
  \$1 = \$2;
  \$2 = "survey_type";
  \$3 = "sent_ts";
  print
}
NR > 1 {
  datecmd = "date --date=\""\$4"\" +%Y-%m-%dT%H:%M:%S";
  datecmd | getline timestamp;
  close(datecmd);
  \$4 = timestamp;
  \$3 = \$1;
  \$1 = \$2;
  \$2 = "engage_psycap";
  print
}
EOF

python remove_strings_psycap.py | \
  grep -v ',SY' | \
  sed -e 's/\([0-9]\{2\}\) \([0-9]\{2\}\)/\1T\2/' -e 's/\.000//' | \
  cut -d',' -f1-3,5- | \
  gawk -f fix_dates_and_fields_psycap.awk | \
  gzip > psychological_capital.csv.gz


cat \
  <(zcat psychological_capital.csv.gz | head -n1) \
  <(zcat psychological_capital.csv.gz | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_capital.csv.gz


# 
# cat > remove_strings_psyflex.py <<EOF
# import csv
# with open('psychological_flexibility_raw.csv') as csvfile:
#     pc = csv.reader(csvfile, delimiter=',', quotechar='"')
#     for ct, row in enumerate(pc):
#         if ct > 0 and len(row[7]) > 1:
#             row[7] = ''
#         print(','.join(row))
# EOF

cat > remove_strings_psyflex.py <<EOF
import sys
import pandas as pd
data = pd.read_csv('psychological_flexibility_raw.csv.gz')
data = data.rename(columns = { 'Actvity': 'Activity' })
for i in range(len(data)):
    if i > 0:
        act = data.iloc[i]["Activity"]
        if isinstance(act, str) and len(act) > 1:
            data.at[i, "Activity"] = r'\n'.join(filter(None, act.split('\n')))
data.to_csv(sys.stdout, index = False)
EOF

cat > fix_dates_and_fields_psyflex.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
  \$1 = \$2;
  \$2 = \$3;
  \$3 = "sent_ts";
  print
}
NR > 1 {
  datecmd = "date --date=\""\$4"\" +%Y-%m-%dT%H:%M:%S";
  datecmd | getline timestamp;
  close(datecmd);
  \$4 = timestamp;
  tmp= \$1;
  \$1 = \$2;
  \$2 = \$3;
  \$3 = tmp;
  print
}
EOF


python remove_strings_psyflex.py | \
  grep -v ',SY' | \
  sed -e 's/\([0-9]\{2\}\) \([0-9]\{2\}\)/\1T\2/' -e 's/\.000//' | \
  cut -d',' -f1,3,5,7- | \
  gawk -f fix_dates_and_fields_psyflex.awk | \
  gzip > psychological_flexibility.csv.gz
  
  
cat \
  <(zcat psychological_flexibility.csv.gz | head -n1) \
  <(zcat psychological_flexibility.csv.gz | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_flexibility.csv.gz





## Surveys: RAW / IGTB

aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .
aws s3 cp --recursive s3://${RAW_BUCKET}/ground_truth/IGTB/ .

rm USC_PILOT_IGTB.csv
mv USC_DAY_IGTB.csv day.csv
mv USC_NIGHT_IGTB.csv night.csv

cut -d',' -f3,8-10,12- day.csv | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\) /\1T/g' > igtb_evidation.csv

#FIXME: Some scales (e.g. PANAS / BFI) do not have a completion time
FILENAME="$(head -n1 igtb_evidation.csv | tr , '\n' | grep complete | sed -e 's/_complete//' | tr '\n' _ | sed -e 's/_$//').csv"

cut -d',' -f3,8-10,12- night.csv | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\) /\1T/g' | \
  tail -n +3 >> igtb_evidation.csv

mv igtb_evidation.csv $FILENAME
sed -e 's/V3/participant_id/' -e 's/V8/start_ts/' -e 's/V9/completed_ts/' -e 's/V10/finished/' $FILENAME | \
  gzip > $FILENAME.gz


# Sort & upload
cat <(zcat $FILENAME.gz | head -n2) <(zcat $FILENAME.gz | tail -n +3 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/baseline/$FILENAME.gz

  

# gzip ./*
# aws s3 sync . s3://${TARGET_BUCKET}/surveys/raw/IGTB/


## Surveys: RAW / Pre-Study

# aws s3 cp s3://${PROCESSED_BUCKET}/participant_info/Pre-Study\ Data\ 11-13-18.csv .
# mv Pre* pre-study-survey.csv
# gzip pre-study-survey.csv


aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .
aws s3 cp s3://${RAW_BUCKET}/ground_truth/pre-study/Pre_Study.csv.gz .

FILENAME="demo_rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv"
zcat Pre_Study.csv.gz | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  cut -d',' -f$(zcat Pre_Study.csv.gz | head -n1 | tr ',' '\n' | grep -ivnE '(record_id|redcap_event_name)' | cut -d':' -f1 | tr '\n' ',' | sed -e 's/,$//') | \
  sed -e 's/, ,/,,/g' -e 's/, ,/,,/g' -e 's/\([0-9]\) /\1T/g' -e 's/ID/participant_id/' -e 's/timestamp/completed_ts/g' | \
  gzip > $FILENAME.gz

# Sort & upload
cat <(zcat $FILENAME.gz | head -n1) <(zcat $FILENAME.gz | tail -n +2 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/baseline/$FILENAME.gz


## Surveys: RAW / Post-Study

aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .
aws s3 cp s3://${RAW_BUCKET}/ground_truth/post-study/Post_Study.csv.gz .

FILENAME="rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv"
zcat Post_Study.csv.gz | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  cut -d',' -f$(zcat Post_Study.csv.gz | head -n1 | tr ',' '\n' | grep -ivnE '(feedback|record_id)' | cut -d':' -f1 | tr '\n' ',' | sed -e 's/,$//') | \
  sed -e 's/, ,/,,/g' -e 's/, ,/,,/g' -e 's/\[.*\]//' -e 's/ /T/g' -e 's/ID/participant_id/' -e 's/poststudy_survey_timestamp_post/start_ts/' -e 's/timestamp/completed_ts/g' | \
  gzip > $FILENAME.gz

# Sort & upload
cat <(zcat $FILENAME.gz | head -n1) <(zcat $FILENAME.gz | tail -n +2 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/post-study/$FILENAME.gz


## Surveys: Scored / MGT

mkdir tmp
aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/ground_truth/MGT/ tmp/
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

cd tmp
mv alc.d.csv.gz alcool.csv.gz
mv anxiety.d.csv.gz anxiety.csv.gz
mv bfi.d1.csv.gz personality.csv.gz
mv dalal.csv.gz ocb_dwb.csv.gz
mv exercise.d.csv.gz exercise.csv.gz
mv irb.d.csv.gz task_performance_irb.csv.gz
mv itp.d.csv.gz task_performance_itp.csv.gz
mv pan.d.csv.gz affect.csv.gz
mv sleep.d.csv.gz sleep.csv.gz
mv stress.d.csv.gz stress.csv.gz
mv tob.d.csv.gz tobacco.csv.gz
mv worktoday.csv.gz worked_today.csv.gz
cd ..

for f in tmp/*csv.gz
do
  zcat $f | \
    grep -v '^"SY' | \
    eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
    sed -e 's@\([0-9]\{1\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@\3-0\1-0\2@g' -e 's@\([0-9]\{2\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@\3-\1-0\2@g' -e 's@\([0-9]\{1\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@\3-0\1-\2@g' -e 's@\([0-9]\{2\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@\3-\1-\2@g' | \
    sed -e 's/"//g' -e 's/ /T/g' -e 's/ID/participant_id/' -e 's/start/start_ts/' -e 's/end/completed_ts/' | \
    cut -d, -f1,2,4- | \
    gzip > ${f//tmp\//}
  
  cat \
  <(zcat ${f//tmp\//} | head -n1) \
  <(zcat ${f//tmp\//} | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
    gzip | \
    aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/EMAs/${f//tmp\//}
done


## Surveys: Scored / Supplemental MGT

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/ground_truth/S-MGT/ .

zcat psychological_capital_scored.csv.gz | \
  grep -v ',SY' | \
  sed -e 's/ /T/' -e 's/\.000//' | \
  cut -d',' -f1-3,5- | \
  awk 'BEGIN {FS=","; OFS=",";} NR == 1 {$1=$2; $2="survey_type"; $3="sent_ts"; $4="completed_ts"; print} NR > 1 {datecmd = "date --date=\""$4"\" +%Y-%m-%dT%H:%M:%S"; datecmd | getline timestamp; close(datecmd); $4=timestamp; $3=$1; $1=$2; $2="engage_psycap"; print}' | \
  gzip > psychological_capital.csv.gz

cat \
  <(zcat psychological_capital.csv.gz | head -n1) \
  <(zcat psychological_capital.csv.gz | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/EMAs/psychological_capital.csv.gz

zcat psychological_flexibility_scored.csv.gz | \
  grep -v ',SY' | \
  sed -e 's/\([0-9]\) /\1T/' -e 's/\.000//' | \
  cut -d',' -f2,4,5,7- | \
  awk 'BEGIN {FS=","; OFS=",";} NR == 1 {$1=$2; $2=$3; $3="sent_ts"; $4="completed_ts"; print} NR > 1 {datecmd = "date --date=\""$4"\" +%Y-%m-%dT%H:%M:%S"; datecmd | getline timestamp; close(datecmd); $4=timestamp; tmp=$1; $1=$2; $2=$3; $3=tmp; print}' | \
  gzip > psychological_flexibility.csv.gz

cat \
  <(zcat psychological_flexibility.csv.gz | head -n1) \
  <(zcat psychological_flexibility.csv.gz | \
      tail -n +2 | \
      awk -F, -v OFS=, '{tmp=$1; $1=$3; $3=$2; $2=tmp; print}' | \
      sort | \
      awk -F, -v OFS=, '{tmp=$1; $1=$2; $2=$3; $3=tmp; print}') | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/EMAs/psychological_flexibility.csv.gz


## Surveys: Scored / IGTB

aws s3 cp s3://${PROCESSED_BUCKET}/3_preprocessed_data/ground_truth/IGTB/igtb.csv.gz .
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

zcat igtb.csv.gz | \
  grep -v 'SY[0-9]\{4\}' | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/ID/participant_id/' -e 's/date_time/start_ts/' -e 's/"//g' -e 's/NA//g' -e 's/\([0-9]\) /\1T/' | \
  gzip > vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz

  
cat <(zcat vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz | head -n1) <(zcat vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz | tail -n +2 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/baseline/vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz


## Surveys: Scored / Pre-Study

aws s3 cp s3://${PROCESSED_BUCKET}/ground_truth/pre-study/Pre_Study.csv.gz .
aws s3 cp s3://${RAW_BUCKET}/ground_truth/pre-study/Pre_Study.csv.gz Pre_Study_raw.csv.gz
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

zcat Pre_Study.csv.gz | \
  cut -d, -f 1,3- | \
  awk 'BEGIN {FS=","; OFS=","} NR==1 {$1 = "participant_id"; $2 = "start_ts"; print} NR>1 {demo_ts = "zgrep \"^" $1 ",\" Pre_Study_raw.csv.gz | cut -d, -f4"; demo_ts | getline start_ts; $1 = $2; $2 = start_ts; print}' | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/timestamp/completed_ts/g' -e 's/ /T/g' |
  gzip > rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz

cat <(zcat rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz | head -n1) <(zcat rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz | tail -n +2 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/baseline/rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz

## Surveys: Scored / Post-Study

aws s3 cp s3://${PROCESSED_BUCKET}/ground_truth/post-study/Post_Study.csv.gz .
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

zcat Post_Study.csv.gz | \
  cut -d, -f2- | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/poststudy_survey_timestamp_post/start_ts/' -e 's/timestamp/completed_ts/g' -e 's/, ,/,,/g' -e 's/, ,/,,/g' -e 's/\[.*\]//' -e 's/ /T/g' -e 's/ID/participant_id/' | \
  gzip > rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz

cat <(zcat rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz | head -n1) <(zcat rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz | tail -n +2 | sort) | \
  gzip | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/post-study/rand_swls_pss_mpfi_waaq_uwes_pcq_chss.csv.gz
