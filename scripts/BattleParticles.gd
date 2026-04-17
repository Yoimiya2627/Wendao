## BattleParticles.gd
## 战斗粒子效果管理器：命中墨点飞溅 + 技能金色粒子
extends Node

var _canvas_layer   : CanvasLayer    = null
var _hit_particles  : CPUParticles2D = null
var _skill_particles: CPUParticles2D = null


func _ready() -> void:
	_canvas_layer = CanvasLayer.new()
	_canvas_layer.layer = 6
	add_child(_canvas_layer)

	_hit_particles = _build_hit_particles()
	_canvas_layer.add_child(_hit_particles)

	_skill_particles = _build_skill_particles()
	_canvas_layer.add_child(_skill_particles)


## 墨点飞溅（命中敌方/受击时）
func _build_hit_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting            = false
	p.one_shot            = true
	p.explosiveness       = 0.95
	p.amount              = 18
	p.lifetime            = 0.55
	p.direction           = Vector2(0.0, -1.0)
	p.spread              = 80.0
	p.gravity             = Vector2(0.0, 350.0)
	p.initial_velocity_min = 80.0
	p.initial_velocity_max = 200.0
	p.scale_amount_min    = 2.0
	p.scale_amount_max    = 6.0
	p.color               = Color(0.06, 0.03, 0.05, 0.80)
	return p


## 金色爆裂（技能/感应释放时）
func _build_skill_particles() -> CPUParticles2D:
	var p := CPUParticles2D.new()
	p.emitting            = false
	p.one_shot            = true
	p.explosiveness       = 0.80
	p.amount              = 28
	p.lifetime            = 0.80
	p.direction           = Vector2(0.0, -1.0)
	p.spread              = 140.0
	p.gravity             = Vector2(0.0, 80.0)
	p.initial_velocity_min = 50.0
	p.initial_velocity_max = 160.0
	p.scale_amount_min    = 3.0
	p.scale_amount_max    = 8.0
	p.color               = Color(0.95, 0.80, 0.30, 0.90)
	return p


## 在屏幕坐标 screen_pos 处播放命中效果
func play_hit(screen_pos: Vector2) -> void:
	if _hit_particles == null:
		return
	_hit_particles.position = screen_pos
	_hit_particles.restart()


## 在屏幕坐标 screen_pos 处播放技能效果
func play_skill(screen_pos: Vector2) -> void:
	if _skill_particles == null:
		return
	_skill_particles.position = screen_pos
	_skill_particles.restart()
