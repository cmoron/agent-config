// Verification minimale des fonctions pures de la barre d'etat : bun test ./tests/pi-statusline.test.ts
import { expect, test } from "bun:test";
import { compact, level, quotaPercent, shortPath } from "../harnesses/pi/extensions/statusline.ts";

test("quotaPercent lit une fraction ou un pourcentage, ignore l'absent", () => {
	expect(quotaPercent("0.42")).toBeCloseTo(42);
	expect(quotaPercent("1")).toBe(100);
	expect(quotaPercent("57")).toBe(57);
	expect(quotaPercent(undefined)).toBeUndefined();
	expect(quotaPercent("")).toBeUndefined();
	expect(quotaPercent("abc")).toBeUndefined();
});

test("level, compact et shortPath", () => {
	expect([level(10), level(50), level(80)]).toEqual(["muted", "warning", "error"]);
	expect([compact(999), compact(120_400), compact(1_000_000)]).toEqual(["999", "120k", "1.0M"]);
	expect(shortPath("/home/c/src/x", "/home/c")).toBe("~/src/x");
	expect(shortPath("/home/c", "/home/c")).toBe("~");
	expect(shortPath("/home/cyril2/x", "/home/c")).toBe("/home/cyril2/x");
	expect(shortPath("/home/c/src/org/repo/pkg", "/home/c")).toBe("…/repo/pkg");
	expect(shortPath("/private/tmp/a/b/c/d", "/home/c")).toBe("…/c/d");
});
