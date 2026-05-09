extends Node2D

enum State { TITLE, CHAT, DIALOGUE, PLAYING, GAME_OVER }

const SCREEN_W = 480
const SCREEN_H = 720
const PLAYER_SPEED = 300
const ROCK_SPEED_START = 200
const ROCK_SPAWN_INTERVAL = 1.0
const SAVE_PATH = "user://highscore.dat"
const STANDING_RATIO: float = 1216.0 / 832.0  # standing PNG: 832×1216

var state: State = State.TITLE

var player: TextureRect
var score_label: Label
var life_label: Label
var highscore_label: Label

# 타이틀 UI
var title_panel: CanvasLayer
var title_best_label: Label

# 채팅 UI
var chat_panel: CanvasLayer
var chat_main_view: Control
var chat_topics_view: Control
var chat_response_view: Control
var chat_response_portrait: TextureRect
var chat_response_name_label: Label
var chat_response_text_label: Label
var chat_followup_container: VBoxContainer
var chat_typing_label: Label
var chat_http: HTTPRequest
var chat_messages: Array = []
var chat_is_waiting: bool = false

# 감정 표정 시스템
var emotion_textures: Dictionary = {}
const EMOTION_FILES: Dictionary = {
	"neutral":   "res://assets/standing/normal.png",
	"happy":     "res://assets/standing/happy.png",
	"sad":       "res://assets/standing/sad.png",
	"surprised": "res://assets/standing/surprised.png",
	"angry":     "res://assets/standing/angry.png",
}
# 감정별 배경 이펙트 색조
const EMOTION_BG_MOD: Dictionary = {
	"neutral":   Color(1.00, 1.00, 1.00, 1.0),   # 보라/파랑 (기본)
	"happy":     Color(1.40, 1.05, 0.40, 1.0),   # 황금/따뜻함
	"sad":       Color(0.35, 0.55, 1.70, 1.0),   # 차가운 파랑
	"surprised": Color(0.70, 1.50, 1.50, 1.0),   # 시안/밝음
	"angry":     Color(1.70, 0.28, 0.28, 1.0),   # 붉은 열기
}
# 감정별 글로우 색상
const EMOTION_GLOW_MOD: Dictionary = {
	"neutral":   Color(0.75, 0.55, 1.00, 0.32),
	"happy":     Color(1.00, 0.85, 0.30, 0.32),
	"sad":       Color(0.30, 0.55, 1.00, 0.32),
	"surprised": Color(0.60, 1.00, 1.00, 0.32),
	"angry":     Color(1.00, 0.25, 0.25, 0.32),
}

const EMOTION_OUTLINE_COLOR: Dictionary = {
	"neutral":   Color(0.55, 0.70, 1.00),
	"happy":     Color(1.00, 0.85, 0.30),
	"sad":       Color(0.30, 0.55, 1.00),
	"surprised": Color(0.40, 1.00, 0.90),
	"angry":     Color(1.00, 0.35, 0.20),
}

var chat_bg_effect: TextureRect
var chat_portrait_glow: TextureRect
var chat_text_scroll: ScrollContainer
var portrait_shader_mat: ShaderMaterial

# 인트로 대화 UI
var dialogue_panel: CanvasLayer
var dialogue_name_label: Label
var dialogue_text_label: Label
var dialogue_index: int = 0

# 게임오버 UI
var gameover_panel: CanvasLayer
var gameover_score: Label
var gameover_best: Label

var rocks: Array = []
var score: float = 0.0
var lives: int = 3
var rock_speed: float = ROCK_SPEED_START
var spawn_timer: float = 0.0
var invincible_timer: float = 0.0
var high_score: int = 0
var api_key: String = ""

var touch_target: Vector2 = Vector2(-1, -1)
var is_touching: bool = false

var audio_hit: AudioStreamPlayer
var audio_gameover: AudioStreamPlayer

const INTRO_LINES: Array = [
	["???", "이 우주 어딘가에서... 돌덩이들이 끊임없이 쏟아지고 있어."],
	["???", "처음엔 나도 무서웠어. 하지만 이제는... 익숙해졌달까?"],
	["마법사", "아, 미안. 자기소개가 늦었네. 나는 이 구역 담당 마법사야."],
	["마법사", "규칙은 간단해. 돌을 피하면서 최대한 오래 버티는 거야."],
	["마법사", "실력껏 해봐. 나는 믿고 있을게!"],
]

const SYSTEM_PROMPT = """너는 우주 마법소녀 캐릭터야. 이름은 '마법사'고, 돌 피하기 게임의 안내자야.
한국어 반말로 친근하고 발랄하게 대화해. 가끔 마법이나 우주 관련 드립을 섞어도 좋아.
이모지 적당히 써도 좋아.
반드시 아래 JSON 형식으로만 답변해. 다른 텍스트 없이 JSON만 출력해:
{"reply": "캐릭터 대사 (2~3문장)", "choices": ["선택지1", "선택지2", "선택지3"]}
reply는 현재 질문에 대한 대답이고, choices는 이 대화에서 자연스럽게 이어질 수 있는 짧은 반응이나 질문 2~3개야."""

const CHAT_TOPICS: Array = [
	{
		"label": "안녕, 잘 지냈어?",
		"message": "안녕, 잘 지냈어?",
		"followups": ["요즘 어때?", "여기 생활은 어때?", "심심하지 않아?"]
	},
	{
		"label": "마법 이야기 해줘",
		"message": "마법 이야기 해줘!",
		"followups": ["어떤 마법 써?", "마법 배우려면?", "마법으로 뭘 할 수 있어?"]
	},
	{
		"label": "오늘 기분이 어때?",
		"message": "오늘 기분이 어때?",
		"followups": ["무슨 일 있었어?", "뭐 하고 싶어?", "좋아하는 게 뭐야?"]
	},
	{
		"label": "게임 얘기해줘",
		"message": "이 게임에 대해 얘기해줘!",
		"followups": ["제일 어려운 게 뭐야?", "기록 어떻게 높여?", "돌 말고 다른 건 없어?"]
	},
	{
		"label": "나에 대해 어떻게 생각해?",
		"message": "나에 대해 어떻게 생각해?",
		"followups": ["나 잘하고 있어?", "뭐가 부족해 보여?", "칭찬 한마디만 해줘!"]
	},
]


func _ready() -> void:
	_load_high_score()
	_load_api_key()
	_load_emotion_textures()
	_setup_background()
	_setup_player()
	_setup_hud()
	_setup_title_ui()
	_setup_chat_ui()
	_setup_dialogue_ui()
	_setup_gameover_ui()
	_setup_audio()
	_show_title()


