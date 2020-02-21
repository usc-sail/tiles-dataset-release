# Owl to Owl packets
mkdir hoots
for file in *.jsonl.gz
do
    if [ ! -f "hoots/"$(basename -- "$file" .jsonl.gz).csv ]; then
        echo "Processing file" $file
        echo "timeStamp,deviceId,receiverId,rssi" > "hoots/$(basename -- "$file" .jsonl.gz).csv"
        zgrep "reelyActive" $file | \
            jq -r 'if has("receiverDirectory") then ((.rssiSignature | to_entries[]) as $tmp | [.time, .deviceId, $tmp.key, $tmp.value]) else [] end | @csv' \
            >> "hoots/$(basename -- "$file" .jsonl.gz).csv"
        pigz -9 "hoots/$(basename -- "$file" .jsonl.gz).csv"
    fi
done

# Jelly to Owl packets
mkdir jelly
for file in *.jsonl.gz
do
    if [ ! -f "jelly/"$(basename -- "$file" .jsonl.gz).csv ]; then
        echo "Processing file" $file
        echo "timeStamp,jellyId,receiverId,rssi" > "jelly/$(basename -- "$file" .jsonl.gz).csv"
        zgrep "Jelly" $file | \
            jq -r 'if has("receiverDirectory") then ((.rssiSignature | to_entries[]) as $tmp | [.time, .tiraid.identifier.advData.serviceData.data, $tmp.key, $tmp.value]) else [] end | @csv' \
            >> "jelly/$(basename -- "$file" .jsonl.gz).csv"
        pigz -9 "jelly/$(basename -- "$file" .jsonl.gz).csv"
    fi
done

# Minew to Owl packets
mkdir minew
for file in *.jsonl.gz
do
    if [ ! -f "minew/"$(basename -- "$file" .jsonl.gz).csv ]; then
        echo "Processing file" $file
        echo "timeStamp,deviceId,productModel,receiverId,rssi" > "minew/$(basename -- "$file" .jsonl.gz).csv"
        zgrep "minew" $file | \
            zgrep -v "eddystone" | \
            jq -r 'if has("receiverDirectory") then ((.rssiSignature | to_entries[]) as $tmp | [.time, .deviceId, .tiraid.identifier.advData.serviceData.minew.productModel, $tmp.key, $tmp.value]) else [] end | @csv' \
            >> "minew/$(basename -- "$file" .jsonl.gz).csv"
        pigz -9 "minew/$(basename -- "$file" .jsonl.gz).csv"
    fi
done
