#!/bin/bash
echo 'Pipeline,RunID,DureeSeconds' > results/overhead_data.csv

gh run list --workflow=baseline.yml --limit 30 --status completed \
--json databaseId,createdAt,updatedAt \
--jq '.[] | ["baseline", .databaseId, ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601))] | @csv' \
>> results/overhead_data.csv

gh run list --workflow=ztsc.yml --limit 30 --status completed \
--json databaseId,createdAt,updatedAt \
--jq '.[] | ["ztsc", .databaseId, ((.updatedAt | fromdateiso8601) - (.createdAt | fromdateiso8601))] | @csv' \
>> results/overhead_data.csv

echo 'Lignes collectées :'
wc -l results/overhead_data.csv
