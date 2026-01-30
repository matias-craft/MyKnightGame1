extends CharacterBody2D

# --- CONFIGURATION ---
const SPEED = 300.0
const JUMP_VELOCITY = -300.0
const DASH_SPEED = 900.0
const DASH_DURATION = 0.2
const DASH_COOLDOWN = 1.0
const SLIDE_SPEED = 500.0
const SLIDE_DURATION = 0.4

# Preload your ghost scene for dashing
const GHOST_SCENE = preload("res://scenes/dash_ghost.tscn")

# --- STATES ---
var is_dashing = false
var can_dash = true
var is_attacking = false
var is_sliding = false
var is_dead = false

# --- HEALTH ---
var max_health: int = 100
var current_health: int = max_health

# --- NODE REFERENCES ---
@onready var animated_sprite: AnimatedSprite2D = $AnimatedSprite2D
@onready var sword_hitbox = $SwordArea/CollisionShape2D
@onready var world_collision = $CollisionShape2D 

# Searches the scene for the "PlayerHealthBar" node (must be in CanvasLayer)
@onready var health_bar = get_tree().current_scene.find_child("PlayerHealthBar", true, false)

func _ready() -> void:
	# Debug check for health bar
	if health_bar:
		print("SUCCESS: PlayerHealthBar found!")
		health_bar.max_value = max_health
		health_bar.value = current_health
	else:
		print("ERROR: PlayerHealthBar NOT found. Make sure it is named 'PlayerHealthBar'!")

func _physics_process(delta: float) -> void:
	if is_dead: return 

	# 1. Action Priorities (Stop movement if attacking/dashing)
	if is_attacking:
		animated_sprite.play("attack")
		velocity.x = move_toward(velocity.x, 0, SPEED * delta)
		move_and_slide()
		return

	if is_dashing:
		add_ghost()
		move_and_slide()
		return
		
	if is_sliding:
		animated_sprite.play("slide")
		move_and_slide()
		return

	# 2. Gravity & Jumping
	if not is_on_floor():
		velocity += get_gravity() * delta

	if Input.is_action_just_pressed("jump") and is_on_floor():
		velocity.y = JUMP_VELOCITY

	# 3. Special Ability Inputs
	if Input.is_action_just_pressed("dash") and can_dash:
		start_dash(Input.get_axis("move_left", "move_right"))
		
	if Input.is_action_just_pressed("attack") and not is_attacking:
		attack()
		
	if Input.is_action_just_pressed("slide") and is_on_floor() and not is_sliding:
		start_slide()

	# 4. Basic Movement Logic
	var direction := Input.get_axis("move_left", "move_right")
	
	# Sprite Flipping
	if direction > 0:
		animated_sprite.flip_h = false
		$SwordArea.scale.x = 1
	elif direction < 0:
		animated_sprite.flip_h = true
		$SwordArea.scale.x = -1
	
	# Walking Animations
	if is_on_floor():
		if direction == 0:
			animated_sprite.play("idle")
		else:
			animated_sprite.play("run")
	else:
		animated_sprite.play("jump")
	
	if direction:
		velocity.x = direction * SPEED
	else:
		velocity.x = move_toward(velocity.x, 0, SPEED)

	move_and_slide()

# --- HEALTH & DAMAGE ---

func take_damage(amount: int) -> void:
	if is_dead: return
	
	current_health -= amount
	print("Player Health: ", current_health)
	
	# Update UI Bar
	if health_bar:
		health_bar.value = current_health
	
	# Hit Flash (Visual Feedback)
	animated_sprite.modulate = Color(1, 0, 0) # Flash Red
	await get_tree().create_timer(0.1).timeout
	animated_sprite.modulate = Color(1, 1, 1) # Reset to Normal
	
	if current_health <= 0:
		die()

func die() -> void:
	is_dead = true
	velocity = Vector2.ZERO 
	animated_sprite.play("death")
	# Wait for death animation, then restart scene
	await get_tree().create_timer(1.2).timeout
	call_deferred("go_to_main_scene")

func go_to_main_scene() -> void:
	# CHANGE THIS PATH to your actual Main Menu scene
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

func _on_deadzone_body_entered(body: Node2D) -> void:
	if body == self:
		call_deferred("go_to_main_scene")

# --- ACTIONS ---

func attack() -> void:
	is_attacking = true
	velocity.y = 0 # Fixes "Wall Jump Boost" glitch
	sword_hitbox.set_deferred("disabled", false)
	await get_tree().create_timer(0.4).timeout # Match your attack animation length
	sword_hitbox.set_deferred("disabled", true)
	is_attacking = false

func start_slide() -> void:
	is_sliding = true
	var slide_dir = -1 if animated_sprite.flip_h else 1
	velocity.x = slide_dir * SLIDE_SPEED
	
	# Shrink Collision Box
	world_collision.scale.y = 0.5
	world_collision.position.y += 10 
	
	await get_tree().create_timer(SLIDE_DURATION).timeout
	
	# Restore Collision Box
	world_collision.scale.y = 1.0
	world_collision.position.y -= 10
	is_sliding = false

func start_dash(dir: float) -> void:
	var dash_dir = dir if dir != 0 else (-1 if animated_sprite.flip_h else 1)
	is_dashing = true
	can_dash = false
	velocity.x = dash_dir * DASH_SPEED
	velocity.y = 0 
	
	if animated_sprite.sprite_frames.has_animation("dash"):
		animated_sprite.play("dash")
	
	await get_tree().create_timer(DASH_DURATION).timeout
	is_dashing = false
	await get_tree().create_timer(DASH_COOLDOWN).timeout
	can_dash = true

func add_ghost() -> void:
	var ghost = GHOST_SCENE.instantiate()
	# Check prevents crash if ghost is wrong type
	if ghost is AnimatedSprite2D:
		ghost.global_transform = animated_sprite.global_transform
		ghost.sprite_frames = animated_sprite.sprite_frames
		ghost.animation = animated_sprite.animation
		ghost.frame = animated_sprite.frame
		ghost.flip_h = animated_sprite.flip_h
		get_tree().current_scene.add_child(ghost)

func _on_sword_area_body_entered(body: Node2D) -> void:
	if body.is_in_group("Enemy") and body.has_method("take_damage"):
		body.take_damage(25)
