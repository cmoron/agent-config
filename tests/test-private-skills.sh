#!/usr/bin/env bash

set -euo pipefail

# shellcheck source=tests/test-lib.sh
source "$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)/test-lib.sh"

new_test_home
trap cleanup_test_home EXIT

# Emplacement par defaut du depot prive, sous le home de test.
private="$HOME/src/agent-skills-private/skills"
mkdir -p "$private/private-demo"
cat >"$private/private-demo/SKILL.md" <<'EOF'
---
name: private-demo
description: Skill prive de test.
---
EOF

"$TEST_ROOT/install.sh" >/dev/null

assert_link_to "$HOME/.agents/skills/private-demo" "$private/private-demo"
assert_link_to "$HOME/.claude/skills/private-demo" "$private/private-demo"
assert_link_to "$HOME/.claude/skills/api-design" "$TEST_ROOT/shared/skills/api-design"

# Un skill retire du depot prive perd ses liens.
rm -r "$private/private-demo"
"$TEST_ROOT/install.sh" >/dev/null
assert_not_exists "$HOME/.agents/skills/private-demo"
assert_not_exists "$HOME/.claude/skills/private-demo"

# Un nom deja pris par agent-config fait echouer l'installation.
mkdir -p "$private/api-design"
cp "$TEST_ROOT/shared/skills/api-design/SKILL.md" "$private/api-design/SKILL.md"
if "$TEST_ROOT/install.sh" >"$TEST_TMP/collision.out" 2>&1; then
  printf '%s\n' 'private skill collision was accepted' >&2
  exit 1
fi
grep -q 'shared skill collision: api-design' "$TEST_TMP/collision.out"
rm -r "$private/api-design"

# Un autre emplacement se declare par variable d'environnement.
other="$TEST_TMP/elsewhere/skills"
mkdir -p "$other/other-demo"
sed 's/private-demo/other-demo/' >"$other/other-demo/SKILL.md" <<'EOF'
---
name: private-demo
description: Skill prive de test.
---
EOF
AGENT_CONFIG_PRIVATE_SKILLS="$other" "$TEST_ROOT/install.sh" --only claude >/dev/null
assert_link_to "$HOME/.claude/skills/other-demo" "$other/other-demo"

printf '%s\n' 'private skills tests: PASS'