func _load_emotion_textures() -> void:
	for emotion in EMOTION_FILES:
		var path = EMOTION_FILES[emotion]
		if ResourceLoader.exists(path):
			emotion_textures[emotion] = load(path) as Texture2D
		else:
			emotion_textures[emotion] = load("res://assets/sd/player.png") as Texture2D


func _detect_emotion(text: String) -> String:
	var t = text.to_lower()
	# 기쁨
	if t.contains("ㅎㅎ") or t.contains("ㅋㅋ") or t.contains("신나") or t.contains("좋아") \
	or t.contains("기뻐") or t.contains("재밌") or t.contains("최고") or t.contains("파이팅") \
	or t.contains("😊") or t.contains("🎉") or t.contains("✨") or t.contains("😄"):
		return "happy"
	# 슬픔
	if t.contains("슬프") or t.contains("힘들") or t.contains("속상") or t.contains("안타깝") \
	or t.contains("미안") or t.contains("😢") or t.contains("😭") or t.contains("울"):
		return "sad"
	# 놀람
	if t.contains("헐") or t.contains("어머") or t.contains("진짜?") or t.contains("정말?") \
	or t.contains("놀라") or t.contains("😮") or t.contains("😲") or t.contains("와!"):
		return "surprised"
	# 화남
	if t.contains("짜증") or t.contains("싫어") or t.contains("😠") or t.contains("어이없") \
	or t.contains("😤") or t.contains("화가"):
		return "angry"
	return "neutral"


func _set_portrait_emotion(emotion: String) -> void:
	if chat_response_portrait and emotion_textures.has(emotion):
		chat_response_portrait.texture = emotion_textures[emotion]
	if portrait_shader_mat:
		portrait_shader_mat.set_shader_parameter("outline_color",
			EMOTION_OUTLINE_COLOR.get(emotion, EMOTION_OUTLINE_COLOR["neutral"]))
	if chat_portrait_glow and emotion_textures.has(emotion):
		chat_portrait_glow.texture = emotion_textures[emotion]
		chat_portrait_glow.modulate = EMOTION_GLOW_MOD.get(emotion, EMOTION_GLOW_MOD["neutral"])
	if chat_bg_effect:
		chat_bg_effect.modulate = EMOTION_BG_MOD.get(emotion, EMOTION_BG_MOD["neutral"])


func _load_api_key() -> void:
	if FileAccess.file_exists("res://api_key.txt"):
		var file = FileAccess.open("res://api_key.txt", FileAccess.READ)
		if file:
			api_key = file.get_as_text().strip_edges()


# ── 디자인 헬퍼 ───────────────────────────────────────
func _btn_style(bg: Color, border: Color, radius: int = 12) -> StyleBoxFlat:
	var s = StyleBoxFlat.new()
	s.bg_color = bg
	s.border_width_left = 1
	s.border_width_right = 1
	s.border_width_top = 1
	s.border_width_bottom = 1
	s.border_color = border
	s.corner_radius_top_left = radius
	s.corner_radius_top_right = radius
	s.corner_radius_bottom_left = radius
	s.corner_radius_bottom_right = radius
	s.content_margin_left = 14
	s.content_margin_right = 14
	s.content_margin_top = 8
	s.content_margin_bottom = 8
	return s


func _style_btn(btn: Button, accent: Color = Color(0.35, 0.65, 1.0)) -> void:
	btn.add_theme_stylebox_override("normal",
		_btn_style(Color(0.07, 0.10, 0.26, 0.88), Color(accent.r, accent.g, accent.b, 0.50)))
	btn.add_theme_stylebox_override("hover",
		_btn_style(Color(0.15, 0.26, 0.55, 0.96), Color(accent.r, accent.g, accent.b, 1.0)))
	btn.add_theme_stylebox_override("pressed",
		_btn_style(Color(0.25, 0.45, 0.85, 1.00), Color(1.0, 1.0, 1.0, 0.6)))
	btn.add_theme_stylebox_override("focus",
		_btn_style(Color(0.07, 0.10, 0.26, 0.88), Color(accent.r, accent.g, accent.b, 0.9)))
	btn.add_theme_color_override("font_color",         Color(0.88, 0.94, 1.00))
	btn.add_theme_color_override("font_hover_color",   Color(1.00, 1.00, 1.00))
	btn.add_theme_color_override("font_pressed_color", Color(1.00, 1.00, 1.00))
	btn.add_theme_font_size_override("font_size", 18)


func _add_space_bg(parent: Node, base_color: Color = Color(0.04, 0.05, 0.12)) -> void:
	var bg = ColorRect.new()
	bg.color = base_color
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(bg)
	var rng = RandomNumberGenerator.new()
	rng.seed = 99
	for i in range(70):
		var star = ColorRect.new()
		var sz = rng.randf_range(0.8, 2.2)
		star.size = Vector2(sz, sz)
		star.color = Color(1, 1, 1, rng.randf_range(0.25, 0.85))
		star.position = Vector2(rng.randf_range(0, SCREEN_W), rng.randf_range(0, SCREEN_H))
		star.mouse_filter = Control.MOUSE_FILTER_IGNORE
		parent.add_child(star)


