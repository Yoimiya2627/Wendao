## EnemySilhouettes.gd
## 妖怪剪影工具库——TempleScene 世界地图和 BattleUI 战斗立绘共用
## 所有函数静态，直接传入 Node2D parent 就会在其下挂载剪影子节点
## BattleUI 调用时可把 parent 外层设 scale = Vector2(2.5, 2.5) 放大为战斗立绘
class_name EnemySilhouettes


## 椭圆多边形工具
static func _ellipse_pts(rx: float, ry: float, segs: int = 18) -> PackedVector2Array:
	var pts := PackedVector2Array()
	for i in segs:
		var a: float = i * TAU / segs
		pts.append(Vector2(cos(a) * rx, sin(a) * ry))
	return pts


## 根据敌人 id 自动分派
static func draw_for_enemy(parent: Node2D, enemy_id: String) -> void:
	if enemy_id == "boss":
		draw_boss(parent)
	elif enemy_id.begins_with("toad"):
		draw_toad(parent)
	else:
		draw_wolf(parent)


## 幽影狼：侧身蹲伏剪影（暗紫色调）
static func draw_wolf(parent: Node2D) -> void:
	var body_color := Color(0.22, 0.12, 0.30, 1)
	var eye_color := Color(0.85, 0.75, 0.35, 1)

	var body := Polygon2D.new()
	body.polygon = _ellipse_pts(14, 7)
	body.color = body_color
	body.position = Vector2(0, 2)
	parent.add_child(body)

	var head := Polygon2D.new()
	head.polygon = _ellipse_pts(7, 6)
	head.color = body_color
	head.position = Vector2(13, -4)
	parent.add_child(head)

	var muzzle := Polygon2D.new()
	muzzle.polygon = _ellipse_pts(4, 3)
	muzzle.color = body_color
	muzzle.position = Vector2(19, -2)
	parent.add_child(muzzle)

	var ear1 := Polygon2D.new()
	ear1.polygon = PackedVector2Array([Vector2(10, -8), Vector2(13, -14), Vector2(15, -8)])
	ear1.color = body_color
	parent.add_child(ear1)
	var ear2 := Polygon2D.new()
	ear2.polygon = PackedVector2Array([Vector2(15, -8), Vector2(18, -13), Vector2(20, -8)])
	ear2.color = body_color
	parent.add_child(ear2)

	var eye := Polygon2D.new()
	eye.polygon = _ellipse_pts(1.2, 1.2, 8)
	eye.color = eye_color
	eye.position = Vector2(15, -5)
	parent.add_child(eye)

	for x in [-8, 8]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(x - 2, 6), Vector2(x + 2, 6),
			Vector2(x + 2, 14), Vector2(x - 2, 14)
		])
		leg.color = body_color
		parent.add_child(leg)
	for x in [-4, 4]:
		var leg2 := Polygon2D.new()
		leg2.polygon = PackedVector2Array([
			Vector2(x - 1.5, 6), Vector2(x + 1.5, 6),
			Vector2(x + 1.5, 13), Vector2(x - 1.5, 13)
		])
		leg2.color = body_color
		parent.add_child(leg2)

	var tail := Polygon2D.new()
	tail.polygon = PackedVector2Array([
		Vector2(-13, 0), Vector2(-20, -4), Vector2(-22, -1),
		Vector2(-18, 2), Vector2(-13, 3)
	])
	tail.color = body_color
	parent.add_child(tail)


## 石皮蟾：蹲坐剪影（石褐色调）
static func draw_toad(parent: Node2D) -> void:
	var body_color := Color(0.38, 0.36, 0.28, 1)
	var belly_color := Color(0.52, 0.50, 0.40, 1)
	var eye_color := Color(0.85, 0.70, 0.25, 1)
	var pupil_color := Color(0.1, 0.08, 0.05, 1)

	var body := Polygon2D.new()
	body.polygon = _ellipse_pts(20, 12)
	body.color = body_color
	body.position = Vector2(0, 2)
	parent.add_child(body)

	var belly := Polygon2D.new()
	belly.polygon = _ellipse_pts(14, 5)
	belly.color = belly_color
	belly.position = Vector2(0, 9)
	parent.add_child(belly)

	for x in [-8, 8]:
		var bump := Polygon2D.new()
		bump.polygon = _ellipse_pts(5, 5)
		bump.color = body_color
		bump.position = Vector2(x, -10)
		parent.add_child(bump)
		var eye := Polygon2D.new()
		eye.polygon = _ellipse_pts(3, 3, 10)
		eye.color = eye_color
		eye.position = Vector2(x, -11)
		parent.add_child(eye)
		var pupil := Polygon2D.new()
		pupil.polygon = _ellipse_pts(0.8, 2, 8)
		pupil.color = pupil_color
		pupil.position = Vector2(x, -11)
		parent.add_child(pupil)

	for x in [-14, 14]:
		var paw := Polygon2D.new()
		paw.polygon = _ellipse_pts(4, 3)
		paw.color = body_color
		paw.position = Vector2(x, 12)
		parent.add_child(paw)


