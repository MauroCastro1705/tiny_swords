extends Control
@onready var coins: Label = $HBoxContainer/Label


func _ready() -> void:
	coins.text = str(Global.player_coins)
