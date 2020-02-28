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

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/owl_in_one/ s3://${TARGET_BUCKET}/owlinone/jelly/
for f in $(aws s3 ls s3://${TARGET_BUCKET}/owlinone/jelly/ | sed -e 's/^.*[0-9] \([0-9a-f].*\)$/\1/')
do
    aws s3 mv "s3://${TARGET_BUCKET}/owlinone/jelly/$f" "s3://${TARGET_BUCKET}/owlinone/jelly/${f//_bleProximity/}"
done


## OWL-in-One: Minew Data
# Assumes the hash map is available as hashed_directories.csv

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/minew/ .
aws s3 cp s3://${RAW_BUCKET}/id-mapping/minews_directories_opendataset.csv .

echo sed $(
    tail -n+2 hashed_directories.csv | \
        sed -e 's/^\(.*\),\(.*\),.*,.*$/-e '"'"'s@\1@\2@'"'"' /'
    tail -n+2 hashed_directories.csv | \
        sed -e 's@^\(.*\):.*,.*,\(.*\),.*$@\1,\2@' | \
        sort -u | \
        sed -e 's/^\(.*\),\(.*\)$/-e '"'"'s@\1@\2@'"'"' /'
) '${1:-/dev/stdin}' > process_directory_mapping.sh
chmod u+x process_directory_mapping.sh
./process_directory_mapping.sh minews_directories_opendataset.csv > minews_hashed_directories_opendataset.csv


mkdir light
cd light
for map in $(grep light ../minews_hashed_directories_opendataset.csv)
do
    MAC=$(echo $map | cut -d, -f1)
    DIRECTORY=$(echo $map | cut -d, -f3)
    (
        zcat ../light.csv.gz | head -n1 | cut -d, -f1,3,4
        zgrep $MAC ../light.csv.gz | \
            grep -E "^2018-0([4-6]|3-0[5-9]|3-[123]|7-0|7-1[0-4])" | \
            cut -d, -f1,3,4
    ) | gzip -9 > ${DIRECTORY}.csv.gz
done
cd ..

mkdir temp_humid
cd temp_humid
for map in $(grep temp_humid ../minews_hashed_directories_opendataset.csv)
do
    MAC=$(echo $map | cut -d, -f1)
    DIRECTORY=$(echo $map | cut -d, -f3)
    (
        zcat ../temperatureHumidity.csv.gz | head -n1 | cut -d, -f1,3,4,5
        zgrep $MAC ../temperatureHumidity.csv.gz | \
            grep -E "^2018-0([4-6]|3-0[5-9]|3-[123]|7-0|7-1[0-4])" | \
            cut -d, -f1,3,4,5
    ) | gzip -9 > ${DIRECTORY}.csv.gz
done
cd ..

mkdir motion
cd motion
for map in $(grep -vE 'Type|light|temp' ../minews_hashed_directories_opendataset.csv)
do
    MAC=$(echo $map | cut -d, -f1)
    DIRECTORY=$(echo $map | cut -d, -f3)
    (
        zcat ../motion.csv.gz | head -n1 | cut -d, -f1,3,4,5,6
        zgrep $MAC ../motion.csv.gz | \
            grep -E "^2018-0([4-6]|3-0[5-9]|3-[123]|7-0|7-1[0-4])" | \
            cut -d, -f1,3,4,5,6
    ) | gzip -9 > ${DIRECTORY}.csv.gz
done
cd ..

s3://${TARGET_BUCKET}/owlinone/minew/data/

cd ..
rm light.csv.gz


## OWL-in-One: Minew Locations

# Hashed version, not this one
# aws s3 cp s3://${PROCESSED_BUCKET}/owl_locations/minew_locations_keck.csv.gz s3://${TARGET_BUCKET}/owlinone/minew/locations/


## OWL-in-One: Minew RSSI
# Assumes process_directory_mapping.sh and minews_hashed_directories_opendataset.csv are available

aws s3 cp --recursive s3://${PROCESSED_BUCKET}/2_raw_csv_data/minew_rssi/ s3://${TARGET_BUCKET}/owlinone/minew/rssi/

for map in $(grep -v 'Type' minews_hashed_directories_opendataset.csv)
do
    MAC=$(echo $map | cut -d, -f1 | sed -e 's/://g')
    DIRECTORY=$(echo $map | cut -d, -f3)
    (
        echo timestamp,directory,rssi
        zgrep -h $MAC 2018*.csv.gz | \
            cut -d, -f1,5,6 | \
            grep -v ',,' | \
            ./process_directory_mapping.sh
    ) | gzip -9 > ${DIRECTORY}.csv.gz
done

aws 

## OWL-in-One: OWL Locations

# Hashed version, not this one
# aws s3 cp s3://${PROCESSED_BUCKET}/owl_locations/owl_locations_keck.csv.gz s3://${TARGET_BUCKET}/owlinone/owls/locations/


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



cat > create_sent_timestamp.awk <<EOF
\$11 ~ /12:00am/ || (\$11 ~ /^$/ && \$(NF) ~ /0000/)  {
    \$8 = \$7"T00:00:00";
}
\$11 ~ /6:00am/  || (\$11 ~ /^$/ && \$(NF) ~ /0600/) {
    \$8 = \$7"T06:00:00";
}
\$11 ~ /12:00pm/ || (\$11 ~ /^$/ && \$(NF) ~ /1200/) {
    \$8 = \$7"T12:00:00";
}
\$11 ~ /6:00pm/  || (\$11 ~ /^$/ && \$(NF) ~ /1800/) {
    \$8 = \$7"T18:00:00";
}
{
    print
}
EOF


aws s3 sync s3://${RAW_BUCKET}/ground_truth/MGT/ . --exclude '*July*'
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .
aws s3 cp s3://${TARGET_BUCKET}/metadata/participant-info/participant-info.csv.gz .

# clean up mitre ids
sed -i -e 's/\r//g' mitreids.csv

# Remove anything from before the beginning of the study
rm *201802* *20180301* *20180302* *20180303* *20180304*

# Remove a duplicated row
head -n-1 USC_PILOT_20180406_personality_6pm.csv > tmp_USC_PILOT_20180406_personality_6pm.csv
mv tmp_USC_PILOT_20180406_personality_6pm.csv USC_PILOT_20180406_personality_6pm.csv

# Rename the files for sorting
for f in USC*
do
    mv $f $(echo $f | sed -e 's/USC_\(NIGHT\|DAY\|PILOT\)_\([0-9]*\)_\(job\|health\|personality\)_\(12[ap]m\|6[ap]m\)/\2_\4_\1_\3/' -e 's/6pm/1800/' -e 's/12am/0000/' -e 's/[ap]m/00/' -e 's/600/0600/');
done

# Add the pilot participants data to the correct file
for f in *PILOT*
do
    g=$(ls | grep -E "${f:0:13}.*(DAY|NIGHT)" | head -n1)
    tail -n+3 $f >> $g
done
rm *PILOT*

# Remove rows that don't make sense (empty participant_id)
for f in 2018*
do
    gawk -F, -v OFS=, -v FPAT="([^,]*)|(\"[^\"]+\")" -i inplace 'NR <= 2 || length($6) > 0 {print}' $f
done


# Get the list of enrolled participants over time
# ATTENTION: SG* participants from wave 2 switched from night to day shift on 04/16, and received 2 surveys on that day
# ATTENTION: SG1056 is an exception: the day surveys only resumed on 04/18

# Below, tmp.csv contains: participant_id, day(1) / night(0), wave, mitre ID
zcat participant-info.csv.gz | \
    awk -F, -v OFS=, '$7 ~ /Day/ {cmd = "grep "$1" mitreids.csv | cut -d, -f2"; cmd | getline tmp; print $1, 1, $8, tmp} $7 ~ /Night/ {cmd = "grep "$1" mitreids.csv | cut -d, -f2"; cmd | getline tmp; print $1, 0, $8, tmp}' > tmp.csv 

grep -E "$(grep ',[01],1' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort > participants_0305-0408.csv
grep -E "$(grep ',1,1' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort > day_0305-0408.csv
grep -E "$(grep ',0,1' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0305-0408.csv

grep -E "$(grep -E ',[01],[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0409-0415.csv
grep -E "$(grep -E ',1,[12],S[DY]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0409-0415.csv
grep -E "$(grep -E '(,0,[12]|,1,[12],SG)' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0409-0415.csv

grep -E "$(grep -E ',[01],[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0416.csv
grep -E "$(grep -E ',1,[12]' tmp.csv | grep -v 'SG1056' | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0416.csv
grep -E "$(grep -E '(,0,[12]|,1,2,SG)' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0416.csv

grep -E "$(grep -E ',[01],[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0417.csv
grep -E "$(grep -E ',1,[12]' tmp.csv | grep -v 'SG1056' | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0417.csv
grep -E "$(grep -E ',0,[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0417.csv

grep -E "$(grep -E ',[01],[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0418-0503.csv
grep -E "$(grep -E ',1,[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0418-0503.csv
grep -E "$(grep -E ',0,[12]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0418-0503.csv

grep -E "$(grep -E ',[01],[123]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0504-0514.csv
grep -E "$(grep -E ',1,[123]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0504-0514.csv
grep -E "$(grep -E ',0,[123]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0504-0514.csv

grep -E "$(grep -E ',[01],[23]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0515-0618.csv
grep -E "$(grep -E ',1,[23]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0515-0618.csv
grep -E "$(grep -E ',0,[23]' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0515-0618.csv

grep -E "$(grep ',[01],3' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > participants_0619-0714.csv
grep -E "$(grep ',1,3' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > day_0619-0714.csv
grep -E "$(grep ',0,3' tmp.csv | cut -d, -f1 | tr '\n' '|' | sed -e 's/|$//')" mitreids.csv | \
    cut -d, -f2 | sed -e 's/\r//g' | sort  > night_0619-0714.csv

for f in 2018*
do
    # First, find the set of participants on that day
    shift=day # PILOT participants are DAY participant in wave 1
    if echo $f | grep -q NIGHT
    then
        shift=night
    fi
    set=""
    filemonth=${f:4:2}
    fileday=${f:6:2}
    if [[ $filemonth -gt 4 ]] || ( [[ $filemonth -eq 4 ]] && [[ $fileday -ge 9 ]] )
    then
        if [[ $filemonth -gt 4 ]] || ( [[ $filemonth -eq 4 ]] && [[ $fileday -ge 16 ]] )
        then
            if [[ $filemonth -gt 4 ]] || ( [[ $filemonth -eq 4 ]] && [[ $fileday -ge 17 ]] )
            then
                if [[ $filemonth -gt 4 ]] || ( [[ $filemonth -eq 4 ]] && [[ $fileday -ge 18 ]] )
                then
                    if [[ $filemonth -gt 5 ]] || ( [[ $filemonth -eq 5 ]] && [[ $fileday -ge 4 ]] )
                    then
                        if [[ $filemonth -gt 5 ]] || ( [[ $filemonth -eq 5 ]] && [[ $fileday -ge 15 ]] )
                        then
                            if [[ $filemonth -gt 6 ]] || ( [[ $filemonth -eq 6 ]] && [[ $fileday -ge 19 ]] )
                            then
                                # eighth interval
                                set=0619-0714
                            else
                                # seventh interval
                                set=0515-0618
                            fi
                        else
                            # sixth interval
                            set=0504-0514
                        fi
                    else
                        # fifth interval
                        set=0418-0503
                    fi
                else
                    # fourth interval
                    set=0417
                fi
            else
                # third interval
                set=0416
            fi
        else
            # second interval
            set=0409-0415
        fi
    else
        # first interval
        set=0305-0408
    fi
    
    # Type and time
    surveytype=$(echo $f | sed -e 's/^.*_.*_.*_\(.*\).csv$/\1/')
    surveytime=$(($(echo $f | sed -e 's/^.*_\(.*\)_.*_.*.csv$/\1/') / 100))
    if [[ $surveytime -ge 12 ]]
    then
        if [[ $surveytime -eq 12 ]]
        then
            surveytime="12:00pm";
        else
            surveytime="6:00pm";
        fi
    else
        if [[ $surveytime -eq 0 ]]
        then
            surveytime="12:00am";
        else
            surveytime="6:00am";
        fi
    fi
    
    # First, remove participants that are not in the study yet/anymore
    grep -E "Q_TotalDuration|$(cat participants_${set}.csv | tr '\n' '|' | sed -e 's/|$//')" $f > $f.tmp
    mv $f.tmp $f
    
    # Then, add back the missing ones.
    grep -vE "$(tail -n+3 $f | awk -F, '{print $6}' | tr '\n' '|' | sed -e 's/|*$//' -e 's/^|*//' -e 's/|\+/|/g')" "${shift}_${set}.csv" | \
        awk -v OFS=, '{$5=0; $6=$1; $7="'"${filemonth}/${fileday}"'/2018"; $9="'"$surveytype"'"; $11="'"$surveytime"'"; print}' >> $f
done

# Then, remove the data for the dropouts
for dropout in $(zcat participant-info.csv.gz | awk -F, -v OFS=, 'length($9) > 0 && NR > 1 {print $1, $9}')
do
    participant=$(echo $dropout | cut -d, -f1)
    lastdate=$(echo $dropout | cut -d, -f2)
    lastdatemonth=${lastdate:5:2}
    lastdateday=${lastdate:8:2}
    
    datestoremove="$(eval ls $(seq $((${lastdateday:1:1} + 1)) 9 | sed -e "s/^/2018${lastdatemonth}${lastdateday:0:1}/" -e 's/$/*/'))"
    for x in $(seq $((${lastdateday:0:1} + 1)) 3)
    do
        datestoremove="$datestoremove $(ls 2018${lastdatemonth}${x}*)"
    done
    for m in $(seq $((${lastdatemonth:1:1} + 1)) 7)
    do
        datestoremove="$datestoremove $(ls 20180${m}*)"
    done
    datestoremove=$(echo $datestoremove | tr ' ' '\n')
#     echo $participant, $lastdate
    
    participant_mitre=$(grep $participant mitreids.csv | cut -d, -f2)
    
    for f in $(echo $datestoremove | tr '\n' ' ')
    do
        sed -i "/,${participant_mitre},/d" $f
    done
done

(
    echo "$(head -n1 $(ls *perso* | head -n1) | sed -e 's/,*$//'),$(head -n1 $(ls *health* | head -n1) | cut -d, -f60- | sed -e 's/,*$//'),$(head -n1 $(ls *job* | head -n1) | cut -d, -f60- | sed -e 's/,*$//')" | \
        sed -e 's/,*$//' -e 's/"//g' -e 's/$/,filename/'
    for f in *
    do
        time_sent=${f}
        if echo $f | grep -q perso
        then
            tail -n+3 $f | \
                gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{NF=73; print}' | \
                sed -e 's/day,/day/' -e "s/$/$(printf ',%.0s' {1..82})/" -e "s/$/,$f/"
        elif echo $f | grep -q health
        then
            tail -n+3 $f | \
                gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "{\$59 = \$59\"$(printf ',%.0s' {1..14})\"; NF=98; print \$0}" | \
                sed -e 's/day,/day/' -e "s/$/$(printf ',%.0s' {1..43})/" -e "s/$/,$f/"
        elif echo $f | grep -q job
        then
            tail -n+3 $f | \
                gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "{\$59 = \$59\"$(printf ',%.0s' {1..53})\"; NF=102; print \$0}" | \
                sed -e 's/day,/day/' -e "s/$/,$f/"
        fi
    done
) | \
    sed -e 's/\r//g' -e 's/""//g' -e "s/$(head -n1 $(ls | head -n1) | cut -d, -f1-5)/$(head -n2 $(ls | head -n1) | cut -d, -f1-5 | tail -n1)/" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{tmp = $118; $118 = $119; $119 = $120; $120 = tmp; print $0}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" -f create_sent_timestamp.awk | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{$1=$6; $2=$9; $6=$12; $7=$5; $5=$4; $4=$3; $3=$8; for (i=8; i<=NF-5; i++) { $i=$(i+5) }; NF-=6; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR == 1 {$1="participant_id"; $2="survey_type"; $3="sent_ts"; $4="start_ts"; $5="completed_ts"; $6="duration"; $7="has_finished"; print} NR>1 {print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'length($1) > 0 {print} {}' | \
    eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
    sed -e 's@,\([0-9]\{2\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@,\3-\1-\2@g' -e 's@,\([0-9]\{1\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@,\3-0\1-\2@g' -e 's@,\([0-9]\{2\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@,\3-\1-0\2@g' -e 's@,\([0-9]\{1\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@,\3-0\1-0\2@g' -e 's/\([0-9]\{2\}\) \([0-9]\{2\}\)/\1T\2/g' | \
    gzip -9 > MGT.csv.gz

aws s3 cp MGT.csv.gz s3://${TARGET_BUCKET}/surveys/raw/EMAs/job_personality_health-context_stress_anxiety_pand_bfid_sleep_ex_tob_alc_work_itpd_irbd_dalal.csv.gz



## Histograms

# Version with N and K on the output (K = number of surveys left unanswered)
cat > started_histo.awk <<EOF
BEGIN {
    FS = ",";
    OFS = ",";
    prev = "";
    K=0;
}
\$2 == prev {
    print prev, sprintf("%.1f", \$1 / (K + \$1) * 100), \$1, K + \$1;
    K = 0;
    next;
}
K > 0 && \$3 == 0 {
    print prev, "0.0", 0, K;
    K = \$1;
    prev = \$2;
    next;
}
K == 0 && \$3 == 0 {
    K = \$1;
    prev = \$2;
    next;
}
K > 0 && \$3 == 1 {
    print prev, "0.0", 0, K;
    print \$2, "100.0", \$1, \$1;
    K = 0;
    prev = \$2;
    next;
}
K == 0 && \$3 == 1 {
    print \$2, "100.0", \$1, \$1;
    K = 0;
    prev = \$2;
    next;
}
END {
    if (K > 0)
        print prev, "0.0", 0, K;
}
EOF

cat > started_histo.awk <<EOF
BEGIN {
    FS = ",";
    prev = "";
    K=0;
}
\$2 == prev {
    print sprintf("%.1f", K / (K + \$1) * 100);
    K = 0;
    next;
}
K > 0 && \$3 == 0 {
    print "0.0";
    K = \$1;
    prev = \$2;
    next;
}
K == 0 && \$3 == 0 {
    K = \$1;
    prev = \$2;
    next;
}
K > 0 && \$3 == 1 {
    print "0.0";
    print "100.0";
    K = 0;
    prev = \$2;
    next;
}
K == 0 && \$3 == 1 {
    print "100.0";
    K = 0;
    prev = \$2;
    next;
}
END {
    if (K > 0)
        print "0.0";
}
EOF


# Job
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /job/ {tmp=0; for (i=2; i<=17; ++i) if (length($(i)) > 0) ++tmp; N=17; if (length($43) > 0) {++tmp; if ($43 == 1) {N=43; for (i=44; i<=69; ++i) if (length($(i)) > 0) ++tmp;}} printf("%.1f\n", tmp / N * 100)}' | \
    sort -n | \
    uniq -c

# Participant Job compliance Histogram:
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-8)=$(i); NF=NF-8; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$2 ~ /job/ {tmp=0; for (i=3; i<=18; ++i) if (length($(i)) > 0) ++tmp; N=17; if (length($44) > 0) {++tmp; if ($44 != 2) {N=43; for (i=45; i<=70; ++i) if (length($(i)) > 0) ++tmp;}} print $1, tmp,  N}' | \
    sort | \
    awk -v OFS="," -v FS="," 'BEGIN {prev = ""; X=0; N=0;} {if (prev != $1) { if (length(prev) > 0) {printf("%.1f\n", X / N * 100); X=0; N=0} prev=$1} X += $2; N += $3} END {printf("%.1f\n", X / N * 100)}' | \
    sort -n | uniq -c

