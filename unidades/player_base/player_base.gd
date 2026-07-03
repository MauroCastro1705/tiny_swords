extends CharacterBody2D  # Cambiado a CharacterBody2D para colisiones
class_name Estructura

signal destroyed

@export var max_health: float = 100.0
@export var health: float = 100.0
@export var destruction_effect: PackedScene




func _ready() -> void:
	# Agregar al grupo "estructura" para que los enemigos la detecten
	add_to_group("estructura")
	


func take_damage(damage: float) -> void:
	health = max(health - damage, 0)
	print("Estructura ", name, " recibió daño. Vida: ", health, "/", max_health)
		
	if health <= 0:
		destroy()


func destroy() -> void:
	destroyed.emit()
	print("Estructura ", name, " destruida")
	
	if destruction_effect:
		var effect = destruction_effect.instantiate()
		effect.global_position = global_position
		get_tree().current_scene.add_child(effect)
	
	queue_free()


func _on_health_depleted() -> void:
	destroy()


func is_destroyed() -> bool:
	return health <= 0


func _on_recibir_dmg_pressed() -> void:
	take_damage(10)