func _make_blur_material(blur_px: float = 8.0) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float blur_px : hint_range(1.0, 20.0) = 8.0;
void fragment() {
    vec4 col = vec4(0.0);
    float wt  = 0.0;
    for (int x = -3; x <= 3; x++) {
        for (int y = -3; y <= 3; y++) {
            float w   = exp(-float(x*x + y*y) * 0.15);
            vec2  uv  = UV + vec2(float(x), float(y)) * TEXTURE_PIXEL_SIZE * blur_px;
            vec4  s   = vec4(0.0);
            if (uv.x >= 0.0 && uv.y >= 0.0 && uv.x <= 1.0 && uv.y <= 1.0)
                s = texture(TEXTURE, uv);
            // 프리멀티플라이: 투명 픽셀 흰 RGB가 블러에 섞이지 않도록
            col += vec4(s.rgb * s.a, s.a) * w;
            wt  += w;
        }
    }
    vec4 res  = col / wt;
    COLOR.a   = res.a;
    COLOR.rgb = (res.a > 0.001) ? res.rgb / res.a : vec3(0.0);
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("blur_px", blur_px)
	return mat


func _make_outline_material(c: Color, px: float = 14.0) -> ShaderMaterial:
	var sh = Shader.new()
	sh.code = """
shader_type canvas_item;
uniform float outline_px    : hint_range(0.0, 40.0) = 14.0;
uniform vec4  outline_color : source_color = vec4(0.55, 0.70, 1.0, 1.0);

void vertex() {
    // quad를 outline_px 픽셀 바깥으로 확장 — 경계 clipping 방지
    VERTEX += (UV * 2.0 - 1.0) * outline_px;
}

void fragment() {
    vec4 orig = vec4(0.0);
    if (UV.x > 0.0 && UV.y > 0.0 && UV.x < 1.0 && UV.y < 1.0)
        orig = texture(TEXTURE, UV);

    if (orig.a > 0.05) {
        COLOR = orig;
    } else {
        // 소프트 글로우: 4중 링 원형 샘플링 (Gaussian 가중치)
        float total = 0.0;
        float wt    = 0.0;
        for (int ri = 1; ri <= 4; ri++) {
            float r = TEXTURE_PIXEL_SIZE.x * outline_px * float(ri) * 0.25;
            float rw = exp(-float(ri * ri) * 0.45);
            for (int si = 0; si < 16; si++) {
                float angle = float(si) * TAU / 16.0;
                vec2 uv = UV + vec2(cos(angle), sin(angle)) * r;
                if (uv.x > 0.0 && uv.y > 0.0 && uv.x < 1.0 && uv.y < 1.0)
                    total += texture(TEXTURE, uv).a * rw;
                wt += rw;
            }
        }
        float glow = clamp(total / wt * 5.5, 0.0, 1.0);
        if (glow > 0.002) {
            COLOR = vec4(outline_color.rgb, glow * outline_color.a);
        } else {
            discard;
        }
    }
}
"""
	var mat = ShaderMaterial.new()
	mat.shader = sh
	mat.set_shader_parameter("outline_px", px)
	mat.set_shader_parameter("outline_color", c)
	return mat


func _add_btn_shine(btn: Button, parent: Node) -> void:
	var shine = ColorRect.new()
	shine.color = Color(1, 1, 1, 0.14)
	shine.size = Vector2(btn.size.x - 2, ceil(btn.size.y * 0.42))
	shine.position = Vector2(btn.position.x + 1, btn.position.y + 1)
	shine.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(shine)


func _add_portrait_fade(parent: Node, clip_h: float, fade_h: float, bg: Color) -> void:
	var fade = TextureRect.new()
	var gtex = GradientTexture2D.new()
	var grad = Gradient.new()
	grad.set_color(0, Color(bg.r, bg.g, bg.b, 0.0))
	grad.set_color(1, Color(bg.r, bg.g, bg.b, 1.0))
	gtex.gradient = grad
	gtex.fill_from = Vector2(0.5, 0.0)
	gtex.fill_to   = Vector2(0.5, 1.0)
	fade.texture = gtex
	fade.stretch_mode = TextureRect.STRETCH_SCALE
	fade.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	fade.size     = Vector2(SCREEN_W, fade_h)
	fade.position = Vector2(0, clip_h - fade_h)
	fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(fade)


# ── 배경 ──────────────────────────────────────────────
func _setup_background() -> void:
	var bg = ColorRect.new()
	bg.color = Color(0.06, 0.06, 0.14)
	bg.size = Vector2(SCREEN_W, SCREEN_H)
	add_child(bg)
	var rng = RandomNumberGenerator.new()
	rng.seed = 42
	for i in range(60):
		var star = ColorRect.new()
		var sz = rng.randf_range(1.0, 2.5)
		star.size = Vector2(sz, sz)
		star.color = Color(1, 1, 1, rng.randf_range(0.3, 0.9))
		star.position = Vector2(rng.randf_range(0, SCREEN_W), rng.randf_range(0, SCREEN_H))
		add_child(star)


# ── 플레이어 ──────────────────────────────────────────
func _setup_player() -> void:
	player = TextureRect.new()
	player.texture = load("res://assets/sd/player.png") as Texture2D
	player.stretch_mode = TextureRect.STRETCH_SCALE
	player.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	player.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	player.visible = false
	add_child(player)
	player.size = Vector2(80, 80)


# ── HUD ───────────────────────────────────────────────
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


# ── 타이틀 화면 ───────────────────────────────────────
func _setup_title_ui() -> void:
	title_panel = CanvasLayer.new()
	title_panel.visible = false
	add_child(title_panel)

	# 우주 배경 (별 + 다크 블루)
	_add_space_bg(title_panel, Color(0.04, 0.05, 0.12))

	# 상단 그라데이션 오버레이 (분위기)
	var top_fade = TextureRect.new()
	var tgtex = GradientTexture2D.new()
	var tgrad = Gradient.new()
	tgrad.set_color(0, Color(0.08, 0.04, 0.18, 0.85))
	tgrad.set_color(1, Color(0.04, 0.05, 0.12, 0.0))
	tgtex.gradient = tgrad
	tgtex.fill_from = Vector2(0.5, 0.0)
	tgtex.fill_to   = Vector2(0.5, 1.0)
	top_fade.texture = tgtex
	top_fade.stretch_mode = TextureRect.STRETCH_SCALE
	top_fade.expand_mode  = TextureRect.EXPAND_IGNORE_SIZE
	top_fade.size = Vector2(SCREEN_W, 380)
	top_fade.position = Vector2(0, 0)
	top_fade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	title_panel.add_child(top_fade)

	# SD 캐릭터 (상단 우측 — mockup 기준)
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/sd/player.png") as Texture2D
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.size = Vector2(270, 270)
	portrait.position = Vector2(SCREEN_W - 282, 20)
	portrait.material = _make_outline_material(EMOTION_OUTLINE_COLOR["neutral"], 10.0)
	title_panel.add_child(portrait)

	# "Dodge" 뒤 블룸 레이어 (넓은 outline → 번지는 글로우 효과)
	var dodge_bloom = Label.new()
	dodge_bloom.text = "Dodge"
	dodge_bloom.add_theme_font_size_override("font_size", 64)
	dodge_bloom.add_theme_color_override("font_color", Color(0.40, 0.78, 1.0, 0.0))
	dodge_bloom.add_theme_constant_override("outline_size", 22)
	dodge_bloom.add_theme_color_override("font_outline_color", Color(0.35, 0.72, 1.0, 0.40))
	dodge_bloom.position = Vector2(24, 92)
	title_panel.add_child(dodge_bloom)

	# "Dodge" — 실제 텍스트 (solid outline glow)
	var dodge_lbl = Label.new()
	dodge_lbl.text = "Dodge"
	dodge_lbl.add_theme_font_size_override("font_size", 64)
	dodge_lbl.add_theme_color_override("font_color", Color(0.96, 0.99, 1.0))
	dodge_lbl.add_theme_constant_override("outline_size", 8)
	dodge_lbl.add_theme_color_override("font_outline_color", Color(0.50, 0.85, 1.0, 1.0))
	dodge_lbl.add_theme_color_override("font_shadow_color", Color(0.25, 0.60, 1.0, 0.70))
	dodge_lbl.add_theme_constant_override("shadow_offset_x", 0)
	dodge_lbl.add_theme_constant_override("shadow_offset_y", 0)
	dodge_lbl.add_theme_constant_override("shadow_outline_size", 12)
	dodge_lbl.position = Vector2(24, 92)
	title_panel.add_child(dodge_lbl)

	# "the Rocks" — 보조 텍스트
	var rocks_lbl = Label.new()
	rocks_lbl.text = "the Rocks"
	rocks_lbl.add_theme_font_size_override("font_size", 38)
	rocks_lbl.add_theme_color_override("font_color", Color(0.75, 0.86, 1.0))
	rocks_lbl.position = Vector2(26, 166)
	title_panel.add_child(rocks_lbl)

	# 서브타이틀 (#6B9FE0) — 겹침 방지 위해 아래로
	var sub = Label.new()
	sub.text = "돌을 피해 살아남아라!"
	sub.add_theme_font_size_override("font_size", 17)
	sub.add_theme_color_override("font_color", Color(0.42, 0.62, 0.88))
	sub.position = Vector2(26, 260)
	title_panel.add_child(sub)

	# 최고 점수 (#D4AF37)
	title_best_label = Label.new()
	title_best_label.add_theme_font_size_override("font_size", 18)
	title_best_label.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))
	title_best_label.position = Vector2(26, 288)
	title_panel.add_child(title_best_label)

	# 구분선
	var div = ColorRect.new()
	div.color = Color(0.12, 0.23, 0.48, 0.8)
	div.size = Vector2(200, 1)
	div.position = Vector2(24, 316)
	title_panel.add_child(div)

	# 버튼들
	var play_btn = Button.new()
	play_btn.text = "▶  게임 시작"
	play_btn.size = Vector2(220, 58)
	play_btn.position = Vector2(24, 380)
	play_btn.pressed.connect(_start_intro)
	_style_btn(play_btn, Color(0.18, 0.80, 0.44))
	title_panel.add_child(play_btn)
	_add_btn_shine(play_btn, title_panel)

	var chat_btn = Button.new()
	chat_btn.text = "💬  캐릭터와 대화"
	chat_btn.size = Vector2(220, 58)
	chat_btn.position = Vector2(24, 454)
	chat_btn.pressed.connect(_show_chat)
	_style_btn(chat_btn, Color(0.53, 0.33, 1.0))
	title_panel.add_child(chat_btn)
	_add_btn_shine(chat_btn, title_panel)


