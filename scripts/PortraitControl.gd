## PortraitControl.gd
## 程序化角色半身剪影立绘控件
## 在 _draw() 里用基础几何形状描绘各角色剪影，无需外部图片资源
extends Control

const _FONT_BOLD := preload("res://assets/fonts/NotoSerifSC-Bold.ttf")

var _speaker: String = ""
var _base_color: Color = Color.TRANSPARENT


func set_speaker(speaker_name: String) -> void:
	_speaker = speaker_name
	_base_color = _resolve_color(speaker_name)
	visible = not speaker_name.is_empty()
	queue_redraw()


func _resolve_color(speaker_name: String) -> Color:
	match speaker_name:
		"苏云晚": return Color(0.83, 0.66, 0.34, 0.92)
		"苏明":   return Color(0.25, 0.35, 0.55, 0.92)
		"年年":   return Color(0.78, 0.78, 0.88, 0.92)
		"大鱼":   return Color(0.85, 0.40, 0.15, 0.92)
		"虚形魇": return Color(0.40, 0.20, 0.50, 0.92)
		_:        return Color(0.62, 0.60, 0.58, 0.92)


func _draw() -> void:
	if _speaker.is_empty() or _base_color.a < 0.01:
		return

	var w := size.x
	var h := size.y
	var cx := w * 0.5

	# ── 背景框（竹简深色底，细金边）───────────────────────────
	draw_rect(Rect2(0, 0, w, h), Color(0.05, 0.04, 0.06, 0.88))
	var border := Color(0.83, 0.66, 0.34, 0.45)
	draw_rect(Rect2(0, 0, w, 1), border)
	draw_rect(Rect2(0, h - 1, w, 1), border)
	draw_rect(Rect2(0, 0, 1, h), border)
	draw_rect(Rect2(w - 1, 0, 1, h), border)
	# 内侧细边（双框感）
	var inner := Color(0.83, 0.66, 0.34, 0.18)
	draw_rect(Rect2(3, 3, w - 6, h - 6), inner, false)

	# ── 头部（8点椭圆多边形）────────────────────────────────
	var head_cy := h * 0.26
	var head_rx := w * 0.28
	var head_ry := head_rx * 1.1
	var head_pts := PackedVector2Array()
	for i in 10:
		var a := i * TAU / 10.0 - PI * 0.5
		head_pts.append(Vector2(cx + cos(a) * head_rx, head_cy + sin(a) * head_ry))
	var col_arr := PackedColorArray([_base_color])
	draw_polygon(head_pts, col_arr)

	# ── 颈部 ─────────────────────────────────────────────────
	var neck_half := w * 0.07
	var neck_top  := head_cy + head_ry * 0.82
	var neck_bot  := head_cy + head_ry * 1.18
	draw_rect(Rect2(cx - neck_half, neck_top, neck_half * 2.0, neck_bot - neck_top), _base_color)

	# ── 身体（梯形剪影，随角色类型变化） ─────────────────────
	var shoulder_y := neck_bot
	var body_pts   : PackedVector2Array
	match _speaker:
		"苏云晚":
			# 古装女性：肩较窄，裙摆宽
			body_pts = PackedVector2Array([
				Vector2(cx - w * 0.26, shoulder_y),
				Vector2(cx + w * 0.26, shoulder_y),
				Vector2(cx + w * 0.42, h * 0.96),
				Vector2(cx - w * 0.42, h * 0.96),
			])
		"年年", "大鱼":
			# 猫咪 / 小体型：矮而圆
			body_pts = PackedVector2Array([
				Vector2(cx - w * 0.22, shoulder_y),
				Vector2(cx + w * 0.22, shoulder_y),
				Vector2(cx + w * 0.24, h * 0.88),
				Vector2(cx - w * 0.24, h * 0.88),
			])
		"虚形魇":
			# BOSS：宽肩，形状更具压迫感
			body_pts = PackedVector2Array([
				Vector2(cx - w * 0.38, shoulder_y),
				Vector2(cx + w * 0.38, shoulder_y),
				Vector2(cx + w * 0.32, h * 0.96),
				Vector2(cx - w * 0.32, h * 0.96),
			])
		_:
			# 通用 NPC：略方正
			body_pts = PackedVector2Array([
				Vector2(cx - w * 0.28, shoulder_y),
				Vector2(cx + w * 0.28, shoulder_y),
				Vector2(cx + w * 0.30, h * 0.96),
				Vector2(cx - w * 0.30, h * 0.96),
			])
	draw_polygon(body_pts, col_arr)

	# ── 底部角色名初字（水墨印章感）─────────────────────────
	if not _speaker.is_empty():
		draw_string(
			_FONT_BOLD,
			Vector2(cx - 7, h - 6),
			_speaker.substr(0, 1),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			12,
			Color(0.83, 0.66, 0.34, 0.55)
		)
