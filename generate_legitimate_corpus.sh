#!/usr/bin/env bash
# =============================================================================
#  generate_legitimate_corpus.sh
#  Corpus de 25 paquets npm legitimes pour le PoC ZTSC
#  Adlal KHERAZ - Memoire de fin d'etudes - Ecole-IT 2025-2026
# =============================================================================
#  Complement obligatoire de generate_malicious_corpus.sh.
#
#  Sans ce script, le classifieur Random Forest apprendrait les mauvais
#  patterns : il pourrait par exemple conclure "si taille < 1 KB alors
#  malveillant", ce qui est une correlation artefactuelle due uniquement
#  a notre facon de generer les paquets malveillants synthetiques.
#
#  Ce script telecharge 25 paquets reels du registre npm officiel via
#  "npm pack", choisis parmi les plus telecharges de l ecosysteme. Ces
#  paquets sont audites, largement utilises, et representent statistiquement
#  la population "non-malveillante".
#
#  POURQUOI NPM PACK ET PAS NPM INSTALL
#    - npm pack ne resout PAS les dependances (pas de chargement recursif)
#    - pas d execution de scripts postinstall
#    - produit directement le .tgz officiel du registre
#    - exactement le format attendu par extract_features.py
#
#  USAGE   :  chmod +x generate_legitimate_corpus.sh && ./generate_legitimate_corpus.sh
#  SORTIE  :  ./dataset/legitimate/leg-pkg-1.tgz ... leg-pkg-25.tgz
#             plus le manifest CSV ./dataset/legitimate/corpus_manifest.csv
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
#  CONFIGURATION
# ---------------------------------------------------------------------------
OUTPUT_DIR="${OUTPUT_DIR:-./dataset/legitimate}"
WORK_DIR="${WORK_DIR:-./.tmp_leg_build}"

# ---------------------------------------------------------------------------
#  COULEURS
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  CL_RST=$'\033[0m'; CL_CYAN=$'\033[1;36m'; CL_GRN=$'\033[1;32m'
  CL_YLW=$'\033[1;33m'; CL_RED=$'\033[1;31m'; CL_DIM=$'\033[2m'
else
  CL_RST=""; CL_CYAN=""; CL_GRN=""; CL_YLW=""; CL_RED=""; CL_DIM=""
fi

log_step() { printf "%s[%02d/25]%s %s\n" "$CL_CYAN" "$1" "$CL_RST" "$2"; }
log_info() { printf "%s[INFO]%s %s\n"   "$CL_GRN" "$CL_RST" "$1"; }
log_warn() { printf "%s[WARN]%s %s\n"   "$CL_YLW" "$CL_RST" "$1"; }
log_err()  { printf "%s[ERR] %s\n"      "$CL_RED" "$1"; }

# ---------------------------------------------------------------------------
#  LISTE DES 25 PAQUETS LEGITIMES
# ---------------------------------------------------------------------------
#  Criteres de selection :
#    - Tous figurent dans le top 1000 npm par telechargements
#    - Varies en categorie (frontend, backend, cli, utilitaires, tests)
#    - Varies en taille (quelques kB a plusieurs centaines de kB)
#    - Certains ont des scripts lifecycle LEGITIMES (ex : husky)
#      -> important pour que le modele apprenne a distinguer un
#         postinstall legitime d un postinstall malveillant
#
#  Format : nom@version_pinned  (pinning pour reproductibilite academique)
LEGIT_PACKAGES=(
  "express@4.19.2"        "lodash@4.17.21"        "react@18.2.0"
  "axios@1.6.7"           "moment@2.30.1"         "chalk@5.3.0"
  "webpack@5.89.0"        "debug@4.3.4"           "dotenv@16.3.1"
  "commander@11.1.0"      "jest@29.7.0"           "eslint@8.56.0"
  "prettier@3.2.4"        "typescript@5.3.3"      "socket.io-client@4.7.4"
  "passport@0.7.0"        "bcryptjs@2.4.3"        "winston@3.11.0"
  "cors@2.8.5"            "body-parser@1.20.2"    "mongoose@8.1.1"
  "cheerio@1.0.0-rc.12"   "nodemailer@6.9.8"      "rollup@4.9.6"
  "vue@3.4.15"
)

# ---------------------------------------------------------------------------
#  VERIFICATION DES PREREQUIS
# ---------------------------------------------------------------------------
if ! command -v npm &>/dev/null; then
  log_err "npm introuvable. Installer Node.js 18+ d abord."
  exit 1
fi

# ---------------------------------------------------------------------------
#  INITIALISATION
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"

# Passer en chemins absolus pour survivre aux "cd" dans la boucle
OUTPUT_DIR="$(cd "$OUTPUT_DIR" && pwd)"
WORK_DIR="$(cd "$WORK_DIR" && pwd)"

log_info "Corpus cible      : ${OUTPUT_DIR}"
log_info "Dossier de travail: ${WORK_DIR}"
log_info "Registre npm      : $(npm config get registry)"
printf '\n%s=== DEBUT DE TELECHARGEMENT (25 paquets legitimes) ===%s\n\n' "$CL_CYAN" "$CL_RST"

# En-tete du manifest
echo "id,filename,package_name,version,size_bytes,has_scripts" \
  > "${OUTPUT_DIR}/corpus_manifest.csv"

