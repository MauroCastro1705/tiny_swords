extends Node2D
class_name Spawner

# ============================================================
# EXPORTS - Configuración principal
# ============================================================

@export_group("Configuración General")
@export var enemy_scenes: Array[PackedScene] = []  # <-- Array de escenas de enemigos
@export var target_node: Marker2D                 # El objetivo al que los enemigos caminarán
@export var spawn_points: Array[Marker2D]         # Puntos de spawn (opcional)
@export var start_on_ready: bool = true
@export var enemies_container: Node2D             # Donde se agregarán los enemigos

@export_group("Configuración de Oleadas")
@export var waves: Array[WaveData] = []           # Las oleadas configuradas en el inspector
@export var time_between_waves: float = 3.0
@export var auto_start_next_wave: bool = true

# ============================================================
# VARIABLES INTERNAS
# ============================================================

var _current_wave_index: int = 0
var _is_spawning: bool = false
var _is_wave_active: bool = false
var _spawn_timer: Timer
var _wave_timer: Timer
var _enemies_spawned_in_wave: int = 0
var _total_enemies_in_wave: int = 0
var _enemies_alive: int = 0
var _enemies_list: Array[Node2D] = []  # Lista para trackear enemigos vivos

# Señales
signal wave_started(wave_index: int)
signal wave_completed(wave_index: int)
signal all_waves_completed()
signal enemy_spawned(enemy: Node2D)
signal enemy_died()

# ============================================================
# FUNCIONES DE CICLO DE VIDA
# ============================================================

func _ready():
	_setup_timers()
	
	# Verificar configuración
	if not target_node:
		push_warning("Spawner: No se ha asignado un target_node (Marker2D)")
	
	if enemy_scenes.size() == 0:
		push_warning("Spawner: No hay escenas de enemigos configuradas en enemy_scenes")
	
	if not enemies_container:
		enemies_container = self  # Usar este nodo como contenedor por defecto
	
	if start_on_ready and waves.size() > 0 and enemy_scenes.size() > 0:
		start_spawning()


func _setup_timers():
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = false
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)
	add_child(_spawn_timer)
	
	_wave_timer = Timer.new()
	_wave_timer.one_shot = true
	_wave_timer.timeout.connect(_on_wave_timer_timeout)
	add_child(_wave_timer)


# ============================================================
# FUNCIONES PÚBLICAS
# ============================================================

## Añadir una nueva escena de enemigo al array (útil para agregar enemigos en tiempo de ejecución)
func add_enemy_scene(enemy_scene: PackedScene) -> void:
	if enemy_scene and not enemy_scene in enemy_scenes:
		enemy_scenes.append(enemy_scene)
		print("Enemigo agregado: ", enemy_scene.resource_path)


## Remover una escena de enemigo del array
func remove_enemy_scene(enemy_scene: PackedScene) -> void:
	if enemy_scene in enemy_scenes:
		enemy_scenes.erase(enemy_scene)
		print("Enemigo removido: ", enemy_scene.resource_path)


## Obtener el array de escenas de enemigos (para modificar en tiempo de ejecución)
func get_enemy_scenes() -> Array[PackedScene]:
	return enemy_scenes


## Establecer el array de escenas de enemigos
func set_enemy_scenes(new_enemy_scenes: Array[PackedScene]) -> void:
	enemy_scenes = new_enemy_scenes


## Iniciar el proceso de spawn
func start_spawning():
	if waves.size() == 0:
		push_warning("Spawner: No hay oleadas configuradas")
		return
	
	if enemy_scenes.size() == 0:
		push_warning("Spawner: No hay escenas de enemigos configuradas")
		return
	
	if _is_spawning:
		return
	
	_is_spawning = true
	_current_wave_index = 0
	_start_wave(_current_wave_index)


## Detener el spawn
func stop_spawning():
	_is_spawning = false
	_is_wave_active = false
	_spawn_timer.stop()
	_wave_timer.stop()


## Saltar a la siguiente oleada (útil para testing)
func skip_to_next_wave():
	if _is_wave_active:
		_force_complete_wave()


## Reiniciar todo el sistema
func reset_spawner():
	stop_spawning()
	_current_wave_index = 0
	_enemies_spawned_in_wave = 0
	_total_enemies_in_wave = 0
	_enemies_alive = 0
	_enemies_list.clear()
	
	# Eliminar enemigos existentes
	if enemies_container:
		for child in enemies_container.get_children():
			child.queue_free()


# ============================================================
# FUNCIONES DE OLEADAS
# ============================================================