# Started Job survey percentage histogram
zcat MGT.csv.gz | \
    awk -F, -v OFS=, '$2 ~ /job/ {print $1, int(length($4) > 0)}' | \
    sort | uniq -c | \
    sed -e 's/^ *\([0-9a-f]\)/\1/' -e 's/ /,/' | \
    awk -f started_histo.awk



# health
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /health/ {tmp=0; for (i=2; i<=17; ++i) if (length($(i)) > 0) ++tmp; for (i=28; i<=42; ++i) if (length($(i)) > 0) ++tmp; N=31; if ($31 == 2) N -= 7; if ($39 == 2) N -= 3; printf("%.1f\n", tmp / N * 100)}' | \
    sort -n | \
    uniq -c

# Participant health compliance Histogram:
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-8)=$(i); NF=NF-8; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$2 ~ /health/ {tmp=0; for (i=3; i<=18; ++i) if (length($(i)) > 0) ++tmp; for (i=29; i<=43; ++i) if (length($(i)) > 0) ++tmp; N=31; if ($32 == 2) N -= 7; if ($40 == 2) N -= 3; print $1, tmp,  N}' | \
    sort | \
    awk -v OFS="," -v FS="," 'BEGIN {prev = ""; X=0; N=0;} {if (prev != $1) { if (length(prev) > 0) {printf("%.1f\n", X / N * 100); X=0; N=0} prev=$1} X += $2; N += $3} END {printf("%.1f\n", X / N * 100)}' | \
    sort -n | \
    uniq -c