# ── 채팅 화면 ────────────────────────────────────────
func _setup_chat_ui() -> void:
	chat_panel = CanvasLayer.new()
	chat_panel.visible = false
	add_child(chat_panel)

	_add_space_bg(chat_panel, Color(0.04, 0.05, 0.13))

	# HTTPRequest
	chat_http = HTTPRequest.new()
	chat_panel.add_child(chat_http)
	chat_http.request_completed.connect(_on_chat_response)

	_setup_chat_main_view()
	_setup_chat_topics_view()
	_setup_chat_response_view()


func _setup_chat_main_view() -> void:
	chat_main_view = Control.new()
	chat_main_view.size = Vector2(SCREEN_W, SCREEN_H)
	chat_panel.add_child(chat_main_view)

	# 뒤로가기
	var back_btn = Button.new()
	back_btn.text = "← 타이틀"
	back_btn.size = Vector2(120, 44)
	back_btn.position = Vector2(12, 12)
	back_btn.pressed.connect(_show_title)
	_style_btn(back_btn, Color(0.5, 0.5, 0.7))
	chat_main_view.add_child(back_btn)

	# 캐릭터 초상화 (mockup: 200×200, 중앙 상단)
	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/sd/player.png") as Texture2D
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.size = Vector2(200, 200)
	portrait.position = Vector2(SCREEN_W / 2 - 100, 50)
	portrait.material = _make_outline_material(EMOTION_OUTLINE_COLOR["neutral"], 10.0)
	chat_main_view.add_child(portrait)

	# 캐릭터 이름 (mockup: 중앙, white, y=276)
	var name_lbl = Label.new()
	name_lbl.text = "마법사"
	name_lbl.add_theme_font_size_override("font_size", 26)
	name_lbl.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	name_lbl.position = Vector2(SCREEN_W / 2 - 30, 264)
	chat_main_view.add_child(name_lbl)

	# 서브타이틀 (mockup: #6B9FE0, y=304)
	var sub_lbl = Label.new()
	sub_lbl.text = "우주 구역 담당 마법사"
	sub_lbl.add_theme_font_size_override("font_size", 15)
	sub_lbl.add_theme_color_override("font_color", Color(0.42, 0.62, 0.88))
	sub_lbl.position = Vector2(SCREEN_W / 2 - 80, 296)
	chat_main_view.add_child(sub_lbl)

	# 구분선 (mockup: #2A4A8A, y=324)
	var line = ColorRect.new()
	line.color = Color(0.16, 0.29, 0.54, 0.7)
	line.size = Vector2(SCREEN_W - 60, 1)
	line.position = Vector2(30, 324)
	chat_main_view.add_child(line)

	# 액션 버튼들 (mockup: y=340, 410, 480, h=56)
	var btn_data = [
		["💬  대화하기", "_on_main_talk",  Color(0.53, 0.33, 1.0)],
		["⭐  응원해줘",  "_on_main_cheer", Color(0.78, 0.63, 0.13)],
		["💡  팁 알려줘", "_on_main_tip",   Color(0.15, 0.66, 0.48)],
	]
	for i in range(btn_data.size()):
		var btn = Button.new()
		btn.text = btn_data[i][0]
		btn.size = Vector2(SCREEN_W - 60, 56)
		btn.position = Vector2(30, 340 + i * 72)
		btn.pressed.connect(Callable(self, btn_data[i][1]))
		_style_btn(btn, btn_data[i][2])
		chat_main_view.add_child(btn)
		_add_btn_shine(btn, chat_main_view)


