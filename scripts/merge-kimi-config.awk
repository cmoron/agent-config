# Fusion textuelle utilisee par render_kimi_config() dans install.sh.
# Usage : awk -f scripts/merge-kimi-config.awk source.toml runtime.toml > merged.toml
# Entree 1 : source declarative non vide, avec les deux cles et tables gerees.
# Entree 2 : config runtime existante, ou source une seconde fois pour initialiser.
# stdout : TOML fusionne ; aucune ecriture dans les entrees. Ne jamais rediriger
# vers un fichier d'entree : le shell le tronquerait avant la lecture par awk.
# L'installateur gere sauvegarde et remplacement ; awk remonte ses erreurs natives.
# Ce n'est pas un parseur TOML : les cles doivent commencer en colonne 1 et les
# en-tetes geres correspondre exactement aux formes reconnues ci-dessous.

# Emet puis vide le compteur global de lignes vides retenues. Aucun argument.
# Ce delai evite d'accumuler des lignes vides autour des tables remplacees.
function flush_pending_blanks() {
  while (pending_blanks > 0) {
    print ""
    pending_blanks--
  }
}

# Premier fichier : memoriser les valeurs imposees et les tables a reinstaller.
FNR == NR {
  if ($0 ~ /^default_permission_mode[[:space:]]*=/) {
    permission_line = $0
  }
  if ($0 ~ /^merge_all_available_skills[[:space:]]*=/) {
    skills_merge_line = $0
  }
  if ($0 == "[[permission.rules]]" || $0 == "[[hooks]]") {
    capture = 1
  } else if ($0 ~ /^\[\[?[^]]+\]\]?$/ && capture) {
    capture = 0
  }
  if (capture) {
    managed[++managed_count] = $0
  }
  next
}

# Second fichier : conserver les autres lignes runtime (modeles, providers...),
# remplacer les deux cles et retirer les anciennes tables gerees avec leur corps.
{
  if ($0 == "[[permission.rules]]" || $0 == "[[hooks]]") {
    pending_blanks = 0
    skip = 1
    next
  }
  if ($0 ~ /^\[\[?[^]]+\]\]?$/ && skip) {
    skip = 0
  }
  if (skip) {
    next
  }

  if ($0 == "") {
    pending_blanks++
    next
  }

  if ($0 ~ /^default_permission_mode[[:space:]]*=/) {
    if (!permission_written) {
      flush_pending_blanks()
      print permission_line
      permission_written = 1
    }
    next
  }

  if ($0 ~ /^merge_all_available_skills[[:space:]]*=/) {
    if (!skills_merge_written) {
      flush_pending_blanks()
      print skills_merge_line
      skills_merge_written = 1
    }
    next
  }

  # Inserer les cles absentes avant la premiere table pour les garder au top-level.
  if ($0 ~ /^\[\[?[^]]+\]\]?$/ && (!permission_written || !skills_merge_written)) {
    flush_pending_blanks()
    if (!permission_written) {
      print permission_line
      permission_written = 1
    }
    if (!skills_merge_written) {
      print skills_merge_line
      skills_merge_written = 1
    }
    print ""
  }
  flush_pending_blanks()
  print
}

# Completer les cles si aucune table n'a permis leur insertion, puis ajouter les
# tables declaratives. Les blancs finaux du runtime sont remplaces par un seul.
END {
  if (!permission_written) {
    print permission_line
  }
  if (!skills_merge_written) {
    print skills_merge_line
  }
  pending_blanks = 0
  print ""
  for (line_number = 1; line_number <= managed_count; line_number++) {
    print managed[line_number]
  }
}