# Started health survey percentage histogram
zcat MGT.csv.gz | \
    awk -F, -v OFS=, '$2 ~ /health/ {print $1, int(length($4) > 0)}' | \
    sort | uniq -c | \
    sed -e 's/^ *\([0-9a-f]\)/\1/' -e 's/ /,/' | \
    awk -f started_histo.awk
    
    


# Personality
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /perso/ {tmp=0; for (i=2; i<=27; ++i) if (length($(i)) > 0) ++tmp; printf("%.1f\n", tmp / 26 * 100)}' | \
    sort -n | \
    uniq -c

# Participant Personality compliance Histogram:
zcat MGT.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-8)=$(i); NF=NF-8; print}' | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$2 ~ /perso/ {tmp=0; for (i=3; i<=28; ++i) if (length($(i)) > 0) ++tmp; print $1, tmp,  26}' | \
    sort | \
    awk -v OFS="," -v FS="," 'BEGIN {prev = ""; X=0; N=0;} {if (prev != $1) { if (length(prev) > 0) {printf("%.1f\n", X / N * 100); X=0; N=0} prev=$1} X += $2; N += $3} END {printf("%.1f\n", X / N * 100)}' | \
    sort -n | \
    uniq -c

# Started Personality survey percentage histogram
zcat MGT.csv.gz | \
    awk -F, -v OFS=, '$2 ~ /personality/ {print $1, int(length($4) > 0)}' | \
    sort | uniq -c | \
    sed -e 's/^ *\([0-9a-f]\)/\1/' -e 's/ /,/' | \
    awk -f started_histo.awk




