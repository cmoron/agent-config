// Isole le Claude Code lance par pi-claude-bridge de la config personnelle.
//
// Le bridge charge toujours les reglages utilisateur de Claude Code : sans ceci,
// les hooks et plugins de ~/.claude (Superpowers, ponytail...) s'injectent dans
// pi avec les modeles Claude, et pas avec les autres providers. Un dossier de
// config dedie donne un Claude Code vierge. Il a son propre login :
//   CLAUDE_CONFIG_DIR=~/.pi/agent/claude-home claude auth login
//
// Le bridge et son process enfant lisent cette variable a chaque appel, donc
// l'ordre de chargement des extensions n'importe pas. Les commandes bash de pi
// en heritent aussi : un `claude` lance depuis pi utilise ce dossier.
import { homedir } from "node:os";
import { join } from "node:path";

export default function claudeCleanHome(): void {
	const agentDir = process.env.PI_CODING_AGENT_DIR ?? join(homedir(), ".pi", "agent");
	process.env.CLAUDE_CONFIG_DIR = join(agentDir, "claude-home");
}
