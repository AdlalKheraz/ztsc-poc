#!/bin/bash
echo 'Lancement de 30 runs par pipeline...'
for i in $(seq 1 30); do
  echo "Run $i/30"
  gh workflow run baseline.yml
  sleep 5
  gh workflow run ztsc.yml
  sleep 30
done
echo 'Les 60 runs sont déclenchés. Attendre 60-90 minutes puis passer à 3.3.'
