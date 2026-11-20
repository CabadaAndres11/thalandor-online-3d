// Shared look of the equipment (v1 make_gear.mjs and v2 make_gear_v2.mjs): the palette,
// the materials of each armor kind and tier, each class's colors at tiers 2 and 3, and the
// weapon materials per tier. Kept in one place so both resolutions stay the same sets.
import { SHADE, LIGHT, TINT_PRIMARY, TINT_SECONDARY, GLOW } from "./vox.mjs";

export const P = TINT_PRIMARY, S = TINT_SECONDARY;

// --- Palette (indices 60+ are this file's own; GLOW is unshaded) ----------------------
export const C = {
  IRON: 60, IRON_D: 61, IRON_L: 62, STEEL: 63, STEEL_D: 64, STEEL_L: 65, DARK: 66, DARK_D: 67, DARK_L: 68,
  GOLD: 69, GOLD_D: 70, GOLD_L: 71, BRONZE: 72, BRONZE_D: 73, LEATHER: 74, LEATHER_D: 75, LEATHER_L: 76,
  BLACK_LEATHER: 77, BLACK_LEATHER_D: 78, CHAIN: 79, CHAIN_D: 80, CHAIN_L: 81, WOOD: 82, WOOD_D: 83,
  EBONY: 84, EBONY_D: 85, RED: 86, RED_D: 87, BLUE: 88, GEM: 89, PAPER: 90, PAPER_D: 91, STRING: 92,
  WHITE: 93, CRYSTAL: 94, CRYSTAL_D: 95,
  // A class's own colors at tiers 2 and 3 (set per piece, see TIER_COLORS).
  X_B: 100, X_D: 101, X_L: 102, X_T: 103, X_T2: 104, X_T2_D: 105,
};
export const PALETTE = {
  [C.IRON]: "#8a8f96", [C.IRON_D]: "#5c6168", [C.IRON_L]: "#b3b8be",
  [C.STEEL]: "#c3cbd4", [C.STEEL_D]: "#838c97", [C.STEEL_L]: "#eef2f6",
  [C.DARK]: "#3d4250", [C.DARK_D]: "#262935", [C.DARK_L]: "#5d6474",
  [C.GOLD]: "#d6ae4c", [C.GOLD_D]: "#9c7a2c", [C.GOLD_L]: "#f2d27e",
  [C.BRONZE]: "#b07a3e", [C.BRONZE_D]: "#7c5328",
  [C.LEATHER]: "#6b4a2b", [C.LEATHER_D]: "#47301b", [C.LEATHER_L]: "#8c6440",
  [C.BLACK_LEATHER]: "#2f2a2c", [C.BLACK_LEATHER_D]: "#1c191b",
  [C.CHAIN]: "#9aa2ac", [C.CHAIN_D]: "#646b74", [C.CHAIN_L]: "#c5ccd4",
  [C.WOOD]: "#7a5531", [C.WOOD_D]: "#4f361e", [C.EBONY]: "#2a2220", [C.EBONY_D]: "#171211",
  [C.RED]: "#a8262a", [C.RED_D]: "#6e1418", [C.BLUE]: "#3c63c8", [C.GEM]: "#d33a4a",
  [C.PAPER]: "#e9dcb8", [C.PAPER_D]: "#b9a67a", [C.STRING]: "#e6dfcc", [C.WHITE]: "#f2efe6",
  [C.CRYSTAL]: "#8fd8ff", [C.CRYSTAL_D]: "#4f9ccf", [GLOW]: "#9fe0ff",
};

// Body part boxes, in voxels from each part's pivot (see make_humans.mjs).
export const BOX = {
  head: [-4, 0, -5, 3, 9, 3], torso: [-6, 0, -4, 5, 11, 3], hips: [-5, -2, -3, 4, 3, 2],
  arm: [-2, -9, -2, 1, 0, 1], fore: [-2, -8, -2, 1, 0, 1], hand: [-2, -4, -2, 1, 0, 1],
  thigh: [-2, -10, -2, 2, 0, 2], shin: [-2, -12, -2, 2, 0, 2],
};

// Materials of an armor kind at a tier: base (with dark and light), trim, accent, runes.
export function mats(kind, tier) {
  const t3 = tier >= 3;
  switch (kind) {
    case "cloth":
      return { b: P, d: SHADE(P), l: LIGHT(P), trim: S, acc: tier >= 2 ? C.GOLD : S, rune: t3 ? GLOW : null, gem: t3 ? C.GEM : C.GOLD };
    case "leather":
      return tier === 1 ? { b: C.LEATHER, d: C.LEATHER_D, l: C.LEATHER_L, trim: S, acc: C.BRONZE, rune: null, gem: C.BRONZE }
        : tier === 2 ? { b: C.LEATHER_D, d: C.BLACK_LEATHER, l: C.LEATHER, trim: S, acc: C.BRONZE, rune: null, gem: C.GOLD }
        : { b: C.BLACK_LEATHER, d: C.BLACK_LEATHER_D, l: C.LEATHER_D, trim: S, acc: C.GOLD, rune: GLOW, gem: C.GEM };
    case "mail":
      return tier === 1 ? { b: C.CHAIN, d: C.CHAIN_D, l: C.CHAIN_L, trim: C.LEATHER, acc: C.IRON, rune: null, gem: C.IRON }
        : tier === 2 ? { b: C.CHAIN, d: C.CHAIN_D, l: C.CHAIN_L, trim: S, acc: C.BRONZE, rune: null, gem: C.GOLD }
        : { b: C.CHAIN_D, d: C.DARK, l: C.CHAIN, trim: S, acc: C.GOLD, rune: GLOW, gem: C.GEM };
    default: // plate
      return tier === 1 ? { b: C.IRON, d: C.IRON_D, l: C.IRON_L, trim: C.IRON_D, acc: C.LEATHER, rune: null, gem: C.IRON_L }
        : tier === 2 ? { b: C.STEEL, d: C.STEEL_D, l: C.STEEL_L, trim: C.GOLD, acc: C.GOLD, rune: null, gem: C.GOLD_L }
        : { b: C.DARK, d: C.DARK_D, l: C.DARK_L, trim: C.GOLD, acc: C.GOLD_L, rune: GLOW, gem: C.GEM };
  }
}

