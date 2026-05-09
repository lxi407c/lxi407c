extends Node2D

enum State { MENU, PLAYING, GAME_OVER }

const SCREEN_W = 480
const SCREEN_H = 720
const PLAYER_SPEED = 300
const ROCK_SPEED_START = 200
const ROCK_SPAWN_INTERVAL = 1.0
const SAVE_PATH = "user://highscore.dat"

const COIN_SPAWN_MIN = 3.0
const COIN_SPAWN_MAX = 6.0
const COIN_SCORE_BONUS = 10
const SHIELD_SPAWN_MIN = 8.0
const SHIELD_SPAWN_MAX = 15.0
const SHIELD_DURATION = 3.0
const ITEM_SPEED = 120.0

var state: State = State.MENU

var player: ColorRect
var score_label: Label
var life_label: Label
var highscore_label: Label
var shield_label: Label

# 메뉴 UI
var menu_panel: CanvasLayer
var menu_title: Label
var menu_best: Label
var menu_start_btn: Button

# 게임오버 UI
var gameover_panel: CanvasLayer
var gameover_title: Label
var gameover_score: Label
var gameover_best: Label
var gameover_restart_btn: Button

var rocks: Array = []
var coins: Array = []
var shield_items: Array = []

var score: float = 0.0
var lives: int = 3
var rock_speed: float = ROCK_SPEED_START
var spawn_timer: float = 0.0
var invincible_timer: float = 0.0
var coin_spawn_timer: float = 0.0
var shield_spawn_timer: float = 0.0
var shield_active: float = 0.0
var high_score: int = 0

var touch_target: Vector2 = Vector2(-1, -1)
var is_touching: bool = false

# 효과음용 오디오 플레이어
var audio_hit: AudioStreamPlayer
var audio_gameover: AudioStreamPlayer
var audio_coin: AudioStreamPlayer
var audio_shield: AudioStreamPlayer


func _ready() -> void:
	_load_high_score()
	_setup_background()
	_setup_player()
	_setup_hud()
	_setup_menu_ui()
	_setup_gameover_ui()
	_setup_audio()
	_show_menu()


# ── 배경 ──────────────────────────────────────────────
func _setup_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.1, 0.1, 0.2)
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)


# ── 플레이어 ──────────────────────────────────────────
func _setup_player() -> void:
	player = ColorRect.new()
	player.color = Color(0.2, 0.8, 0.4)
	player.size = Vector2(50, 50)
	player.visible = false
	add_child(player)


# ── HUD (점수/생명) ───────────────────────────────────
func _setup_hud() -> void:
	score_label = Label.new()
	score_label.position = Vector2(10, 10)
	score_label.add_theme_font_size_override("font_size", 24)
	score_label.add_theme_color_override("font_color", Color.WHITE)
	score_label.visible = false
	add_child(score_label)

	life_label = Label.new()
	life_label.position = Vector2(10, 40)
	life_label.add_theme_font_size_override("font_size", 24)
	life_label.add_theme_color_override("font_color", Color(1, 0.3, 0.3))
	life_label.visible = false
	add_child(life_label)

	highscore_label = Label.new()
	highscore_label.position = Vector2(SCREEN_W - 200, 10)
	highscore_label.add_theme_font_size_override("font_size", 22)
	highscore_label.add_theme_color_override("font_color", Color.YELLOW)
	highscore_label.visible = false
	add_child(highscore_label)

	shield_label = Label.new()
	shield_label.position = Vector2(10, 70)
	shield_label.add_theme_font_size_override("font_size", 22)
	shield_label.add_theme_color_override("font_color", Color.CYAN)
	shield_label.visible = false
	add_child(shield_label)