func _setup_chat_topics_view() -> void:
	chat_topics_view = Control.new()
	chat_topics_view.size = Vector2(SCREEN_W, SCREEN_H)
	chat_topics_view.visible = false
	chat_panel.add_child(chat_topics_view)

	var back_btn = Button.new()
	back_btn.text = "← 뒤로"
	back_btn.size = Vector2(110, 44)
	back_btn.position = Vector2(12, 12)
	back_btn.pressed.connect(_show_chat_main)
	_style_btn(back_btn, Color(0.5, 0.5, 0.7))
	chat_topics_view.add_child(back_btn)

	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/sd/player.png") as Texture2D
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.size = Vector2(130, 130)
	portrait.position = Vector2(SCREEN_W / 2 - 65, 70)
	portrait.material = _make_outline_material(EMOTION_OUTLINE_COLOR["neutral"], 10.0)
	chat_topics_view.add_child(portrait)

	var ask_lbl = Label.new()
	ask_lbl.text = "무슨 이야기를 할까?"
	ask_lbl.add_theme_font_size_override("font_size", 22)
	ask_lbl.add_theme_color_override("font_color", Color.WHITE)
	ask_lbl.position = Vector2(SCREEN_W / 2 - 110, 215)
	chat_topics_view.add_child(ask_lbl)

	for i in range(CHAT_TOPICS.size()):
		var btn = Button.new()
		btn.text = CHAT_TOPICS[i]["label"]
		btn.size = Vector2(SCREEN_W - 60, 60)
		btn.position = Vector2(30, 255 + i * 70)
		btn.pressed.connect(_on_topic_selected.bind(i, CHAT_TOPICS[i]["message"], CHAT_TOPICS[i]["followups"]))
		_style_btn(btn)
		chat_topics_view.add_child(btn)


func _setup_chat_response_view() -> void:
	chat_response_view = Control.new()
	chat_response_view.size = Vector2(SCREEN_W, SCREEN_H)
	chat_response_view.visible = false
	chat_panel.add_child(chat_response_view)

	# ① 배경 이펙트 (SVG는 480×480 정사각형이므로 1:1로 표시)
	chat_bg_effect = TextureRect.new()
	chat_bg_effect.texture = load("res://assets/char_bg_effect.svg") as Texture2D
	chat_bg_effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	chat_bg_effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat_bg_effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chat_bg_effect.size = Vector2(SCREEN_W, SCREEN_W)
	chat_bg_effect.position = Vector2(0, -80)
	chat_bg_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_response_view.add_child(chat_bg_effect)

	# ② 글로우/아우라 레이어 (같은 이미지, 약간 확대 + 감정 색조 + 반투명)
	var glow_clip = Control.new()
	glow_clip.clip_contents = true
	glow_clip.size = Vector2(SCREEN_W + 24, 284)
	glow_clip.position = Vector2(-12, -4)
	glow_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_response_view.add_child(glow_clip)

	chat_portrait_glow = TextureRect.new()
	chat_portrait_glow.texture = load("res://assets/standing/normal.png") as Texture2D
	chat_portrait_glow.stretch_mode = TextureRect.STRETCH_SCALE
	chat_portrait_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat_portrait_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chat_portrait_glow.size = Vector2(SCREEN_W + 24, roundi((SCREEN_W + 24) * STANDING_RATIO))
	chat_portrait_glow.position = Vector2(0, 0)
	chat_portrait_glow.modulate = EMOTION_GLOW_MOD["neutral"]
	chat_portrait_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	chat_portrait_glow.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	chat_portrait_glow.material = _make_blur_material(8.0)
	glow_clip.add_child(chat_portrait_glow)

	# ③ 실제 스탠딩 초상화 (상반신 클립) — vertex 확장 glow를 위해 clip을 ow만큼 확장
	var ow_chat: float = 14.0
	var portrait_clip = Control.new()
	portrait_clip.clip_contents = true
	portrait_clip.position = Vector2(-ow_chat, -ow_chat)
	portrait_clip.size = Vector2(SCREEN_W + ow_chat * 2.0, 280.0 + ow_chat)
	chat_response_view.add_child(portrait_clip)

	chat_response_portrait = TextureRect.new()
	chat_response_portrait.texture = load("res://assets/standing/normal.png") as Texture2D
	chat_response_portrait.stretch_mode = TextureRect.STRETCH_SCALE
	chat_response_portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	chat_response_portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	chat_response_portrait.size = Vector2(SCREEN_W, roundi(SCREEN_W * STANDING_RATIO))
	chat_response_portrait.position = Vector2(ow_chat, ow_chat)
	portrait_shader_mat = _make_outline_material(EMOTION_OUTLINE_COLOR["neutral"])
	chat_response_portrait.material = portrait_shader_mat
	portrait_clip.add_child(chat_response_portrait)

	# ④ 하단 그라데이션 페이드 (비네트)
	_add_portrait_fade(chat_response_view, 280.0, 120.0, Color(0.04, 0.05, 0.12))

	# 타이핑 인디케이터
	chat_typing_label = Label.new()
	chat_typing_label.text = "마법사가 생각 중..."
	chat_typing_label.add_theme_font_size_override("font_size", 18)
	chat_typing_label.add_theme_color_override("font_color", Color(0.5, 0.8, 1.0))
	chat_typing_label.position = Vector2(SCREEN_W / 2 - 90, 284)
	chat_typing_label.visible = false
	chat_response_view.add_child(chat_typing_label)

	# 대화창 박스 (상단 얇은 글로우 테두리 + 반투명 패널)
	var border_glow = ColorRect.new()
	border_glow.color = Color(0.35, 0.65, 1.0, 0.55)
	border_glow.size = Vector2(SCREEN_W, 2)
	border_glow.position = Vector2(0, 276)
	chat_response_view.add_child(border_glow)

	var box = ColorRect.new()
	box.color = Color(0.04, 0.06, 0.18, 0.96)
	box.size = Vector2(SCREEN_W, SCREEN_H - 278)
	box.position = Vector2(0, 278)
	chat_response_view.add_child(box)

	# 이름 탭 (라운드 Panel)
	var name_panel = Panel.new()
	var name_style = StyleBoxFlat.new()
	name_style.bg_color = Color(0.20, 0.38, 0.90, 1.0)
	name_style.corner_radius_top_left = 0
	name_style.corner_radius_top_right = 10
	name_style.corner_radius_bottom_left = 0
	name_style.corner_radius_bottom_right = 0
	name_style.border_width_top = 1
	name_style.border_width_right = 1
	name_style.border_color = Color(0.5, 0.75, 1.0, 0.8)
	name_panel.add_theme_stylebox_override("panel", name_style)
	name_panel.size = Vector2(130, 32)
	name_panel.position = Vector2(20, 258)
	chat_response_view.add_child(name_panel)

	chat_response_name_label = Label.new()
	chat_response_name_label.text = "마법사"
	chat_response_name_label.add_theme_font_size_override("font_size", 19)
	chat_response_name_label.add_theme_color_override("font_color", Color(0.9, 0.97, 1.0))
	chat_response_name_label.position = Vector2(32, 260)
	chat_response_view.add_child(chat_response_name_label)

	# 스크롤 가능한 응답 텍스트 영역
	chat_text_scroll = ScrollContainer.new()
	chat_text_scroll.position = Vector2(0, 294)
	chat_text_scroll.size = Vector2(SCREEN_W, 160)
	chat_text_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	chat_text_scroll.vertical_scroll_mode = ScrollContainer.SCROLL_MODE_AUTO
	var scroll_style = StyleBoxFlat.new()
	scroll_style.bg_color = Color(0, 0, 0, 0)
	chat_text_scroll.add_theme_stylebox_override("panel", scroll_style)
	chat_response_view.add_child(chat_text_scroll)

	chat_response_text_label = Label.new()
	chat_response_text_label.add_theme_font_size_override("font_size", 19)
	chat_response_text_label.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	chat_response_text_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	chat_response_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	chat_response_text_label.add_theme_constant_override("line_spacing", 4)
	var label_style = StyleBoxFlat.new()
	label_style.bg_color = Color(0, 0, 0, 0)
	label_style.content_margin_left = 20
	label_style.content_margin_right = 20
	label_style.content_margin_top = 4
	chat_response_text_label.add_theme_stylebox_override("normal", label_style)
	chat_text_scroll.add_child(chat_response_text_label)

	# 선택지 버튼 컨테이너 - 화면 하단 기준 고정
	chat_followup_container = VBoxContainer.new()
	chat_followup_container.anchor_left   = 0.0
	chat_followup_container.anchor_right  = 1.0
	chat_followup_container.anchor_top    = 1.0
	chat_followup_container.anchor_bottom = 1.0
	chat_followup_container.offset_left   = 20
	chat_followup_container.offset_right  = -20
	chat_followup_container.offset_top    = -262
	chat_followup_container.offset_bottom = -12
	chat_followup_container.add_theme_constant_override("separation", 6)
	chat_followup_container.visible = false
	chat_response_view.add_child(chat_followup_container)