func _start_wave(wave_index: int):
	if wave_index >= waves.size():
		all_waves_completed.emit()
		_is_spawning = false
		return
	
	var wave_data = waves[wave_index]
	
	# Verificar que la oleada tenga enemigos configurados
	if wave_data.enemy_indices.size() == 0:
		push_warning("Spawner: La oleada %d no tiene índices de enemigos configurados" % wave_index)
		_current_wave_index += 1
		_start_wave(_current_wave_index)
		return
	
	_enemies_spawned_in_wave = 0
	_total_enemies_in_wave = wave_data.total_enemies
	_enemies_list.clear()  # Limpiar lista de enemigos para la nueva wave
	
	wave_started.emit(wave_index)
	_is_wave_active = true
	
	print("=== OLEADA %d INICIADA ===" % (wave_index + 1))
	print("Enemigos totales: %d" % _total_enemies_in_wave)
	print("Intervalo: %.2f segundos" % wave_data.spawn_interval)
	print("Tipos de enemigos disponibles: ", _get_enemy_names_from_indices(wave_data.enemy_indices))
	
	# Iniciar el spawn de enemigos
	_spawn_timer.wait_time = wave_data.spawn_interval
	_spawn_timer.start()


func _force_complete_wave():
	"""Completa la oleada actual forzosamente (para skip)"""
	_spawn_timer.stop()
	_enemies_spawned_in_wave = _total_enemies_in_wave
	_on_wave_completed()


func _on_spawn_timer_timeout():
	if not _is_wave_active:
		return
	
	# Spawnear un enemigo
	_spawn_enemy()
	_enemies_spawned_in_wave += 1
	_enemies_alive += 1
	
	# Verificar si ya se spawnearon todos los enemigos de la oleada
	if _enemies_spawned_in_wave >= _total_enemies_in_wave:
		_spawn_timer.stop()
		# Esperar a que los enemigos mueran
		_check_wave_completion()


func _check_wave_completion():
	"""Verifica si todos los enemigos de la oleada han muerto"""
	if _enemies_alive <= 0 and _enemies_spawned_in_wave >= _total_enemies_in_wave:
		_on_wave_completed()
	else:
		# Esperar y verificar de nuevo después de un tiempo
		_wave_timer.wait_time = 0.5
		_wave_timer.start()


func _on_wave_timer_timeout():
	_check_wave_completion()


func _on_wave_completed():
	_is_wave_active = false
	wave_completed.emit(_current_wave_index)
	
	print("=== OLEADA %d COMPLETADA ===" % (_current_wave_index + 1))
	
	# Hacer desaparecer a los enemigos que aún están vivos (pero muertos)
	_make_enemies_disappear()
	
	_current_wave_index += 1
	
	if _current_wave_index < waves.size():
		# Esperar antes de iniciar la siguiente oleada
		if auto_start_next_wave:
			await get_tree().create_timer(time_between_waves).timeout
			_start_wave(_current_wave_index)
	else:
		all_waves_completed.emit()
		_is_spawning = false
		print("=== TODAS LAS OLEADAS COMPLETADAS ===")


func _make_enemies_disappear():
	"""Hace que todos los enemigos vivos (muertos) desaparezcan con la animación disapear"""
	print("Haciendo desaparecer a %d enemigos" % _enemies_list.size())
	
	# Crear una copia de la lista para evitar problemas durante la iteración
	var enemies_to_disappear = _enemies_list.duplicate()
	
	for enemy in enemies_to_disappear:
		if is_instance_valid(enemy) and enemy.has_method("start_disappear"):
			# Llamar a la función de desaparición
			enemy.start_disappear()
			print("Enemigo %s iniciando desaparición" % enemy.name)
		elif is_instance_valid(enemy):
			# Si el enemigo no tiene el método, eliminarlo directamente
			enemy.queue_free()
	
	# Limpiar la lista (los enemigos se eliminarán cuando termine la animación)
	_enemies_list.clear()


# ============================================================
# FUNCIONES DE SPAWN
# ============================================================

func _spawn_enemy():
	var wave_data = waves[_current_wave_index]
	
	# Seleccionar un índice de enemigo de los disponibles en la oleada
	var enemy_index = _get_random_enemy_index(wave_data.enemy_indices)
	if enemy_index == -1:
		return
	
	# Verificar que el índice exista en el array de enemigos
	if enemy_index >= enemy_scenes.size():
		push_error("Spawner: Índice de enemigo %d fuera de rango. Tamaño del array: %d" % [enemy_index, enemy_scenes.size()])
		return
	
	var enemy_scene = enemy_scenes[enemy_index]
	if not enemy_scene:
		return
	
	var enemy = enemy_scene.instantiate()
	
	# Configurar posición de spawn
	var spawn_position = _get_spawn_position()
	enemy.global_position = spawn_position
	
	# Asignar el objetivo (target) al enemigo
	_assign_target_to_enemy(enemy)
	
	# Asignar el contenedor
	if enemies_container:
		enemies_container.add_child(enemy)
	else:
		add_child(enemy)
	
	# Conectar señal de muerte del enemigo
	_connect_enemy_signals(enemy)
	
	# Agregar a la lista de enemigos vivos
	_enemies_list.append(enemy)
	
	enemy_spawned.emit(enemy)


