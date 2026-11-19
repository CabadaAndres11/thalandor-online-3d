class_name ItemTooltip
extends RefCounted
## What hovering an item shows: its name in the rarity color, slot and type, level (red
## above the character's), fixed stats and properties, durability (red when broken), sale
## value, and under a line the difference with what is worn in that slot (green better,
## red worse). lines() is the text; build() the panel.

const BETTER := Color("#5fd36a")
const WORSE := Color("#e5533d")
const DIM := Color(1, 1, 1, 0.65)
## Stats shown as whole numbers.
const WHOLE := ["armor_add", "attack_power_add", "spell_power_add", "max_resource_add", "strength", "agility",
	"intellect", "stamina", "spirit"]


## [text, color] rows. `worn`: the item in the same slot (null when empty or not gear).
static func lines(it: Item, class_id: String, level: int, worn: Item, db: ItemDB) -> Array:
	var out: Array = []
	var b := db.base(it.base_id)
	out.append([tr_text(str(b.get("name", it.base_id))), ItemIcons.rarity_color(it.rarity)])
	if db.is_consumable(it.base_id):
		out.append([tr_text("ITEM_POTION_%s_DESC" % str(b.get("potion", "")).to_upper()), HoloTheme.TEXT])
		out.append([tr_text("ITEM_STACK") % it.count, DIM])
		return out
	var kind := tr_text("KIND_" + str(b.get("kind", "")).to_upper())
	var slot := tr_text("EQUIP_" + str(b.get("slot", "")).to_upper())
	var hands := (" · " + tr_text("ITEM_TWO_HANDS")) if db.hands(it.base_id) == 2 else ""
	out.append(["%s · %s%s · %s" % [slot, kind, hands, tr_text("RARITY_" + it.rarity.to_upper())], DIM])
	out.append([tr_text("ITEM_LEVEL") % it.level, WORSE if it.level > level else HoloTheme.TEXT])
	if not db.can_use(class_id, it.base_id):
		out.append([tr_text("ITEM_CLASS_CANNOT"), WORSE])
	var mine := stats_of(it, db)
	for stat: String in mine:
		out.append([_describe(stat, mine[stat]), HoloTheme.TEXT])
	out.append([tr_text("ITEM_DURABILITY") % it.durability, WORSE if it.durability <= 0 else DIM])
	out.append([tr_text("ITEM_SELL") % Merchant.sell_price(it, db), DIM])
	if worn != null and worn != it:
		out.append([tr_text("ITEM_COMPARE"), HoloTheme.ACCENT])
		var theirs := stats_of(worn, db)
		var keys: Array = mine.keys()
		for k: String in theirs:
			if not k in keys:
				keys.append(k)
		var any := false
		for stat: String in keys:
			var diff := float(mine.get(stat, 0.0)) - float(theirs.get(stat, 0.0))
			if absf(diff) < 0.00005:
				continue
			any = true
			out.append([_describe(stat, diff), BETTER if diff > 0.0 else WORSE])
		if not any:
			out.append([tr_text("ITEM_SAME"), DIM])
	return out


## stat -> total of an item's fixed stats and properties (whole-number stats rounded).
static func stats_of(it: Item, db: ItemDB) -> Dictionary:
	var out := {}
	var two := db.hands(it.base_id) == 2
	for s: Dictionary in db.base(it.base_id).get("stats", []):
		out[str(s.stat)] = float(out.get(str(s.stat), 0.0)) + ItemRoll.stat_value(s, it.level, two, db)
	for a: Dictionary in it.affixes:
		var stat := str(db.affix(a.id).get("stat", ""))
		out[stat] = float(out.get(stat, 0.0)) + float(a.value)
	for stat: String in out.keys():
		if stat in WHOLE:
			out[stat] = float(roundi(out[stat]))
		if is_zero_approx(float(out[stat])):
			out.erase(stat)
	return out


static func _describe(stat: String, value: float) -> String:
	return StatText.describe({"stat": stat, "value": value})


static func tr_text(key: String) -> String:
	return TranslationServer.translate(key)


## The tooltip panel (Godot shows it from _make_custom_tooltip).
static func build(it: Item, class_id: String, level: int, worn: Item, db: ItemDB) -> Control:
	var panel := PanelContainer.new()
	panel.add_theme_stylebox_override("panel", HoloTheme.panel_style(10))
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 2)
	panel.add_child(box)
	var first := true
	for l: Array in lines(it, class_id, level, worn, db):
		if l[0] == tr_text("ITEM_COMPARE"):
			box.add_child(HoloTheme.divider())
		var label := Label.new()
		label.text = l[0]
		label.add_theme_color_override("font_color", l[1])
		label.add_theme_font_size_override("font_size", 20 if first else 15)
		box.add_child(label)
		first = false
	return panel
