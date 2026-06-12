#!/usr/bin/env bash
# Correction automatique indicative - Activité C-PRO Linux Debian 13
# Usage conseillé : bash check_cpro_linux_debian13.sh
# Option : EXPECTED_USER=ciel EXPECTED_HOSTNAME=ciel-linux bash check_cpro_linux_debian13.sh
set -u

EXPECTED_USER="${EXPECTED_USER:-ciel}"
EXPECTED_HOSTNAME="${EXPECTED_HOSTNAME:-ciel-linux}"
EXPECTED_BASE_NAME="${EXPECTED_BASE_NAME:-AP_CPRO_LINUX}"
MAX=100
SCORE=0
WARNINGS=0

OK_ITEMS=()
BAD_ITEMS=()
INFO_ITEMS=()

add_ok() {
  local pts="$1" msg="$2"
  SCORE=$((SCORE + pts))
  OK_ITEMS+=("[OK] +${pts} - ${msg}")
}

add_bad() {
  local msg="$1"
  BAD_ITEMS+=("[--] 0 - ${msg}")
  WARNINGS=$((WARNINGS + 1))
}

add_info() {
  INFO_ITEMS+=("[INFO] ${1}")
}

has_cmd() { command -v "$1" >/dev/null 2>&1; }

section() {
  printf '\n=== %s ===\n' "$1"
}

# Détection du dossier élève.
if [[ "${1:-}" != "" ]]; then
  STUDENT_HOME="$1"
elif [[ -d "/home/${EXPECTED_USER}/${EXPECTED_BASE_NAME}" ]]; then
  STUDENT_HOME="/home/${EXPECTED_USER}"
elif [[ -d "${HOME}/${EXPECTED_BASE_NAME}" ]]; then
  STUDENT_HOME="$HOME"
else
  # Dernière tentative : chercher un dossier AP_CPRO_LINUX dans /home.
  FOUND_BASE="$(find /home -maxdepth 2 -type d -name "$EXPECTED_BASE_NAME" 2>/dev/null | head -n 1 || true)"
  if [[ -n "$FOUND_BASE" ]]; then
    STUDENT_HOME="$(dirname "$FOUND_BASE")"
  else
    STUDENT_HOME="$HOME"
  fi
fi

BASE="${STUDENT_HOME}/${EXPECTED_BASE_NAME}"
SCRIPT="$BASE/bin/audit_post_install.sh"
LOGFILE="$BASE/donnees/auth-sample.log"
INVFILE="$BASE/donnees/inventaire.csv"
FICHE="$BASE/config/fiche_poste.txt"
CHECKLIST="$BASE/config/checklist_installation.txt"

printf 'Correction automatique indicative - C-PRO Linux Debian 13\n'
printf 'Utilisateur attendu : %s\n' "$EXPECTED_USER"
printf 'Hostname attendu    : %s\n' "$EXPECTED_HOSTNAME"
printf 'Dossier évalué      : %s\n' "$BASE"
printf '----------------------------------------\n'

# 1. Installation et système - 20 pts
section "1. Installation et système"
if [[ -r /etc/os-release ]] && grep -qi '^ID=debian' /etc/os-release; then
  if grep -Eq '^VERSION_ID="?13"?' /etc/os-release; then
    add_ok 6 "Debian 13 détecté"
  else
    add_ok 3 "Debian détecté, mais version 13 non confirmée"
    add_bad "Version Debian attendue : 13"
  fi
else
  add_bad "Système Debian non confirmé dans /etc/os-release"
fi

CURRENT_HOST="$(hostname 2>/dev/null || true)"
if [[ "$CURRENT_HOST" == "$EXPECTED_HOSTNAME" ]]; then
  add_ok 4 "hostname conforme : $CURRENT_HOST"
else
  add_bad "hostname non conforme : actuel='$CURRENT_HOST', attendu='$EXPECTED_HOSTNAME'"
fi

if id "$EXPECTED_USER" >/dev/null 2>&1; then
  add_ok 3 "compte utilisateur attendu présent : $EXPECTED_USER"
else
  add_bad "compte utilisateur attendu absent : $EXPECTED_USER"
fi

if [[ "$(id -u)" -eq 0 && -r /etc/shadow ]]; then
  ROOT_SHADOW="$(awk -F: '$1=="root" {print $2}' /etc/shadow 2>/dev/null || true)"
  if [[ -n "$ROOT_SHADOW" && "$ROOT_SHADOW" != "!" && "$ROOT_SHADOW" != "*" && "$ROOT_SHADOW" != '!*' ]]; then
    add_ok 2 "compte root actif détecté"
  else
    add_bad "compte root désactivé ou non vérifiable dans /etc/shadow"
  fi
else
  add_info "mot de passe root non vérifiable sans exécution en root ; aucun point retiré automatiquement"
  add_ok 2 "vérification root ignorée proprement"
