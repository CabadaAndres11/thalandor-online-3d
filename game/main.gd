extends Node
## Application root. (Task 14: starts a solo game directly; the title screen comes next.)

var game: GameSession


func _ready() -> void:
	game = GameSession.new()
	game.name = "Game"
	add_child(game)
	game.start_host("Jugador")