# ── 메인 메뉴 UI ──────────────────────────────────────
func _setup_menu_ui() -> void:
	menu_panel = CanvasLayer.new()
	add_child(menu_panel)

	menu_title = Label.new()
	menu_title.text = "Dodge the Rocks"
	menu_title.add_theme_font_size_override("font_size", 42)
	menu_title.add_theme_color_override("font_color", Color.WHITE)
	menu_title.position = Vector2(SCREEN_W / 2 - 185, SCREEN_H / 2 - 180)
	menu_panel.add_child(menu_title)

	var sub = Label.new()
	sub.text = "돌을 피해 최대한 오래 살아남으세요!"
	sub.add_theme_font_size_override("font_size", 18)
	sub.add_theme_color_override("font_color", Color(0.8, 0.8, 0.8))
	sub.position = Vector2(SCREEN_W / 2 - 175, SCREEN_H / 2 - 120)
	menu_panel.add_child(sub)

	var items_info = Label.new()
	items_info.text = "★ 코인: +%d점   ◆ 방어막: %d초 무적" % [COIN_SCORE_BONUS, int(SHIELD_DURATION)]
	items_info.add_theme_font_size_override("font_size", 16)
	items_info.add_theme_color_override("font_color", Color(0.9, 0.85, 0.4))
	items_info.position = Vector2(SCREEN_W / 2 - 175, SCREEN_H / 2 - 80)
	menu_panel.add_child(items_info)

	menu_best = Label.new()
	menu_best.add_theme_font_size_override("font_size", 24)
	menu_best.add_theme_color_override("font_color", Color.YELLOW)
	menu_best.position = Vector2(SCREEN_W / 2 - 100, SCREEN_H / 2 - 30)
	menu_panel.add_child(menu_best)

	menu_start_btn = Button.new()
	menu_start_btn.text = "게임 시작"
	menu_start_btn.size = Vector2(180, 60)
	menu_start_btn.position = Vector2(SCREEN_W / 2 - 90, SCREEN_H / 2 + 50)
	menu_start_btn.pressed.connect(_start_game)
	menu_panel.add_child(menu_start_btn)

	var ctrl = Label.new()
	ctrl.text = "조작: 방향키 또는 터치/클릭"
	ctrl.add_theme_font_size_override("font_size", 18)
	ctrl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
	ctrl.position = Vector2(SCREEN_W / 2 - 145, SCREEN_H / 2 + 140)
	menu_panel.add_child(ctrl)


# ── 게임오버 UI ───────────────────────────────────────
func _setup_gameover_ui() -> void:
	gameover_panel = CanvasLayer.new()
	gameover_panel.visible = false
	add_child(gameover_panel)

	gameover_title = Label.new()
	gameover_title.text = "GAME OVER"
	gameover_title.add_theme_font_size_override("font_size", 52)
	gameover_title.add_theme_color_override("font_color", Color.RED)
	gameover_title.position = Vector2(SCREEN_W / 2 - 155, SCREEN_H / 2 - 120)
	gameover_panel.add_child(gameover_title)

	gameover_score = Label.new()
	gameover_score.add_theme_font_size_override("font_size", 30)
	gameover_score.add_theme_color_override("font_color", Color.WHITE)
	gameover_score.position = Vector2(SCREEN_W / 2 - 90, SCREEN_H / 2 - 50)
	gameover_panel.add_child(gameover_score)

	gameover_best = Label.new()
	gameover_best.add_theme_font_size_override("font_size", 26)
	gameover_best.add_theme_color_override("font_color", Color.YELLOW)
	gameover_best.position = Vector2(SCREEN_W / 2 - 100, SCREEN_H / 2)
	gameover_panel.add_child(gameover_best)

	gameover_restart_btn = Button.new()
	gameover_restart_btn.text = "다시 시작"
	gameover_restart_btn.size = Vector2(180, 60)
	gameover_restart_btn.position = Vector2(SCREEN_W / 2 - 90, SCREEN_H / 2 + 70)
	gameover_restart_btn.pressed.connect(_start_game)
	gameover_panel.add_child(gameover_restart_btn)

	var menu_btn = Button.new()
	menu_btn.text = "메인 메뉴"
	menu_btn.size = Vector2(180, 60)
	menu_btn.position = Vector2(SCREEN_W / 2 - 90, SCREEN_H / 2 + 145)
	menu_btn.pressed.connect(_show_menu)
	gameover_panel.add_child(menu_btn)


# ── 효과음 (AudioStreamWAV 프로시저럴 생성) ────────────
func _setup_audio() -> void:
	audio_hit = AudioStreamPlayer.new()
	add_child(audio_hit)
	audio_gameover = AudioStreamPlayer.new()
	add_child(audio_gameover)
	audio_coin = AudioStreamPlayer.new()
	add_child(audio_coin)
	audio_shield = AudioStreamPlayer.new()
	add_child(audio_shield)

	_assign_tone(audio_hit, 220.0, 0.15)
	_assign_tone(audio_gameover, 110.0, 0.4)
	_assign_tone(audio_coin, 880.0, 0.12)
	_assign_tone(audio_shield, 440.0, 0.25)


