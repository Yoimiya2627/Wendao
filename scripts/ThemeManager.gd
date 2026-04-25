## ThemeManager.gd
## 全局UI主题 AutoLoad
## 在游戏启动时构建一套水墨克制风的Theme，应用到所有Control节点
##
## 设计原则：
## - 沿用游戏现有色系（深紫背景 + 暖白边框 + 金色强调）
## - 字体统一 NotoSerifSC，行距宽
## - 按钮无花哨动画/阴影/发光，克制
## - 不破坏已有手动设置的颜色（章末画面/对话框等）
extends Node

# ── 颜色常量 ──────────────────────────────────────────────────
const COLOR_BG_DARK    := Color(0.078, 0.051, 0.149, 1.0)  ## 深紫背景
const COLOR_TEXT_WARM  := Color(0.95, 0.90, 0.75, 1.0)     ## 暖白正文
const COLOR_TEXT_MUTED := Color(0.75, 0.70, 0.60, 1.0)     ## 次要灰白
const COLOR_ACCENT     := Color(0.83, 0.66, 0.34, 1.0)     ## 强调金
const COLOR_DANGER     := Color(0.72, 0.18, 0.18, 1.0)     ## 警示红
const COLOR_DISABLED   := Color(0.35, 0.31, 0.38, 1.0)     ## 禁用灰
const COLOR_PANEL_BG   := Color(0.078, 0.051, 0.149, 0.92) ## 面板半透明深紫
const COLOR_PANEL_BORDER := Color(0.95, 0.90, 0.75, 0.6)   ## 面板边框
const COLOR_ACCENT_GOLD    := Color(0.83, 0.66, 0.34, 1.0) ## 暖金色（场景标注/名称文字）
const COLOR_TEXT_SECONDARY := Color(0.75, 0.70, 0.60, 1.0) ## 次要文字（旁白/气泡）
const COLOR_TEXT_PRIMARY   := Color(0.95, 0.90, 0.75, 1.0) ## 主要正文（暖白，同 COLOR_TEXT_WARM）
const COLOR_BORDER         := Color(0.95, 0.90, 0.75, 0.45) ## 通用细边框线

# ── 字体 ──────────────────────────────────────────────────────
const FONT_REGULAR_PATH := "res://assets/fonts/NotoSerifSC-Regular.ttf"
const FONT_BOLD_PATH    := "res://assets/fonts/NotoSerifSC-Bold.ttf"

var _theme: Theme = null
var _font_regular: Font = null
var _font_bold: Font = null


func _ready() -> void:
	## 加载字体
	if ResourceLoader.exists(FONT_REGULAR_PATH):
		_font_regular = load(FONT_REGULAR_PATH)
	if ResourceLoader.exists(FONT_BOLD_PATH):
		_font_bold = load(FONT_BOLD_PATH)

	_theme = _build_theme()
	## 应用为全局默认主题
	ProjectSettings.set_setting("gui/theme/custom", "")  ## 清除可能的预设
	## 通过场景树设置默认主题
	get_tree().root.theme = _theme

	## 运行时强制设置内容缩放, 不依赖 project.godot 的持久化
	## (Godot 编辑器有时会把它认为"默认值"的设置剥离, 导致 stretch/aspect 丢失)
	## CANVAS_ITEMS + KEEP: 内容随窗口等比缩放, 保持 16:9, 超比例时黑边
	var win := get_tree().root
	win.content_scale_mode   = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	win.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	win.content_scale_size   = Vector2i(1280, 720)


# ══════════════════════════════════════════════════════════════
# Theme 构建
# ══════════════════════════════════════════════════════════════

func _build_theme() -> Theme:
	var theme := Theme.new()

	## 默认字体
	if _font_regular:
		theme.default_font = _font_regular
	theme.default_font_size = 14

	_apply_button_theme(theme)
	_apply_label_theme(theme)
	_apply_panel_theme(theme)
	_apply_progressbar_theme(theme)
	_apply_richtextlabel_theme(theme)

	return theme


