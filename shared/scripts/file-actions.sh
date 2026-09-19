#!/usr/bin/env bash
# Actions partagees, a sourcer depuis les adaptateurs deployes (docs/hooks.md).
# Le chargement definit seulement les fonctions ; l'adaptateur active son mode
# shell strict, valide l'entree, choisit le cwd puis appelle l'action voulue.

# Lit stdin jusqu'a EOF et exige un unique objet JSON, sans valider ses champs.
# Emet cet objet en JSON compact sur stdout pour les fonctions suivantes.
# Retour : 0 si valide ; 2 avec diagnostic stderr si parsing/type/cardinalite
# invalide ou si jq echoue. Aucune lecture ni modification de fichier.
read_hook_input() {
  jq -ces 'select(length == 1) | .[0] | select(type == "object")' || {
    printf '%s\n' 'hook: expected one JSON object on stdin' >&2
    return 2
  }
}

# $1 : objet JSON deja valide par read_hook_input (protocole Claude/Kimi).
# Emet tool_input.file_path brut sur stdout : chaine non vide, sans caracteres
# de controle. Ne resout pas le chemin et ne verifie pas son existence.
# Retour : 0 si valide ; 2 avec diagnostic stderr sinon.
read_file_path() {
  jq -er '.tool_input.file_path | select(type == "string" and length > 0)
    | select(test("[[:cntrl:]]") | not)' <<<"$1" || {
    printf '%s\n' 'hook: expected a nonempty tool_input.file_path without control characters' >&2
    return 2
  }
}

# $1 : objet JSON deja valide par read_hook_input.
# Change le repertoire du shell appelant vers cwd, ou conserve le repertoire
# courant si ce champ est absent. Un cwd relatif part du repertoire courant.
# A appeler avant les actions de fichiers ; le repertoire n'est pas restaure.
# Retour : 0 apres cd ; 2 avec diagnostic stderr si cwd est invalide/inaccessible.
change_hook_directory() {
  local directory
  directory=$(jq -er '(if has("cwd") then .cwd else "." end)
    | select(type == "string" and length > 0)
    | select(test("[[:cntrl:]]") | not)' <<<"$1") || {
    printf '%s\n' 'hook: invalid cwd' >&2
    return 2
  }
  cd -- "$directory" || return 2
}

# $@ : chemins deja valides par l'adaptateur, un argument par fichier.
# Refuse le premier basename .env ou .env.* (dont .env.example), sans toucher
# au disque. Ce controle lexical ne suit pas les symlinks et n'est pas une sandbox.
# Retour : 0 si aucun nom protege ; 2 avec diagnostic stderr au premier refus.
# Stdout reste vide ; une liste vide est acceptee.
protect_files() {
  local file
  for file in "$@"; do
    case "${file##*/}" in
      .env|.env.*)
        printf 'Fichier protege : %s\nModifie-le manuellement si necessaire.\n' "$file" >&2
        return 2
        ;;
    esac
  done
}

# $@ : chemins deja valides, relatifs au cwd choisi ou absolus.
# Modifie les fichiers existants en place selon leur extension ; pour Python,
# ruff check --fix peut aussi corriger du code apres ruff format.
# Fichier absent/extension inconnue : ignore. Outil absent : diagnostic stderr,
# puis poursuite. Les outils sont cherches sur PATH, sans installation implicite.
# Retour : 0 si traite/ignore ; premier code d'echec d'un outil sinon. Ses sorties
# vont sur stderr et les modifications deja faites ne sont pas annulees.
# Un retour 0 ne certifie donc ni le formatage de tous les fichiers ni le lint.
format_files() {
  local file extension
  local -a formatter
  for file in "$@"; do
    [ -f "$file" ] || continue
    # Absolute paths also keep leading '-' filenames out of CLI option parsing.
    case "$file" in /*) ;; *) file="$PWD/$file" ;; esac
    extension="${file##*.}"
    case "$extension" in
      py) formatter=(ruff format --quiet) ;;
      rs) formatter=(rustfmt --edition 2021) ;;
      ts|tsx|js|jsx|json|jsonc|css) formatter=(biome format --write) ;;
      html|md|yaml|yml) formatter=(prettier --write --log-level silent) ;;
      *) continue ;;
    esac
    if ! command -v "${formatter[0]}" >/dev/null 2>&1; then
      printf 'hook: %s unavailable; skipped %s\n' "${formatter[0]}" "$file" >&2
      continue
    fi
    "${formatter[@]}" "$file" >&2 || return $?
    if [ "$extension" = py ]; then
      ruff check --fix --quiet "$file" >&2 || return $?
    fi
  done
}
