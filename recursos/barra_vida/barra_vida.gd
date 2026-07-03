extends Node2D
class_name HealthBar

@onready var progress_bar: ProgressBar = $ProgressBar

## Señal que se emite cuando la vida llega a 0
signal health_depleted

# Configuración de la barra
@export_group("Configuración")
@export var max_health: float = 100.0:
	set(value):
		max_health = max(value, 1)  # Evitar que sea 0 o negativo
		_update_max_value()  # <-- NUEVO: Actualizar max_value
		_update_ui()

@export var current_health: float = 100.0:
	set(value):
		current_health = clamp(value, 0, max_health)
		_update_ui()
		if current_health <= 0:
			health_depleted.emit()


func _ready():
	_setup_ui()
	_update_ui()


func _setup_ui():
	if not progress_bar:
		return
	# Configurar el ProgressBar
	progress_bar.min_value = 0.0
	progress_bar.max_value = max_health  # <-- IMPORTANTE
	progress_bar.value = current_health


func _update_max_value():
	"""Actualiza el max_value del ProgressBar cuando cambia max_health"""
	if progress_bar:
		progress_bar.max_value = max_health


func _update_ui():
	if progress_bar:  # Verificar que existe
		progress_bar.value = current_health


# ============================================================
# FUNCIONES PÚBLICAS
# ============================================================

## Establecer la vida máxima
func set_max_health(new_max: float) -> void:
	max_health = new_max
	# El setter ya llama a _update_max_value() y _update_ui()


## Establecer la vida actual
func set_health(new_health: float) -> void:
	current_health = new_health
	# El setter ya llama a _update_ui()


## Curar al personaje (sumar vida)
func heal(amount: float) -> void:
	current_health = min(current_health + amount, max_health)


## Dañar al personaje (restar vida)
func take_damage(amount: float) -> void:
	current_health = max(current_health - amount, 0)


## Restaurar vida al máximo
func full_heal() -> void:
	current_health = max_health

## Verificar si está vivo
func is_alive() -> bool:
	return current_health > 0
