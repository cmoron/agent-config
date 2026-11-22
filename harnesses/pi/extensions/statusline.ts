// Barre d'etat : modele et effort, contexte, quota du forfait, branche, dossier.
// Remplace le pied de page natif ; les statuts des autres extensions (Un Bien...)
// restent affiches a droite.
import type { ExtensionAPI } from "@earendil-works/pi-coding-agent";
import { homedir } from "node:os";

// Fenetres de quota du forfait Claude, telles que pi-claude-bridge les expose
// dans les en-tetes `anthropic-ratelimit-unified-<fenetre>-utilization`.
const QUOTA_WINDOWS = ["5h", "7d"] as const;

type Level = "muted" | "warning" | "error";

export function level(percent: number): Level {
	if (percent >= 80) return "error";
	if (percent >= 50) return "warning";
	return "muted";
}

export function compact(tokens: number): string {
	if (tokens >= 1_000_000) return `${(tokens / 1_000_000).toFixed(1)}M`;
	if (tokens >= 1000) return `${Math.round(tokens / 1000)}k`;
	return String(tokens);
}

/** L'en-tete est une fraction (0.42) ; un pourcentage deja exprime est garde tel quel. */
export function quotaPercent(header: string | undefined): number | undefined {
	if (header === undefined || header === "") return undefined;
	const value = Number(header);
	if (!Number.isFinite(value)) return undefined;
	return value <= 1 ? value * 100 : value;
}

/** `~` pour le home, et seulement les deux derniers dossiers d'un chemin profond. */
export function shortPath(cwd: string, home: string): string {
	const path = cwd === home || cwd.startsWith(`${home}/`) ? `~${cwd.slice(home.length)}` : cwd;
	const segments = path.split("/");
	return segments.length > 4 ? `…/${segments.slice(-2).join("/")}` : path;
}

export default async function statusline(pi: ExtensionAPI): Promise<void> {
	// Import differe : les fonctions pures ci-dessus restent testables sans pi.
	const { truncateToWidth, visibleWidth } = await import("@earendil-works/pi-tui");
	const quota = new Map<string, number>();
	let requestRender = (): void => {};

	pi.on("after_provider_response", (event) => {
		for (const window of QUOTA_WINDOWS) {
			const percent = quotaPercent(event.headers[`anthropic-ratelimit-unified-${window}-utilization`]);
			if (percent !== undefined) quota.set(window, percent);
		}
		requestRender();
	});
	// Le quota affiche est celui du provider precedent : il se remplit au prochain appel.
	pi.on("model_select", () => {
		quota.clear();
		requestRender();
	});
	pi.on("thinking_level_select", () => requestRender());

	pi.on("session_start", (_event, ctx) => {
		if (!ctx.hasUI) return;
		ctx.ui.setFooter((tui, theme, footerData) => {
			requestRender = () => tui.requestRender();
			const unsubscribe = footerData.onBranchChange(requestRender);
			return {
				dispose() {
					unsubscribe();
					requestRender = () => {};
				},
				invalidate() {},
				render(width: number): string[] {
					const separator = theme.fg("dim", " │ ");
					const parts: string[] = [];

					const model = ctx.model ? ctx.model.id.replace(/^claude-/, "") : "aucun modele";
					parts.push(theme.fg("accent", model) + theme.fg("dim", ` ${pi.getThinkingLevel()}`));

					const usage = ctx.getContextUsage();
					if (usage?.percent != null && usage.tokens != null) {
						const text = `ctx ${Math.round(usage.percent)}% ${compact(usage.tokens)}/${compact(usage.contextWindow)}`;
						parts.push(theme.fg(level(usage.percent), text));
					}

					const quotas = QUOTA_WINDOWS.flatMap((window) => {
						const percent = quota.get(window);
						return percent === undefined ? [] : [theme.fg(level(percent), `${window} ${Math.round(percent)}%`)];
					});
					if (quotas.length > 0) parts.push(quotas.join(theme.fg("dim", " · ")));

					const branch = footerData.getGitBranch();
					if (branch) parts.push(theme.fg("success", ` ${branch}`));
					parts.push(theme.fg("muted", shortPath(ctx.cwd, homedir())));

					const left = parts.join(separator);
					const right = [...footerData.getExtensionStatuses().values()].join(" ");
					const gap = width - visibleWidth(left) - visibleWidth(right);
					// Trop etroit : la gauche prime, les statuts d'extensions sont coupes.
					const line = gap >= 1 ? left + " ".repeat(gap) + right : `${left} ${right}`;
					return [truncateToWidth(line, width)];
				},
			};
		});
	});
}
