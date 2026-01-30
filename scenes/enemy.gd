extends CharacterBody2D

# --- CONFIGURATION (Fixed Nil error by adding = 0.0) ---
@export var speed: float = 120.0
@export var jump_velocity: float = -350.0
@export var damage_amount: int = 15
@export var attack_cooldown: float = 1.2
@export var stopping_distance: float = 55.0 
@export var max_health: int = 50

# --- STATE MACHINE ---
enum State { PATROL, CHASE, ATTACKING, DEAD }
var current_state = State.PATROL

var player = null
var can_attack = true
var current_health: int = 50

@onready var sprite = $AnimatedSprite2D
@onready var floor_checker = $FloorChecker 

func _ready():
	current_health = max_health
	add_to_group("Enemy")

func _physics_process(delta: float) -> void:
	if current_state == State.DEAD:
		return

	if not is_on_floor():
		velocity += get_gravity() * delta
	else:
		velocity.y = 10 

	match current_state:
		State.PATROL: _patrol_logic()
		State.CHASE: _chase_logic()
		State.ATTACKING: velocity.x = move_toward(velocity.x, 0, speed)

	move_and_slide()

# --- MOVEMENT BEHAVIORS ---

func _patrol_logic():
	if not sprite.is_playing() or sprite.animation != "run":
		sprite.play("run")
		
	var direction = -1 if sprite.flip_h else 1
	velocity.x = direction * (speed * 0.5)
	
	if is_on_wall() or (is_on_floor() and not floor_checker.is_colliding()):
		sprite.flip_h = !sprite.flip_h
		floor_checker.position.x *= -1 

func _chase_logic():
	if not player:
		current_state = State.PATROL
		return

	# Fixed the typo here: changed dir_x_to_player to dist_to_player
	var dist_to_player = player.global_position.x - global_position.x
	var dir = sign(dist_to_player)
	
	sprite.flip_h = dir < 0
	floor_checker.position.x = abs(floor_checker.position.x) * dir

	if abs(dist_to_player) > stopping_distance:
		velocity.x = dir * speed
		sprite.play("run")
		if is_on_floor() and (is_on_wall() or not floor_checker.is_colliding()):
			velocity.y = jump_velocity
	else:
		velocity.x = move_toward(velocity.x, 0, speed)
		sprite.play("idle")

# --- HEALTH & DAMAGE ---

func take_damage(amount: int):
	if current_state == State.DEAD: return
	current_health -= amount
	
	sprite.modulate = Color.RED
	await get_tree().create_timer(0.1).timeout
	sprite.modulate = Color.WHITE
	
	if current_health <= 0:
		die()

func die():
	current_state = State.DEAD
	velocity = Vector2.ZERO
	sprite.play("death")
	collision_layer = 0
	collision_mask = 0
	await sprite.animation_finished
	queue_free()

# --- SIGNALS ---

func _on_attack_area_body_entered(body):
	if body.is_in_group("Player") and can_attack:
		_perform_attack(body)

func _perform_attack(target):
	current_state = State.ATTACKING
	can_attack = false
	sprite.play("attack")
	await get_tree().create_timer(0.4).timeout 
	if is_instance_valid(target) and global_position.distance_to(target.global_position) < stopping_distance + 20:
		target.take_damage(damage_amount)
	await get_tree().create_timer(attack_cooldown).timeout
	can_attack = true
	if current_state != State.DEAD: current_state = State.CHASE

func _on_detection_area_body_entered(body):
	if body.is_in_group("Player"):
		player = body
		current_state = State.CHASE

func _on_detection_area_body_exited(body):
	if body == player:
		player = null
		current_state = State.PATROL
