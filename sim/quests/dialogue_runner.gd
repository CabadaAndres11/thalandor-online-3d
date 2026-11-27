class_name DialogueRunner
extends RefCounted
## A conversation (Plan 8.2): data/dialogues/<id>.json, nodes of lines ([speaker, text key];
## speaker "player" or an NPC id) followed by choices or by the next node. Linear: choices
## only where they matter. A choice may ask for flags (if_flags, not_flags), hide after use
## (once: also hidden when its own flags are already set), set flags and run an action
## (accept, turn_in, trade, scene:<id>). "end" (or no next) finishes. Coming back to a
## node already shown skips its lines and shows its choices again.
## Pure logic: the client walks it; the host uses offered_flags() to check the flags it sets.

const DIR := "res://data/dialogues/"
const ACTIONS := ["accept", "turn_in", "trade"]

## Where dialogues are read from (tests point it at their own).
static var dir: String = DIR

var id: String = ""
var _nodes: Dictionary = {}
var _node: String = ""
var _line: int = 0
var _finished: bool = false
var _flags: Array = [] # the log's flags plus those set in this conversation
var _set: Array = [] # flags set in this conversation, in order
var _used: Array = [] # "node:index" of once choices taken
var _visited: Array = [] # nodes already shown: coming back to one skips to its choices


static func _read(dialogue_id: String, from_dir: String) -> Dictionary:
	var path := from_dir.path_join(dialogue_id + ".json")
	if dialogue_id == "" or not FileAccess.file_exists(path):
		return {}
	var d: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	return d if d is Dictionary and (d as Dictionary).get("nodes") is Dictionary else {}


static func load_id(dialogue_id: String) -> DialogueRunner:
	var d := _read(dialogue_id, dir)
	if d.is_empty():
		return null
	var r := DialogueRunner.new()
	r.id = dialogue_id
	r._nodes = d.nodes
	return r


## A conversation of plain lines with no file (2026-11-27: an NPC's greeting is shown in the
## dialogue window, not in the chat). lines: [[speaker, text key], ...].
static func from_lines(dialogue_id: String, lines: Array) -> DialogueRunner:
	var r := DialogueRunner.new()
	r.id = dialogue_id
	r._nodes = {"start": {"lines": lines.duplicate(true)}}
	return r


func start(log: QuestLog) -> void:
	_flags = log.flags.duplicate()
	_set.clear()
	_used.clear()
	_visited.clear()
	_finished = false
	_enter("start")


func _enter(node: String) -> void:
	if node == "end" or node == "" or not _nodes.has(node):
		_finished = true
		_node = ""
		return
	_node = node
	_line = 0
	if node in _visited and not _n().get("choices", []).is_empty():
		_line = _lines().size() # back at a hub: straight to its choices
		return
	_visited.append(node)
	if _lines().is_empty():
		_after_lines()


func _n() -> Dictionary:
	return _nodes.get(_node, {})


func _lines() -> Array:
	return _n().get("lines", [])


func _after_lines() -> void:
	for f: Variant in _n().get("flags", []):
		_add_flag(str(f))
	if not _n().get("choices", []).is_empty():
		return
	_enter(str(_n().get("next", "end")))


func _add_flag(f: String) -> void:
	if not f in _flags:
		_flags.append(f)
	if not f in _set:
		_set.append(f)


func finished() -> bool:
	return _finished


## [speaker, text key] of the line being shown ([] at choices or at the end).
func current_line() -> Array:
	if _finished or _line >= _lines().size():
		return []
	return _lines()[_line]


## Next line; false when it reached the choices or the end.
func advance() -> bool:
	if _finished or _line >= _lines().size():
		return false
	_line += 1
	if _line < _lines().size():
		return true
	var node := _node
	_after_lines()
	return not _finished and _node != node and _line < _lines().size()


static func _shows(c: Dictionary, flags: Array) -> bool:
	for f: Variant in c.get("if_flags", []):
		if not str(f) in flags:
			return false
	for f: Variant in c.get("not_flags", []):
		if str(f) in flags:
			return false
	return true


func _visible() -> Array:
	var out: Array = []
	if _finished or _line < _lines().size():
		return out
	var all: Array = _n().get("choices", [])
	for i in all.size():
		var c: Dictionary = all[i]
		if not _shows(c, _flags):
			continue
		if bool(c.get("once", false)):
			var own: Array = c.get("flags", [])
			if "%s:%d" % [_node, i] in _used or (not own.is_empty() and own.all(func(f: Variant) -> bool: return str(f) in _flags)):
				continue
		out.append([i, c])
	return out


