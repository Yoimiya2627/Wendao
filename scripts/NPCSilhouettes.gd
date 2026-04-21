## NPCSilhouettes.gd
## NPC 独特剪影工具库——每个剧情 NPC 一个专属绘制函数
## 调用约定：传入 Node2D parent 和 base_color（来自 NPC.body_color）
## 坐标系与 NPC.gd 通用剪影一致：头 y≈-12，躯干 -5~20，宽 ±10
class_name NPCSilhouettes


## 椭圆工具
static func _ellipse(cx: float, cy: float, rx: float, ry: float, n: int = 12) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in n:
		var a := TAU * i / n
		pts.append(Vector2(cx + rx * cos(a), cy + ry * sin(a)))
	return pts


static func _rect(x1: float, y1: float, x2: float, y2: float) -> PackedVector2Array:
	return PackedVector2Array([
		Vector2(x1, y1), Vector2(x2, y1),
		Vector2(x2, y2), Vector2(x1, y2)
	])


static func _add_poly(parent: Node2D, poly: PackedVector2Array, color: Color) -> Polygon2D:
	var p := Polygon2D.new()
	p.polygon = poly
	p.color = color
	parent.add_child(p)
	return p


## 分派：根据 body_shape 返回是否处理
static func try_draw(parent: Node2D, body: Polygon2D, shape: String, base: Color) -> bool:
	match shape:
		"granny":          _draw_granny(parent, body, base)
		"fortune_teller":  _draw_fortune_teller(parent, body, base)
		"matron":          _draw_matron(parent, body, base)
		"water_carrier":   _draw_water_carrier(parent, body, base)
		"dog":             _draw_dog(parent, body, base)
		"guard":           _draw_guard(parent, body, base)
		"examiner":        _draw_examiner(parent, body, base)
		"vendor_tanghulu": _draw_vendor_tanghulu(parent, body, base)
		"vendor_spice":    _draw_vendor_spice(parent, body, base)
		"vendor_poultry":  _draw_vendor_poultry(parent, body, base)
		"shopkeeper":      _draw_shopkeeper(parent, body, base)
		"tea_keeper":      _draw_tea_keeper(parent, body, base)
		"storyteller":     _draw_storyteller(parent, body, base)
		"wanderer":        _draw_wanderer(parent, body, base)
		_: return false
	return true


## ── 1. 老婆婆：驼背 + 白发髻 + 拐杖 ─────────────────────────
static func _draw_granny(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var hair_color := Color(0.88, 0.85, 0.80, 1)
	var cane_color := Color(0.38, 0.25, 0.15, 1)
	## 驼背躯干：上身微前倾，下摆外扩
	body.polygon = PackedVector2Array([
		Vector2(-7, -3), Vector2(8, -5),
		Vector2(10, 20), Vector2(-9, 20)
	])
	body.color = base
	## 头（略低，前倾）
	_add_poly(parent, _ellipse(1.0, -11.0, 5.5, 6.5), base)
	## 白发髻
	_add_poly(parent, _ellipse(1.0, -16.0, 4.0, 3.0), hair_color)
	## 拐杖（右侧竖直）
	_add_poly(parent, _rect(11, -8, 13, 20), cane_color)
	_add_poly(parent, _ellipse(12.0, -9.0, 2.5, 1.5), cane_color)


## ── 2. 算命先生：黑道袍 + 道冠 + 签幡 ───────────────────────
static func _draw_fortune_teller(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var robe_dark := Color(base.r * 0.6, base.g * 0.6, base.b * 0.6, 1)
	var crown_color := Color(0.20, 0.18, 0.25, 1)
	var flag_color := Color(0.85, 0.75, 0.35, 1)   # 黄幡
	var flag_tip := Color(0.75, 0.25, 0.20, 1)     # 红尖
	var beard := Color(0.90, 0.88, 0.85, 1)
	## 长袍
	body.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(9, -5),
		Vector2(11, 20), Vector2(-11, 20)
	])
	body.color = robe_dark
	## 头
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 道冠（头顶横条 + 方块）
	_add_poly(parent, _rect(-5, -19, 5, -16), crown_color)
	_add_poly(parent, _rect(-2, -22, 2, -18), crown_color)
	## 山羊胡
	_add_poly(parent, _rect(-1.5, -7, 1.5, -3), beard)
	## 签幡（左侧竖长条 + 红尖）
	_add_poly(parent, _rect(-15, -8, -12, 14), flag_color)
	_add_poly(parent, PackedVector2Array([
		Vector2(-15, 14), Vector2(-12, 14), Vector2(-13.5, 18)
	]), flag_tip)


