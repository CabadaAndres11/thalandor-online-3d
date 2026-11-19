class_name AmbienceCommand
extends RefCounted
## The local chat command /ambiente [id]: lists the ambiences or switches the player's own
## view to one. It never reaches the host. Returns {handled, switch_to, message}.

const NAME := "/ambiente"


static func handle(text: String, current: String, ids: PackedStringArray) -> Dictionary:
	var parts := text.strip_edges().split(" ", false)
	if parts.is_empty() or parts[0].to_lower() != NAME:
		return {"handled": false, "switch_to": "", "message": ""}
	var listed := ", ".join(ids)
	if parts.size() < 2:
		return {"handled": true, "switch_to": "",
			"message": TranslationServer.translate("AMBIENCE_LIST") % [current, listed]}
	var wanted := parts[1].to_lower()
	if wanted in ids:
		return {"handled": true, "switch_to": wanted,
			"message": TranslationServer.translate("AMBIENCE_SET") % wanted}
	return {"handled": true, "switch_to": "",
		"message": TranslationServer.translate("AMBIENCE_UNKNOWN") % [parts[1], listed]}
