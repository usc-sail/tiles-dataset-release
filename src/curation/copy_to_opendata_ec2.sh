#!/bin/bash

## Needs to run on EC2, with an appropriate role

if [[ ! "$#" -eq 3 ]]
then
    printf "Please provide the correct arguments\n"
    printf "Usage: %s <raw data bucket 1> <raw data bucket 2> <audio bucket> <target bucket> <target bucket audio>\n" "$0"
    exit 1
fi

RAW_BUCKET_1="$1"
RAW_BUCKET_2="$2"
AUDIO_BUCKET="$3"
TARGET_BUCKET="$4"
TARGET_AUDIO_BUCKET="$5"


## OMSignal ECG (on an EC2 instance)

sudo yum install python2-pip
sudo pip install pytz pandas

cat > om_features_fix.py <<EOF
from datetime import datetime
import pytz
import sys
import pandas as pd

df = pd.read_csv(sys.argv[1])
pt = pytz.timezone('US/Pacific')
utc = pytz.timezone('UTC')
df.loc[:, 'timestamp'] = [utc.localize(datetime.fromtimestamp(t)).astimezone(pt).strftime("%Y-%m-%dT%H:%M:%f") for t in df.loc[:, 'timestamp']]
df.to_csv(sys.argv[1], index=False)
EOF

cat > om_features_fix.awk <<EOF
BEGIN {
    FS=",";
    OFS=",";
    x=-1
}

NR == 1 {
    print "record_id", "timestamp", "raw_ecg"
}

$1 ~ /Timestamp/ {
    x = x + 1;
    next
}

{
    #datecmd = "date --date='@"$1"' +%Y-%m-%dT%H:%M:%S.%N | sed -e 's/[0-9]\\{6\\}$//'"
    #datecmd | getline timestamp
    #close(datecmd)
    #print x,timestamp,$2
print x,$0
}
EOF

# OMSignal ECG Data

aws s3 cp --recursive s3://${RAW_BUCKET_1}/omsignal-raw-ecg/ .


# Processing Wave 1

mkdir wave1
cd wave1
tar xzf ../wave1_rawecg_feb18tomay15.tar.gz
mkdir output
for f in */*csv
do
    mv "$f" "output/${f//\/raw_ecg/}"
done
cd output
find . -name "*csv" -print0 | xargs -0 -P 8 -I % gzip %
mkdir ../participants
aws s3 cp s3://${RAW_BUCKET_1}/id-mapping/omsignal_recording_id_map_wave1.csv .
for p in $(grep FALSE omsignal_recording_id_map_wave1.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    for f in $(grep "$p,FALSE" omsignal_recording_id_map_wave1.csv | cut -d ',' -f 2)
    do
        zcat "$f.csv.gz" >> "../participants/$p.csv"
    done
    gzip "../participants/$p.csv"
done
mkdir ../metadata
for p in $(grep FALSE omsignal_recording_id_map_wave1.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    echo "record_id,$(head -n1 omsignal_recording_id_map_wave1.csv | cut -d ',' -f 1,3,5)" > "../metadata/$p.csv"
    grep "$p,FALSE" omsignal_recording_id_map_wave1.csv | cut -d ',' -f 1,3,5 | sed -e 's#\([0-9]*\)/\([0-9]*\)/\([0-9]*\),#\3-\1-\2,#' | awk -F',' -v OFS=',' '{print (NR - 1),$0}' >> "../metadata/$p.csv"
    gzip "../metadata/$p.csv"
done
cd ../
mv participants/ participants_old/
cd participants/
for p in $(grep FALSE ../output/omsignal_recording_id_map_wave1.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    zcat "../participants_old/$p.csv.gz" | awk -f ~/om_features_fix.awk | gzip > "$p.csv.gz"
    python ~/om_features_fix.py "$p.csv.gz"
done
cd ../metadata/
aws s3 sync . s3://${TARGET_BUCKET}/omsignal/metadata/
cd ../participants/
aws s3 sync . s3://${TARGET_BUCKET}/omsignal/ecg/

# Processing Wave 2

mkdir wave2
cd wave2
tar xzf ../wave2_rawecg_apr7tojun19.tgz
mkdir output
for f in */*csv
do
    mv "$f" "output/${f//\/raw_ecg/}"