## ── 3. 大婶：圆润 + 白围裙 + 头巾 ──────────────────────────
static func _draw_matron(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var apron := Color(0.92, 0.88, 0.80, 1)
	var scarf := Color(base.r * 0.7, base.g * 0.5, base.b * 0.5, 1)
	## 躯干：微胖
	body.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4),
		Vector2(11, 20), Vector2(-11, 20)
	])
	body.color = base
	## 头
	_add_poly(parent, _ellipse(0.0, -12.0, 6.0, 7.0), base)
	## 头巾（覆盖头顶前额）
	_add_poly(parent, PackedVector2Array([
		Vector2(-6, -18), Vector2(6, -18),
		Vector2(7, -12), Vector2(-7, -12)
	]), scarf)
	## 白围裙（腹部矩形）
	_add_poly(parent, PackedVector2Array([
		Vector2(-6, 0), Vector2(6, 0),
		Vector2(7, 18), Vector2(-7, 18)
	]), apron)


## ── 4. 打水人：扁担 + 两水桶 ────────────────────────────────
static func _draw_water_carrier(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var wood := Color(0.45, 0.30, 0.18, 1)
	var bucket := Color(0.30, 0.22, 0.15, 1)
	var water := Color(0.35, 0.55, 0.65, 1)
	body.polygon = PackedVector2Array([
		Vector2(-7, -4), Vector2(7, -4),
		Vector2(9, 20), Vector2(-9, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 扁担（水平横跨肩部）
	_add_poly(parent, _rect(-16, -8, 16, -6), wood)
	## 左桶
	_add_poly(parent, PackedVector2Array([
		Vector2(-18, -5), Vector2(-11, -5),
		Vector2(-12, 4), Vector2(-17, 4)
	]), bucket)
	_add_poly(parent, _rect(-17, -5, -12, -3), water)
	## 右桶
	_add_poly(parent, PackedVector2Array([
		Vector2(11, -5), Vector2(18, -5),
		Vector2(17, 4), Vector2(12, 4)
	]), bucket)
	_add_poly(parent, _rect(12, -5, 17, -3), water)


## ── 5. 老狗：趴卧四足兽形 ─────────────────────────────────
static func _draw_dog(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var dark := Color(base.r * 0.7, base.g * 0.65, base.b * 0.6, 1)
	var nose := Color(0.15, 0.10, 0.08, 1)
	## 主身体（横向椭圆，趴卧）
	body.polygon = _ellipse(0.0, 8.0, 13.0, 6.0, 16)
	body.color = base
	## 头（前方）
	_add_poly(parent, _ellipse(-12.0, 4.0, 6.0, 5.0, 14), base)
	## 吻部
	_add_poly(parent, _ellipse(-17.0, 6.0, 3.5, 2.5, 10), dark)
	_add_poly(parent, _ellipse(-19.0, 6.0, 1.2, 1.0, 8), nose)
	## 垂耳（左右各一）
	_add_poly(parent, PackedVector2Array([
		Vector2(-13, -1), Vector2(-9, -1), Vector2(-11, 5)
	]), dark)
	_add_poly(parent, PackedVector2Array([
		Vector2(-10, -2), Vector2(-6, -2), Vector2(-8, 4)
	]), dark)
	## 四条折叠小腿（趴卧，仅露一点）
	for x: int in [-6, 6]:
		_add_poly(parent, _rect(float(x - 2), 12, float(x + 2), 16), dark)
	## 尾巴（右后侧小曲线，用小三角近似）
	_add_poly(parent, PackedVector2Array([
		Vector2(12, 6), Vector2(18, 3), Vector2(17, 8), Vector2(12, 10)
	]), base)


## ── 6. 守卫：头盔 + 长戟 ───────────────────────────────────
static func _draw_guard(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var armor := Color(base.r * 0.75, base.g * 0.78, base.b * 0.85, 1)
	var helm := Color(0.30, 0.30, 0.38, 1)
	var plume := Color(0.70, 0.20, 0.20, 1)
	var pole := Color(0.38, 0.28, 0.18, 1)
	var blade := Color(0.80, 0.82, 0.85, 1)
	## 甲胄躯干：方正
	body.polygon = PackedVector2Array([
		Vector2(-10, -4), Vector2(10, -4),
		Vector2(10, 20), Vector2(-10, 20)
	])
	body.color = armor
	## 胸口分条（腰带）
	_add_poly(parent, _rect(-10, 6, 10, 9), helm)
	## 头
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.0), base)
	## 头盔（梯形覆顶）
	_add_poly(parent, PackedVector2Array([
		Vector2(-7, -10), Vector2(7, -10),
		Vector2(6, -20), Vector2(-6, -20)
	]), helm)
	## 盔缨
	_add_poly(parent, PackedVector2Array([
		Vector2(-2, -22), Vector2(2, -22),
		Vector2(1, -20), Vector2(-1, -20)
	]), plume)
	## 长戟杆（左侧竖立）
	_add_poly(parent, _rect(-15, -22, -13, 20), pole)
	## 戟刃（顶端）
	_add_poly(parent, PackedVector2Array([
		Vector2(-16, -22), Vector2(-12, -22),
		Vector2(-10, -16), Vector2(-14, -14)
	]), blade)


## ── 7. 测验师：太平宗高级弟子——发冠 + 披肩 + 玉牌 ──────────
static func _draw_examiner(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var robe_light := Color(base.r * 1.1, base.g * 1.08, base.b * 1.15, 1).clamp()
	var sash := Color(0.85, 0.72, 0.30, 1)   # 金肩带
	var crown := Color(0.90, 0.82, 0.40, 1)  # 金冠
	var jade := Color(0.75, 0.90, 0.80, 1)   # 玉牌
	var cord := Color(0.70, 0.30, 0.30, 1)   # 红绳
	## 长袍（比 monk 更修长）
	body.polygon = PackedVector2Array([
		Vector2(-10, -5), Vector2(10, -5),
		Vector2(13, 20), Vector2(-13, 20)
	])
	body.color = robe_light
	## 头
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 发冠（头顶横带 + 方冠）
	_add_poly(parent, _rect(-5, -20, 5, -17), crown)
	_add_poly(parent, PackedVector2Array([
		Vector2(-3, -22), Vector2(3, -22),
		Vector2(2, -20), Vector2(-2, -20)
	]), crown)
	## 披肩（金色三角从左肩垂到胸前）
	_add_poly(parent, PackedVector2Array([
		Vector2(-10, -5), Vector2(10, -5),
		Vector2(8, 2), Vector2(-8, 2)
	]), sash)
	## 胸前红绳 + 玉牌
	_add_poly(parent, _rect(-0.5, 2, 0.5, 8), cord)
	_add_poly(parent, _rect(-2.5, 7, 2.5, 12), jade)


## ── 8. 糖葫芦摊：斗笠 + 糖葫芦串 ──────────────────────────
static func _draw_vendor_tanghulu(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var hat := Color(0.55, 0.40, 0.20, 1)
	var stick := Color(0.35, 0.22, 0.12, 1)
	var haw := Color(0.80, 0.20, 0.18, 1)   # 山楂红
	body.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4),
		Vector2(10, 20), Vector2(-10, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 斗笠（宽帽檐）
	_add_poly(parent, PackedVector2Array([
		Vector2(-12, -16), Vector2(12, -16),
		Vector2(7, -19), Vector2(-7, -19)
	]), hat)
	## 糖葫芦：右手持竖直签子
	_add_poly(parent, _rect(13, -8, 14, 14), stick)
	## 四颗山楂
	for y: int in [-6, -1, 4, 9]:
		_add_poly(parent, _ellipse(13.5, float(y), 3.0, 3.0, 10), haw)


## ── 9. 香料摊：头巾 + 腰挎篮 ──────────────────────────────
static func _draw_vendor_spice(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var scarf := Color(0.75, 0.55, 0.25, 1)
	var basket := Color(0.55, 0.40, 0.20, 1)
	var basket_dark := Color(0.38, 0.25, 0.12, 1)
	body.polygon = PackedVector2Array([
		Vector2(-7, -4), Vector2(7, -4),
		Vector2(10, 20), Vector2(-10, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 6.0, 7.0), base)
	## 头巾（盖过发际）
	_add_poly(parent, PackedVector2Array([
		Vector2(-7, -18), Vector2(7, -18),
		Vector2(8, -10), Vector2(-8, -10)
	]), scarf)
	## 腰间挎篮（右侧方形，带编织纹）
	_add_poly(parent, _rect(9, 4, 17, 14), basket)
	_add_poly(parent, _rect(9, 7, 17, 8), basket_dark)
	_add_poly(parent, _rect(9, 10, 17, 11), basket_dark)
	## 篮带
	_add_poly(parent, _rect(8, 0, 10, 5), basket_dark)


## ── 10. 鸡鸭摊：围裙 + 脚边笼子 ──────────────────────────
static func _draw_vendor_poultry(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var apron := Color(0.85, 0.78, 0.55, 1)
	var cage := Color(0.40, 0.28, 0.15, 1)
	var feather := Color(0.95, 0.92, 0.85, 1)
	body.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4),
		Vector2(10, 20), Vector2(-10, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 围裙
	_add_poly(parent, PackedVector2Array([
		Vector2(-5, 0), Vector2(5, 0),
		Vector2(6, 15), Vector2(-6, 15)
	]), apron)
	## 脚边笼子
	_add_poly(parent, _rect(-18, 10, -10, 20), cage)
	## 竹条横纹
	for y: int in [12, 15, 18]:
		_add_poly(parent, _rect(-18, float(y), -10, float(y) + 0.8), Color(0.25, 0.18, 0.10, 1))
	## 笼内白色家禽
	_add_poly(parent, _ellipse(-14.0, 16.0, 2.5, 2.0, 8), feather)


## ── 11. 苏明：杂货铺老掌柜，长衫 + 围裙 + 账本 ───────────
static func _draw_shopkeeper(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var apron := Color(0.72, 0.58, 0.32, 1)
	var book := Color(0.55, 0.30, 0.20, 1)
	var beard := Color(0.78, 0.75, 0.70, 1)
	body.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(9, -5),
		Vector2(11, 20), Vector2(-11, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 发髻
	_add_poly(parent, _ellipse(0.0, -19.0, 3.0, 2.5, 10), Color(0.35, 0.30, 0.28, 1))
	## 山羊胡（贴下巴，不延入胸口）
	_add_poly(parent, PackedVector2Array([
		Vector2(-1.5, -7), Vector2(1.5, -7),
		Vector2(1.0, -5), Vector2(-1.0, -5)
	]), beard)
	## 围裙（腰下）
	_add_poly(parent, PackedVector2Array([
		Vector2(-8, 3), Vector2(8, 3),
		Vector2(9, 18), Vector2(-9, 18)
	]), apron)
	## 账本（右手）
	_add_poly(parent, _rect(9, 2, 14, 10), book)
	_add_poly(parent, _rect(10, 4, 13, 4.8), Color(0.88, 0.82, 0.70, 1))
	_add_poly(parent, _rect(10, 6, 13, 6.8), Color(0.88, 0.82, 0.70, 1))


## ── 12. 茶馆掌柜：圆肚 + 围裙 + 茶壶 ────────────────────
static func _draw_tea_keeper(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var apron := Color(0.55, 0.38, 0.22, 1)
	var cap := Color(base.r * 0.6, base.g * 0.6, base.b * 0.6, 1)
	var pot := Color(0.25, 0.20, 0.18, 1)
	var pot_lid := Color(0.35, 0.28, 0.22, 1)
	## 圆肚躯干
	body.polygon = PackedVector2Array([
		Vector2(-8, -4), Vector2(8, -4),
		Vector2(12, 10), Vector2(12, 20),
		Vector2(-12, 20), Vector2(-12, 10)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 布帽（圆顶）
	_add_poly(parent, _ellipse(0.0, -18.0, 5.5, 3.0, 12), cap)
	## 围裙（大面积）
	_add_poly(parent, PackedVector2Array([
		Vector2(-7, 0), Vector2(7, 0),
		Vector2(10, 18), Vector2(-10, 18)
	]), apron)
	## 茶壶（右手）
	_add_poly(parent, _ellipse(14.0, 6.0, 4.0, 3.5, 12), pot)
	_add_poly(parent, _rect(13.5, 2, 14.5, 3), pot_lid)
	## 壶嘴
	_add_poly(parent, PackedVector2Array([
		Vector2(18, 5), Vector2(20, 3), Vector2(19, 7)
	]), pot)


## ── 13. 说书人：高发髻 + 长须 + 折扇 ────────────────────
static func _draw_storyteller(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var hair := Color(0.18, 0.15, 0.18, 1)
	var beard := Color(0.90, 0.88, 0.85, 1)
	var fan := Color(0.92, 0.82, 0.55, 1)
	var fan_ribs := Color(0.55, 0.38, 0.22, 1)
	body.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(9, -5),
		Vector2(11, 20), Vector2(-11, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 高发髻
	_add_poly(parent, _ellipse(0.0, -20.0, 3.5, 4.0, 12), hair)
	_add_poly(parent, _rect(-1, -17, 1, -14), hair)
	## 长须（下巴到胸）
	_add_poly(parent, PackedVector2Array([
		Vector2(-3, -7), Vector2(3, -7),
		Vector2(2, 2), Vector2(-2, 2)
	]), beard)
	## 折扇（右手水平展开）
	_add_poly(parent, PackedVector2Array([
		Vector2(9, -2), Vector2(20, -6),
		Vector2(20, 4), Vector2(9, 2)
	]), fan)
	## 扇骨
	for i in range(5):
		var t := float(i) / 4.0
		var x_top := lerpf(9.0, 20.0, t)
		var y_top := lerpf(-2.0, -6.0, t)
		var y_bot := lerpf(2.0, 4.0, t)
		_add_poly(parent, PackedVector2Array([
			Vector2(x_top, y_top), Vector2(x_top + 0.3, y_top),
			Vector2(x_top + 0.3, y_bot), Vector2(x_top, y_bot)
		]), fan_ribs)


## ── 14. 老江湖：斗笠 + 腰侧佩刀 ────────────────────────
static func _draw_wanderer(parent: Node2D, body: Polygon2D, base: Color) -> void:
	var hat := Color(0.30, 0.22, 0.15, 1)
	var sheath := Color(0.20, 0.15, 0.12, 1)
	var hilt := Color(0.55, 0.35, 0.20, 1)
	var guard := Color(0.70, 0.62, 0.30, 1)
	body.polygon = PackedVector2Array([
		Vector2(-9, -5), Vector2(9, -5),
		Vector2(11, 20), Vector2(-11, 20)
	])
	body.color = base
	_add_poly(parent, _ellipse(0.0, -12.0, 5.5, 6.5), base)
	## 斗笠（低压，遮眼）
	_add_poly(parent, PackedVector2Array([
		Vector2(-13, -14), Vector2(13, -14),
		Vector2(8, -20), Vector2(-8, -20)
	]), hat)
	_add_poly(parent, _rect(-13, -14, 13, -12), hat)
	## 腰侧佩刀（左腰，斜向下）
	_add_poly(parent, PackedVector2Array([
		Vector2(-12, 2), Vector2(-8, 2),
		Vector2(-4, 18), Vector2(-8, 18)
	]), sheath)
	## 刀柄（上端）
	_add_poly(parent, _rect(-13, -2, -8, 3), hilt)
	## 护手
	_add_poly(parent, _rect(-14, 1, -7, 3), guard)
