class_name UI
extends CanvasLayer
# All 2D screens: menu, HUD (with touch controls), pause, game over, shop.

signal play_pressed()
signal retry_pressed()
signal menu_pressed()
signal resume_pressed()
signal restart_pressed()
signal pause_pressed()
signal skin_chosen(skin)

var game: Game

const ORANGE := Color(0.96, 0.59, 0.12)
const GREEN := Color(0.18, 0.62, 0.31)
const BLUE := Color(0.24, 0.63, 0.86)
const DARK := Color(0.10, 0.11, 0.16)
const CREAM := Color(0.96, 0.94, 0.88)

var menu: Control
var hud: Control
var pause_scr: Control
var over_scr: Control
var shop_scr: Control

var _lbl_score: Label
var _lbl_coins_hud: Label
var _lbl_dist: Label
var _pw_box: HBoxContainer
var _over_score: Label
var _over_best: Label
var _over_coins: Label
var _over_new: Label
var _menu_best: Label
var _menu_coins: Label
var _missions_box: VBoxContainer
var _shop_box: VBoxContainer
var _shop_coins: Label

func _ready() -> void:
	layer = 10
	_build_menu()
	_build_hud()
	_build_pause()
	_build_over()
	_build_shop()
	Global.coins_changed.connect(_on_coins_changed)
	Global.missions_changed.connect(_refresh_missions)
	show_menu()

# ---------------------------------------------------------------- style helpers
func _sb(color: Color, radius := 18) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(14)
	s.shadow_color = Color(0, 0, 0, 0.25)
	s.shadow_size = 6
	s.shadow_offset = Vector2(0, 3)
	return s

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

func _label(txt: String, size := 32, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.55))
	l.add_theme_constant_override("outline_size", 6)
	return l

func _button(txt: String, color := ORANGE, size := 34) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", CREAM)
	b.add_theme_stylebox_override("normal", _sb(color))
	b.add_theme_stylebox_override("hover", _sb(color.lightened(0.1)))
	b.add_theme_stylebox_override("pressed", _sb(color.darkened(0.15)))
	b.add_theme_stylebox_override("disabled", _sb(Color(0.4, 0.4, 0.45)))
	b.custom_minimum_size = Vector2(0, 66)
	b.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	b.pressed.connect(func(): Audio.play("click"))
	return b

func _tex(path: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % path)

func _bg(scr: Control, top: Color, bot: Color) -> void:
	var g := ColorRect.new()
	_full(g)
	g.color = bot
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, top)
	grad.gradient.set_color(1, bot)
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	_full(tr)
	tr.texture = grad
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	scr.add_child(tr)

# ---------------------------------------------------------------- MENU
func _build_menu() -> void:
	menu = Control.new(); _full(menu); add_child(menu)
	_bg(menu, Color(0.20, 0.45, 0.70), Color(0.96, 0.72, 0.42))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	v.position = Vector2(0, 60)
	v.custom_minimum_size = Vector2(360, 0)
	v.offset_left = -180; v.offset_right = 180
	v.add_theme_constant_override("separation", 12)
	menu.add_child(v)
	v.add_child(_label("ABIDJAN", 64, ORANGE))
	v.add_child(_label("RUNNER", 52, CREAM))
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 24)
	_menu_best = _label("Record: 0", 26, DARK)
	_menu_coins = _label("0 CFA", 26, DARK)
	stats.add_child(_menu_best); stats.add_child(_menu_coins)
	v.add_child(stats)
	v.add_child(_spacer(10))
	var play := _button("JOUER", GREEN, 40)
	play.pressed.connect(func(): play_pressed.emit())
	v.add_child(play)
	var shop := _button("BOUTIQUE", BLUE, 30)
	shop.pressed.connect(func(): show_shop())
	v.add_child(shop)
	# sound toggles
	var snd := HBoxContainer.new(); snd.alignment = BoxContainer.ALIGNMENT_CENTER
	snd.add_theme_constant_override("separation", 10)
	var mus := _button("Musique: %s" % ("ON" if Global.music_on else "OFF"), DARK, 22)
	mus.pressed.connect(func():
		Global.music_on = not Global.music_on; Global.save_game()
		Audio.toggle_music(Global.music_on)
		mus.text = "Musique: %s" % ("ON" if Global.music_on else "OFF"))
	var sfx := _button("Sons: %s" % ("ON" if Global.sfx_on else "OFF"), DARK, 22)
	sfx.pressed.connect(func():
		Global.sfx_on = not Global.sfx_on; Global.save_game()
		sfx.text = "Sons: %s" % ("ON" if Global.sfx_on else "OFF"))
	snd.add_child(mus); snd.add_child(sfx)
	v.add_child(snd)
	# missions
	v.add_child(_label("Missions du jour", 24, DARK))
	var mpanel := PanelContainer.new()
	mpanel.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.18), 16))
	_missions_box = VBoxContainer.new()
	_missions_box.add_theme_constant_override("separation", 6)
	mpanel.add_child(_missions_box)
	v.add_child(mpanel)
	_refresh_menu(); _refresh_missions()