fi

if has_cmd systemctl && systemctl is-active --quiet ssh 2>/dev/null; then
  add_ok 3 "service SSH actif"
elif has_cmd sshd || [[ -x /usr/sbin/sshd ]]; then
  add_ok 1 "OpenSSH semble installé, mais le service SSH n'est pas confirmé actif"
  add_bad "service SSH à activer ou vérifier : systemctl status ssh"
else
  add_bad "OpenSSH Server non détecté"
fi

NON_LOOP_IP="$(ip -o -4 addr show scope global 2>/dev/null | awk '{print $4}' | head -n 1 || true)"
DEFAULT_ROUTE="$(ip route show default 2>/dev/null | head -n 1 || true)"
DNS_LINE="$(grep -E '^nameserver[[:space:]]+' /etc/resolv.conf 2>/dev/null | head -n 1 || true)"
if [[ -n "$NON_LOOP_IP" && -n "$DEFAULT_ROUTE" && -n "$DNS_LINE" ]]; then
  add_ok 2 "réseau IPv4, route par défaut et DNS visibles"
else
  add_bad "réseau incomplet : IPv4='$NON_LOOP_IP', route='$DEFAULT_ROUTE', DNS='$DNS_LINE'"
fi

# 2. Arborescence et fichiers - 20 pts
section "2. Arborescence et fichiers"
if [[ -d "$BASE" ]]; then
  add_ok 3 "dossier de travail présent : $BASE"
else
  add_bad "dossier de travail absent : $BASE"
fi

DIR_POINTS=0
for d in bin config donnees preuves rapports archives; do
  if [[ -d "$BASE/$d" ]]; then
    DIR_POINTS=$((DIR_POINTS + 1))
  else
    add_bad "dossier manquant : $BASE/$d"
  fi
done
if (( DIR_POINTS == 6 )); then
  add_ok 6 "arborescence complète"
elif (( DIR_POINTS >= 4 )); then
  add_ok 3 "arborescence partielle : ${DIR_POINTS}/6 dossiers"
else
  add_bad "arborescence très incomplète : ${DIR_POINTS}/6 dossiers"
fi

FILE_POINTS=0
for f in "$FICHE" "$CHECKLIST" "$INVFILE" "$LOGFILE"; do
  if [[ -f "$f" ]]; then
    FILE_POINTS=$((FILE_POINTS + 1))
  else
    add_bad "fichier attendu absent : $f"
  fi
done
if (( FILE_POINTS == 4 )); then
  add_ok 4 "fichiers texte demandés présents"
elif (( FILE_POINTS >= 2 )); then
  add_ok 2 "fichiers texte partiellement présents"
else
  add_bad "fichiers texte demandés absents ou presque"
fi

if [[ -f "$FICHE" ]] && grep -Eqi 'Nom|Pr.nom|Poste|Hostname|Utilisateur|SSH' "$FICHE"; then
  add_ok 2 "fiche poste renseignée avec les champs attendus"
else
  add_bad "fiche poste absente ou trop peu renseignée"
fi

if [[ -f "$CHECKLIST" ]] && grep -Eqi 'Debian|hostname|SSH|r.seau|rapport|script' "$CHECKLIST"; then
  add_ok 2 "checklist installation exploitable"
else
  add_bad "checklist installation absente ou non exploitable"
fi

if [[ -f "$INVFILE" ]] && grep -Eq 'type;nom;role;etat' "$INVFILE" && grep -Eq 'ciel-linux|ssh|AP_CPRO_LINUX' "$INVFILE"; then
  add_ok 2 "inventaire CSV conforme ou très proche"
else
  add_bad "inventaire CSV absent ou contenu non conforme"
fi

if [[ -f "$LOGFILE" ]]; then
  FAIL_COUNT="$(grep -c 'Failed password' "$LOGFILE" || true)"
  IP1_COUNT="$(grep 'Failed password' "$LOGFILE" | grep -c '203\.0\.113\.10' || true)"
  IP2_COUNT="$(grep 'Failed password' "$LOGFILE" | grep -c '198\.51\.100\.23' || true)"
  if [[ "$FAIL_COUNT" -eq 7 && "$IP1_COUNT" -eq 3 && "$IP2_COUNT" -eq 3 ]]; then
    add_ok 1 "fichier auth-sample.log conforme : échecs et IP attendues"
  else
    add_bad "auth-sample.log non conforme : Failed=$FAIL_COUNT, 203.0.113.10=$IP1_COUNT, 198.51.100.23=$IP2_COUNT"
  fi
fi

# 3. Droits et permissions - 15 pts
section "3. Droits et permissions"
perm_of() { stat -c '%a' "$1" 2>/dev/null || echo 'NA'; }

