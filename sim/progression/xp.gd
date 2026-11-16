class_name Xp
extends RefCounted
## Experience curve, monster rewards and level-ups (no nodes, no network).

const MAX_AMOUNT := 2_000_000_000


static func _f(b: Balance, key: String) -> float:
	return float(b.xp.get(key, 0.0))


## Experience needed to go from `level` to the next one.
static func to_next(level: int, b: Balance) -> int:
	var from := int(_f(b, "linear_from"))
	if level <= from:
		return roundi(_f(b, "base") * pow(float(level), _f(b, "exponent")))
	return to_next(from, b) + int(_f(b, "linear_step")) * (level - from)


static func monster_xp(level: int, elite: bool, boss: bool, b: Balance) -> int:
	var v := roundi(_f(b, "monster_base") * pow(float(maxi(1, level)), _f(b, "monster_exponent")))
	if elite:
		v = roundi(v * _f(b, "elite_mult"))
	if boss:
		v = roundi(v * _f(b, "boss_mult"))
	return v


## Reduction for monsters well below the player's level.
static func level_factor(player_level: int, monster_level: int, b: Balance) -> float:
	var d := player_level - monster_level
	var grace := int(_f(b, "level_grace"))
	if d <= grace:
		return 1.0
	return maxf(_f(b, "min_factor"), 1.0 - _f(b, "level_penalty") * float(d - grace))


## What each of `n` sharing players gets from `total`.
static func group_share(total: int, n: int, b: Balance) -> int:
	n = maxi(1, n)
	return roundi(float(total) * (1.0 + _f(b, "group_bonus") * float(n - 1)) / float(n))


## Adds experience and raises as many levels as it allows. Returns how many.
static func add(progress: PlayerProgress, amount: int, b: Balance) -> int:
	amount = clampi(amount, 0, MAX_AMOUNT)
	progress.xp += amount
	var gained := 0
	while progress.level < PlayerProgress.MAX_LEVEL:
		var need := to_next(progress.level, b)
		if progress.xp < need:
			break
		progress.xp -= need
		progress.level += 1
		gained += 1
	if progress.level >= PlayerProgress.MAX_LEVEL:
		progress.xp = 0
	return gained