## The choices shown now: [{text, action}].
func choices() -> Array:
	return _visible().map(func(v: Array) -> Dictionary: return {"text": str(v[1].get("text", "")), "action": str(v[1].get("action", ""))})


## Takes a shown choice: {flags, action, next}; the conversation moves on.
func choose(index: int) -> Dictionary:
	var shown := _visible()
	if index < 0 or index >= shown.size():
		return {}
	var c: Dictionary = shown[index][1]
	if bool(c.get("once", false)):
		_used.append("%s:%d" % [_node, shown[index][0]])
	var flags: Array = (c.get("flags", []) as Array).map(func(f: Variant) -> String: return str(f))
	for f: String in flags:
		_add_flag(f)
	var next := str(c.get("next", "end"))
	_enter(next)
	return {"flags": flags, "action": str(c.get("action", "")), "next": next}


## Flags set in this conversation (node flags and choices), in order.
func set_flags() -> Array:
	return _set.duplicate()


## Every flag this dialogue could set for a player with this log (the host refuses others).
static func offered_flags(dialogue_id: String, log: QuestLog) -> Array:
	var d := _read(dialogue_id, dir)
	if d.is_empty():
		return []
	var nodes: Dictionary = d.nodes
	var flags := log.flags.duplicate()
	var out: Array = []
	var seen := {}
	var queue: Array = ["start"]
	var grew := true
	while grew:
		grew = false
		queue = ["start"]
		seen.clear()
		while not queue.is_empty():
			var name: String = queue.pop_front()
			if seen.has(name) or not nodes.has(name):
				continue
			seen[name] = true
			var n: Dictionary = nodes[name]
			var gained: Array = (n.get("flags", []) as Array).duplicate()
			for c: Dictionary in n.get("choices", []):
				if _shows(c, flags):
					gained += c.get("flags", [])
					queue.append(str(c.get("next", "end")))
			queue.append(str(n.get("next", "end")))
			for f: Variant in gained:
				if not str(f) in out:
					out.append(str(f))
				if not str(f) in flags:
					flags.append(str(f))
					grew = true
	return out


## A text with the player's name and epithet in it ({nombre}, {apodo}).
static func format_text(text: String, player_name: String, epithet: String) -> String:
	return text.replace("{nombre}", player_name).replace("{apodo}", epithet)


static func format(key: String, player_name: String, epithet: String) -> String:
	return format_text(TranslationServer.translate(key), player_name, epithet)


## Problems in a folder of dialogues, as readable lines.
static func validate_dir(from_dir: String) -> Array[String]:
	var errors: Array[String] = []
	if not DirAccess.dir_exists_absolute(from_dir):
		return errors
	var npcs := NpcDB.load_default()
	for f: String in DirAccess.get_files_at(from_dir):
		if not f.ends_with(".json"):
			continue
		var did := f.get_basename()
		var d := _read(did, from_dir)
		if d.is_empty():
			errors.append("%s: no se puede leer" % did)
			continue
		var nodes: Dictionary = d.nodes
		if not nodes.has("start"):
			errors.append("%s: sin nodo start" % did)
		for name: String in nodes:
			var n: Dictionary = nodes[name]
			var nexts: Array = [str(n.get("next", "end"))]
			for l: Variant in n.get("lines", []):
				if not l is Array or (l as Array).size() != 2:
					errors.append("%s/%s: línea mal formada" % [did, name])
					continue
				if str(l[0]) != "player" and npcs.npc(str(l[0])).is_empty():
					errors.append("%s/%s: quién habla '%s'" % [did, name, l[0]])
				if TranslationServer.translate(str(l[1])) == str(l[1]):
					errors.append("%s/%s: texto sin traducir '%s'" % [did, name, l[1]])
			for c: Variant in n.get("choices", []):
				if not c is Dictionary:
					continue
				nexts.append(str(c.get("next", "end")))
				if TranslationServer.translate(str(c.get("text", ""))) == str(c.get("text", "")):
					errors.append("%s/%s: texto sin traducir '%s'" % [did, name, c.get("text", "")])
				var act := str(c.get("action", ""))
				if act != "" and not act in ACTIONS and not act.begins_with("scene:"):
					errors.append("%s/%s: acción desconocida '%s'" % [did, name, act])
			for nx: String in nexts:
				if nx != "end" and not nodes.has(nx):
					errors.append("%s/%s: nodo desconocido '%s'" % [did, name, nx])
	return errors
