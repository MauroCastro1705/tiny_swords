extends CharacterBody2D
class_name Enemy

signal died

@onready var barra_vida: HealthBar = $BarraVida
@onready var goblin_sprite: AnimatedSprite2D = $goblin_sprite
#new animations = "die" and "disapear"
@onready var click_dmg: AnimatedSprite2D = $click_dmg
@onready var recibir_dmg: Button = $recibir_dmg

@export var speed: float = 100.0
@export var attack_damage: float = 10.0
@export var attack_cooldown_time: float = 1.0
@export var attack_range: float = 50.0

var max_health: float
var current_health: float
var target: Node2D
var can_attack: bool = true
var is_attacking: bool = false
var attack_timer: Timer
var cooldown_timer: Timer

# Nuevas variables para controlar estados
var is_dead: bool = false
var is_disappearing: bool = false
var has_dealt_damage: bool = false  # Para evitar daño múltiple


func _ready() -> void:
	max_health = Global.goblin_max_healt
	current_health = max_health
	
	# Configurar barra de vida
	barra_vida.health_depleted.connect(_on_health_depleted)
	barra_vida.max_health = max_health
	barra_vida.current_health = current_health
	
	# Crear timers
	_setup_timers()
	
	# Conectar señales de animación
	if goblin_sprite:
		goblin_sprite.animation_finished.connect(_on_animation_finished)


func _setup_timers():
	# Timer para cooldown de ataque
	cooldown_timer = Timer.new()
	cooldown_timer.one_shot = true
	cooldown_timer.wait_time = attack_cooldown_time
	cooldown_timer.timeout.connect(_on_cooldown_timeout)
	add_child(cooldown_timer)
	
	# Timer para duración de ataque - AUMENTADO para que la animación tenga tiempo
	attack_timer = Timer.new()
	attack_timer.one_shot = true
	attack_timer.wait_time = 0.8  # Aumentado de 0.3 a 0.8 segundos
	attack_timer.timeout.connect(_on_attack_timeout)
	add_child(attack_timer)


@warning_ignore("unused_parameter")
func _physics_process(delta: float) -> void:
	# Si está muerto o desapareciendo, no se mueve
	if is_dead or is_disappearing:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	if not target:
		return
	
	# Si está atacando, no se mueve
	if is_attacking:
		velocity = Vector2.ZERO
		move_and_slide()
		return
	
	# Calcular distancia al objetivo
	var distance = global_position.distance_to(target.global_position)
	
	# Si está en rango de ataque
	if distance <= attack_range:
		# Si puede atacar y no está en cooldown
		if can_attack and not is_attacking:
			_start_attack()
		else:
			# Esperar cooldown
			velocity = Vector2.ZERO
			_update_animation("idle")
	else:
		# Moverse hacia el objetivo
		var direction = (target.global_position - global_position).normalized()
		velocity = direction * speed
		move_and_slide()
		_update_animation("walk")
		_flip_sprite(direction)
		
		# Detectar colisiones mientras se mueve
		_check_collisions()


func _check_collisions():
	"""Verifica colisiones con estructuras"""
	for i in range(get_slide_collision_count()):
		var collision = get_slide_collision(i)
		var collider = collision.get_collider()
		
		# Verificar si el collider es una estructura
		if collider and collider.is_in_group("estructura"):
			# Si colisiona, atacar
			if can_attack and not is_attacking:
				_start_attack_with_target(collider)


func _start_attack():
	"""Inicia ataque contra el target actual"""
	if not target:
		return
	_start_attack_with_target(target)


@warning_ignore("unused_parameter")
func _start_attack_with_target(target_node: Node2D):
	"""Inicia ataque contra un target específico"""
	if is_attacking or not can_attack:
		return
	
	is_attacking = true
	can_attack = false
	has_dealt_damage = false  # Resetear flag de daño
	
	# Reproducir animación de ataque
	_update_animation("attack")
	
	# Iniciar timer para terminar el ataque
	attack_timer.start()


func _on_attack_timeout():
	"""Termina la animación de ataque"""
	is_attacking = false
	
	# Si no se ha aplicado daño aún, aplicarlo ahora (por si acaso)
	if not has_dealt_damage and target and is_instance_valid(target):
		_deal_damage(target)
		has_dealt_damage = true
	
	# Volver a idle
	_update_animation("idle")
	# Iniciar cooldown
	cooldown_timer.start()


func _on_cooldown_timeout():
	"""Termina el cooldown, permite atacar de nuevo"""
	can_attack = true


func _deal_damage(target_node: Node2D):
	"""Aplica daño a la estructura"""
	if has_dealt_damage:
		return  # Evitar daño múltiple
	
	if not target_node or not is_instance_valid(target_node):
		return
	
	has_dealt_damage = true
	
	print("Goblin atacando a: ", target_node.name)
	
	# Buscar el nodo estructura (puede ser el nodo o su padre)
	var structure = target_node
	if not structure.is_in_group("estructura"):
		# Buscar en el padre
		if target_node.get_parent() and target_node.get_parent().is_in_group("estructura"):
			structure = target_node.get_parent()
		else:
			# Buscar en hijos
			for child in target_node.get_children():
				if child.is_in_group("estructura"):
					structure = child
					break
	
	# Aplicar daño si tiene el método
	if structure.has_method("take_damage"):
		structure.take_damage(attack_damage)
		print("Daño aplicado: ", attack_damage)
	else:
		print("La estructura no tiene método take_damage")


func _update_animation(animation_name: String):
	if not goblin_sprite:
		return
	
	var animations = goblin_sprite.sprite_frames.get_animation_names()
	if animation_name in animations:
		if goblin_sprite.animation != animation_name:
			goblin_sprite.play(animation_name)


func _flip_sprite(direction: Vector2):
	if not goblin_sprite:
		return
	
	if direction.x < 0:
		goblin_sprite.flip_h = true
	elif direction.x > 0:
		goblin_sprite.flip_h = false


func _on_animation_finished():
	if goblin_sprite:
		# Si terminó la animación de muerte, quedarse quieto
		if goblin_sprite.animation == "die":
			# No hacemos nada, el goblin queda en el frame final
			pass
		# Si terminó la animación de desaparición, eliminar
		elif goblin_sprite.animation == "disapear":
			queue_free()
		# Si terminó la animación de ataque
		elif goblin_sprite.animation == "attack":
			# Aplicar daño en el momento exacto que termina la animación
			if not has_dealt_damage and target and is_instance_valid(target):
				_deal_damage(target)
			# Nota: El attack_timer también manejará el fin del ataque
			# pero esto asegura que el daño se aplique incluso si el timer falla


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
	died.emit()
	
	# Reproducir animación de muerte
	_update_animation("die")
	recibir_dmg.hide()
	recibir_dmg.disabled = true
	barra_vida.hide()
	
	# Detener movimiento
	velocity = Vector2.ZERO
	set_physics_process(false)


func start_disappear():
	"""Inicia la animación de desaparición cuando termina la wave"""
	if is_dead and not is_disappearing:
		is_disappearing = true
		# Reproducir animación de desaparición
		_update_animation("disapear")
		# Reactivar physics process para que la animación pueda terminar
		set_physics_process(true)


func set_target(target_node: Node2D):
	target = target_node


func _on_recibir_dmg_pressed():
	click_dmg.play("fuego")
	await click_dmg.animation_finished
	take_damage(Global.player_click_dmg)
