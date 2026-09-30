class_name UI
extends CanvasLayer
# All 2D screens: menu, HUD (with touch controls), pause, game over, shop.
# Menu & shop keep the 3D scene visible (runner idling in the street behind the UI).

signal play_pressed()
signal retry_pressed()
signal menu_pressed()
signal resume_pressed()
signal restart_pressed()
signal pause_pressed()
signal skin_chosen(skin)
signal skin_preview(skin)
signal shop_closed()
signal screen_changed(name)

var game: Game

const ORANGE := Color(0.97, 0.55, 0.10)
const GREEN := Color(0.16, 0.66, 0.33)
const BLUE := Color(0.20, 0.55, 0.90)
const DARK := Color(0.09, 0.10, 0.15)
const CREAM := Color(1.0, 0.97, 0.90)
const GOLD := Color(1.0, 0.83, 0.25)
const CARD := Color(0.08, 0.09, 0.14, 0.82)

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
var _over_dist: Label
var _over_new: Label
var _menu_best: Label
var _menu_coins: Label
var _missions_box: VBoxContainer
var _shop_box: VBoxContainer
var _shop_coins: Label
var _btn_music: Button
var _btn_sfx: Button
var _last_dist := 0

func _ready() -> void:
	layer = 10
	_build_menu()
	_build_hud()
	_build_pause()
	_build_over()
	_build_shop()
	# font applied at runtime (a project-setting font errors on the very first editor import)
	var theme := Theme.new()
	theme.default_font = load("res://assets/fonts/LilitaOne-Regular.ttf")
	for scr in [menu, hud, pause_scr, over_scr, shop_scr]:
		scr.theme = theme
	Global.coins_changed.connect(_on_coins_changed)
	Global.missions_changed.connect(_refresh_missions)
	show_menu()

# ---------------------------------------------------------------- style helpers
func _sb(color: Color, radius := 22, border_bottom := 0, border_col := Color.BLACK) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = color
	s.set_corner_radius_all(radius)
	s.set_content_margin_all(16)
	if border_bottom > 0:
		s.border_width_bottom = border_bottom
		s.border_color = border_col
	return s

func _full(c: Control) -> void:
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE

func _label(txt: String, size := 32, color := Color.WHITE, align := HORIZONTAL_ALIGNMENT_CENTER, outline := 8) -> Label:
	var l := Label.new()
	l.text = txt
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.horizontal_alignment = align
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	if outline > 0:
		l.add_theme_color_override("font_outline_color", Color(0.05, 0.05, 0.1, 0.9))
		l.add_theme_constant_override("outline_size", outline)
	return l

func _button(txt: String, color := ORANGE, size := 40, height := 92) -> Button:
	var b := Button.new()
	b.text = txt
	b.add_theme_font_size_override("font_size", size)
	b.add_theme_color_override("font_color", Color.WHITE)
	b.add_theme_color_override("font_hover_color", Color.WHITE)
	b.add_theme_color_override("font_pressed_color", CREAM)
	b.add_theme_color_override("font_outline_color", color.darkened(0.5))
	b.add_theme_constant_override("outline_size", 6)
	var dark := color.darkened(0.35)
	b.add_theme_stylebox_override("normal", _sb(color, 24, 8, dark))
	b.add_theme_stylebox_override("hover", _sb(color.lightened(0.08), 24, 8, dark))
	var pressed := _sb(color.darkened(0.08), 24, 2, dark)
	pressed.content_margin_top = 22
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("disabled", _sb(Color(0.42, 0.43, 0.48), 24, 8, Color(0.3, 0.3, 0.34)))
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.custom_minimum_size = Vector2(0, height)
	b.pressed.connect(func(): Audio.play("click"))
	return b

