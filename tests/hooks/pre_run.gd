extends GutHookScript
## Before the suite (Plan 8.3a): no story by default. The prologue starts by itself for every
## new character and takes it into a story moment, which most tests of the host do not want.
## Tests that play the real quests read them with QuestDB.load_dir(QuestDB.DIR).


func run() -> void:
	QuestDB.dir = "res://tests/data/no_quests/"
	QuestDB._default = null