func _assign_tone(player_node: AudioStreamPlayer, freq: float, duration: float) -> void:
	var sample_rate = 22050
	var samples = int(sample_rate * duration)
	var stream = AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = sample_rate
	var data = PackedByteArray()
	data.resize(samples * 2)
	for i in range(samples):
		var t = float(i) / sample_rate
		var envelope = 1.0 - (t / duration)
		var val = int(sin(TAU * freq * t) * envelope * 16000)
		val = clamp(val, -32768, 32767)
		data[i * 2] = val & 0xFF
		data[i * 2 + 1] = (val >> 8) & 0xFF
	stream.data = data
	player_node.stream = stream


# ── 파티클 이펙트 ─────────────────────────────────────
func _spawn_particles(pos: Vector2, color: Color) -> void:
	for i in range(10):
		var p = ColorRect.new()
		p.size = Vector2(8, 8)
		p.color = color
		p.position = pos
		add_child(p)
		var dir = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)).normalized()
		var dist = randf_range(40.0, 120.0)
		var tween = create_tween()
		tween.tween_property(p, "position", pos + dir * dist, 0.5)
		tween.parallel().tween_property(p, "modulate:a", 0.0, 0.5)
		tween.tween_callback(p.queue_free)


# ── 상태 전환 ─────────────────────────────────────────
func _show_menu() -> void:
	state = State.MENU
	menu_best.text = "최고 점수: %d" % high_score
	menu_panel.visible = true
	gameover_panel.visible = false
	score_label.visible = false
	life_label.visible = false
	highscore_label.visible = false
	shield_label.visible = false
	player.visible = false
	_clear_all_objects()


func _start_game() -> void:
	state = State.PLAYING
	score = 0.0
	lives = 3
	rock_speed = ROCK_SPEED_START
	spawn_timer = 0.0
	invincible_timer = 0.0
	coin_spawn_timer = randf_range(COIN_SPAWN_MIN, COIN_SPAWN_MAX)
	shield_spawn_timer = randf_range(SHIELD_SPAWN_MIN, SHIELD_SPAWN_MAX)
	shield_active = 0.0
	touch_target = Vector2(-1, -1)
	is_touching = false

	_clear_all_objects()

	player.position = Vector2(SCREEN_W / 2 - 25, SCREEN_H - 100)
	player.color = Color(0.2, 0.8, 0.4)
	player.modulate.a = 1.0
	player.visible = true

	score_label.visible = true
	life_label.visible = true
	highscore_label.visible = true
	shield_label.visible = true

	menu_panel.visible = false
	gameover_panel.visible = false


func _game_over() -> void:
	state = State.GAME_OVER
	audio_gameover.play()
	player.color = Color(0.2, 0.8, 0.4)

	var final_score = int(score)
	if final_score > high_score:
		high_score = final_score
		_save_high_score()

	gameover_score.text = "점수: %d" % final_score
	gameover_best.text = "최고 점수: %d" % high_score
	gameover_panel.visible = true


func _clear_all_objects() -> void:
	for obj in rocks:
		obj.queue_free()
	rocks.clear()
	for obj in coins:
		obj.queue_free()
	coins.clear()
	for obj in shield_items:
		obj.queue_free()
	shield_items.clear()


# ── 최고 점수 저장/불러오기 ───────────────────────────
func _save_high_score() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()


# ── 입력 ─────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		is_touching = event.pressed
		if event.pressed:
			touch_target = event.position
		else:
			touch_target = Vector2(-1, -1)
	elif event is InputEventScreenDrag:
		touch_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_touching = event.pressed
		if event.pressed:
			touch_target = event.position
		else:
			touch_target = Vector2(-1, -1)
	elif event is InputEventMouseMotion and is_touching:
		touch_target = event.position