func _spacer(h: int) -> Control:
	var c := Control.new(); c.custom_minimum_size = Vector2(0, h); return c

func _on_coins_changed(_v: int) -> void:
	_refresh_menu()
	_refresh_shop()

func _refresh_menu() -> void:
	if _menu_best:
		_menu_best.text = "Record: %d" % Global.best_score
		_menu_coins.text = "%d CFA" % Global.coins

func _refresh_missions(_a = null) -> void:
	if not _missions_box:
		return
	for c in _missions_box.get_children():
		c.queue_free()
	for m in Global.missions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		var txt := "%s  (%d/%d)" % [m["text"], m["progress"], m["target"]]
		var l := _label(txt, 18, DARK, HORIZONTAL_ALIGNMENT_LEFT)
		l.custom_minimum_size = Vector2(260, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		row.add_child(l)
		if m["done"] and not m["claimed"]:
			var claim := _button("+%d" % m["reward"], GREEN, 18)
			claim.custom_minimum_size = Vector2(70, 40)
			var mid: int = m["id"]
			claim.pressed.connect(func(): Global.claim_mission(mid))
			row.add_child(claim)
		elif m["claimed"]:
			row.add_child(_label("✓", 22, GREEN))
		_missions_box.add_child(row)

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new(); _full(hud); hud.visible = false; add_child(hud)
	# top bar
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 16; top.offset_left = 16; top.offset_right = -16
	top.add_theme_constant_override("separation", 10)
	hud.add_child(top)
	var pause_btn := TextureButton.new()
	pause_btn.texture_normal = _tex("btn_pause")
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_btn.custom_minimum_size = Vector2(64, 64)
	pause_btn.pressed.connect(func(): Audio.play("click"); pause_pressed.emit())
	top.add_child(pause_btn)
	var scorebox := VBoxContainer.new()
	scorebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lbl_score = _label("0", 44, CREAM)
	_lbl_dist = _label("0 m", 22, CREAM)
	scorebox.add_child(_lbl_score); scorebox.add_child(_lbl_dist)
	top.add_child(scorebox)
	var coinbox := HBoxContainer.new()
	coinbox.alignment = BoxContainer.ALIGNMENT_END
	var ci := TextureRect.new(); ci.texture = _tex("coin")
	ci.custom_minimum_size = Vector2(48, 48); ci.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	ci.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_lbl_coins_hud = _label("0", 34, Color(1, 0.85, 0.3))
	coinbox.add_child(ci); coinbox.add_child(_lbl_coins_hud)
	top.add_child(coinbox)
	# power-up row
	_pw_box = HBoxContainer.new()
	_pw_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pw_box.position = Vector2(0, 96)
	_pw_box.offset_left = -150; _pw_box.offset_right = 150
	_pw_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pw_box.add_theme_constant_override("separation", 16)
	hud.add_child(_pw_box)
	# touch controls (bottom): left / right + jump / roll
	var pad_l := _touch_btn("btn_left", func(): if game: game.player.do_left())
	pad_l.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad_l.position = Vector2(24, -170)
	hud.add_child(pad_l)
	var pad_r := _touch_btn("btn_right", func(): if game: game.player.do_right())
	pad_r.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	pad_r.position = Vector2(140, -170)
	hud.add_child(pad_r)
	var pad_roll := _touch_btn("btn_roll", func(): if game: game.player.do_roll())
	pad_roll.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pad_roll.position = Vector2(-224, -170)
	hud.add_child(pad_roll)
	var pad_jump := _touch_btn("btn_jump", func(): if game: game.player.do_jump())
	pad_jump.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_RIGHT)
	pad_jump.position = Vector2(-108, -170)
	hud.add_child(pad_jump)
	var hint := _label("Glisse pour bouger • saute • roule", 18, Color(1, 1, 1, 0.7))
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -40
	hud.add_child(hint)