## Surveys: RAW / Supplemental MGT


aws s3 cp s3://${RAW_BUCKET}/app_surveys/app_surveys_updated.csv.gz .

cat > extract_context_2.sed <<EOF
# Getting rid of the one entry with a quote in it
# NOTICE: if more of those single quote appear, then a more complex substitution is needed
s/""\\(.*\\)'\\(.*\\)""/'\1´\2'/

# Set of more than one context2 answers
s/^\\(.*\\), '2': \\[\\(.*\\)\\]\\(.*\\)$/\\1\\3,\\"\\2\\"/
s/^\\(.*\\)'2': \\[\\(.*\\)\\]\\(.*\\)$/\\1\\3,\\"\\2\\"/

# Just one context2 answer
s/^\\(.*\\), '2': \\([0-9]\\+\\)\\([^0-9].*\\)$/\\1\\3,\\"\\2\\"/
s/^\\(.*\\)'2': \\([0-9]\\+\\)\\([^0-9].*\\)$/\\1\\3,\\"\\2\\"/

# Free response context2 answer
s/^\\(.*\\), '2': \\('[^']*'\\)\\(.*\\)$/\\1\\3,\\"\\2\\"/
s/^\\(.*\\)'2': \\('[^']*'\\)\\(.*\\)$/\\1\\3,\\"\\2\\"/

# Cleanup the timezone offset
s/"tzoffset(None, \\(-\?[0-9]*\\))"/\\1/g
EOF

# timezone offset in hours
# every timestamps in PT (except ingested_ts_utc we don't need) => bottleneck
# NOTE: assumes the local timezone is America/Los_Angeles (for the utility `date`)
cat > fix_time.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    \$5  = gensub(/_utc$/, "", "g", \$5);
    \$6  = gensub(/_utc$/, "", "g", \$6);
    \$8  = gensub(/_utc$/, "", "g", \$8);
    print
}
NR > 1 {
    if (length(\$7) > 0) {
        \$7 = (\$7+0) / 3600;
    }
    if (length(\$9) > 0) {
        \$9 = (\$9+0) / 3600;
    }
    if (length(\$5) > 0) {
        cmd = "date --date=\""\$5"\" +%Y-%m-%dT%H:%M:%S";
        cmd | getline tmp;
        close(cmd);
        \$5 = tmp;
    }
    if (length(\$6) > 0) {
        cmd = "date --date=\""\$6"\" +%Y-%m-%dT%H:%M:%S";
        cmd | getline tmp;
        close(cmd);
        \$6 = tmp;
    }
    if (length(\$8) > 0) {
        cmd = "date --date=\""\$8"\" +%Y-%m-%dT%H:%M:%S";
        cmd | getline tmp;
        close(cmd);
        \$8 = tmp;
    }
    print
}
EOF