func _show_chat() -> void:
	state = State.CHAT
	_hide_all_panels()
	chat_panel.visible = true
	_show_chat_main()


func _show_chat_main() -> void:
	chat_messages = []
	chat_main_view.visible = true
	chat_topics_view.visible = false
	chat_response_view.visible = false


func _on_main_talk() -> void:
	chat_main_view.visible = false
	chat_topics_view.visible = true


func _on_main_cheer() -> void:
	chat_messages = [{"role": "user", "content": "나 게임 열심히 할게! 응원해줘!"}]
	_call_claude_api()


func _on_main_tip() -> void:
	chat_messages = [{"role": "user", "content": "돌 피하기 게임에서 잘 살아남는 팁 알려줘!"}]
	_call_claude_api()


func _on_topic_selected(_idx: int, message: String, _followups: Array) -> void:
	chat_messages = [{"role": "user", "content": message}]
	_call_claude_api()


func _on_followup_selected(text: String) -> void:
	chat_messages.append({"role": "user", "content": text})
	_call_claude_api()


func _call_claude_api() -> void:
	chat_is_waiting = true
	chat_typing_label.visible = true
	chat_followup_container.visible = false
	chat_response_text_label.text = ""
	chat_response_name_label.text = "마법사"

	chat_main_view.visible = false
	chat_topics_view.visible = false
	chat_response_view.visible = true

	var msgs = chat_messages.slice(max(0, chat_messages.size() - 20))

	var body = JSON.stringify({
		"model": "claude-haiku-4-5-20251001",
		"max_tokens": 500,
		"system": SYSTEM_PROMPT,
		"messages": msgs
	})

	var headers = [
		"Content-Type: application/json",
		"x-api-key: " + api_key,
		"anthropic-version: 2023-06-01"
	]

	chat_http.request(
		"https://api.anthropic.com/v1/messages",
		headers,
		HTTPClient.METHOD_POST,
		body
	)