func _touch_btn(icon: String, cb: Callable) -> TextureButton:
	var b := TextureButton.new()
	b.texture_normal = _tex(icon)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(96, 96)
	b.size = Vector2(96, 96)
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(cb)
	return b

func update_hud(score: int, coins: int, dist: int) -> void:
	if _lbl_score:
		_lbl_score.text = str(score)
		_lbl_coins_hud.text = str(coins)
		_lbl_dist.text = "%d m" % dist

func update_power(states: Dictionary) -> void:
	if not _pw_box:
		return
	for c in _pw_box.get_children():
		c.queue_free()
	_add_power_icon("magnet", states["magnet"], states["magnet_dur"])
	_add_power_icon("x2", states["x2"], states["x2_dur"])
	if states["shield"]:
		_add_power_icon("shield", 1, 1)

func _add_power_icon(icon: String, t: float, dur: float) -> void:
	if t <= 0:
		return
	var v := VBoxContainer.new()
	var tr := TextureRect.new(); tr.texture = _tex(icon)
	tr.custom_minimum_size = Vector2(52, 52)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(tr)
	if dur > 0:
		var pb := ProgressBar.new()
		pb.max_value = dur; pb.value = t; pb.show_percentage = false
		pb.custom_minimum_size = Vector2(52, 8)
		v.add_child(pb)
	_pw_box.add_child(v)

# ---------------------------------------------------------------- PAUSE
func _build_pause() -> void:
	pause_scr = Control.new(); _full(pause_scr); pause_scr.visible = false
	pause_scr.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_scr)
	var dim := ColorRect.new(); _full(dim); dim.color = Color(0, 0, 0, 0.55)
	pause_scr.add_child(dim)
	var v := _center_box(pause_scr)
	v.add_child(_label("PAUSE", 52, CREAM))
	var r := _button("REPRENDRE", GREEN); r.pressed.connect(func(): resume_pressed.emit()); v.add_child(r)
	var rs := _button("RECOMMENCER", ORANGE); rs.pressed.connect(func(): restart_pressed.emit()); v.add_child(rs)
	var m := _button("MENU", BLUE); m.pressed.connect(func(): menu_pressed.emit()); v.add_child(m)

func _center_box(parent: Control) -> VBoxContainer:
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	v.offset_left = -170; v.offset_right = 170; v.offset_top = -220; v.offset_bottom = 220
	v.alignment = BoxContainer.ALIGNMENT_CENTER
	v.add_theme_constant_override("separation", 16)
	parent.add_child(v)
	return v

# ---------------------------------------------------------------- GAME OVER
func _build_over() -> void:
	over_scr = Control.new(); _full(over_scr); over_scr.visible = false; add_child(over_scr)
	var dim := ColorRect.new(); _full(dim); dim.color = Color(0.05, 0.05, 0.1, 0.7)
	over_scr.add_child(dim)
	var v := _center_box(over_scr)
	v.add_child(_label("TERMINÉ", 54, ORANGE))
	_over_new = _label("NOUVEAU RECORD!", 26, Color(1, 0.9, 0.3)); _over_new.visible = false
	v.add_child(_over_new)
	_over_score = _label("Score: 0", 36, CREAM); v.add_child(_over_score)
	_over_best = _label("Record: 0", 26, CREAM); v.add_child(_over_best)
	_over_coins = _label("+0 CFA", 26, Color(1, 0.85, 0.3)); v.add_child(_over_coins)
	v.add_child(_spacer(8))
	var retry := _button("REJOUER", GREEN); retry.pressed.connect(func(): retry_pressed.emit()); v.add_child(retry)
	var m := _button("MENU", BLUE); m.pressed.connect(func(): menu_pressed.emit()); v.add_child(m)

