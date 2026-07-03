extends CharacterBody2D

@onready var barra_vida: HealthBar = $BarraVida
@onready var warrior_sprite: AnimatedSprite2D = $warrior_sprite

@export var speed: float = 80.0
@export var attack_damage: float = 15.0
@export var attack_cooldown_time: float = 1.0
@export var attack_range: float = 50.0
@export var detection_range: float = 300.0

var max_health: float
var current_health: float
var target: Node2D = null
var can_attack: bool = true
var is_attacking: bool = false
var attack_timer: Timer
var cooldown_timer: Timer
var is_dead: bool = false
var has_dealt_damage: bool = false
var is_moving: bool = false
var attack_alternator: bool = false


func _ready() -> void:
	max_health = Global.warrior_max_health
	current_health = max_health
	
	# Configurar barra de vida
	barra_vida.health_depleted.connect(_on_health_depleted)
	barra_vida.max_health = max_health
	barra_vida.current_health = current_health
	
	# Configurar timers
	_setup_timers()
	
	# Conectar señales de animación
	if warrior_sprite:
		warrior_sprite.animation_finished.connect(_on_animation_finished)
	
	# Buscar enemigos al inicio
	call_deferred("_find_nearest_enemy")
	
	print("Guerrero listo! Buscando enemigos...")


func _setup_timers():
	# Timer para cooldown de ataque
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = attack_cooldown_time
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Timer para duración de ataque
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = 0.6
	attack_timer.timeout.connect(_on_attack_timeout)
	add_child(attack_timer)


func _physics_process(_delta: float) -> void:
	# Si está muerto, no hace nada
	if is_dead:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Si está atacando, no se mueve
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Verificar si el target actual es válido y está vivo
	if target and is_instance_valid(target):
		# Verificar si el enemigo está muerto
		if _is_enemy_dead(target):
			target = null
			_find_nearest_enemy()
			# Si no hay target después de buscar, quedarse idle
			if not target:
				_update_animation("idle")
				velocity = Vector2.ZERO
				move_and_slide()
				return
		else:
			# El target está vivo, proceder normalmente
			_process_combat()
	else:
		# No hay target o no es válido, buscar uno
		_find_nearest_enemy()
		if not target:
			# Si no hay enemigos, quedarse idle
			_update_animation("idle")
			velocity = Vector2.ZERO
			move_and_slide()
			return


func _process_combat():
	"""Procesa la lógica de combate cuando hay un target válido"""
	if not target or not is_instance_valid(target):
		return
	
	# Calcular distancia al objetivo
	var distance = global_position.distance_to(target.global_position)
	
	# Si está en rango de ataque
	if distance <= attack_range:
		# Si puede atacar y no está en cooldown
		if can_attack and not is_attacking:
			_start_attack()
		else:
			# Esperar cooldown o ataque
			velocity = Vector2.ZERO
			_update_animation("idle")
	else:
		# Moverse hacia el objetivo
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		_update_animation("walk")
		_flip_sprite(direction)


func _is_enemy_dead(enemy: Node2D) -> bool:
	"""Verifica si un enemigo está muerto usando diferentes métodos"""
	if not enemy or not is_instance_valid(enemy):
		return true
	
	# Método 1: Verificar variable is_dead
	if enemy.has_method("is_dead"):
		return enemy.is_dead
	
	# Método 2: Verificar propiedad is_dead
	if "is_dead" in enemy:
		return enemy.is_dead
	
	# Método 3: Verificar si tiene una variable de muerte
	if enemy.has_var("is_dead"):
		return enemy.get("is_dead")
	
	# Si no se puede determinar, asumir que está vivo
	return false