## 按钮：1px暖白边框 + 深紫透明背景 + 暖白文字 + 悬停金色边框
func _apply_button_theme(theme: Theme) -> void:
	## 默认状态
	var sb_normal := StyleBoxFlat.new()
	sb_normal.bg_color = Color(0.078, 0.051, 0.149, 0.7)
	sb_normal.border_color = COLOR_TEXT_WARM
	sb_normal.set_border_width_all(1)
	sb_normal.set_corner_radius_all(2)
	sb_normal.content_margin_left = 12
	sb_normal.content_margin_right = 12
	sb_normal.content_margin_top = 6
	sb_normal.content_margin_bottom = 6
	theme.set_stylebox("normal", "Button", sb_normal)

	## 悬停状态
	var sb_hover := sb_normal.duplicate()
	sb_hover.bg_color = Color(0.13, 0.09, 0.22, 0.85)
	sb_hover.border_color = COLOR_ACCENT
	theme.set_stylebox("hover", "Button", sb_hover)

	## 按下状态
	var sb_pressed := sb_normal.duplicate()
	sb_pressed.bg_color = Color(0.04, 0.025, 0.09, 0.85)
	sb_pressed.border_color = COLOR_ACCENT
	theme.set_stylebox("pressed", "Button", sb_pressed)

	## 焦点（键盘导航）
	var sb_focus := sb_normal.duplicate()
	sb_focus.border_color = COLOR_ACCENT
	sb_focus.set_border_width_all(2)
	theme.set_stylebox("focus", "Button", sb_focus)

	## 禁用状态
	var sb_disabled := sb_normal.duplicate()
	sb_disabled.bg_color = Color(0.078, 0.051, 0.149, 0.3)
	sb_disabled.border_color = COLOR_DISABLED
	theme.set_stylebox("disabled", "Button", sb_disabled)

	## 文字颜色
	theme.set_color("font_color",          "Button", COLOR_TEXT_WARM)
	theme.set_color("font_hover_color",    "Button", COLOR_ACCENT)
	theme.set_color("font_pressed_color",  "Button", COLOR_ACCENT)
	theme.set_color("font_focus_color",    "Button", COLOR_ACCENT)
	theme.set_color("font_disabled_color", "Button", COLOR_DISABLED)


## Label：默认暖白文字 + NotoSerifSC
func _apply_label_theme(theme: Theme) -> void:
	theme.set_color("font_color", "Label", COLOR_TEXT_WARM)
	theme.set_constant("line_spacing", "Label", 4)


## Panel：半透明深紫 + 暖白细边框
func _apply_panel_theme(theme: Theme) -> void:
	var sb := StyleBoxFlat.new()
	sb.bg_color = COLOR_PANEL_BG
	sb.border_color = COLOR_PANEL_BORDER
	sb.set_border_width_all(1)
	sb.set_corner_radius_all(2)
	sb.content_margin_left = 8
	sb.content_margin_right = 8
	sb.content_margin_top = 6
	sb.content_margin_bottom = 6
	theme.set_stylebox("panel", "Panel", sb)


## ProgressBar：暖白背景框 + 金色填充
func _apply_progressbar_theme(theme: Theme) -> void:
	var sb_bg := StyleBoxFlat.new()
	sb_bg.bg_color = Color(0.04, 0.025, 0.09, 0.85)
	sb_bg.border_color = COLOR_TEXT_WARM
	sb_bg.set_border_width_all(1)
	sb_bg.set_corner_radius_all(1)
	theme.set_stylebox("background", "ProgressBar", sb_bg)

	var sb_fill := StyleBoxFlat.new()
	sb_fill.bg_color = COLOR_ACCENT
	sb_fill.set_corner_radius_all(1)
	theme.set_stylebox("fill", "ProgressBar", sb_fill)

	theme.set_color("font_color", "ProgressBar", COLOR_TEXT_WARM)


## RichTextLabel：默认正文颜色 + 行距
func _apply_richtextlabel_theme(theme: Theme) -> void:
	theme.set_color("default_color", "RichTextLabel", COLOR_TEXT_WARM)
	theme.set_constant("line_separation", "RichTextLabel", 4)
