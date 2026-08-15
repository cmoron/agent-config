function flush_pending_blanks() {
  while (pending_blanks > 0) {
    print ""
    pending_blanks--
  }
}

FNR == NR {
  if ($0 ~ /^default_permission_mode[[:space:]]*=/) {
    permission_line = $0
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

  if ($0 ~ /^\[\[?[^]]+\]\]?$/ && !permission_written) {
    flush_pending_blanks()
    print permission_line
    print ""
    permission_written = 1
  }
  flush_pending_blanks()
  print
}

END {
  if (!permission_written) {
    print permission_line
  }
  pending_blanks = 0
  print ""
  for (line_number = 1; line_number <= managed_count; line_number++) {
    print managed[line_number]
  }
}