## 虚形魇（BOSS）：形态模糊的人形剪影
## 用多层半透明叠加模拟"形态不稳"；双眼是唯一锐利元素（呼应"虚无凝视"）
## 底部没有脚——消散成阴影（用多层渐小 polygon 近似）
static func draw_boss(parent: Node2D) -> void:
	var base_color := Color(0.12, 0.06, 0.22, 0.88)
	var blur_color := Color(0.20, 0.10, 0.35, 0.35)  # 半透明用于叠加"模糊"
	var eye_glow := Color(0.95, 0.35, 0.45, 1.0)     # 暗红发光
	var eye_core := Color(1.0, 0.85, 0.90, 1.0)       # 高光芯

	## 第一层模糊晕（最大，最浅）
	var halo := Polygon2D.new()
	halo.polygon = _ellipse_pts(22, 30, 20)
	halo.color = Color(0.25, 0.15, 0.45, 0.18)
	halo.position = Vector2(0, 0)
	parent.add_child(halo)

	## 第二层模糊晕（偏移 -2,-1）
	var blur1 := Polygon2D.new()
	blur1.polygon = _ellipse_pts(16, 24, 18)
	blur1.color = blur_color
	blur1.position = Vector2(-2, -1)
	parent.add_child(blur1)

	## 第三层模糊晕（偏移 +2, 0）
	var blur2 := Polygon2D.new()
	blur2.polygon = _ellipse_pts(16, 24, 18)
	blur2.color = blur_color
	blur2.position = Vector2(2, 0)
	parent.add_child(blur2)

	## 主体：拉长的人形剪影（头小肩宽、腰以下渐散）
	## 用多段 polygon 堆叠：头、肩、胸、腰、散尾
	var head := Polygon2D.new()
	head.polygon = _ellipse_pts(7, 9, 16)
	head.color = base_color
	head.position = Vector2(0, -14)
	parent.add_child(head)

	var shoulders := Polygon2D.new()
	shoulders.polygon = PackedVector2Array([
		Vector2(-13, -4), Vector2(-10, -7), Vector2(10, -7),
		Vector2(13, -4), Vector2(11, 3), Vector2(-11, 3)
	])
	shoulders.color = base_color
	parent.add_child(shoulders)

	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-10, 2), Vector2(10, 2),
		Vector2(8, 14), Vector2(-8, 14)
	])
	torso.color = base_color
	parent.add_child(torso)

	## 散尾：逐渐变稀、变透明的三段
	var tail1 := Polygon2D.new()
	tail1.polygon = PackedVector2Array([
		Vector2(-8, 13), Vector2(8, 13),
		Vector2(6, 22), Vector2(-6, 22)
	])
	tail1.color = Color(base_color.r, base_color.g, base_color.b, 0.65)
	parent.add_child(tail1)

	var tail2 := Polygon2D.new()
	tail2.polygon = PackedVector2Array([
		Vector2(-6, 21), Vector2(6, 21),
		Vector2(3, 28), Vector2(-3, 28)
	])
	tail2.color = Color(base_color.r, base_color.g, base_color.b, 0.35)
	parent.add_child(tail2)

	## 双眼发光（核心视觉）——外晕 + 实心芯
	for x in [-3, 3]:
		var glow := Polygon2D.new()
		glow.polygon = _ellipse_pts(2.5, 2.5, 12)
		glow.color = Color(eye_glow.r, eye_glow.g, eye_glow.b, 0.55)
		glow.position = Vector2(x, -14)
		parent.add_child(glow)

		var core := Polygon2D.new()
		core.polygon = _ellipse_pts(1.2, 1.4, 10)
		core.color = eye_core
		core.position = Vector2(x, -14)
		parent.add_child(core)


## 清除 parent 下所有子节点（切换形态前调用）
static func clear(parent: Node2D) -> void:
	for child in parent.get_children():
		child.queue_free()


