extends Control
@onready var coins: Label = $HBoxContainer/Label


func _ready() -> void:
	Global.update_things.connect(_update_coins)
	coins.text = str(Global.player_coins)

func _update_coins():
	coins.text = str(Global.player_coins)