func _on_chat_response(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	chat_is_waiting = false
	chat_typing_label.visible = false

	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		chat_response_text_label.text = "앗, 통신 오류가 생겼어... (코드: %d) 😢" % response_code
		_show_followup_buttons([])
		return

	var json = JSON.new()
	if json.parse(body.get_string_from_utf8()) != OK:
		chat_response_text_label.text = "응답을 읽지 못했어, 미안! 😢"
		_show_followup_buttons([])
		return

	var raw_text = json.data["content"][0]["text"]

	# 마크다운 코드블록 제거 (```json ... ``` 또는 ``` ... ```)
	var clean = raw_text.strip_edges()
	if clean.begins_with("```"):
		var first_newline = clean.find("\n")
		if first_newline != -1:
			clean = clean.substr(first_newline + 1)
		if clean.ends_with("```"):
			clean = clean.substr(0, clean.length() - 3).strip_edges()

	var inner = JSON.new()
	var reply: String
	var choices: Array = []
	if inner.parse(clean) == OK and inner.data is Dictionary:
		reply = inner.data.get("reply", raw_text)
		choices = inner.data.get("choices", [])
	else:
		reply = raw_text

	chat_messages.append({"role": "assistant", "content": raw_text})
	chat_response_text_label.text = reply
	if chat_text_scroll:
		chat_text_scroll.scroll_vertical = 0
	_set_portrait_emotion(_detect_emotion(reply))
	_show_followup_buttons(choices)


func _show_followup_buttons(followups: Array) -> void:
	# 기존 버튼 제거
	for child in chat_followup_container.get_children():
		child.queue_free()

	# 선택지 버튼들 (AI가 동적으로 생성)
	for text in followups:
		var btn = Button.new()
		btn.text = text
		btn.pressed.connect(_on_followup_selected.bind(text))
		_style_btn(btn, Color(0.45, 0.60, 1.0))
		chat_followup_container.add_child(btn)

	# 구분선 + nav 버튼 나란히 (mockup 기준)
	var sep = HSeparator.new()
	chat_followup_container.add_child(sep)

	var nav_row = HBoxContainer.new()
	nav_row.add_theme_constant_override("separation", 10)
	chat_followup_container.add_child(nav_row)

	var topics_btn = Button.new()
	topics_btn.text = "다른 주제로"
	topics_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	topics_btn.pressed.connect(func():
		chat_main_view.visible = false
		chat_response_view.visible = false
		chat_topics_view.visible = true
	)
	_style_btn(topics_btn, Color(0.47, 0.27, 0.80))
	nav_row.add_child(topics_btn)

	var home_btn = Button.new()
	home_btn.text = "처음으로"
	home_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	home_btn.pressed.connect(_show_chat_main)
	_style_btn(home_btn, Color(0.27, 0.27, 0.40))
	nav_row.add_child(home_btn)

	chat_followup_container.visible = true


# ── 인트로 대화 UI ────────────────────────────────────
func _setup_dialogue_ui() -> void:
	dialogue_panel = CanvasLayer.new()
	dialogue_panel.visible = false
	add_child(dialogue_panel)

	_add_space_bg(dialogue_panel, Color(0.04, 0.05, 0.13))

	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/sd/player.png") as Texture2D
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	portrait.size = Vector2(280, 280)
	portrait.position = Vector2(SCREEN_W / 2 - 140, SCREEN_H - 490)
	portrait.material = _make_outline_material(EMOTION_OUTLINE_COLOR["neutral"], 10.0)
	dialogue_panel.add_child(portrait)

	var box = ColorRect.new()
	box.color = Color(0.05, 0.08, 0.18, 0.93)
	box.size = Vector2(SCREEN_W, 200)
	box.position = Vector2(0, SCREEN_H - 200)
	dialogue_panel.add_child(box)

	var border = ColorRect.new()
	border.color = Color(0.3, 0.6, 1.0, 0.6)
	border.size = Vector2(SCREEN_W, 2)
	border.position = Vector2(0, SCREEN_H - 200)
	dialogue_panel.add_child(border)

	var name_bg = ColorRect.new()
	name_bg.color = Color(0.15, 0.35, 0.8, 1.0)
	name_bg.size = Vector2(160, 38)
	name_bg.position = Vector2(24, SCREEN_H - 220)
	dialogue_panel.add_child(name_bg)

	dialogue_name_label = Label.new()
	dialogue_name_label.add_theme_font_size_override("font_size", 22)
	dialogue_name_label.add_theme_color_override("font_color", Color.WHITE)
	dialogue_name_label.position = Vector2(34, SCREEN_H - 218)
	dialogue_panel.add_child(dialogue_name_label)

	dialogue_text_label = Label.new()
	dialogue_text_label.add_theme_font_size_override("font_size", 22)
	dialogue_text_label.add_theme_color_override("font_color", Color(0.9, 0.95, 1.0))
	dialogue_text_label.position = Vector2(30, SCREEN_H - 175)
	dialogue_text_label.size = Vector2(SCREEN_W - 60, 140)
	dialogue_text_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialogue_panel.add_child(dialogue_text_label)

	var hint = Label.new()
	hint.text = "▼ 클릭 또는 스페이스"
	hint.add_theme_font_size_override("font_size", 16)
	hint.add_theme_color_override("font_color", Color(0.5, 0.7, 1.0))
	hint.position = Vector2(SCREEN_W - 210, SCREEN_H - 36)
	dialogue_panel.add_child(hint)


# ── 게임오버 UI ───────────────────────────────────────
func _setup_gameover_ui() -> void:
	gameover_panel = CanvasLayer.new()
	gameover_panel.visible = false
	add_child(gameover_panel)

	# 배경 (어두운 우주 분위기)
	_add_space_bg(gameover_panel, Color(0.04, 0.04, 0.12))

	# ① 배경 이펙트 (SVG 1:1로 표시 — 찌그러짐 방지)
	var go_bg_effect = TextureRect.new()
	go_bg_effect.texture = load("res://assets/char_bg_effect.svg") as Texture2D
	go_bg_effect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	go_bg_effect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	go_bg_effect.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	go_bg_effect.size = Vector2(SCREEN_W, SCREEN_W)
	go_bg_effect.position = Vector2(0, -60)
	go_bg_effect.modulate = Color(0.60, 0.45, 0.85, 1.0)
	go_bg_effect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_panel.add_child(go_bg_effect)

	# ② 글로우/아우라 레이어
	var go_glow_clip = Control.new()
	go_glow_clip.clip_contents = true
	go_glow_clip.size = Vector2(SCREEN_W + 24, 408)
	go_glow_clip.position = Vector2(-12, -4)
	go_glow_clip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	gameover_panel.add_child(go_glow_clip)

	var go_glow = TextureRect.new()
	go_glow.texture = load("res://assets/standing/sad.png") as Texture2D
	go_glow.stretch_mode = TextureRect.STRETCH_SCALE
	go_glow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	go_glow.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	go_glow.size = Vector2(SCREEN_W + 24, roundi((SCREEN_W + 24) * STANDING_RATIO))
	go_glow.position = Vector2(0, 0)
	go_glow.modulate = EMOTION_GLOW_MOD["sad"]
	go_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	go_glow.texture_repeat = CanvasItem.TEXTURE_REPEAT_DISABLED
	go_glow.material = _make_blur_material(8.0)
	go_glow_clip.add_child(go_glow)

	# ③ 슬픈 스탠딩 일러스트 클립 — vertex 확장 glow를 위해 clip 확장
	var ow_go: float = 14.0
	var portrait_clip = Control.new()
	portrait_clip.clip_contents = true
	portrait_clip.position = Vector2(-ow_go, -ow_go)
	portrait_clip.size = Vector2(SCREEN_W + ow_go * 2.0, 400.0 + ow_go)
	gameover_panel.add_child(portrait_clip)

	var portrait = TextureRect.new()
	portrait.texture = load("res://assets/standing/sad.png") as Texture2D
	portrait.stretch_mode = TextureRect.STRETCH_SCALE
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR
	portrait.size = Vector2(SCREEN_W, roundi(SCREEN_W * STANDING_RATIO))
	portrait.position = Vector2(ow_go, ow_go)
	portrait.material = _make_outline_material(EMOTION_OUTLINE_COLOR["sad"])
	portrait_clip.add_child(portrait)

	# ④ 하단 그라데이션 페이드
	_add_portrait_fade(gameover_panel, 400.0, 160.0, Color(0.06, 0.04, 0.10))

	# GAME OVER 텍스트 (mockup: #FF3333, 그림자로 glow 근사)
	var go_title = Label.new()
	go_title.text = "GAME OVER"
	go_title.add_theme_font_size_override("font_size", 48)
	go_title.add_theme_color_override("font_color", Color(1.0, 0.20, 0.20))  # #FF3333
	go_title.add_theme_color_override("font_shadow_color", Color(0.9, 0.15, 0.15, 0.45))
	go_title.add_theme_constant_override("shadow_offset_x", 0)
	go_title.add_theme_constant_override("shadow_offset_y", 0)
	go_title.add_theme_constant_override("shadow_outline_size", 4)
	go_title.position = Vector2(SCREEN_W / 2 - 148, 410)
	gameover_panel.add_child(go_title)

	# 구분선 (#661A1A)
	var line = ColorRect.new()
	line.color = Color(0.40, 0.10, 0.10, 0.7)
	line.size = Vector2(SCREEN_W - 60, 1)
	line.position = Vector2(30, 462)
	gameover_panel.add_child(line)

	# 점수 (white, #E0ECFF)
	gameover_score = Label.new()
	gameover_score.add_theme_font_size_override("font_size", 28)
	gameover_score.add_theme_color_override("font_color", Color(0.88, 0.93, 1.0))
	gameover_score.position = Vector2(SCREEN_W / 2 - 70, 474)
	gameover_panel.add_child(gameover_score)

	# 최고 점수 (#D4AF37)
	gameover_best = Label.new()
	gameover_best.add_theme_font_size_override("font_size", 22)
	gameover_best.add_theme_color_override("font_color", Color(0.83, 0.69, 0.22))  # #D4AF37
	gameover_best.position = Vector2(SCREEN_W / 2 - 82, 510)
	gameover_panel.add_child(gameover_best)

	# 버튼들
	var restart_btn = Button.new()
	restart_btn.text = "▶  다시 시작"
	restart_btn.size = Vector2(SCREEN_W - 80, 62)
	restart_btn.position = Vector2(40, 562)
	restart_btn.pressed.connect(_start_game)
	_style_btn(restart_btn, Color(0.3, 0.75, 0.45))
	gameover_panel.add_child(restart_btn)
	_add_btn_shine(restart_btn, gameover_panel)

	var menu_btn = Button.new()
	menu_btn.text = "타이틀로"
	menu_btn.size = Vector2(SCREEN_W - 80, 62)
	menu_btn.position = Vector2(40, 638)
	menu_btn.pressed.connect(_show_title)
	_style_btn(menu_btn, Color(0.5, 0.5, 0.7))
	gameover_panel.add_child(menu_btn)
	_add_btn_shine(menu_btn, gameover_panel)


# ── 효과음 ────────────────────────────────────────────
func _setup_audio() -> void:
	audio_hit = AudioStreamPlayer.new()
	add_child(audio_hit)
	audio_gameover = AudioStreamPlayer.new()
	add_child(audio_gameover)
	_assign_tone(audio_hit, 220.0, 0.15)
	_assign_tone(audio_gameover, 110.0, 0.4)


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


# ── 파티클 ────────────────────────────────────────────
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
func _hide_all_panels() -> void:
	title_panel.visible = false
	chat_panel.visible = false
	dialogue_panel.visible = false
	gameover_panel.visible = false
	score_label.visible = false
	life_label.visible = false
	highscore_label.visible = false
	player.visible = false
	for rock in rocks:
		rock.queue_free()
	rocks.clear()


func _show_title() -> void:
	state = State.TITLE
	_hide_all_panels()
	title_best_label.text = "최고 점수: %d" % high_score
	title_panel.visible = true


func _start_intro() -> void:
	state = State.DIALOGUE
	_hide_all_panels()
	dialogue_index = 0
	dialogue_name_label.text = INTRO_LINES[0][0]
	dialogue_text_label.text = INTRO_LINES[0][1]
	dialogue_panel.visible = true


func _advance_dialogue() -> void:
	dialogue_index += 1
	if dialogue_index >= INTRO_LINES.size():
		_start_game()
	else:
		dialogue_name_label.text = INTRO_LINES[dialogue_index][0]
		dialogue_text_label.text = INTRO_LINES[dialogue_index][1]


func _start_game() -> void:
	state = State.PLAYING
	_hide_all_panels()
	score = 0.0
	lives = 3
	rock_speed = ROCK_SPEED_START
	spawn_timer = 0.0
	invincible_timer = 0.0
	touch_target = Vector2(-1, -1)
	is_touching = false
	player.position = Vector2(SCREEN_W / 2 - 40, SCREEN_H - 130)
	player.modulate = Color.WHITE
	player.visible = true
	score_label.visible = true
	life_label.visible = true
	highscore_label.visible = true


func _game_over() -> void:
	state = State.GAME_OVER
	audio_gameover.play()
	var final_score = int(score)
	if final_score > high_score:
		high_score = final_score
		_save_high_score()
	gameover_score.text = "점수: %d" % final_score
	gameover_best.text = "최고 점수: %d" % high_score
	gameover_panel.visible = true


# ── 저장 ──────────────────────────────────────────────
func _save_high_score() -> void:
	var file = FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if file:
		file.store_32(high_score)


func _load_high_score() -> void:
	if FileAccess.file_exists(SAVE_PATH):
		var file = FileAccess.open(SAVE_PATH, FileAccess.READ)
		if file:
			high_score = file.get_32()


# ── 입력 ──────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if state == State.DIALOGUE:
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			_advance_dialogue()
		elif event is InputEventScreenTouch and event.pressed:
			_advance_dialogue()
		elif event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
			_advance_dialogue()
		return
	if state != State.PLAYING:
		return
	if event is InputEventScreenTouch:
		is_touching = event.pressed
		touch_target = event.position if event.pressed else Vector2(-1, -1)
	elif event is InputEventScreenDrag:
		touch_target = event.position
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		is_touching = event.pressed
		touch_target = event.position if event.pressed else Vector2(-1, -1)
	elif event is InputEventMouseMotion and is_touching:
		touch_target = event.position


# ── 매 프레임 ─────────────────────────────────────────
func _process(delta: float) -> void:
	if state != State.PLAYING:
		return
	_move_player(delta)
	_spawn_rocks(delta)
	_move_rocks(delta)
	_check_collisions()
	_update_hud()
	score += delta
	rock_speed = ROCK_SPEED_START + score * 10
	if invincible_timer > 0:
		invincible_timer -= delta
		player.modulate.a = 0.3 if int(invincible_timer * 10) % 2 == 0 else 1.0
	else:
		player.modulate = Color.WHITE


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
		var rock = TextureRect.new()
		rock.texture = load("res://rock.svg") as Texture2D
		var size = randf_range(30, 55)
		rock.size = Vector2(size, size)
		rock.stretch_mode = TextureRect.STRETCH_SCALE
		rock.position = Vector2(randf_range(0, SCREEN_W - size), -size)
		add_child(rock)
		rocks.append(rock)


func _move_rocks(delta: float) -> void:
	for rock in rocks:
		rock.position.y += rock_speed * delta


func _check_collisions() -> void:
	var player_rect = Rect2(player.position, player.size)
	var to_remove: Array = []
	for rock in rocks:
		if rock.position.y > SCREEN_H:
			to_remove.append(rock)
		elif Rect2(rock.position, rock.size).intersects(player_rect) and invincible_timer <= 0:
			lives -= 1
			invincible_timer = 2.0
			_spawn_particles(player.position + player.size / 2, Color.ORANGE_RED)
			audio_hit.play()
			to_remove.append(rock)
			if lives <= 0:
				_spawn_particles(player.position + player.size / 2, Color.RED)
				_game_over()
				return
	for rock in to_remove:
		rocks.erase(rock)
		rock.queue_free()


func _update_hud() -> void:
	score_label.text = "점수: %d" % int(score)
	life_label.text = "생명: " + "♥ ".repeat(lives)
	highscore_label.text = "최고: %d" % high_score
