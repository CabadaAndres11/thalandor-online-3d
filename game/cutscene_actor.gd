class_name CutsceneActor
extends Node3D
## An actor of a cutscene that is neither an NPC nor a monster (Plan 8.2): the player's own
## look, or a loose look (masked cultists, Mira). Only visual.

var rig: HumanRig


func set_rig(r: HumanRig) -> void:
	rig = r
	add_child(r)