if [[ -d "$BASE/bin" && "$(perm_of "$BASE/bin")" =~ ^7[0-5][0-5]$|^755$ ]]; then
  add_ok 2 "droits du dossier bin corrects ou acceptables"
else
  add_bad "droits du dossier bin inattendus : $(perm_of "$BASE/bin")"
fi

if [[ -d "$BASE/rapports" && "$(perm_of "$BASE/rapports")" == "700" ]]; then
  add_ok 2 "dossier rapports en 700"
else
  add_bad "dossier rapports attendu en 700, actuel : $(perm_of "$BASE/rapports")"
fi

if [[ -d "$BASE/archives" && "$(perm_of "$BASE/archives")" == "700" ]]; then
  add_ok 2 "dossier archives en 700"
else
  add_bad "dossier archives attendu en 700, actuel : $(perm_of "$BASE/archives")"
fi

if [[ -f "$LOGFILE" && "$(perm_of "$LOGFILE")" == "600" ]]; then
  add_ok 3 "auth-sample.log en 600"
else
  add_bad "auth-sample.log attendu en 600, actuel : $(perm_of "$LOGFILE")"
fi

PUBLIC_FILES_OK=0
for f in "$FICHE" "$CHECKLIST" "$INVFILE"; do
  if [[ -f "$f" && "$(perm_of "$f")" == "644" ]]; then
    PUBLIC_FILES_OK=$((PUBLIC_FILES_OK + 1))
  fi
done
if (( PUBLIC_FILES_OK == 3 )); then
  add_ok 3 "fichiers texte principaux en 644"
elif (( PUBLIC_FILES_OK >= 1 )); then
  add_ok 1 "certains fichiers texte sont en 644"
  add_bad "tous les fichiers fiche/checklist/inventaire devraient être en 644"
else
  add_bad "droits 644 non observés sur les fichiers texte principaux"
fi

if [[ -x "$SCRIPT" ]]; then
  add_ok 3 "script audit_post_install.sh exécutable"
else
  add_bad "script non exécutable ou absent : $SCRIPT"
fi

# 4. Script Bash - 25 pts
section "4. Script Bash"
if [[ -f "$SCRIPT" ]]; then
  add_ok 2 "script présent"
  if bash -n "$SCRIPT" 2>/tmp/check_cpro_bashn.err; then
    add_ok 5 "syntaxe Bash valide"
  else
    add_bad "erreur de syntaxe Bash : $(tr '\n' ' ' </tmp/check_cpro_bashn.err | cut -c1-180)"
  fi

  SCRIPT_TEXT="$(cat "$SCRIPT" 2>/dev/null || true)"
  for token in 'BASE=' 'RAPPORT=' 'LOG=' 'SEUIL='; do
    if grep -q "$token" "$SCRIPT"; then
      add_ok 1 "variable détectée dans le script : $token"
    else
      add_bad "variable attendue absente dans le script : $token"
    fi
  done

  if grep -Eq '\[\[.*-r.*\$?LOG|test .* -r .*\$?LOG' "$SCRIPT"; then
    add_ok 3 "test de présence/lecture du fichier de log"
  else
    add_bad "test de lecture du fichier de log absent ou non détecté"
  fi

  REQUIRED_CMDS=(date hostname whoami uname df free ip find stat grep awk sort uniq sha256sum)
  CMD_COUNT=0
  for c in "${REQUIRED_CMDS[@]}"; do
    if grep -Eq "(^|[^A-Za-z0-9_])${c}([^A-Za-z0-9_]|$)" "$SCRIPT"; then
      CMD_COUNT=$((CMD_COUNT + 1))
    fi
  done
  if (( CMD_COUNT >= 11 )); then
    add_ok 5 "commandes système/réseau/fichiers largement utilisées (${CMD_COUNT}/${#REQUIRED_CMDS[@]})"
  elif (( CMD_COUNT >= 7 )); then
    add_ok 3 "commandes attendues partiellement utilisées (${CMD_COUNT}/${#REQUIRED_CMDS[@]})"
    add_bad "certaines commandes attendues manquent dans le script"
  else
    add_bad "trop peu de commandes attendues dans le script (${CMD_COUNT}/${#REQUIRED_CMDS[@]})"
  fi

  if grep -Eq 'Failed password' "$SCRIPT" && grep -Eq 'from' "$SCRIPT" && grep -Eq 'ALERTE|SEUIL|seuil' "$SCRIPT"; then
    add_ok 4 "analyse des logs SSH prévue dans le script"
  else
    add_bad "analyse des logs SSH insuffisamment détectée dans le script"
  fi
else
  add_bad "script absent : impossible de contrôler la syntaxe et les commandes"
fi

