// Chevron `>` a gauche de la zone de saisie, comme dans Claude Code.
import { CustomEditor, type ExtensionAPI } from "@earendil-works/pi-coding-agent";

const GUTTER = 2;
const ANSI = /\x1b\[[0-9;]*m/g;

class ChevronEditor extends CustomEditor {
	render(width: number): string[] {
		// L'editeur se dessine sur une largeur reduite ; la gouttiere est ajoutee apres,
		// donc le retour a la ligne et le curseur restent ceux de l'editeur natif.
		const lines = super.render(width - GUTTER);
		let chevronPlaced = false;
		return lines.map((line) => {
			if (line.replace(ANSI, "").startsWith("─")) return this.borderColor("─".repeat(GUTTER)) + line;
			if (chevronPlaced) return " ".repeat(GUTTER) + line;
			chevronPlaced = true;
			return `${this.borderColor(">")} ${line}`;
		});
	}
}

export default function chevronPrompt(pi: ExtensionAPI): void {
	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.setEditorComponent((tui, theme, keybindings) => new ChevronEditor(tui, theme, keybindings));
	});
}
