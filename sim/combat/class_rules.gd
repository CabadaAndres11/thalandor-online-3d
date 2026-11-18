class_name ClassRules
extends RefCounted
## Class mechanics that are not generic effects:
##   - class stats and resource from data/characters/classes.json (setup_player);
##   - assassin combo points: abilities with "combo_gain" add points when they hit;
##     "finisher" abilities need points, multiply their damage by them and spend them;
##   - archer charged shot: basic abilities with a "charge" block are held and fired on
##     release; a charge above min_ratio costs focus and scales damage and range;
##   - "ally_or_self" targets (cleric heals and shields).

const MAX_COMBO := 5
const ALLY_PICK_RADIUS := 1.0


static func setup_player(p: PlayerState, class_id: String, catalog: CharacterCatalog = null, world: SimWorld = null) -> void:
	var cat := catalog if catalog != null else CharacterCatalog.load_default()
	var def := cat.class_def(cat.sanitize_class(class_id))
	p.class_id = str(def.get("id", class_id))
	Progression.rebuild(p, world, true)


## The ally (not the caster) closest to `point`, within the pick radius; else null.
static func ally_under_cursor(world: SimWorld, caster: CombatEntity, point: Vector3) -> CombatEntity:
	var best: CombatEntity = null
	var best_d := INF
	for o: CombatEntity in world.entities():
		if o == caster or o.team != caster.team or not o.is_alive():
			continue
		var d := Effects.flat(o.position).distance_to(Effects.flat(point))
		if d <= ALLY_PICK_RADIUS + o.radius and d < best_d:
			best = o
			best_d = d
	return best


## Before a cast: finishers need combo points; stealth needs to be out of combat
## unless it is a vanish. Returns false to refuse the cast.
static func can_cast(world: SimWorld, caster: CombatEntity, ability: Dictionary) -> bool:
	if bool(ability.get("finisher", false)):
		return caster is PlayerState and (caster as PlayerState).combo > 0
	for e: Dictionary in ability.get("effects", []):
		if e.get("type") == "stealth" and not bool(e.get("vanish", false)) and caster.in_combat(world):
			return false
	return true


static func _is_stealth(ability: Dictionary) -> bool:
	for e: Dictionary in ability.get("effects", []):
		if e.get("type") == "stealth":
			return true
	return false


## The ability as the caster's passives change it, and the rules that run on every
## accepted cast: Ráfaga (every n-th basic crits), Ojo de halcón (range), Emboscada
## (the opener from stealth crits harder) and breaking stealth by attacking.
static func with_passives(world: SimWorld, caster: CombatEntity, ability: Dictionary) -> Dictionary:
	var ab := ability
	var h := Passives.has_hook(caster, "range_pct")
	if not h.is_empty():
		ab = scale_damage(ab, 1.0, 1.0 + float(h.get("pct", 0.0)))
	h = Passives.has_hook(caster, "every_nth_basic_crits")
	if ab.get("kind") == "basic":
		caster.basic_count += 1
		if not h.is_empty() and caster.basic_count % maxi(int(h.get("n", 5)), 1) == 0:
			ab = force_crit(ab)
	if caster.has_status("stealth") and not _is_stealth(ab):
		h = Passives.has_hook(caster, "stealth_opener_crit_bonus")
		if not h.is_empty():
			ab = force_crit(scale_damage(ab, 1.0 + float(h.get("pct", 0.0)), 1.0))
		caster.remove_status("stealth")
		world.emit(["status_end", caster.id, "stealth"])
	return ab


## A copy of `ability` whose every damage is critical.
static func force_crit(ability: Dictionary) -> Dictionary:
	var a := ability.duplicate(true)
	for e: Dictionary in a.get("effects", []):
		if e.has("damage"):
			(e.damage as Dictionary)["force_crit"] = true
		if e.has("explode"):
			((e.explode as Dictionary).get("damage", {}) as Dictionary)["force_crit"] = true
	return a