func _pill(parent: Control, icon: String, lbl: Label) -> PanelContainer:
	var pc := PanelContainer.new()
	var sb := _sb(Color(0.05, 0.06, 0.1, 0.55), 40)
	sb.content_margin_top = 6; sb.content_margin_bottom = 6; sb.content_margin_left = 12; sb.content_margin_right = 20
	pc.add_theme_stylebox_override("panel", sb)
	var h := HBoxContainer.new()
	h.add_theme_constant_override("separation", 8)
	if icon != "":
		var tr := TextureRect.new()
		tr.texture = _tex(icon)
		tr.custom_minimum_size = Vector2(44, 44)
		tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		h.add_child(tr)
	h.add_child(lbl)
	pc.add_child(h)
	parent.add_child(pc)
	return pc

func _card(parent: Control) -> VBoxContainer:
	var pc := PanelContainer.new()
	var sb := _sb(CARD, 34)
	sb.set_content_margin_all(30)
	pc.add_theme_stylebox_override("panel", sb)
	parent.add_child(pc)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 16)
	pc.add_child(v)
	return v

func _tex(path: String) -> Texture2D:
	return load("res://assets/ui/%s.png" % path)

func _gradient(scr: Control, top: Color, bot: Color, preset: int, height: float) -> void:
	var grad := GradientTexture2D.new()
	grad.gradient = Gradient.new()
	grad.gradient.set_color(0, top)
	grad.gradient.set_color(1, bot)
	grad.fill_from = Vector2(0, 0)
	grad.fill_to = Vector2(0, 1)
	var tr := TextureRect.new()
	tr.texture = grad
	tr.stretch_mode = TextureRect.STRETCH_SCALE
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.set_anchors_and_offsets_preset(preset)
	if preset == Control.PRESET_TOP_WIDE:
		tr.offset_bottom = height
	else:
		tr.offset_top = -height
	tr.mouse_filter = Control.MOUSE_FILTER_IGNORE
	scr.add_child(tr)

func _margin(parent: Control, l := 28, t := 36, r := 28, b := 36) -> MarginContainer:
	var m := MarginContainer.new()
	m.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	m.mouse_filter = Control.MOUSE_FILTER_IGNORE
	m.add_theme_constant_override("margin_left", l)
	m.add_theme_constant_override("margin_top", t)
	m.add_theme_constant_override("margin_right", r)
	m.add_theme_constant_override("margin_bottom", b)
	parent.add_child(m)
	return m

func _expander() -> Control:
	var c := Control.new()
	c.size_flags_vertical = Control.SIZE_EXPAND_FILL
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return c