# Context2 is stored as an array of checked checkboxes indices, and we convert that to a csv
# We also clean up the string of the free response text (15th context2)
cat > split_context_2.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    for (i=1; i<=15; ++i)
        \$(12+1+i)="context2_"i
    print
}
NR > 1 {
    if (NF >= 12) {
        NF=12+1+15;
        context2 = substr(\$12, 2, length(\$12) - 2);
        if (context2 ~ /[a-zA-Z]/) {
            context2 = substr(\$12, 3, length(\$12) - 4);
            while (match(context2, /^( |\\\\n)(.*)$/, tmp) != 0) {
                context2=tmp[2];
            }
            while (match(context2, /^(.*)( |\\\\n)$/, tmp) != 0) {
                context2=tmp[1];
            }
            \$(12+1+15)="\\""context2"\\""
        } else {
            context2 = gensub(/'/, "", "g", context2);
            context2 = gensub(/\.0/, "", "g", context2);
            n = split(context2, tmp, ", ");
            for (i=1; i<=n; ++i) {
                \$(13+tmp[i]+1)=1;
            }
        }
        \$12 = "\\""context2"\\""
    }
    print
}
EOF


cat > split_all_fields.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    \$13="context1";
    for (i = 3; i<=29; ++i)
        \$(13+15+i-2) = i;
    print
}
NR > 1 {
    n = patsplit(substr(\$11, 3, length(\$11) - 4), tmp, "'[0-9][0-9]*': (([^',]+)|('[^']+'))");
    for (i=1; i<=n; ++i) {
        split(substr(tmp[i], 2, length(tmp[i]) - 1), data, "': ");
        if (data[2] ~ /^'[0-9]+'$/)
            data[2] = substr(data[2], 2, length(data[2]) - 2);
        if (data[2] ~ /^'.*[a-zA-Z].*'$/)
            data[2] = "\\""substr(data[2], 2, length(data[2]) - 2)"\\"";

        if (data[1] == 1) {
            if (data[2] ~ /"/) {
                data[2] = substr(data[2], 2, length(data[2]) - 2);
                while (match(data[2], /^( |\\\\n)(.*)$/, tmp) != 0) {
                    data[2]=tmp[2];
                }
                while (match(data[2], /^(.*)( |\\\\n)$/, tmp) != 0) {
                    data[2]=tmp[1];
                }
                \$13 = "\\""data[2]"\\"";
            } else {
                \$13 = data[2];
            }
        } else {
            \$(13+15+data[1]-2) = data[2];
        }
    }
    print
}
EOF

# Cleanup: removing unused fields
cat > cleanup.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
{
    \$1 = \$2;
    \$2 = \$3;
    for (i = 5; i <= 9; ++i)
        \$(i-2) = \$i;
    for (i = 13; i <= NF; ++i)
        \$(i-5) = \$i;
    if (NF <= 11)
        NF = NF - 4;
    else 
        NF = NF-5;
    print
}
EOF

zcat app_surveys_updated.csv.gz | \
    grep -v -E ",2018-0(2-[0-9][0-9]|3-0[1-4])," | \
    sed -f extract_context_2.sed | \
    gawk -f fix_time.awk | \
    gawk -f split_context_2.awk | \
    gawk -f split_all_fields.awk | \
    gawk -f cleanup.awk > app_surveys_cleaned.csv


# Psychological Capital

# Name the columns, and remove the unused ones
cat > psycap.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    \$(7+1) = "Location";
    \$(7+2) = "Activity";
    for (i = 1; i <= 3; ++i)
        \$(7+2+i) = "Engage"i;
    for (i = 1; i <= 12; ++i)
        \$(7+2+3+i) = "Psycap"i;
    for (i = 1; i <= 3; ++i)
        \$(7+2+3+12+i) = "IS"i;
    for (i = 1; i <= 5; ++i)
        \$(7+2+3+12+3+i) = "CS"i;
    for (i = 1; i <= 4; ++i)
        \$(7+2+3+12+3+5+i) = "HS"i;
    
    NF_final = 6+2+3+12+3+5+4;
    for (i = 3; i <= NF_final + 1; ++i)
        \$(i-1) = \$(i);
    NF = NF_final;
    print
}
\$2 ~ /engage_psycap/ {
    if (NF > 7) {
#         \$(7+1) = \$(7+1);
        if (length(\$(7+1+15)) > 0) {
            \$(7+2) = \$(7+1+15);
        } else {
            tmp = 0;
            for (i = 1; i <= 14; ++i)
                tmp += i * \$(7+1+i);
            if (tmp == 0)
                \$(7+2) = "";
            else
                \$(7+2) = tmp;
        }
        for (i = 1; i <= 3; ++i)
            \$(7+2+i) = \$(7+1+15+i);
        for (i = 1; i <= 12; ++i)
            \$(7+2+3+i) = \$(7+1+15+3+i);
        for (i = 1; i <= 3; ++i)
            \$(7+2+3+12+i) = \$(7+1+15+3+12+i);
        for (i = 1; i <= 5; ++i)
            \$(7+2+3+12+3+i) = \$(7+1+15+3+12+3+i);
        for (i = 1; i <= 4; ++i)
            \$(7+2+3+12+3+5+i) = \$(7+1+15+3+12+3+5+i);
    }
    for (i = 3; i <= NF; ++i)
        \$(i-1) = \$(i);
    NF = 6+2+3+12+3+5+4;
    print
}
EOF

# Sort the rows using awk and sort, by survey send time
cat > sort_csv_k2k1.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    print
}
NR > 1 {
    print | "sort --field-separator=',' -k2,2 -k1,1"
}
EOF

gawk -f psycap.awk app_surveys_cleaned.csv | \
    gawk -f sort_csv_k2k1.awk | \
    gzip -9 > psychological_capital.csv.gz

aws s3 cp psychological_capital.csv.gz s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_capital-Psycap_Location_Activity_Engage_IS_CS_HS.csv.gz

# Histogram:
zcat psychological_capital.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 7; i <= NF; ++i) if (length($(i)) > 0) tmp++; printf("%.1f\n", tmp / (NF - 7 + 1) * 100)}' | \
    sort -n | uniq -c

# Participant compliance Histogram:
zcat psychological_capital.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 7; i <= NF; ++i) if (length($(i)) > 0) tmp++; printf("%s,%d,%d\n", $1, tmp, NF - 7 + 1)}' | \
    sort | \
    awk -v OFS="," -v FS="," 'BEGIN {prev = ""; X=0; N=0;} {if (prev != $1) { if (length(prev) > 0) {printf("%.1f\n", X / N * 100); X=0; N=0} prev=$1} X += $2; N += $3} END {printf("%.1f\n", X / N * 100)}' | \
    sort -n | uniq -c

# Started survey percentage histogram
zcat psychological_capital-Psycap_Location_Activity_Engage_IS_CS_HS.csv.gz | \
    tail -n+2 | \
    sort | \
    awk -F, -v OFS=, 'BEGIN {prev = ""; N = 0; K = 0;} {if (prev != $1) {if (length(prev) > 0) {printf("%.1f\n", K / N * 100); N = 0; K = 0;} prev = $1;} N++; if (length($3) > 0) K++;} END {printf("%.1f\n", K / N * 100);}' | \
    sort -n | uniq -c

# Psychological Flexibility

# Name the columns, and remove the unused ones
cat > psyflex.awk <<EOF
BEGIN {
  FS = ",";
  OFS = ",";
  FPAT = "([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    \$(7+1) = "Activity";
    for (i = 1; i <= 14; ++i)
        \$(7+1+i) = "Experience"i;
    for (i = 1; i <= 13; ++i)
        \$(7+1+14+i) = "PF"i;
    
    NF_final = 6+1+14+13;
    for (i = 3; i <= NF_final + 1; ++i)
        \$(i-1) = \$(i);
    NF = NF_final;
    print
}
\$2 ~ /psych_flex/ {
    if (NF > 7) {
#         \$(7+1) = \$(7+1);
#         for (i = 1; i <= 14; ++i)
#             \$(7+1+i) = \$(7+1+i);
        for (i = 1; i <= 13; ++i)
            \$(7+1+14+i) = \$(7+1+15+i);
    }
    for (i = 3; i <= NF; ++i)
        \$(i-1) = \$(i);
    NF = 6+1+14+13;
    print
}
EOF