func _find_nearest_enemy():
	"""Busca el enemigo más cercano en el grupo 'enemy' que esté vivo"""
	var enemies = get_tree().get_nodes_in_group("enemy")
	var nearest = null
	var nearest_distance = detection_range	
	for enemy in enemies:
		if not is_instance_valid(enemy):
			continue
		
		# Verificar si el enemigo está muerto
		if _is_enemy_dead(enemy):
			print("Enemigo ", enemy.name, " está muerto, ignorando...")
			continue
		
		var distance = global_position.distance_to(enemy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			nearest = enemy
	
	if nearest:
		target = nearest

	else:
		target = null


func _start_attack():
	"""Inicia ataque contra el target actual"""
	if not target or not is_instance_valid(target):
		return
	
	# Verificar si el target está muerto antes de atacar
	if _is_enemy_dead(target):
		target = null
		_find_nearest_enemy()
		return
	
	if is_attacking:
		return
	
	if not can_attack:
		return
	
	is_attacking = true
	can_attack = false
	has_dealt_damage = false
	
	# Alternar entre attack_1 y attack_2
	attack_alternator = not attack_alternator
	var attack_animation = "attack_1" if attack_alternator else "attack_2"
	
	# Reproducir animación de ataque
	_update_animation(attack_animation)
	
	# Aplicar daño inmediatamente
	_deal_damage(target)
	
	# Iniciar timer para terminar el ataque
	attack_timer.start()


func _on_attack_timeout():
	"""Termina la animación de ataque"""
	is_attacking = false
	
	# Si no se ha aplicado daño aún (fallback)
	if not has_dealt_damage and target and is_instance_valid(target):
		# Verificar que el target siga vivo antes de aplicar daño
		if not _is_enemy_dead(target):

			_deal_damage(target)
			has_dealt_damage = true
		else:
			target = null
			_find_nearest_enemy()
	
	# Volver a idle
	_update_animation("idle")
	# Iniciar cooldown
	cooldown_timer.start()



func _on_cooldown_timeout():
	"""Termina el cooldown, permite atacar de nuevo"""
	can_attack = true

func _deal_damage(target_node: Node2D):
	"""Aplica daño al enemigo"""
	if has_dealt_damage:
		return
	
	if not target_node or not is_instance_valid(target_node):
		return
	
	# Verificar si el enemigo está muerto antes de aplicar daño
	if _is_enemy_dead(target_node):
		target = null
		_find_nearest_enemy()
		return
	
	has_dealt_damage = true
		
	# Buscar el nodo enemigo (puede ser el nodo o su padre)
	var enemy = target_node
	
	# Si el target es el hijo de un enemigo, buscar el padre
	if not enemy.is_in_group("enemy"):
		var parent = enemy.get_parent()
		if parent and parent.is_in_group("enemy"):
			enemy = parent
		else:
			# Buscar en hijos
			for child in enemy.get_children():
				if child.is_in_group("enemy"):
					enemy = child
					break
	
	# Aplicar daño si tiene el método
	if enemy and enemy.has_method("take_damage"):
		enemy.take_damage(attack_damage)
		print("Daño aplicado exitosamente a: ", enemy.name)


func _update_animation(animation_name: String):
	if not warrior_sprite:
		return
	
	var animations = warrior_sprite.sprite_frames.get_animation_names()
	if animation_name in animations:
		if warrior_sprite.animation != animation_name:
			print("Cambiando animación a: ", animation_name)
			warrior_sprite.play(animation_name)


func _flip_sprite(direction: Vector2):
	if not warrior_sprite:
		return
	
	if direction.x < 0:
		warrior_sprite.flip_h = true
	elif direction.x > 0:
		warrior_sprite.flip_h = false


func _on_animation_finished():
	if warrior_sprite:
		# Si terminó una animación de ataque
		if warrior_sprite.animation in ["attack_1", "attack_2"]:
			# Si no se ha aplicado daño aún (fallback)
			if not has_dealt_damage and target and is_instance_valid(target):
				# Verificar que el target siga vivo
				if not _is_enemy_dead(target):
					_deal_damage(target)
				else:
					target = null
					_find_nearest_enemy()


# ============================================================
# FUNCIONES DE VIDA
# ============================================================

func take_damage(damage: float):
	if is_dead:
		return
	
	current_health = max(current_health - damage, 0)
	if barra_vida:
		barra_vida.take_damage(damage)


func _on_health_depleted():
	die()


func die():
	if is_dead:
		return
	
	is_dead = true
	print("Guerrero ha muerto!")
	
	# Si existe animación de muerte, reproducirla
	if warrior_sprite and "die" in warrior_sprite.sprite_frames.get_animation_names():
		_update_animation("die")
		await warrior_sprite.animation_finished
	
	queue_free()


# ============================================================
# FUNCIONES DE UTILIDAD
# ============================================================

func get_target() -> Node2D:
	return target


func set_target(new_target: Node2D):
	target = new_target
	print("Target manual asignado: ", new_target.name)