# ---------------------------------------------------------------- SHOP
func _build_shop() -> void:
	shop_scr = Control.new(); _full(shop_scr); shop_scr.visible = false; add_child(shop_scr)
	_bg(shop_scr, Color(0.18, 0.30, 0.45), Color(0.10, 0.12, 0.18))
	var v := VBoxContainer.new()
	v.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	v.position = Vector2(0, 40); v.offset_left = -200; v.offset_right = 200
	v.add_theme_constant_override("separation", 12)
	shop_scr.add_child(v)
	v.add_child(_label("BOUTIQUE", 46, ORANGE))
	_shop_coins = _label("0 CFA", 28, Color(1, 0.85, 0.3)); v.add_child(_shop_coins)
	_shop_box = VBoxContainer.new(); _shop_box.add_theme_constant_override("separation", 10)
	v.add_child(_shop_box)
	var back := _button("RETOUR", BLUE, 28); back.pressed.connect(func(): show_menu()); v.add_child(back)
	_refresh_shop()

var _skin_colors := {"urban": BLUE, "trad": ORANGE, "foot": Color(0.95, 0.75, 0.1), "biz": Color(0.2, 0.2, 0.28)}

func _refresh_shop() -> void:
	if not _shop_box:
		return
	_shop_coins.text = "%d CFA" % Global.coins
	for c in _shop_box.get_children():
		c.queue_free()
	for skin in Data.SKINS.keys():
		var d: Dictionary = Data.SKINS[skin]
		var panel := PanelContainer.new()
		panel.add_theme_stylebox_override("panel", _sb(Color(1, 1, 1, 0.10), 16))
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 12)
		panel.add_child(row)
		var sw := ColorRect.new(); sw.color = _skin_colors[skin]
		sw.custom_minimum_size = Vector2(56, 56)
		row.add_child(sw)
		var info := VBoxContainer.new(); info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_child(_label(d["name"], 22, CREAM, HORIZONTAL_ALIGNMENT_LEFT))
		var sub := "Débloqué" if Global.is_unlocked(skin) else "%d CFA" % d["price"]
		info.add_child(_label(sub, 18, Color(0.85, 0.85, 0.9), HORIZONTAL_ALIGNMENT_LEFT))
		row.add_child(info)
		if Global.is_unlocked(skin):
			if Global.selected_skin == skin:
				row.add_child(_label("✓ ACTIF", 20, GREEN))
			else:
				var b := _button("CHOISIR", GREEN, 20); b.custom_minimum_size = Vector2(120, 50)
				b.pressed.connect(func(): Global.select_skin(skin); skin_chosen.emit(skin); _refresh_shop())
				row.add_child(b)
		else:
			var b := _button("ACHETER", ORANGE, 20); b.custom_minimum_size = Vector2(120, 50)
			b.disabled = Global.coins < d["price"]
			b.pressed.connect(func():
				if Global.unlock_skin(skin):
					Global.select_skin(skin); skin_chosen.emit(skin)
				_refresh_shop())
			row.add_child(b)
		_shop_box.add_child(panel)

# ---------------------------------------------------------------- screen switch
func _hide_all() -> void:
	for s in [menu, hud, pause_scr, over_scr, shop_scr]:
		if s: s.visible = false

func show_menu() -> void:
	_hide_all(); menu.visible = true; _refresh_menu(); _refresh_missions()

func show_hud() -> void:
	_hide_all(); hud.visible = true

func show_pause() -> void:
	pause_scr.visible = true

func hide_pause() -> void:
	pause_scr.visible = false

func show_over(score: int, coins: int, best: int, is_best: bool) -> void:
	over_scr.visible = true
	_over_score.text = "Score: %d" % score
	_over_best.text = "Record: %d" % best
	_over_coins.text = "+%d CFA" % coins
	_over_new.visible = is_best

func show_shop() -> void:
	_hide_all(); shop_scr.visible = true; _refresh_shop()