done
cd output
find . -name "*csv" -print0 | xargs -0 -P 8 -I % gzip %
mkdir ../participants
aws s3 cp s3://${RAW_BUCKET_1}/id-mapping/omsignal_recording_id_map_wave2.csv .
for p in $(grep FALSE omsignal_recording_id_map_wave2.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    for f in $(grep "$p,FALSE" omsignal_recording_id_map_wave2.csv | cut -d ',' -f 2;)
    do
        zcat "$f.csv.gz" >> "../participants/$p.csv"
    done
    gzip "../participants/$p.csv"
done
mkdir ../metadata
for p in $(grep FALSE omsignal_recording_id_map_wave2.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    echo "record_id,$(head -n1 omsignal_recording_id_map_wave2.csv | cut -d ',' -f 1,3,5)" > "../metadata/$p.csv"
    grep "$p,FALSE" omsignal_recording_id_map_wave2.csv | cut -d ',' -f 1,3,5 | sed -e 's#\([0-9]*\)/\([0-9]*\)/\([0-9]*\),#\3-\1-\2,#' | awk -F',' -v OFS=',' '{print (NR - 1),$0}' >> "../metadata/$p.csv"
    gzip "../metadata/$p.csv"
done
cd ../
mv participants/ participants_old/
cd participants/
for p in $(grep FALSE ../output/omsignal_recording_id_map_wave2.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    zcat "../participants_old/$p.csv.gz" | awk -f ~/om_features_fix.awk | gzip > "$p.csv.gz"
    python ~/om_features_fix.py "$p.csv.gz"
done
cd ../
rm metadata/mwmw*
rm participants/mwmw*
aws s3 cp --recursive metadata/ s3://${TARGET_BUCKET}/omsignal/metadata/
aws s3 cp --recursive participants/ s3://${TARGET_BUCKET}/omsignal/ecg/


# Processing Wave 3

mkdir wave3
cd wave3
tar xzf ../wave3_rawecg.tgz
mkdir output
for f in */*csv
do
    mv "$f" "output/${f//\/raw_ecg/}"
done
cd output
find . -name "*csv" -print0 | xargs -0 -P 8 -I % gzip %
mkdir ../participants
aws s3 cp s3://${RAW_BUCKET_1}/id-mapping/omsignal_recording_id_map_wave3.csv .
sed 's/\r$//' omsignal_recording_id_map_wave3.csv > omsignal_recording_id_map_wave3_fixed.csv
for p in $(tail -n +2 omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    for f in $(grep -E "$p\$" omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 2)
    do
        zcat "$f.csv.gz" >> "../participants/$p.csv"
    done
    gzip "../participants/$p.csv"
done
mkdir ../metadata
for p in $(tail -n +2 omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    echo "record_id,$(head -n1 omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 1,3,5)" > "../metadata/$p.csv"
    grep -E "$p\$" omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 1,3,5 | sed -e 's#\([0-9]*\)/\([0-9]*\)/\([0-9]*\),#\3-\1-\2,#' | awk -F',' -v OFS=',' '{print (NR - 1),$0}' >> "../metadata/$p.csv"
    gzip "../metadata/$p.csv"
done
cd ../
mv participants/ participants_old/
cd participants/
for p in $(tail -n +2 ../output/omsignal_recording_id_map_wave3_fixed.csv | cut -d ',' -f 6 | sort -u | uniq)
do
    zcat "../participants_old/$p.csv.gz" | awk -f ~/om_features_fix.awk | gzip > "$p.csv.gz"
    python ~/om_features_fix.py "$p.csv.gz"
done
cd ../
aws s3 cp --recursive metadata/ s3://${TARGET_BUCKET}/omsignal/metadata/
aws s3 cp --recursive participants/ s3://${TARGET_BUCKET}/omsignal/ecg/









## Audio: removing potential privacy issues


# Keeping a subset of features

cat > keep.txt <<EOF
frameIndex
frameTime
F0final_sma
voicingFinalUnclipped_sma
jitterLocal_sma
jitterDDP_sma
shimmerLocal_sma
logHNR_sma
voiceProb_sma
F0_sma
F0env_sma
audspec_lengthL1norm_sma
audspecRasta_lengthL1norm_sma
pcm_RMSenergy_sma
pcm_zcr_sma
pcm_intensity_sma
pcm_loudness_sma
pcm_fftMag_fband250-650_sma
pcm_fftMag_fband1000-4000_sma
pcm_fftMag_spectralRollOff25.0_sma
pcm_fftMag_spectralRollOff50.0_sma
pcm_fftMag_spectralRollOff75.0_sma
pcm_fftMag_spectralRollOff90.0_sma
pcm_fftMag_spectralFlux_sma
pcm_fftMag_spectralCentroid_sma
pcm_fftMag_spectralEntropy_sma
pcm_fftMag_spectralVariance_sma
pcm_fftMag_spectralSkewness_sma
pcm_fftMag_spectralKurtosis_sma
pcm_fftMag_spectralSlope_sma
pcm_fftMag_psySharpness_sma
pcm_fftMag_spectralHarmonicity_sma
F0final_sma_ff0
isTurn
EOF

cat > full_features.txt <<EOF
frameIndex
frameTime
F0final_sma
voicingFinalUnclipped_sma
jitterLocal_sma
jitterDDP_sma
shimmerLocal_sma
logHNR_sma
voiceProb_sma
F0_sma
F0env_sma
audspec_lengthL1norm_sma
audspecRasta_lengthL1norm_sma
pcm_RMSenergy_sma
pcm_zcr_sma
pcm_intensity_sma
pcm_loudness_sma
audSpec_Rfilt_sma[0]
audSpec_Rfilt_sma[1]
audSpec_Rfilt_sma[2]
audSpec_Rfilt_sma[3]
audSpec_Rfilt_sma[4]
audSpec_Rfilt_sma[5]
audSpec_Rfilt_sma[6]
audSpec_Rfilt_sma[7]
audSpec_Rfilt_sma[8]
audSpec_Rfilt_sma[9]
audSpec_Rfilt_sma[10]
audSpec_Rfilt_sma[11]
audSpec_Rfilt_sma[12]
audSpec_Rfilt_sma[13]
audSpec_Rfilt_sma[14]
audSpec_Rfilt_sma[15]
audSpec_Rfilt_sma[16]
audSpec_Rfilt_sma[17]
audSpec_Rfilt_sma[18]
audSpec_Rfilt_sma[19]
audSpec_Rfilt_sma[20]
audSpec_Rfilt_sma[21]
audSpec_Rfilt_sma[22]
audSpec_Rfilt_sma[23]
audSpec_Rfilt_sma[24]
audSpec_Rfilt_sma[25]
pcm_fftMag_fband250-650_sma
pcm_fftMag_fband1000-4000_sma
pcm_fftMag_spectralRollOff25.0_sma
pcm_fftMag_spectralRollOff50.0_sma
pcm_fftMag_spectralRollOff75.0_sma
pcm_fftMag_spectralRollOff90.0_sma
pcm_fftMag_spectralFlux_sma
pcm_fftMag_spectralCentroid_sma
pcm_fftMag_spectralEntropy_sma
pcm_fftMag_spectralVariance_sma
pcm_fftMag_spectralSkewness_sma
pcm_fftMag_spectralKurtosis_sma
pcm_fftMag_spectralSlope_sma
pcm_fftMag_psySharpness_sma
pcm_fftMag_spectralHarmonicity_sma
lpcCoeff_sma[0]
lpcCoeff_sma[1]
lpcCoeff_sma[2]
lpcCoeff_sma[3]
lpcCoeff_sma[4]
lpcCoeff_sma[5]
lpcCoeff_sma[6]
lpcCoeff_sma[7]
mfcc_sma[1]
mfcc_sma[2]
mfcc_sma[3]
mfcc_sma[4]
mfcc_sma[5]
mfcc_sma[6]
mfcc_sma[7]
mfcc_sma[8]
mfcc_sma[9]
mfcc_sma[10]
mfcc_sma[11]
mfcc_sma[12]
mfcc_sma[13]
mfcc_sma[14]
F0final_sma_ff0
voiceProb_sma_de
F0_sma_de
F0env_sma_de
audspec_lengthL1norm_sma_de
audspecRasta_lengthL1norm_sma_de
pcm_RMSenergy_sma_de
pcm_zcr_sma_de
pcm_intensity_sma_de
pcm_loudness_sma_de
mfcc_sma_de[1]
mfcc_sma_de[2]
mfcc_sma_de[3]
mfcc_sma_de[4]
mfcc_sma_de[5]
mfcc_sma_de[6]
mfcc_sma_de[7]
mfcc_sma_de[8]
mfcc_sma_de[9]
mfcc_sma_de[10]
mfcc_sma_de[11]
mfcc_sma_de[12]
mfcc_sma_de[13]
mfcc_sma_de[14]
voiceProb_sma_de_de
F0_sma_de_de
F0env_sma_de_de
audspec_lengthL1norm_sma_de_de
audspecRasta_lengthL1norm_sma_de_de
pcm_RMSenergy_sma_de_de
pcm_zcr_sma_de_de
pcm_intensity_sma_de_de
pcm_loudness_sma_de_de
mfcc_sma_de_de[1]
mfcc_sma_de_de[2]
mfcc_sma_de_de[3]
mfcc_sma_de_de[4]
mfcc_sma_de_de[5]
mfcc_sma_de_de[6]
mfcc_sma_de_de[7]
mfcc_sma_de_de[8]
mfcc_sma_de_de[9]
mfcc_sma_de_de[10]
mfcc_sma_de_de[11]
mfcc_sma_de_de[12]
mfcc_sma_de_de[13]
mfcc_sma_de_de[14]
isTurn
EOF

cat > emo_features.txt <<EOF
frameIndex
frameTime
voiceProb_sma
F0_sma
F0env_sma
audspec_lengthL1norm_sma
audspecRasta_lengthL1norm_sma
pcm_RMSenergy_sma
pcm_zcr_sma
pcm_intensity_sma
pcm_loudness_sma
pcm_fftMag_fband250-650_sma
pcm_fftMag_fband1000-4000_sma
pcm_fftMag_spectralRollOff25.0_sma
pcm_fftMag_spectralRollOff50.0_sma
pcm_fftMag_spectralRollOff75.0_sma
pcm_fftMag_spectralRollOff90.0_sma
pcm_fftMag_spectralFlux_sma
pcm_fftMag_spectralCentroid_sma
pcm_fftMag_spectralEntropy_sma
pcm_fftMag_spectralVariance_sma
pcm_fftMag_spectralSkewness_sma
pcm_fftMag_spectralKurtosis_sma
pcm_fftMag_spectralSlope_sma
pcm_fftMag_psySharpness_sma
pcm_fftMag_spectralHarmonicity_sma
mfcc_sma[1]
mfcc_sma[2]
mfcc_sma[3]
mfcc_sma[4]
mfcc_sma[5]
mfcc_sma[6]
mfcc_sma[7]
mfcc_sma[8]
mfcc_sma[9]
mfcc_sma[10]
mfcc_sma[11]
mfcc_sma[12]
mfcc_sma[13]
mfcc_sma[14]
isTurn
EOF

grep -E "($(cat keep.txt | tr '\n' '|' | sed -e 's/|$//'))" emo_features.txt > emo_keep_features.txt


# Filechecks:
#  0: unrecognized set of features (contains neither full_features nor emo_features)
#  1: same set than full_features, no duplicates
#    1.0: same order
#    1.1: different order
#  2: file feature set contains full_features
#    2.1: duplicated fields (of full_features) only [bitwise: 1<<0]
#    2.2: extra fields only [bitwise: 1<<1]
#    2.3: both [bitwise: 1<<0 + 1<<1]
#    2.(x+8): F1_sma changed for F0_sma
#  3: file feature set contains emo_features
#    3.0: same set, no duplicates, same order
#    3.1: same set, no duplicates, different order
#    3.2: same set, duplicates (of emo_features) [bitwise: 1<<1]
#    3.4: larger set, no duplicates (of emo_features) [bitwise: 1<<2]
#    3.6: larger set, duplicates (of emo_features) [bitwise: 1<<1 + 1<<2]
#    3.(x+8): F1_sma changed for F0_sma
#  9: empty file (no record)
cat > check_files_and_remove_incorrect.sh <<EOF
#!/bin/bash

echo 'file_path,unixtime,time_UTC,file_check,nb_rows' > \$2
for f in \${1%%/}/*
do
    FILE_HEADER=\$(zcat "\$f" | head -n1)
    FILE_FIELDS="\$(echo "\$FILE_HEADER" | tr ';' '\n')"
    FILE_FIELDS_SORTED="\$(echo "\$FILE_FIELDS" | sort)"
    NBFIELDS=\$(echo "\$FILE_FIELDS" | wc -l)
    NBFIELDS_UNIQUE=\$(echo "\$FILE_FIELDS_SORTED" | uniq | wc -l)
    NBROWS=\$(echo "\$(zcat "\$f" | wc -l) - 1" | bc)
    
    FILE_FIELDS_F1_SMA_FLAG="0"
    if echo "\$FILE_HEADER" | grep F1_sma > /dev/null; then
        FILE_FIELDS_F1_SMA_FLAG="8"
    fi
    FILE_FIELDS_F1_SMA_FIXED="\$(echo "\$FILE_FIELDS" | sed -e 's/F1_sma/F0_sma/')"
    
    FILE_FIELDS_FULLSUBSET="\$(echo "\$FILE_FIELDS_F1_SMA_FIXED" | grep -E "^($(cat full_features.txt | tr '\n' '|' | sed -e 's/|$//' -e 's/\[/\\[/g'  -e 's/\]/\\]/g'))$")"
    FILE_FIELDS_EMOSUBSET="\$(echo "\$FILE_FIELDS_F1_SMA_FIXED" | grep -E "^($(cat emo_features.txt | tr '\n' '|' | sed -e 's/|$//' -e 's/\[/\\[/g'  -e 's/\]/\\]/g'))$")"


    if [ \$NBROWS -eq 0 ]
    then
        echo "\$f,\$(basename \${f##*_} .csv.gz),,9,\$NBROWS" >> \$2
#         mv "\$f" ~/trash/
        rm "\$f"
    elif [ "\$(echo "\$FILE_FIELDS_FULLSUBSET" | sort | uniq | wc -l)" -eq "$(cat full_features.txt | wc -l)" ]
    then
        if [ \$NBFIELDS -eq $(cat full_features.txt | wc -l) ]
        then
            if [[ "\$FILE_HEADER" == "$(cat full_features.txt | tr '\n' ';' | sed -e 's/;$//')" ]]
            then
                # All features of full_features.txt and only once, in the same order
                echo "\$f,\$(basename \${f##*_} .csv.gz),,1.\$(echo 0+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

            else
                # All features of full_features.txt and only once, in a different order
                echo "\$f,\$(basename \${f##*_} .csv.gz),,1.\$(echo 1+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2
            fi

        elif [ "\$NBFIELDS_UNIQUE" -eq $(cat full_features.txt | wc -l) ]
        then
            # Duplicated fields, but only those from full_features.txt are in the file
            echo "\$f,\$(basename \${f##*_} .csv.gz),,2.\$(echo 1+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

        elif [ "\$(echo "\$FILE_FIELDS_FULLSUBSET" | wc -l)" -eq "$(cat full_features.txt | wc -l)" ]
        then
            # Extra fields, no duplicates from full_features.txt are in the file
            echo "\$f,\$(basename \${f##*_} .csv.gz),,2.\$(echo 2+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

        else
            # Both
            echo "\$f,\$(basename \${f##*_} .csv.gz),,2.\$(echo 3+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2
        fi

    elif [ "\$(echo "\$FILE_FIELDS_EMOSUBSET" | sort | uniq | wc -l)" -eq "$(cat emo_features.txt | wc -l)" ]
    then
        if [ \$NBFIELDS -eq $(cat emo_features.txt | wc -l) ]
        then
            if [[ "\$FILE_HEADER" == "$(cat emo_features.txt | tr '\n' ';' | sed -e 's/;$//')" ]]
            then
                # All features of emo_features.txt and only once, in the same order
                echo "\$f,\$(basename \${f##*_} .csv.gz),,3.\$(echo 0+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

            else
                # All features of emo_features.txt and only once, in a different order
                echo "\$f,\$(basename \${f##*_} .csv.gz),,3.\$(echo 1+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2
            fi

        elif [ "\$NBFIELDS_UNIQUE" -eq $(cat emo_features.txt | wc -l) ]
        then
            # Duplicated fields, but only those from emo_features.txt are in the file
            echo "\$f,\$(basename \${f##*_} .csv.gz),,3.\$(echo 2+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

        elif [ "\$(echo "\$FILE_FIELDS_EMOSUBSET" | wc -l)" -eq "$(cat emo_features.txt | wc -l)" ]
        then
            # Extra fields, no duplicates from emo_features.txt are in the file
            echo "\$f,\$(basename \${f##*_} .csv.gz),,3.\$(echo 4+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2

        else
            # Both
            echo "\$f,\$(basename \${f##*_} .csv.gz),,3.\$(echo 6+\$FILE_FIELDS_F1_SMA_FLAG | bc),\$NBROWS" >> \$2
        fi

    else
        echo "\$f,\$(basename \${f##*_} .csv.gz),,0,\$NBROWS" >> \$2
#         mv "\$f" ~/trash/
        rm "\$f"
    fi
done
EOF
chmod u+x check_files_and_remove_incorrect.sh

FIELDS="$(grep -in -E "^($(cat keep.txt | tr '\n' '|' | sed -e 's/|$//'))$" full_features.txt | cut -f1 -d: | tr '\n' ',' | sed -e 's/,$//')"
cat > process_file.sh <<EOF
#!/bin/bash

NBFIELDS=\$(zcat \$1 | head -n1 | tr ';' '\n' | wc -l)

OUTPUT_FILENAME="\$2/\$(grep "\$1" ../metadata.txt | cut -d',' -f2).csv.gz"

FILE_CHECK="\$(grep "\$1" ../metadata.txt | cut -d',' -f4)"
FILE_CHECK_MAJOR="\${FILE_CHECK%.*}"
FILE_CHECK_MINOR="\${FILE_CHECK#*.}"
if [[ "\$FILE_CHECK" == "1.0" ]]
then
    zcat "\$1" | \\
        cut -f$FIELDS -d';' | \\
        sed -e 's/;/,/g' | \\
        gzip > "\$OUTPUT_FILENAME"
elif [[ \$FILE_CHECK_MAJOR == "1" ]] || [[ \$FILE_CHECK_MAJOR == "2" ]] || [[ \$FILE_CHECK_MAJOR == "3" ]]
then
    KEPT_FIELDS=""
    FILE_FIELDS="\$(zcat "\$1" | head -n1 | tr ';' '\n')"
    if [[ "\$((\$FILE_CHECK_MINOR>>3))" -eq "1" ]]
    then
        FILE_FIELDS="\$(echo -e "\$FILE_FIELDS" | sed -e 's/F1_sma/F0_sma/')"
    fi
    FIRST_ROW="\$(zcat "\$1" | head -n2 | tail -n1)"
    while read -r feat
    do
        FEAT_ESCAPED_TMP=\${feat//\[/\\[}
        COLUMNS="\$(echo -e "\$FILE_FIELDS" | grep -En "^\${FEAT_ESCAPED_TMP//\]/\\]}$")"
        if [ \$(echo -n \$COLUMNS | wc -l) -eq 1 ]
        then
            KEPT_FIELDS="\$KEPT_FIELDS,\$(echo \$COLUMNS | cut -d: -f1)"
        else
            CUR_COL="nan" #\$(echo \$COLUMNS | head -n1 | cut -d: -f1)"
            for col in \$COLUMNS
            do
                F=\$(echo \$col | cut -d: -f1)
                if [[ "\$(echo \$FIRST_ROW | cut -d';' -f\$F)" == "" ]]
                then
                    continue;
                fi
                CUR_COL="\$F"
                break;
            done
            KEPT_FIELDS="\$KEPT_FIELDS,\$CUR_COL"
        fi
    done < $(pwd)/keep.txt
    zcat "\$1" | \\
      awk -F';' -v OFS=',' "NR==1 {print $(cat keep.txt | tr '\n' ',' | sed -e 's/,$/\\"/' -e 's/,/\\",\\"/g' -e 's/^/\\"/')} NR>1{print \$(echo \$KEPT_FIELDS | sed -e 's/^,/$/' -e 's/,/,$/g' -e 's/\\\$nan/""/g')}" | \\
      gzip > "\$OUTPUT_FILENAME"
fi
EOF
chmod u+x process_file.sh

cd

# mkdir trash
for u in $(aws s3 ls s3://${RAW_BUCKET_1}/jelly/ | sed -e 's/^.*PRE //' -e 's@/@@g')
do
    echo Processing: $u
    if [ "$(aws s3 ls s3://${AUDIO_BUCKET}/metadata/$u.csv | wc -l)" -eq 1 ]
    then
        continue;
    fi
    
    mkdir $u
    cd $u
    aws s3 sync "s3://${RAW_BUCKET_1}/jelly/$u/" . > ~/$u.dl.log
    
    find . -name '*.csv.gz' -exec bash -c 'zcat "{}" | head -n1' \; | sort | uniq -c > ../features_stats.txt
    
    cd ..
    ~/check_files_and_remove_incorrect.sh $u metadata.txt
    aws s3 cp metadata.txt "s3://${AUDIO_BUCKET}/metadata/$u.csv"
    aws s3 cp features_stats.txt "s3://${AUDIO_BUCKET}/features_stats/$u.csv"
    
    mkdir new
    cd $u
    find . -name '*.csv.gz' -print0 | xargs -0 -P 3 -I {} ~/process_file.sh "{}" "../new/"
    
    cd
    aws s3 sync new/ "s3://${TARGET_AUDIO_BUCKET}/raw/$u/" > ~/$u.ul.log
    
    rm -Rf new $u
done



# Wave 4
for u in $(aws s3 ls s3://${RAW_BUCKET_2}/jelly/ | sed -e 's/^.*PRE //' -e 's@/@@g')
do
    echo Processing: $u
    if [ "$(aws s3 ls s3://${AUDIO_BUCKET}/metadata-wave4/$u.csv | wc -l)" -eq 1 ]
    then
        continue;
    fi
    
    mkdir $u
    cd $u
    aws s3 sync "s3://${RAW_BUCKET_2}/jelly/$u/" . > ~/$u.dl.log
    
    find . -name '*.csv.gz' -exec bash -c 'zcat "{}" | head -n1' \; | sort | uniq -c > ../features_stats.txt
    
    cd ..
    ~/check_files_and_remove_incorrect.sh $u metadata.txt
    aws s3 cp metadata.txt "s3://${AUDIO_BUCKET}/metadata-wave4/$u.csv"
    aws s3 cp features_stats.txt "s3://${AUDIO_BUCKET}/features_stats-wave4/$u.csv"
    
    rm -Rf $u
done



# for u in $(aws s3 ls s3://${RAW_BUCKET_1}/jelly/ | sed -e 's/^.*PRE //' -e 's@/@@g')
# do
#     echo $u,$(aws s3 ls "s3://${RAW_BUCKET_1}/jelly/$u/" | wc -l) >> nb_files.txt
# done

for u in $(aws s3 ls s3://${RAW_BUCKET_2}/jelly/ | sed -e 's/^.*PRE //' -e 's@/@@g')
do
    echo $u,$(aws s3 ls "s3://${RAW_BUCKET_2}/jelly/$u/" | wc -l) >> nb_files4.txt
done


