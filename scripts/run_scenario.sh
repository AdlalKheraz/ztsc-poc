#!/bin/bash
# Usage : ./run_scenario.sh S1 "description" "commande-de-modification"
SCENARIO=$1
DESCRIPTION=$2
BRANCH="test-${SCENARIO,,}"

echo "=== Scénario $SCENARIO : $DESCRIPTION ==="
git checkout -b $BRANCH
# La modification est passée par la variable MODIFY
eval "$MODIFY"
git add -A && git commit -m "$SCENARIO $DESCRIPTION" && git push -u origin $BRANCH

# Attendre que les workflows se lancent
echo "Attente 90 secondes pour que les pipelines tournent..."
sleep 90

# Récupérer les statuts
BL=$(gh run list --workflow=baseline.yml --branch $BRANCH --limit 1 --json conclusion --jq '.[0].conclusion')
ZT=$(gh run list --workflow=ztsc.yml --branch $BRANCH --limit 1 --json conclusion --jq '.[0].conclusion')

# Interpréter
BLRES=$([ "$BL" = "success" ] && echo "PASS" || echo "BLOCK")
ZTRES=$([ "$ZT" = "success" ] && echo "PASS" || echo "BLOCK")
echo "$SCENARIO,$DESCRIPTION,$BLRES,$ZTRES" >> results/scenario_results.csv

# Nettoyer
git checkout main
git branch -D $BRANCH
git push origin --delete $BRANCH 2>/dev/null