gawk -f psyflex.awk app_surveys_cleaned.csv | \
    gawk -f sort_csv_k2k1.awk | \
    gzip -9 > psychological_flexibility.csv.gz

aws s3 cp psychological_flexibility.csv.gz s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_flexibility-Activity_Experience_PF.csv.gz


# Histogram:
zcat psychological_flexibility.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 1; i <= 14; ++i) if (length($(6+1+i)) > 0) tmp = 1; if (length($(6+1)) > 0) ++tmp; for (i = 1; i <= 13; ++i) if (length($(6+1+14+i)) > 0) tmp++; printf("%.1f\n", tmp / 15 * 100)}' | \
    sort -n | uniq -c

# Participant compliance Histogram:
zcat psychological_flexibility.csv.gz | \
    gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 1; i <= 14; ++i) if (length($(6+1+i)) > 0) tmp = 1; if (length($(6+1)) > 0) ++tmp; for (i = 1; i <= 13; ++i) if (length($(6+1+14+i)) > 0) tmp++; print $1, tmp, 15}' | \
    sort | \
    awk -v OFS="," -v FS="," 'BEGIN {prev = ""; X=0; N=0;} {if (prev != $1) { if (length(prev) > 0) {printf("%.1f\n", X / N * 100); X=0; N=0} prev=$1} X += $2; N += $3} END {printf("%.1f\n", X / N * 100)}' | \
    sort -n | uniq -c

# Started survey percentage histogram
zcat psychological_flexibility-Activity_Experience_PF.csv.gz | \
    tail -n+2 | \
    sort | \
    awk -F, -v OFS=, 'BEGIN {prev = ""; N = 0; K = 0;} {if (prev != $1) {if (length(prev) > 0) {printf("%.1f\n", K / N * 100); N = 0; K = 0;} prev = $1;} N++; if (length($3) > 0) K++;} END {printf("%.1f\n", K / N * 100);}' | \
    sort -n | uniq -c

    
## Histogram of the overall compliance

(
    # Job
    zcat MGT.csv.gz | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /job/ {tmp=0; for (i=2; i<=17; ++i) if (length($(i)) > 0) ++tmp; N=17; if (length($43) > 0) {++tmp; if ($43 == 1) {N=43; for (i=44; i<=69; ++i) if (length($(i)) > 0) ++tmp;}} printf("%.1f\n", tmp / N * 100)}'

    # health
    zcat MGT.csv.gz | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /health/ {tmp=0; for (i=2; i<=17; ++i) if (length($(i)) > 0) ++tmp; for (i=28; i<=42; ++i) if (length($(i)) > 0) ++tmp; N=31; if ($31 == 2) N -= 7; if ($39 == 2) N -= 3; printf("%.1f\n", tmp / N * 100)}'

    # Personality
    zcat MGT.csv.gz | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" "NR > 1 {print $(zcat MGT.csv.gz | head -n1 | tr , '\n' | nl | grep -v Time | awk '{print $1}' | tr '\n' ',' | sed -e 's/,$//' -e 's/,/,$/g' -e 's/^/$/')}" | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '{if (length($13) > 0 || length($14) > 0) $14=1; else $14=""; if (length($11) > 0 || length($12) > 0) $13=1; else $13=""; if (length($9) > 0 || length($10) > 0) $12=1; else $12=""; $11=$8; $10=$2; for (i=10; i <= NF; ++i) $(i-9)=$(i); NF=NF-9; print}' | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" '$1 ~ /perso/ {tmp=0; for (i=2; i<=27; ++i) if (length($(i)) > 0) ++tmp; printf("%.1f\n", tmp / 26 * 100)}'
        
    # Psychological Capital
    zcat psychological_capital.csv.gz | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 7; i <= NF; ++i) if (length($(i)) > 0) tmp++; printf("%.1f\n", tmp / (NF - 7 + 1) * 100)}'

     # Psychological Flexibility   
    zcat psychological_flexibility.csv.gz | \
        gawk -v OFS="," -v FS="," -v FPAT="([^,]*)|(\"[^\"]+\")" 'NR > 1 {tmp = 0; for (i = 1; i <= 14; ++i) if (length($(6+1+i)) > 0) tmp = 1; if (length($(6+1)) > 0) ++tmp; for (i = 1; i <= 13; ++i) if (length($(6+1+14+i)) > 0) tmp++; printf("%.1f\n", tmp / 15 * 100)}'
) | \
    sort -n | \
    uniq -c



## Surveys: RAW / IGTB

aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .
aws s3 cp --recursive s3://${RAW_BUCKET}/ground_truth/IGTB/ .

# rm USC_PILOT_IGTB.csv
mv USC_PILOT_IGTB.csv pilot.csv
mv USC_DAY_IGTB.csv day.csv
mv USC_NIGHT_IGTB.csv night.csv

MITREID_SED="sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')"
FILENAME="part_one-demo_abs_vocab_gats_audit_psqi_ipaq_iod_ocb_irb_itp_bfi_pan_stai.csv"

cat > dates_location_fields.sed <<EOF
# Dates
s/\([0-9]\{4\}-[0-9]\{2\}-[0-9]\{2\}\) /\1T/g

# Remove the last 4 fields (3 locations, 1 empty)
s/,[^,]*,[^,]*,[^,]*,[^,]*\$//

# Rename some fields
s/V3/participant_id/
s/V8/start_ts/
s/V9/completed_ts/
s/V10/finished/

# Cleanup some fields
s/ \\+,/,/g
EOF


# Remove some useless fields
# Convert participant_id
# Convert dates
# Remove location
# Rename some fields
cat day.csv <(tail -n+3 night.csv) <(tail -n+3 pilot.csv) | \
    cut -d',' -f3,8-10,12- | \
    eval $MITREID_SED | \
    sed -f dates_location_fields.sed > $FILENAME

# Sort & upload
cat <(cat $FILENAME | head -n2) <(cat $FILENAME | tail -n+3 | sort) | \
  gzip -9 | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/raw/baseline/$FILENAME.gz



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
mv alc.d.csv.gz alc.csv.gz
mv anxiety.d.csv.gz anxiety.csv.gz
mv bfi.d1.csv.gz bfid.csv.gz
mv exercise.d.csv.gz ex.csv.gz
mv irb.d.csv.gz irbd.csv.gz
mv itp.d.csv.gz itpd.csv.gz
mv pan.d.csv.gz pand.csv.gz
mv sleep.d.csv.gz sleepd.csv.gz
mv stress.d.csv.gz stressd.csv.gz
mv tob.d.csv.gz tob.csv.gz
mv worktoday.csv.gz work.csv.gz
cd ..