# 5. Exécution et rapport généré - 20 pts
section "5. Exécution et rapport"
REPORT=""
if [[ -f "$SCRIPT" ]]; then
  RUN_OK=0
  if [[ "$(id -u)" -eq 0 && "$STUDENT_HOME" == "/home/${EXPECTED_USER}" ]] && id "$EXPECTED_USER" >/dev/null 2>&1; then
    if timeout 20 su -s /bin/bash "$EXPECTED_USER" -c "bash '$SCRIPT'" >/tmp/check_cpro_run.out 2>/tmp/check_cpro_run.err; then
      RUN_OK=1
    fi
  else
    if timeout 20 bash "$SCRIPT" >/tmp/check_cpro_run.out 2>/tmp/check_cpro_run.err; then
      RUN_OK=1
    fi
  fi

  if (( RUN_OK == 1 )); then
    add_ok 4 "script exécuté sans erreur bloquante"
  else
    add_bad "script non exécuté correctement : $(tr '\n' ' ' </tmp/check_cpro_run.err | cut -c1-180)"
  fi

  REPORT="$(find "$BASE/rapports" -type f \( -name 'rapport*.txt' -o -name '*rapport*.txt' \) -printf '%T@ %p\n' 2>/dev/null | sort -n | tail -n 1 | cut -d' ' -f2- || true)"
fi

if [[ -n "$REPORT" && -f "$REPORT" ]]; then
  add_ok 3 "rapport généré trouvé : $REPORT"
else
  add_bad "aucun rapport généré trouvé dans $BASE/rapports"
fi

if [[ -n "$REPORT" && -f "$REPORT" ]]; then
  SECTION_COUNT=0
  for sec in IDENTITE INSTALLATION SYSTEME RESEAU FICHIERS LOGS_SSH SYNTHESE; do
    if grep -Eqi "=== *${sec} *===" "$REPORT"; then
      SECTION_COUNT=$((SECTION_COUNT + 1))
    else
      add_bad "section absente du rapport : $sec"
    fi
  done
  if (( SECTION_COUNT == 7 )); then
    add_ok 5 "sections principales du rapport présentes"
  elif (( SECTION_COUNT >= 5 )); then
    add_ok 3 "rapport partiel : ${SECTION_COUNT}/7 sections principales"
  else
    add_bad "rapport très incomplet : ${SECTION_COUNT}/7 sections principales"
  fi

  if grep -Eqi 'Debian|VERSION_ID|PRETTY_NAME|Noyau|Linux' "$REPORT"; then
    add_ok 2 "installation documentée dans le rapport"
  else
    add_bad "installation non documentée dans le rapport"
  fi

  if grep -Eqi 'default via|nameserver|ip -br|127\.0\.0\.1|1\.1\.1\.1|RESEAU|Routes|DNS' "$REPORT"; then
    add_ok 2 "réseau et tests documentés dans le rapport"
  else
    add_bad "réseau ou tests insuffisamment documentés dans le rapport"
  fi

  if grep -Eq '203\.0\.113\.10' "$REPORT" && grep -Eq '198\.51\.100\.23' "$REPORT" && grep -Eqi 'ALERTE|seuil|suspect' "$REPORT"; then
    add_ok 3 "IP suspectes et notion d'alerte visibles dans le rapport"
  else
    add_bad "analyse d'IP suspectes absente ou incomplète dans le rapport"
  fi

  if grep -Eqi 'sha256|stat|permissions|droits|[0-7]{3} .*AP_CPRO_LINUX' "$REPORT"; then
    add_ok 1 "preuves fichiers/permissions ou empreintes visibles"
  else
    add_bad "preuves fichiers/permissions ou empreintes absentes"
  fi
else
  add_bad "rapport absent : impossible d'évaluer son contenu"
fi

# Synthèse
section "Résultat"
for line in "${OK_ITEMS[@]}"; do printf '%s\n' "$line"; done
for line in "${BAD_ITEMS[@]}"; do printf '%s\n' "$line"; done
for line in "${INFO_ITEMS[@]}"; do printf '%s\n' "$line"; done

if (( SCORE > MAX )); then SCORE=$MAX; fi
NOTE20=$(( (SCORE * 20 + 50) / 100 ))
printf '\nScore indicatif : %s/%s, soit environ %s/20\n' "$SCORE" "$MAX" "$NOTE20"
printf 'Points à contrôler manuellement : qualité de la synthèse, autonomie observée, exactitude des mots de passe imposés.\n'
printf 'Nombre de points à revoir : %s\n' "$WARNINGS"

if (( SCORE >= 85 )); then
  printf 'Niveau C-PRO proposé : Très satisfaisant\n'
elif (( SCORE >= 65 )); then
  printf 'Niveau C-PRO proposé : Satisfaisant\n'
elif (( SCORE >= 40 )); then
  printf 'Niveau C-PRO proposé : Fragile\n'
else
  printf 'Niveau C-PRO proposé : Insuffisant\n'
fi