## 玩家人形剪影（站姿，暖棕调）
static func draw_player(parent: Node2D) -> void:
	var body_color := Color(0.22, 0.16, 0.28, 1.0)
	var cloth_color := Color(0.28, 0.20, 0.35, 1.0)

	var head := Polygon2D.new()
	head.polygon = _ellipse_pts(5.5, 6.5, 14)
	head.color = body_color
	head.position = Vector2(0, -28)
	parent.add_child(head)

	var neck := Polygon2D.new()
	neck.polygon = PackedVector2Array([
		Vector2(-2, -22), Vector2(2, -22),
		Vector2(2, -19), Vector2(-2, -19)
	])
	neck.color = body_color
	parent.add_child(neck)

	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-8, -19), Vector2(8, -19),
		Vector2(6, -2), Vector2(-6, -2)
	])
	torso.color = cloth_color
	parent.add_child(torso)

	# 左臂
	var arm_l := Polygon2D.new()
	arm_l.polygon = PackedVector2Array([
		Vector2(-8, -18), Vector2(-11, -15),
		Vector2(-13, 0), Vector2(-10, 0)
	])
	arm_l.color = cloth_color
	parent.add_child(arm_l)

	# 右臂（持剑，略前伸）
	var arm_r := Polygon2D.new()
	arm_r.polygon = PackedVector2Array([
		Vector2(8, -18), Vector2(11, -15),
		Vector2(14, 2), Vector2(11, 2)
	])
	arm_r.color = cloth_color
	parent.add_child(arm_r)

	# 剑（右手持）
	var sword := Polygon2D.new()
	sword.polygon = PackedVector2Array([
		Vector2(12, -12), Vector2(14, -12),
		Vector2(15, 16), Vector2(13, 16)
	])
	sword.color = Color(0.70, 0.68, 0.65, 1.0)
	parent.add_child(sword)

	# 剑穗
	var tassel := Polygon2D.new()
	tassel.polygon = PackedVector2Array([
		Vector2(12, 16), Vector2(15, 16),
		Vector2(14, 24), Vector2(13, 24)
	])
	tassel.color = Color(0.75, 0.55, 0.30, 0.85)
	parent.add_child(tassel)

	# 下裳
	var skirt := Polygon2D.new()
	skirt.polygon = PackedVector2Array([
		Vector2(-7, -3), Vector2(7, -3),
		Vector2(8, 10), Vector2(-8, 10)
	])
	skirt.color = cloth_color
	parent.add_child(skirt)

	for x: float in [-4.0, 4.0]:
		var leg := Polygon2D.new()
		leg.polygon = PackedVector2Array([
			Vector2(x - 3, 9), Vector2(x + 3, 9),
			Vector2(x + 3, 26), Vector2(x - 3, 26)
		])
		leg.color = body_color
		parent.add_child(leg)


## 虚形魇 BOSS 二阶段：形态凝固、冰蓝配色、双眼放大（"静止即恐惧"）
static func draw_boss_phase2(parent: Node2D) -> void:
	var base_color := Color(0.05, 0.07, 0.18, 0.96)
	var edge_color := Color(0.10, 0.14, 0.30, 0.60)
	var eye_glow  := Color(0.55, 0.75, 1.00, 0.80)
	var eye_core  := Color(0.90, 0.96, 1.00, 1.00)

	# 单层细晕（比 P1 少得多，强调清晰轮廓）
	var halo := Polygon2D.new()
	halo.polygon = _ellipse_pts(18, 26, 16)
	halo.color = Color(0.08, 0.12, 0.28, 0.14)
	parent.add_child(halo)

	# 主体头部——比 P1 更棱角化，用八边形
	var head := Polygon2D.new()
	head.polygon = PackedVector2Array([
		Vector2(-5, -23), Vector2(5, -23),
		Vector2(9, -18), Vector2(9, -9),
		Vector2(5, -4), Vector2(-5, -4),
		Vector2(-9, -9), Vector2(-9, -18)
	])
	head.color = base_color
	parent.add_child(head)

	# 肩部——更宽更方
	var shoulders := Polygon2D.new()
	shoulders.polygon = PackedVector2Array([
		Vector2(-15, -5), Vector2(-12, -8), Vector2(12, -8),
		Vector2(15, -5), Vector2(13, 4), Vector2(-13, 4)
	])
	shoulders.color = base_color
	parent.add_child(shoulders)

	var torso := Polygon2D.new()
	torso.polygon = PackedVector2Array([
		Vector2(-12, 3), Vector2(12, 3),
		Vector2(10, 15), Vector2(-10, 15)
	])
	torso.color = base_color
	parent.add_child(torso)

	# 散尾：P2 比 P1 更短，更"压抑"
	var tail1 := Polygon2D.new()
	tail1.polygon = PackedVector2Array([
		Vector2(-10, 14), Vector2(10, 14),
		Vector2(7, 22), Vector2(-7, 22)
	])
	tail1.color = Color(base_color.r, base_color.g, base_color.b, 0.55)
	parent.add_child(tail1)

	var tail2 := Polygon2D.new()
	tail2.polygon = PackedVector2Array([
		Vector2(-7, 21), Vector2(7, 21),
		Vector2(3, 26), Vector2(-3, 26)
	])
	tail2.color = Color(base_color.r, base_color.g, base_color.b, 0.22)
	parent.add_child(tail2)

	# 双眼：比 P1 大，冰蓝色，无心跳感
	for x: float in [-4.0, 4.0]:
		var glow := Polygon2D.new()
		glow.polygon = _ellipse_pts(3.5, 3.5, 12)
		glow.color = eye_glow
		glow.position = Vector2(x, -15)
		parent.add_child(glow)

		var core := Polygon2D.new()
		core.polygon = _ellipse_pts(2.0, 2.2, 10)
		core.color = eye_core
		core.position = Vector2(x, -15)
		parent.add_child(core)