# ── 매 프레임 ─────────────────────────────────────────
func _process(delta: float) -> void:
	if state != State.PLAYING:
		if state == State.GAME_OVER and Input.is_action_just_pressed("ui_accept"):
			_start_game()
		return

	_move_player(delta)
	_spawn_rocks(delta)
	_spawn_coins(delta)
	_spawn_shield_items(delta)
	_move_rocks(delta)
	_move_items(delta)
	_check_collisions()
	_update_hud()

	score += delta
	rock_speed = ROCK_SPEED_START + score * 10

	if shield_active > 0:
		shield_active -= delta
		player.color = Color(0.2, 0.6, 1.0)
		player.modulate.a = 1.0
	elif invincible_timer > 0:
		invincible_timer -= delta
		player.color = Color(0.2, 0.8, 0.4)
		player.modulate.a = 0.3 if int(invincible_timer * 10) % 2 == 0 else 1.0
	else:
		player.color = Color(0.2, 0.8, 0.4)
		player.modulate.a = 1.0


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

	if is_touching and touch_target != Vector2(-1, -1):
		var center = player.position + player.size / 2
		var dir = touch_target - center
		if dir.length() > 10:
			velocity = dir.normalized()

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


func _spawn_coins(delta: float) -> void:
	coin_spawn_timer -= delta
	if coin_spawn_timer <= 0:
		coin_spawn_timer = randf_range(COIN_SPAWN_MIN, COIN_SPAWN_MAX)
		var coin = ColorRect.new()
		coin.size = Vector2(28, 28)
		coin.color = Color(1.0, 0.85, 0.1)
		coin.position = Vector2(randf_range(0, SCREEN_W - 28), -28)
		add_child(coin)
		coins.append(coin)


func _spawn_shield_items(delta: float) -> void:
	shield_spawn_timer -= delta
	if shield_spawn_timer <= 0:
		shield_spawn_timer = randf_range(SHIELD_SPAWN_MIN, SHIELD_SPAWN_MAX)
		var shield = ColorRect.new()
		shield.size = Vector2(30, 30)
		shield.color = Color(0.2, 0.7, 1.0)
		shield.position = Vector2(randf_range(0, SCREEN_W - 30), -30)
		add_child(shield)
		shield_items.append(shield)


func _move_rocks(delta: float) -> void:
	for rock in rocks:
		rock.position.y += rock_speed * delta


func _move_items(delta: float) -> void:
	for coin in coins:
		coin.position.y += ITEM_SPEED * delta
	for shield in shield_items:
		shield.position.y += ITEM_SPEED * delta


func _check_collisions() -> void:
	var player_rect = Rect2(player.position, player.size)
	var to_remove: Array = []

	for rock in rocks:
		if rock.position.y > SCREEN_H:
			to_remove.append(rock)
		elif Rect2(rock.position, rock.size).intersects(player_rect) and shield_active <= 0 and invincible_timer <= 0:
			lives -= 1
			invincible_timer = 2.0
			_spawn_particles(player.position + player.size / 2, Color.ORANGE_RED)
			audio_hit.play()
			to_remove.append(rock)
			if lives <= 0:
				_spawn_particles(player.position + player.size / 2, Color.RED)
				_game_over()
				return
		elif Rect2(rock.position, rock.size).intersects(player_rect) and shield_active > 0:
			to_remove.append(rock)

	for rock in to_remove:
		rocks.erase(rock)
		rock.queue_free()

	var coins_to_remove: Array = []
	for coin in coins:
		if coin.position.y > SCREEN_H:
			coins_to_remove.append(coin)
		elif Rect2(coin.position, coin.size).intersects(player_rect):
			score += COIN_SCORE_BONUS
			_spawn_particles(coin.position + coin.size / 2, Color.YELLOW)
			audio_coin.play()
			coins_to_remove.append(coin)
	for coin in coins_to_remove:
		coins.erase(coin)
		coin.queue_free()

	var shields_to_remove: Array = []
	for shield in shield_items:
		if shield.position.y > SCREEN_H:
			shields_to_remove.append(shield)
		elif Rect2(shield.position, shield.size).intersects(player_rect):
			shield_active = SHIELD_DURATION
			invincible_timer = 0.0
			_spawn_particles(shield.position + shield.size / 2, Color.CYAN)
			audio_shield.play()
			shields_to_remove.append(shield)
	for shield in shields_to_remove:
		shield_items.erase(shield)
		shield.queue_free()


func _update_hud() -> void:
	score_label.text = "점수: %d" % int(score)
	life_label.text = "생명: " + "♥ ".repeat(lives)
	highscore_label.text = "최고: %d" % high_score
	if shield_active > 0:
		shield_label.text = "방어막: %.1f초" % shield_active
		shield_label.visible = true
	else:
		shield_label.visible = false