func _get_random_enemy_index(enemy_indices: Array[int]) -> int:
	if enemy_indices.size() == 0:
		return -1
	
	# Si solo hay un índice, devolverlo
	if enemy_indices.size() == 1:
		return enemy_indices[0]
	
	# Seleccionar un índice aleatorio con pesos
	var total_weight = 0
	for index in enemy_indices:
		total_weight += _get_enemy_weight(index)
	
	var random_value = randf() * total_weight
	var cumulative = 0
	
	for index in enemy_indices:
		cumulative += _get_enemy_weight(index)
		if random_value <= cumulative:
			return index
	
	return enemy_indices[0]


@warning_ignore("unused_parameter")
func _get_enemy_weight(index: int) -> float:
	# Si el enemigo tiene un componente de peso, podrías obtenerlo aquí
	# Por defecto, todos los enemigos tienen peso 1.0
	return 1.0


func _assign_target_to_enemy(enemy: Node2D):
	"""Asigna el target al enemigo usando diferentes métodos posibles"""
	if not target_node:
		return
	
	# Método 1: función set_target
	if enemy.has_method("set_target"):
		enemy.set_target(target_node)
	
	# Método 2: función set_target_node
	elif enemy.has_method("set_target_node"):
		enemy.set_target_node(target_node)
	
	# Método 3: propiedad target
	elif "target" in enemy:
		enemy.target = target_node
	
	# Método 4: propiedad target_node
	elif "target_node" in enemy:
		enemy.target_node = target_node


func _connect_enemy_signals(enemy: Node2D):
	"""Conecta las señales de muerte del enemigo"""
	# Señal "died"
	if enemy.has_signal("died") and not enemy.died.is_connected(_on_enemy_died):
		enemy.died.connect(_on_enemy_died.bind(enemy))
	
	# Señal "health_depleted"
	if enemy.has_signal("health_depleted") and not enemy.health_depleted.is_connected(_on_enemy_died):
		enemy.health_depleted.connect(_on_enemy_died.bind(enemy))


func _get_spawn_position() -> Vector2:
	# Si hay puntos de spawn configurados, usar uno aleatorio
	if spawn_points.size() > 0:
		var random_point = spawn_points[randi() % spawn_points.size()]
		return random_point.global_position
	
	# Si no, usar la posición del spawner con offset aleatorio
	var random_offset = Vector2(
		randf_range(-200, 200),
		randf_range(-200, 200)
	)
	return global_position + random_offset


func _get_enemy_names_from_indices(indices: Array[int]) -> String:
	"""Devuelve los nombres de los enemigos a partir de sus índices (para debug)"""
	var names = []
	for index in indices:
		if index < enemy_scenes.size() and enemy_scenes[index]:
			var scene = enemy_scenes[index]
			# Obtener el nombre del archivo
			var path = scene.resource_path
			var file_name = path.get_file().replace(".tscn", "").replace(".scn", "")
			names.append(file_name)
		else:
			names.append("Enemigo_%d" % index)
	return ", ".join(names)


func _on_enemy_died(enemy: Node2D):
	_enemies_alive -= 1
	enemy_died.emit()
	
	# Remover el enemigo de la lista de vivos (pero mantenerlo para la desaparición)
	if enemy in _enemies_list:
		# No lo removemos de la lista, porque queremos que desaparezca al final de la wave
		pass
	
	# Verificar si la oleada está completa
	if _is_wave_active and _enemies_spawned_in_wave >= _total_enemies_in_wave:
		_check_wave_completion()


# ============================================================
# FUNCIONES DE DEBUG
# ============================================================

func get_current_wave_info() -> Dictionary:
	return {
		"current_wave": _current_wave_index + 1,
		"total_waves": waves.size(),
		"enemies_spawned": _enemies_spawned_in_wave,
		"total_enemies": _total_enemies_in_wave,
		"enemies_alive": _enemies_alive,
		"enemies_in_list": _enemies_list.size(),
		"is_spawning": _is_spawning,
		"is_wave_active": _is_wave_active,
		"enemy_types_available": enemy_scenes.size()
	}


func get_wave_data(wave_index: int) -> Dictionary:
	if wave_index < 0 or wave_index >= waves.size():
		return {}
	
	var wave = waves[wave_index]
	return {
		"total_enemies": wave.total_enemies,
		"spawn_interval": wave.spawn_interval,
		"enemy_types": wave.enemy_indices.size()
	}
