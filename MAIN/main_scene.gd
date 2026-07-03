extends Node2D
@onready var enemy_spawner: Spawner = $EnemySpawner
@onready var player_base: Estructura = $PlayerBase


func start_waves():
	enemy_spawner.start_spawning()
	


func _on_button_pressed() -> void:
	start_waves()