// Tiers 2 and 3 leave the class tints for colors of their own, more striking each time:
// base (and its dark and light), trim, second trim (capes, sashes) and the glow of runes
// and auras. Tier 1 keeps the wearer's colors.
export const TIER_COLORS = {
  warrior: {
    2: { b: "#c9d1da", d: "#8a94a0", l: "#f2f5f8", t: "#d6ae4c", t2: "#a3212b", glow: "#ffd27a" },
    3: { b: "#363a49", d: "#1f212b", l: "#5d6577", t: "#e8c25a", t2: "#b3202a", glow: "#ff7a2a" },
  },
  cleric: {
    2: { b: "#f3eee0", d: "#c9c0a8", l: "#ffffff", t: "#d9b04a", t2: "#3c6fd0", glow: "#ffe9a0" },
    3: { b: "#fbf3da", d: "#d8c58f", l: "#fffdf5", t: "#f0c84a", t2: "#2f5fc4", glow: "#fff1b0" },
  },
  mage: {
    2: { b: "#2b3f8f", d: "#1b2860", l: "#4560b8", t: "#d3dae6", t2: "#7b3fc4", glow: "#9fd0ff" },
    3: { b: "#1e1530", d: "#120c1e", l: "#3a2a5a", t: "#e0b84a", t2: "#9b4fe8", glow: "#c07bff" },
  },
  archer: {
    2: { b: "#3f6b35", d: "#2a4a23", l: "#5c8f4d", t: "#b07a3e", t2: "#6b4a2b", glow: "#c8ff9a" },
    3: { b: "#1f6b4a", d: "#124430", l: "#3a9a6e", t: "#e0b84a", t2: "#4a3020", glow: "#6dffb0" },
  },
  assassin: {
    2: { b: "#222128", d: "#141317", l: "#3a3842", t: "#a8262a", t2: "#b8bec8", glow: "#ff6070" },
    3: { b: "#17131f", d: "#0b0910", l: "#2f2840", t: "#c81e3a", t2: "#d6ae4c", glow: "#ff3355" },
  },
};

// The palette of a class's pieces at a tier (its colors in the X_* slots, its glow).
export function tierPalette(cls, t) {
  const c = TIER_COLORS[cls][t];
  if (!c) return PALETTE;
  const dark = (hex) => "#" + hex.slice(1).match(/../g).map((h) => Math.round(parseInt(h, 16) * 0.65).toString(16).padStart(2, "0")).join("");
  return { ...PALETTE, [C.X_B]: c.b, [C.X_D]: c.d, [C.X_L]: c.l, [C.X_T]: c.t, [C.X_T2]: c.t2, [C.X_T2_D]: dark(c.t2), [GLOW]: c.glow };
}

// The armor of each class: its kind (the shape of its pieces) and its materials.
export const CLASS_SETS = {
  warrior: { kind: "plate" }, cleric: { kind: "cloth" }, mage: { kind: "cloth" },
  archer: { kind: "mail" }, assassin: { kind: "leather" },
};
export function cmats(cls, t) {
  const m = mats(CLASS_SETS[cls].kind, t);
  if (t >= 2) {
    const x = { b: C.X_B, d: C.X_D, l: C.X_L, trim: C.X_T, acc: C.X_T, alt: C.X_T2, alt_d: C.X_T2_D, hood: C.X_B, gem: t >= 3 ? C.GEM : C.GOLD_L, rune: t >= 3 ? GLOW : null };
    // The Archer's mail stays metal; its colors go to the hood, trim and cloak.
    return cls === "archer" ? { ...x, b: C.CHAIN, d: C.CHAIN_D, l: C.CHAIN_L, trim: C.X_B } : x;
  }
  switch (cls) {
    case "warrior": return { ...m, trim: t === 1 ? S : m.trim, acc: t === 1 ? S : m.acc };
    case "cleric": return { ...m, acc: C.GOLD, gem: t >= 3 ? C.GEM : C.GOLD_L };
    case "archer": return { ...m, trim: P, acc: t === 1 ? C.LEATHER : m.acc };
    case "assassin": return { ...m, b: P, d: SHADE(P), l: LIGHT(P), trim: S };
    default: return m;
  }
}


export function wmats(t) {
  return t === 1 ? { blade: C.IRON, edge: C.IRON_L, dark: C.IRON_D, guard: C.IRON_D, grip: C.LEATHER, wood: C.WOOD, wood_d: C.WOOD_D, gold: C.BRONZE, gem: C.IRON_L, rune: null, crystal: C.CRYSTAL }
    : t === 2 ? { blade: C.STEEL, edge: C.STEEL_L, dark: C.STEEL_D, guard: C.GOLD, grip: C.LEATHER_D, wood: C.WOOD_D, wood_d: C.EBONY, gold: C.GOLD, gem: C.GEM, rune: null, crystal: C.CRYSTAL }
    : { blade: C.DARK_L, edge: GLOW, dark: C.DARK, guard: C.GOLD, grip: C.RED_D, wood: C.EBONY, wood_d: C.GOLD_D, gold: C.GOLD_L, gem: C.GEM, rune: GLOW, crystal: GLOW };
}