# ---------------------------------------------------------------- MENU
func _build_menu() -> void:
	menu = Control.new(); _full(menu); add_child(menu)
	_gradient(menu, Color(0.05, 0.12, 0.30, 0.75), Color(0.05, 0.12, 0.30, 0.0), Control.PRESET_TOP_WIDE, 330)
	_gradient(menu, Color(0.04, 0.05, 0.1, 0.0), Color(0.04, 0.05, 0.1, 0.85), Control.PRESET_BOTTOM_WIDE, 640)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 14)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin(menu).add_child(v)
	var title := _label("ABIDJAN", 104, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 14)
	title.add_theme_constant_override("line_spacing", -30)
	v.add_child(title)
	var sub := _label("RUNNER", 70, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 12)
	sub.custom_minimum_size.y = 60
	v.add_child(sub)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 14)
	_menu_best = _label("0", 30, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_menu_coins = _label("0", 30, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_pill(stats, "star", _menu_best)
	_pill(stats, "coin", _menu_coins)
	v.add_child(stats)
	v.add_child(_expander())
	# missions card
	var mc := _card(v)
	mc.add_child(_label("MISSIONS DU JOUR", 30, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0))
	_missions_box = VBoxContainer.new()
	_missions_box.add_theme_constant_override("separation", 12)
	mc.add_child(_missions_box)
	var play := _button("JOUER", GREEN, 56, 118)
	play.pressed.connect(func(): play_pressed.emit())
	v.add_child(play)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 12)
	var shop := _button("BOUTIQUE", BLUE, 34, 84)
	shop.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	shop.pressed.connect(func(): show_shop())
	row.add_child(shop)
	_btn_music = _button("", DARK.lightened(0.15), 26, 84)
	_btn_music.custom_minimum_size.x = 150
	_btn_music.pressed.connect(func():
		Global.music_on = not Global.music_on; Global.save_game()
		Audio.toggle_music(Global.music_on); _refresh_toggles())
	row.add_child(_btn_music)
	_btn_sfx = _button("", DARK.lightened(0.15), 26, 84)
	_btn_sfx.custom_minimum_size.x = 150
	_btn_sfx.pressed.connect(func():
		Global.sfx_on = not Global.sfx_on; Global.save_game(); _refresh_toggles())
	row.add_child(_btn_sfx)
	v.add_child(row)
	_refresh_toggles()
	_refresh_menu(); _refresh_missions()

func _refresh_toggles() -> void:
	_btn_music.text = "Musique\n%s" % ("ON" if Global.music_on else "OFF")
	_btn_sfx.text = "Sons\n%s" % ("ON" if Global.sfx_on else "OFF")

func _on_coins_changed(_v: int) -> void:
	_refresh_menu()
	_refresh_shop()

func _refresh_menu() -> void:
	if _menu_best:
		_menu_best.text = "Record %d" % Global.best_score
		_menu_coins.text = "%d CFA" % Global.coins

func _refresh_missions(_a = null) -> void:
	if not _missions_box:
		return
	for c in _missions_box.get_children():
		c.queue_free()
	for m in Global.missions:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var col := VBoxContainer.new()
		col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		col.add_theme_constant_override("separation", 4)
		var l := _label(m["text"], 24, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0)
		l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		col.add_child(l)
		var pb := ProgressBar.new()
		pb.max_value = m["target"]; pb.value = m["progress"]; pb.show_percentage = false
		pb.custom_minimum_size = Vector2(0, 14)
		pb.add_theme_stylebox_override("background", _sb(Color(1, 1, 1, 0.12), 7))
		pb.add_theme_stylebox_override("fill", _sb(GREEN if m["done"] else ORANGE, 7))
		col.add_child(pb)
		row.add_child(col)
		if m["done"] and not m["claimed"]:
			var claim := _button("+%d" % m["reward"], GREEN, 26, 60)
			claim.custom_minimum_size.x = 120
			var mid: int = m["id"]
			claim.pressed.connect(func(): Global.claim_mission(mid))
			row.add_child(claim)
		else:
			var tag := _label("OK" if m["claimed"] else "%d/%d" % [m["progress"], m["target"]], 22,
				GREEN if m["claimed"] else Color(0.8, 0.82, 0.9), HORIZONTAL_ALIGNMENT_RIGHT, 0)
			tag.custom_minimum_size.x = 120
			row.add_child(tag)
		_missions_box.add_child(row)

# ---------------------------------------------------------------- HUD
func _build_hud() -> void:
	hud = Control.new(); _full(hud); hud.visible = false; add_child(hud)
	_gradient(hud, Color(0, 0, 0, 0.35), Color(0, 0, 0, 0), Control.PRESET_TOP_WIDE, 190)
	var top := HBoxContainer.new()
	top.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top.offset_top = 26; top.offset_left = 22; top.offset_right = -22
	top.add_theme_constant_override("separation", 10)
	hud.add_child(top)
	var pause_btn := TextureButton.new()
	pause_btn.texture_normal = _tex("btn_pause")
	pause_btn.ignore_texture_size = true
	pause_btn.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	pause_btn.custom_minimum_size = Vector2(80, 80)
	pause_btn.pressed.connect(func(): Audio.play("click"); pause_pressed.emit())
	top.add_child(pause_btn)
	var scorebox := VBoxContainer.new()
	scorebox.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scorebox.add_theme_constant_override("separation", -6)
	_lbl_score = _label("0", 64, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 12)
	_lbl_dist = _label("0 m", 28, Color(0.85, 0.9, 1.0), HORIZONTAL_ALIGNMENT_CENTER, 8)
	scorebox.add_child(_lbl_score); scorebox.add_child(_lbl_dist)
	top.add_child(scorebox)
	_lbl_coins_hud = _label("0", 38, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0)
	var coin_pill := _pill(top, "coin", _lbl_coins_hud)
	coin_pill.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	_pw_box = HBoxContainer.new()
	_pw_box.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	_pw_box.offset_top = 150; _pw_box.offset_left = -180; _pw_box.offset_right = 180
	_pw_box.alignment = BoxContainer.ALIGNMENT_CENTER
	_pw_box.add_theme_constant_override("separation", 18)
	hud.add_child(_pw_box)
	# touch controls
	_touch(hud, "btn_left", Control.PRESET_BOTTOM_LEFT, Vector2(26, -196), func(): if game: game.player.do_left())
	_touch(hud, "btn_right", Control.PRESET_BOTTOM_LEFT, Vector2(152, -196), func(): if game: game.player.do_right())
	_touch(hud, "btn_roll", Control.PRESET_BOTTOM_RIGHT, Vector2(-248, -196), func(): if game: game.player.do_roll())
	_touch(hud, "btn_jump", Control.PRESET_BOTTOM_RIGHT, Vector2(-122, -196), func(): if game: game.player.do_jump())
	var hint := _label("Glisse pour bouger - saute - roule", 22, Color(1, 1, 1, 0.75), HORIZONTAL_ALIGNMENT_CENTER, 6)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -56
	hud.add_child(hint)

func _touch(parent: Control, icon: String, preset: int, pos: Vector2, cb: Callable) -> void:
	var b := TextureButton.new()
	b.texture_normal = _tex(icon)
	b.ignore_texture_size = true
	b.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
	b.custom_minimum_size = Vector2(108, 108)
	b.set_anchors_and_offsets_preset(preset)
	b.position = pos
	b.size = Vector2(108, 108)
	b.modulate = Color(1, 1, 1, 0.85)
	b.pressed.connect(cb)
	parent.add_child(b)

func update_hud(score: int, coins: int, dist: int) -> void:
	if _lbl_score:
		_lbl_score.text = str(score)
		_lbl_coins_hud.text = str(coins)
		_lbl_dist.text = "%d m" % dist
		_last_dist = dist

func update_power(states: Dictionary) -> void:
	if not _pw_box:
		return
	for c in _pw_box.get_children():
		c.queue_free()
	_add_power_icon("magnet", states["magnet"], states["magnet_dur"])
	_add_power_icon("x2", states["x2"], states["x2_dur"])
	if states["shield"]:
		_add_power_icon("shield", 1, 0)

func _add_power_icon(icon: String, t: float, dur: float) -> void:
	if t <= 0:
		return
	var v := VBoxContainer.new()
	var tr := TextureRect.new(); tr.texture = _tex(icon)
	tr.custom_minimum_size = Vector2(64, 64)
	tr.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	tr.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	v.add_child(tr)
	if dur > 0:
		var pb := ProgressBar.new()
		pb.max_value = dur; pb.value = t; pb.show_percentage = false
		pb.custom_minimum_size = Vector2(64, 10)
		pb.add_theme_stylebox_override("background", _sb(Color(0, 0, 0, 0.4), 5))
		pb.add_theme_stylebox_override("fill", _sb(GOLD, 5))
		v.add_child(pb)
	_pw_box.add_child(v)

# ---------------------------------------------------------------- PAUSE
func _build_pause() -> void:
	pause_scr = Control.new(); _full(pause_scr); pause_scr.visible = false
	pause_scr.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(pause_scr)
	var dim := ColorRect.new(); _full(dim); dim.color = Color(0.02, 0.03, 0.08, 0.6)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	pause_scr.add_child(dim)
	var v := _center_card(pause_scr)
	v.add_child(_label("PAUSE", 72, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 12))
	var r := _button("REPRENDRE", GREEN); r.pressed.connect(func(): resume_pressed.emit()); v.add_child(r)
	var rs := _button("RECOMMENCER", ORANGE); rs.pressed.connect(func(): restart_pressed.emit()); v.add_child(rs)
	var m := _button("MENU", BLUE); m.pressed.connect(func(): menu_pressed.emit()); v.add_child(m)

func _center_card(parent: Control) -> VBoxContainer:
	var c := CenterContainer.new()
	c.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	parent.add_child(c)
	var holder := VBoxContainer.new()
	holder.custom_minimum_size = Vector2(520, 0)
	c.add_child(holder)
	return _card(holder)

# ---------------------------------------------------------------- GAME OVER
func _build_over() -> void:
	over_scr = Control.new(); _full(over_scr); over_scr.visible = false; add_child(over_scr)
	var dim := ColorRect.new(); _full(dim); dim.color = Color(0.03, 0.03, 0.08, 0.55)
	dim.mouse_filter = Control.MOUSE_FILTER_STOP
	over_scr.add_child(dim)
	var v := _center_card(over_scr)
	v.add_child(_label("TERMINÉ !", 76, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 12))
	_over_new = _label("NOUVEAU RECORD !", 34, GOLD, HORIZONTAL_ALIGNMENT_CENTER, 8)
	_over_new.visible = false
	v.add_child(_over_new)
	_over_score = _label("0", 96, CREAM, HORIZONTAL_ALIGNMENT_CENTER, 12)
	v.add_child(_over_score)
	var stats := HBoxContainer.new()
	stats.alignment = BoxContainer.ALIGNMENT_CENTER
	stats.add_theme_constant_override("separation", 12)
	_over_dist = _label("0 m", 28, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_over_coins = _label("+0", 28, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_pill(stats, "", _over_dist)
	_pill(stats, "coin", _over_coins)
	v.add_child(stats)
	_over_best = _label("Record 0", 28, Color(0.8, 0.83, 0.92), HORIZONTAL_ALIGNMENT_CENTER, 0)
	v.add_child(_over_best)
	var retry := _button("REJOUER", GREEN, 44, 100); retry.pressed.connect(func(): retry_pressed.emit()); v.add_child(retry)
	var m := _button("MENU", BLUE); m.pressed.connect(func(): menu_pressed.emit()); v.add_child(m)

# ---------------------------------------------------------------- SHOP
func _build_shop() -> void:
	shop_scr = Control.new(); _full(shop_scr); shop_scr.visible = false; add_child(shop_scr)
	_gradient(shop_scr, Color(0.05, 0.12, 0.30, 0.8), Color(0.05, 0.12, 0.30, 0.0), Control.PRESET_TOP_WIDE, 260)
	_gradient(shop_scr, Color(0.04, 0.05, 0.1, 0.0), Color(0.04, 0.05, 0.1, 0.9), Control.PRESET_BOTTOM_WIDE, 820)
	var v := VBoxContainer.new()
	v.add_theme_constant_override("separation", 12)
	v.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_margin(shop_scr).add_child(v)
	v.add_child(_label("BOUTIQUE", 80, ORANGE, HORIZONTAL_ALIGNMENT_CENTER, 12))
	var coins_row := HBoxContainer.new()
	coins_row.alignment = BoxContainer.ALIGNMENT_CENTER
	_shop_coins = _label("0 CFA", 32, GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0)
	_pill(coins_row, "coin", _shop_coins)
	v.add_child(coins_row)
	v.add_child(_expander())
	_shop_box = VBoxContainer.new()
	_shop_box.add_theme_constant_override("separation", 10)
	v.add_child(_shop_box)
	var back := _button("RETOUR", BLUE, 36, 88)
	back.pressed.connect(func(): shop_closed.emit(); show_menu())
	v.add_child(back)
	var credits := _label("Personnages : Mannequiny (c) GDQuest, CC-BY 4.0 - animations KayKit, décors KayKit & Kenney (CC0)",
		16, Color(1, 1, 1, 0.6), HORIZONTAL_ALIGNMENT_CENTER, 0)
	credits.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	v.add_child(credits)
	_refresh_shop()

func _refresh_shop() -> void:
	if not _shop_box:
		return
	_shop_coins.text = "%d CFA" % Global.coins
	for c in _shop_box.get_children():
		c.queue_free()
	for skin in Data.SKINS.keys():
		var d: Dictionary = Data.SKINS[skin]
		var owned := Global.is_unlocked(skin)
		var active: bool = Global.selected_skin == skin
		var panel := PanelContainer.new()
		var sb := _sb(CARD, 26)
		sb.set_content_margin_all(8)
		if active:
			sb.border_color = GOLD
			sb.set_border_width_all(4)
		panel.add_theme_stylebox_override("panel", sb)
		var row := HBoxContainer.new(); row.add_theme_constant_override("separation", 14)
		panel.add_child(row)
		var portrait := TextureButton.new()
		portrait.texture_normal = _tex("skins/" + skin)
		portrait.ignore_texture_size = true
		portrait.stretch_mode = TextureButton.STRETCH_KEEP_ASPECT_CENTERED
		portrait.custom_minimum_size = Vector2(96, 96)
		portrait.pressed.connect(func(): skin_preview.emit(skin))
		row.add_child(portrait)
		var info := VBoxContainer.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.alignment = BoxContainer.ALIGNMENT_CENTER
		info.add_child(_label(d["name"], 30, CREAM, HORIZONTAL_ALIGNMENT_LEFT, 0))
		var sub := "Débloqué" if owned else "%d CFA" % d["price"]
		info.add_child(_label(sub, 24, GREEN.lightened(0.3) if owned else GOLD, HORIZONTAL_ALIGNMENT_LEFT, 0))
		row.add_child(info)
		var b: Button
		if active:
			b = _button("ACTIF", GREEN, 26, 66)
			b.disabled = true
		elif owned:
			b = _button("CHOISIR", GREEN, 26, 66)
			b.pressed.connect(func(): Global.select_skin(skin); skin_chosen.emit(skin); _refresh_shop())
		else:
			b = _button("ACHETER", ORANGE, 26, 66)
			b.disabled = Global.coins < d["price"]
			b.pressed.connect(func():
				if Global.unlock_skin(skin):
					Global.select_skin(skin); skin_chosen.emit(skin)
				_refresh_shop())
		b.custom_minimum_size.x = 170
		b.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		row.add_child(b)
		_shop_box.add_child(panel)

# ---------------------------------------------------------------- screen switch
func _hide_all() -> void:
	for s in [menu, hud, pause_scr, over_scr, shop_scr]:
		if s: s.visible = false

func show_menu() -> void:
	_hide_all(); menu.visible = true; _refresh_menu(); _refresh_missions()
	screen_changed.emit("menu")

func show_hud() -> void:
	_hide_all(); hud.visible = true

func show_pause() -> void:
	pause_scr.visible = true

func hide_pause() -> void:
	pause_scr.visible = false

func show_over(score: int, coins: int, best: int, is_best: bool) -> void:
	over_scr.visible = true
	_over_score.text = str(score)
	_over_best.text = "Record %d" % best
	_over_coins.text = "+%d" % coins
	_over_dist.text = "%d m" % _last_dist
	_over_new.visible = is_best

func show_shop() -> void:
	_hide_all(); shop_scr.visible = true; _refresh_shop()
	screen_changed.emit("shop")