## The ability as it will be cast: finishers scale with combo points.
static func shaped(caster: CombatEntity, ability: Dictionary) -> Dictionary:
	if bool(ability.get("finisher", false)) and caster is PlayerState:
		return scale_damage(ability, float((caster as PlayerState).combo), 1.0)
	return ability


## After a cast: combo points gained (if it hit) or spent (finisher).
static func after_cast(caster: CombatEntity, ability: Dictionary, hits: int) -> void:
	var p := caster as PlayerState
	if p == null:
		return
	if bool(ability.get("finisher", false)):
		if float(ability.get("refund_per_combo", 0.0)) > 0.0: # evolved Eviscerar
			Resources.add(p, float(ability.refund_per_combo) * float(p.combo))
		for h: Dictionary in Passives.hooks(p, "finisher_refund_per_combo"):
			Resources.add(p, float(h.get("amount", 0.0)) * float(p.combo)) # Eviscerar: energy back per point
		p.combo = 0
	elif hits > 0:
		var gain := int(ability.get("combo_gain", 0)) + int(ability.get("combo_per_hit", 0)) * hits
		if gain > 0 and p.bonus_combo_ready:
			# Evasión mortal: the first combo gain after a dodge is at least `combo`.
			gain = maxi(gain, int(Passives.has_hook(p, "after_dodge_combo").get("combo", gain)))
			p.bonus_combo_ready = false
		p.combo = mini(p.combo + gain, MAX_COMBO)


## A copy of `ability` whose projectiles stop after `hits` enemies.
static func with_pierce_hits(ability: Dictionary, hits: int) -> Dictionary:
	var a := ability.duplicate(true)
	for e: Dictionary in a.get("effects", []):
		if e.get("type") == "projectile":
			e["pierce_hits"] = hits
	return a


## A copy of `ability` with every damage × mult and every range × range_mult.
static func scale_damage(ability: Dictionary, mult: float, range_mult: float) -> Dictionary:
	var a := ability.duplicate(true)
	for e: Dictionary in a.get("effects", []):
		_scale_effect(e, mult, range_mult)
	return a


static func _scale_effect(e: Dictionary, mult: float, range_mult: float) -> void:
	if e.has("damage"):
		var d: Dictionary = e.damage
		d.base = float(d.get("base", 0.0)) * mult
		d.coef = float(d.get("coef", 0.0)) * mult
	if e.has("range"):
		e.range = float(e.range) * range_mult
	if e.has("explode"):
		_scale_effect(e.explode, mult, 1.0)


## Archer: fires a held basic shot. ratio 0..1 of the full charge. Below min_ratio (a
## quick tap) or without enough focus it is a normal free shot.
static func release_charged(world: SimWorld, p: PlayerState, ability_id: String, aim: Vector3, ratio: float) -> bool:
	var ab := world.abilities.resolved(ability_id, p.progress.upgrade, world.upgrades)
	var charge: Dictionary = ab.get("charge", {})
	var mods := {}
	if not charge.is_empty() and ratio >= float(charge.get("min_ratio", 0.2)) \
			and p.resource >= float(charge.get("cost", 0.0)):
		var r := clampf(ratio, 0.0, 1.0)
		mods = {
			"damage_mult": lerpf(1.0, float(charge.get("damage_mult", 1.0)), r),
			"range_mult": lerpf(1.0, float(charge.get("range_mult", 1.0)), r),
			"extra_cost": float(charge.get("cost", 0.0)),
		}
		# Tirador certero: a charge of pierce_ratio or more goes through pierce_hits enemies.
		if int(charge.get("pierce_hits", 0)) > 0 and r >= float(charge.get("pierce_ratio", 0.8)):
			mods["pierce_hits"] = int(charge.pierce_hits)
	return Combat.try_cast(world, p, ability_id, aim, mods)
