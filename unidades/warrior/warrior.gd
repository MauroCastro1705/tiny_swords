extends CharacterBody2D

@onready var barra_vida: HealthBar = $BarraVida

var max_health:float
var current_health: float


func _ready() -> void:
	max_health = Global.warrior_max_health
	current_health = max_health
	barra_vida.health_depleted.connect(_on_health_depleted)
	barra_vida.max_health = max_health# Configurar la barra
	barra_vida.current_health = current_health
	
	
func _on_health_depleted():
	# Lógica cuando el personaje muere
	queue_free()
	print("warrior derrotado!")
	
func _on_health_changed():
	pass

func take_damage(damage: float):
	current_health = max(current_health - damage, 0)
	if barra_vida:
		barra_vida.take_damage(damage)