# ---------------------------------------------------------------------------
#  BOUCLE DE TELECHARGEMENT
# ---------------------------------------------------------------------------
cd "$WORK_DIR"
FAILED_PACKAGES=()

for i in "${!LEGIT_PACKAGES[@]}"; do
  idx=$(( i + 1 ))
  pkg_spec="${LEGIT_PACKAGES[$i]}"
  # Separation nom@version
  pkg_name="${pkg_spec%@*}"
  pkg_version="${pkg_spec##*@}"

  log_step "$idx" "npm pack ${pkg_spec}  ${CL_DIM}(telechargement...)${CL_RST}"

  # npm pack produit un tgz dont le nom suit la convention :
  #   nom-version.tgz (scope @ remplace par un tiret)
  # --silent pour ne pas polluer la sortie ; --quiet empeche les warnings
  if output=$(npm pack "${pkg_spec}" --silent --quiet 2>&1); then
    # npm pack ecrit le nom du fichier genere sur stdout (derniere ligne)
    produced_file=$(echo "$output" | tail -1 | tr -d '\n\r ')

    if [[ -f "$produced_file" ]]; then
      # Renommage vers leg-pkg-N.tgz pour uniformiser avec mal-pkg-N.tgz
      target="${OUTPUT_DIR}/leg-pkg-${idx}.tgz"
      mv "$produced_file" "$target"

      # Statistiques pour le manifest
      size=$(stat -c%s "$target" 2>/dev/null || stat -f%z "$target")
      # Detection d un eventuel scripts lifecycle legitime
      has_scripts=$(tar -xzOf "$target" package/package.json 2>/dev/null \
        | grep -q '"scripts"' && echo "yes" || echo "no")

      printf '%d,%s,%s,%s,%s,%s\n' \
        "$idx" "leg-pkg-${idx}.tgz" "$pkg_name" "$pkg_version" "$size" "$has_scripts" \
        >> "${OUTPUT_DIR}/corpus_manifest.csv"

      log_info "  -> ${target} (${size} octets, scripts=${has_scripts})"
    else
      log_warn "  Fichier attendu introuvable : ${produced_file}"
      FAILED_PACKAGES+=("$pkg_spec")
    fi
  else
    log_err "  Echec npm pack pour ${pkg_spec}"
    FAILED_PACKAGES+=("$pkg_spec")
  fi
done

cd - >/dev/null

# ---------------------------------------------------------------------------
#  NETTOYAGE
# ---------------------------------------------------------------------------
printf '\n%s=== NETTOYAGE ===%s\n' "$CL_CYAN" "$CL_RST"
rm -rf "$WORK_DIR"
log_info "Dossier de travail supprime : ${WORK_DIR}"

# ---------------------------------------------------------------------------
#  STATISTIQUES FINALES
# ---------------------------------------------------------------------------
printf '\n%s=== STATISTIQUES DU CORPUS LEGITIME ===%s\n' "$CL_CYAN" "$CL_RST"

num_ok=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'leg-pkg-*.tgz' | wc -l)
total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
num_with_scripts=$(awk -F',' 'NR>1 && $6=="yes"' "${OUTPUT_DIR}/corpus_manifest.csv" | wc -l)

printf '  %-30s %d / 25 archives\n' "Paquets telecharges"     "$num_ok"
printf '  %-30s %d paquets\n'       "Avec scripts lifecycle"  "$num_with_scripts"
printf '  %-30s %s\n'               "Taille totale du corpus" "$total_size"
printf '  %-30s %s\n'               "Manifest CSV"            "${OUTPUT_DIR}/corpus_manifest.csv"

if (( ${#FAILED_PACKAGES[@]} > 0 )); then
  printf '\n%sPaquets en echec (%d) :%s\n' "$CL_YLW" "${#FAILED_PACKAGES[@]}" "$CL_RST"
  for pkg in "${FAILED_PACKAGES[@]}"; do
    printf '  - %s\n' "$pkg"
  done
  printf '%sCes echecs sont generalement dus a un reseau lent ou une version retiree.%s\n' "$CL_DIM" "$CL_RST"
  printf '%sRelancer le script ou editer LEGIT_PACKAGES pour remplacer les paquets.%s\n' "$CL_DIM" "$CL_RST"
fi

# ---------------------------------------------------------------------------
#  VERIFICATION DE LA DIVERSITE DE TAILLE (anti-biais)
# ---------------------------------------------------------------------------
printf '\n%sDistribution des tailles (octets) :%s\n' "$CL_GRN" "$CL_RST"
awk -F',' 'NR>1 {print $5}' "${OUTPUT_DIR}/corpus_manifest.csv" \
  | sort -n | awk '
  BEGIN { cnt = 0; sum = 0 }
  { a[cnt++] = $1; sum += $1 }
  END {
    if (cnt == 0) { print "  (aucun)"; exit }
    printf "  min    : %d\n", a[0]
    printf "  max    : %d\n", a[cnt-1]
    printf "  mediane: %d\n", a[int(cnt/2)]
    printf "  moyenne: %d\n", sum/cnt
  }'

printf '\n%s=== CORPUS LEGITIME GENERE AVEC SUCCES ===%s\n' "$CL_GRN" "$CL_RST"
printf '\nEtape suivante  : Phase 4.3 extraction des features\n'
printf '  python3 scripts/extract_features.py\n\n'