cat > mgt_fix.sed <<EOF
# Fix dates from the weird [M]M/[D]D/YYYY to YYYY-MM-DD
s@\([0-9]\{1\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@\3-0\1-0\2@g
s@\([0-9]\{2\}\)/\([0-9]\{1\}\)/\([0-9]\{4\}\)@\3-\1-0\2@g
s@\([0-9]\{1\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@\3-0\1-\2@g
s@\([0-9]\{2\}\)/\([0-9]\{2\}\)/\([0-9]\{4\}\)@\3-\1-\2@g

# Remove quotes
s/"//g

# Uniformize timestamps with a "T" in the middle
s/ /T/g

# Fix common field names
s/ID/participant_id/
s/start/start_ts/
s/end/completed_ts/

# Fix timestamps without seconds
s/\(T[0-9]\{2\}:[0-9]\{2\}\),/\1:00,/g

# Remove "NA"s
s/,NA/,/g

# Fix specific scales

# Alcool
s/alc_status/alc_Status/
s/alc.quantity.d/alc_Quantity/

# Anxiety
s/anxiety.d/anxiety/

# BFId
s/extraversion.d/bfid_Extraversion/
s/agreeableness.d/bfid_Agreeableness/
s/conscientiousness.d/bfid_Conscientiousness/
s/neuroticism.d/bfid_Neuroticism/
s/openness.d/bfid_Openness/

# DALAL (with DNW removed)
s/ocb.d/dalal_OCBD/
s/cwb.d/dalal_CWBD/
s/,DNW/,/g

# Ex
s/total.pa.d/ex_Total/

# IRBd
s/irb.d/irbd/

# ITPd
s/itp.d/itpd/

# PANd
s/pos.affect.d/pand_PosAffect/
s/neg.affect.d/pand_NegAffect/

# SLEEPd
s/sleep.d/sleepd/

# STRESSd
s/stress.d/stressd/

# TOBd
s/tob_status/tob_Status/
s/tob.quantity.d/tob_Quantity/
EOF

cat > csv_sort_k3_k1.awk <<EOF
BEGIN {
    FS = ",";
    OFS = ",";
}
NR == 1 {
    print
}
NR > 1 {
    print | "sort --field-separator=',' -k3,3 -k1,1"
}
EOF

for f in tmp/*csv.gz
do
  zcat $f | \
    grep -v -E ",2018-0(2-[0-9][0-9]|3-0[1-4])," | \
    eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
    sed -f mgt_fix.sed | \
    cut -d, -f1,2,4- | \
    awk -f csv_sort_k3_k1.awk | \
    gzip -9 > ${f//tmp\//}
    
    aws s3 cp ${f//tmp\//} s3://${TARGET_BUCKET}/surveys/scored/EMAs/
done


## Surveys: Scored / Supplemental MGT


# Psychological Capital

cat > pc_scoring.awk <<EOF
BEGIN {
    OFS=",";
    FS=",";
    FPAT="([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    print "participant_id", "sent_ts", "completed_ts", "engage", "psycap", "is", "cs", "hs";
}
NR > 1 {
    engage = "";
    N = int(length(\$9) > 0) + int(length(\$10) > 0) + int(length(\$11) > 0);
    if (N > 0) {
        engage = sprintf("%.2f", (\$9 + \$10 + \$11) / N);
    }
    
    psycap = "";
    N = 0;
    for (i = 12; i <= 23; ++i) {
        if (length(\$(i)) > 0) {
            N++;
            psycap += \$(i);
        }
    }
    if (N > 0) {
        psycap = sprintf("%.2f", psycap / N);
    }
    
    is = "";
    N = int(length(\$24) > 0) + int(length(\$25) > 0) + int(length(\$26) > 0);
    if (N > 0) {
        is = sprintf("%.2f", (\$24 + \$25 + \$26) / N);
    }
    
    cs = "";
    N = int(length(\$27) > 0) + int(length(\$28) > 0) + int(length(\$29) > 0) + int(length(\$30) > 0) + int(length(\$31) > 0);
    if (N > 0) {
        cs = sprintf("%.2f", (\$27 + \$28 + \$29 + \$30 + \$31) / N);
    }
    
    hs = "";
    N = int(length(\$32) > 0) + int(length(\$33) > 0) + int(length(\$34) > 0) + int(length(\$35) > 0);
    if (N > 0) {
        hs = sprintf("%.2f", (\$32 + \$33 + \$34 + \$35) / N);
    }
    
    print \$1, \$2, \$5, engage, psycap, is, cs, hs
}
EOF

aws s3 cp s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_capital-Psycap_Location_Activity_Engage_IS_CS_HS.csv.gz .

zcat psychological_capital-Psycap_Location_Activity_Engage_IS_CS_HS.csv.gz | gawk -f pc_scoring.awk | gzip -9 > psychological_capital.csv.gz
aws s3 cp psychological_capital.csv.gz s3://${TARGET_BUCKET}/surveys/scored/EMAs/engage_psycap_is_cs_hs.csv.gz


# Psychological flexibility

cat > pf_scoring.awk <<EOF
BEGIN {
    OFS=",";
    FS=",";
    FPAT="([^,]*)|(\"[^\"]+\")";
}
NR == 1 {
    print "participant_id", "sent_ts", "completed_ts", "experience_Negative", "experience_Positive", "experience_Neutral", "experience_Negative1", "pf";
}
NR > 1 {
    # PF
    pf = "";
    N = 0;
    for (i=22; i<=NF; ++i) {
        if (length(\$(i)) > 0) {
            N++;
            pf += \$(i);
        }
    }
    if (N > 0)
        pf = sprintf("%.2f", pf / N);

    # Experience
    answered_act = 0;
    if (length(\$7) > 0)
        answered_act = 1;
    answered_exp = 0;
    for (i = 8; i <=21; ++i)
        if (length(\$(i)) > 0)
            answered_exp = 1;
    if (answered_act == 1 && N > 0) {
        expneg = \$8 + \$10 + \$12 + \$14 + \$16;
        exppos  = \$9 + \$11 + \$13 + \$15;
        expneut = \$17 + \$18 + \$19 + \$20 + \$21;
        expneg1 = \$8 + \$9 + \$10 + \$12 + \$14 + \$16 + \$17 + \$18 + \$19 + \$20;
    } else {
        expneg = "";
        exppos = "";
        expneut = "";
        expneg1 = "";
    }
    print \$1, \$2, \$5, expneg, exppos, expneut, expneg1, pf
}
EOF

aws s3 cp s3://${TARGET_BUCKET}/surveys/raw/EMAs/psychological_flexibility-Activity_Experience_PF.csv.gz .

zcat psychological_flexibility-Activity_Experience_PF.csv.gz | gawk -f pf_scoring.awk | gzip -9 > psychological_flexibility.csv.gz
aws s3 cp psychological_flexibility.csv.gz s3://${TARGET_BUCKET}/surveys/scored/EMAs/experience_pf.csv.gz





# aws s3 cp --recursive s3://${PROCESSED_BUCKET}/3_preprocessed_data/ground_truth/S-MGT/ .




# cat > psycap_fix_and_sort.awk <<EOF
# BEGIN {
#     FS=",";
#     OFS=",";
# }
# NR == 1 {
#     \$1=\$2;
#     \$2="survey_type";
#     \$3="sent_ts";
#     \$4="completed_ts";
#     \$5="psycap";
#     \$6="engage";
#     \$7="is";
#     \$8="cs";
#     \$9="hs";
#     print
# }
# NR > 1 {
#     datecmd = "date --date=\""\$4"\" +%Y-%m-%dT%H:%M:%S";
#     datecmd | getline timestamp;
#     close(datecmd);
#     \$4=timestamp;
#     \$3=\$1;
#     \$1=\$2;
#     \$2="engage_psycap";
#     print | "sort --field-separator=',' -k3,3 -k1,1"
# }
# EOF
# 
# zcat psychological_capital_scored.csv.gz | \
#     grep -v -E "^2018-0(2-[0-9][0-9]|3-0[1-4])" | \
#     sed -e 's/ /T/' -e 's/\.000//' -e 's/\r$//' | \
#     cut -d',' -f1-3,5- | \
#     awk -f psycap_fix_and_sort.awk | \
#     gzip -9 > psychological_capital.csv.gz
# 
# aws s3 cp psychological_capital.csv.gz s3://${TARGET_BUCKET}/surveys/scored/EMAs/psycap_engage_is_cs_hs.csv.gz
# 
# 
# cat > psyflex_fix_and_sort.awk <<EOF
# BEGIN {
#     FS=",";
#     OFS=",";
# }
# NR == 1 {
#     \$1=\$2;
#     \$2=\$3;
#     \$3="sent_ts";
#     \$4="completed_ts";
#     \$5="pf";
#     \$6="experience_Negative";
#     \$7="experience_Positive";
#     \$8="experience_Neutral";
#     \$9="experience_Negative1";
#     print
# }
# NR > 1 {
#     datecmd = "date --date=\""\$4"\" +%Y-%m-%dT%H:%M:%S";
#     datecmd | getline timestamp;
#     close(datecmd);
#     \$4=timestamp;
#     tmp=\$1;
#     \$1=\$2;
#     \$2=\$3;
#     \$3=tmp;
#     print | "sort --field-separator=',' -k3,3 -k1,1"
# }
# EOF
# 
# zcat psychological_flexibility_scored.csv.gz | \
#     grep -v -E "^2018-0(2-[0-9][0-9]|3-0[1-4])" | \
#     sed -e 's/\([0-9]\) /\1T/' -e 's/\.000//' -e 's/\r$//' | \
#     cut -d',' -f2,4,5,7- | \
#     awk -f psyflex_fix_and_sort.awk | \
#     gzip -9 > psychological_flexibility.csv.gz
# 
# 
# aws s3 cp psychological_flexibility.csv.gz s3://${TARGET_BUCKET}/surveys/scored/EMAs/


## Surveys: Scored / IGTB

aws s3 cp s3://${PROCESSED_BUCKET}/3_preprocessed_data/ground_truth/IGTB/igtb.csv.gz .
aws s3 cp s3://${PROCESSED_BUCKET}/id-mapping/mitreids.csv .

cat > reorder_and_rename_fields.awk <<EOF
BEGIN {
    FS=",";
    OFS=",";
}
NR == 1 {
    \$3 = "abs";
    \$4 = "vocab";
    
    \$5 = "gats_Status";
    \$6 = "gats_Quantity";
    \$7 = "gats_Quantity_Sub";
    
    \$8 = "audit";
    \$9 = "psqi";
    \$10 = "ipaq";
    \$11 = "iod_ID";
    \$12 = "iod_OD";
    
    \$13 = "ocb";
    \$14 = "irb";
    \$15 = "itp";
    
    \$16 = "bfi_Neuroticism";
    \$17 = "bfi_Conscientiousness";
    \$18 = "bfi_Extraversion";
    \$19 = "bfi_Agreeableness";
    \$20 = "bfi_Openness";
    
    \$21 = "pan_PosAffect";
    \$22 = "pan_NegAffect";
    
    \$23 = "stai";

    print
}
NR > 1 {
    tmp = \$4;
    \$4 = \$3;
    \$3 = tmp;
    
    tmp14 = \$5;
    tmp15 = \$6;
    tmp13 = \$7;
    \$5 = \$19;
    \$6 = \$20;
    \$7 = \$21;
    
    tmp11 = \$8;
    \$8 = \$18;
    
    tmp12 = \$9;
    \$9 = \$23;
  
    tmp18 = \$10;
    \$10 = \$22;
    
    tmp19 = \$11;
    tmp17 = \$12;
    \$11 = tmp11;
    \$12 = tmp12;
  
    tmp16 = \$13;
    tmp20 = \$14;
    tmp21 = \$15;
    \$13 = tmp13;
    \$14 = tmp14;
    \$15 = tmp15;
    
    tmp22 = \$16;
    tmp23 = \$17;
    \$16 = tmp16;
    \$17 = tmp17;
    \$18 = tmp18;
    \$19 = tmp19;
    \$20 = tmp20;
    
    \$21 = tmp21;
    \$22 = tmp22;
    
    \$23 = tmp23;
    
    print
}
EOF

zcat igtb.csv.gz | \
  eval "sed $(grep S mitreids.csv | sed 's/\r$//' | sed -e 's@^\(.*\),\(.*\)$@-e "s/\2/\1/"@' | tr '\n' ' ')" | \
  sed -e 's/ID/participant_id/' -e 's/date_time/start_ts/' -e 's/"//g' -e 's/NA//g' -e 's/\([0-9]\) /\1T/' | \
  awk -f reorder_and_rename_fields.awk | \
  gzip > vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz

  
cat <(zcat vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz | head -n1) <(zcat vocab_gats_audit_psqi_iod_ocb_irb_itp_stai.csv.gz | tail -n +2 | sort) | \
  gzip -9 | \
  aws s3 cp - s3://${TARGET_BUCKET}/surveys/scored/baseline/part_one-abs_vocab_gats_audit_psqi_ipaq_iod_ocb_irb_itp_bfi_pan_stai.csv.gz


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
