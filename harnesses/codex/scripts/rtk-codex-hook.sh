#!/usr/bin/env bash

set -euo pipefail

# rtk emet le schema Claude (hookSpecificOutput.updatedInput) ; Codex exige en
# plus permissionDecision:"allow", sinon il rejette la reecriture.
command -v rtk >/dev/null 2>&1 || exit 0
command -v jq >/dev/null 2>&1 || exit 0

rtk hook claude | jq -c '.hookSpecificOutput += {"permissionDecision":"allow"}'
