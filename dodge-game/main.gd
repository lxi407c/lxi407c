extends Node2D

const SCREEN_W = 480
const SCREEN_H = 720
const PLAYER_SPEED = 300
const ROCK_SPEED_START = 200
const ROCK_SPAWN_INTERVAL = 1.0

var player: ColorRect
var score_label: Label
var life_label: Label
var game_over_label: Label
var restart_label: Label

var rocks: Array = []
var score: float = 0.0
var lives: int = 3
var rock_speed: float = ROCK_SPEED_START
var spawn_timer: float = 0.0
var game_running: bool = false
var invincible_timer: float = 0.0


func _ready() -> void:
	_setup_background()
	_setup_player()
	_setup_ui()
	_start_game()


func _setup_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)


func _setup_player() -> void:
	player = ColorRect.new()
	player.color = Color(0.2, 0.8, 0.4)
	player.size = Vector2(50, 50)
	player.position = Vector2(SCREEN_W / 2 - 25, SCREEN_H - 100)
	add_child(player)


func _setup_ui() -> void:
	score_label = Label.new()
	score_label.position = Vector2(10, 10)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	add_child(score_label)

	life_label = Label.new()
	life_label.position = Vector2(10, 40)
	life_label.add_theme_font_size_override("font_size", 24)
	life_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	add_child(life_label)

	game_over_label = Label.new()
	game_over_label.text = "GAME OVER"
	game_over_label.add_theme_font_size_override("font_size", 48)
	game_over_label.add_theme_color_override("font_color", Color.RED)
	game_over_label.position = Vector2(SCREEN_W / 2 - 130, SCREEN_H / 2 - 60)
	game_over_label.visible = false
	add_child(game_over_label)

	restart_label = Label.new()
	restart_label.text = "SPACE 키로 재시작"
	restart_label.add_theme_font_size_override("font_size", 28)
	restart_label.add_theme_color_override("font_color", Color.YELLOW)
	restart_label.position = Vector2(SCREEN_W / 2 - 120, SCREEN_H / 2 + 10)
	restart_label.visible = false
	add_child(restart_label)


func _start_game() -> void:
	score = 0.0
	lives = 3
	rock_speed = ROCK_SPEED_START
	spawn_timer = 0.0
	invincible_timer = 0.0
	game_running = true

	for rock in rocks:
		rock.queue_free()
	rocks.clear()

	player.position = Vector2(SCREEN_W / 2 - 25, SCREEN_H - 100)
	player.color = Color(0.2, 0.8, 0.4)
	game_over_label.visible = false
	restart_label.visible = false


func _process(delta: float) -> void:
	if not game_running:
		if Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	_move_player(delta)
	_spawn_rocks(delta)
	_move_rocks(delta)
	_check_collisions()
	_update_ui()

	score += delta
	rock_speed = ROCK_SPEED_START + score * 10

	if invincible_timer > 0:
		invincible_timer -= delta
		player.color.a = 0.3 if int(invincible_timer * 10) % 2 == 0 else 1.0
	else:
		player.color.a = 1.0


func _move_player(delta: float) -> void:
	var velocity = Vector2.ZERO
	if Input.is_action_pressed("ui_left"):
		velocity.x -= 1
	if Input.is_action_pressed("ui_right"):
		velocity.x += 1
	if Input.is_action_pressed("ui_up"):
		velocity.y -= 1
	if Input.is_action_pressed("ui_down"):
		velocity.y += 1

	player.position += velocity.normalized() * PLAYER_SPEED * delta
	player.position.x = clamp(player.position.x, 0, SCREEN_W - player.size.x)
	player.position.y = clamp(player.position.y, 0, SCREEN_H - player.size.y)


func _spawn_rocks(delta: float) -> void:
	spawn_timer -= delta
	if spawn_timer <= 0:
		spawn_timer = max(0.3, ROCK_SPAWN_INTERVAL - score * 0.01)
		var rock = ColorRect.new()
		var size = randf_range(20, 50)
		rock.size = Vector2(size, size)
		rock.color = Color(randf_range(0.5, 1.0), randf_range(0.2, 0.5), 0.1)
		rock.position = Vector2(randf_range(0, SCREEN_W - size), -size)
		add_child(rock)
		rocks.append(rock)


func _move_rocks(delta: float) -> void:
	for rock in rocks:
		rock.position.y += rock_speed * delta


func _check_collisions() -> void:
	var player_rect = Rect2(player.position, player.size)
	var to_remove = []

	for rock in rocks:
		var rock_rect = Rect2(rock.position, rock.size)
		if rock.position.y > SCREEN_H:
			to_remove.append(rock)
		elif player_rect.intersects(rock_rect) and invincible_timer <= 0:
			lives -= 1
			invincible_timer = 2.0
			to_remove.append(rock)
			if lives <= 0:
				_game_over()
				return

	for rock in to_remove:
		rocks.erase(rock)
		rock.queue_free()


func _update_ui() -> void:
	score_label.text = "점수: %d" % int(score)
	life_label.text = "생명: " + "♥ ".repeat(lives)


func _game_over() -> void:
	game_running = false
	game_over_label.visible = true
	restart_label.visible = true
	restart_label.text = "최종 점수: %d\nSPACE 키로 재시작" % int(score)
