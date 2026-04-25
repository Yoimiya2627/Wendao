## AudioManager.gd
## 全局音频管理 AutoLoad 单例
##
## 设计原则：
## - 所有音频文件可以缺失，缺失时静默不报错
## - BGM 切换自动 crossfade，避免硬切割
## - SFX 用对象池，多个短音效不互相打断
## - BGM/SFX 音量分开控制，写入 user://settings.json
##
## 文件约定：
## - BGM: res://assets/audio/bgm/{name}.ogg
## - SFX: res://assets/audio/sfx/{name}.ogg
## - 同时尝试 .wav 后缀作为兜底
##
## 公开 API：
## - play_bgm(name, fade_in, loop)     带 crossfade 切换，loop=false 用于觉醒/章节结尾
## - play_bgm_once(name, fade_in)      play_bgm 的快捷版，loop=false
## - stop_bgm(fade_out)
## - fade_bgm_to(target_vol, duration) 动态调整 BGM 音量（不停止，用于战斗紧张感过渡）
## - play_sfx(name, volume_scale)      对话翻页 / 战斗攻击 / UI 点击等一次性音效（含音调微扰）
## - stop_all_sfx()                    场景切换时清空所有正在播放的 SFX
## - set_bgm_volume(linear_0_to_1)
## - set_sfx_volume(linear_0_to_1)
## - bgm_volume / sfx_volume （只读）
##
## 音频总线架构：
##   Master → BGM  : AudioEffectCompressor（防止crossfade爆音）
##          → SFX  : AudioEffectLimiter（防止多音效叠加失真）
##          → Voice: AudioEffectReverb（为将来语音预留，轻混响）
##
## 设置持久化：音量数据由 UIManager.save_settings_to_file() 统一写入
## user://settings.json，AudioManager 不直接写文件，避免覆盖冲突
extends Node

# ── 配置 ──────────────────────────────────────────────────────
const BGM_DIR := "res://assets/audio/bgm/"
const SFX_DIR := "res://assets/audio/sfx/"
const SFX_POOL_SIZE := 8           ## 同时可播放的最大SFX数
const BGM_DEFAULT_FADE := 1.5      ## 默认crossfade时长（秒）

## BGM 别名表：多个名称指向同一文件，无需改各场景脚本
## 格式：{ "别名": "真实文件名（不含后缀）" }
##
## 当前音频资产：town_day / town_night / tea_house / temple_explore /
##   shop_morning / shop_return / battle_boss_p1 / battle_boss_p2 /
##   temple_boss / main_menu / chapter_end
const BGM_ALIAS: Dictionary = {
	## 普通战斗复用古刹 boss 曲：紧张/压迫感，与 boss_p1 形成层次
	"battle_normal" : "temple_boss",
	## 觉醒演出复用章节结尾钢琴独奏：情绪延续到 ChapterEndScene 时
	## AudioManager 的"同名不重启"逻辑会让音乐无缝衔接
	"awakening"     : "chapter_end",
}

## 每首 BGM 的响度修正（dB，正数更响，负数更轻）
## 因各音频文件未做统一响度归一化，这里手动补偿
## 键用"真实文件名"（别名解析之后），不要写别名
const BGM_LOUDNESS_OFFSET: Dictionary = {
	"temple_boss" : -15.0,  ## 普通战斗 BGM 母带偏响，压低 15dB（v40.x 调过 -5dB 仍偏响）
}

## SFX 音调微扰：每种音效的随机偏移幅度（0.05 = ±5%）
## 列在这里的音效每次播放时音调略有不同，避免机械重复感
const SFX_PITCH_VARIATION: Dictionary = {
	"dialogue_advance" : 0.05,
	"attack_hit"       : 0.06,
	"enemy_hurt"       : 0.08,
	"player_hurt"      : 0.06,
	"button_click"     : 0.03,
	"charge"           : 0.04,
	"sense"            : 0.04,
}

# ── 节点池 ────────────────────────────────────────────────────
var _bgm_player_a: AudioStreamPlayer
var _bgm_player_b: AudioStreamPlayer
var _active_bgm_player: AudioStreamPlayer    ## 当前活跃的BGM播放器
var _sfx_pool: Array[AudioStreamPlayer] = []
var _sfx_pool_index: int = 0

# ── 状态 ──────────────────────────────────────────────────────
var bgm_volume: float = 0.6           ## 0.0 - 1.0
var sfx_volume: float = 0.7
var _current_bgm_name: String = ""    ## 当前播放的BGM名（避免重复触发）
var _bgm_fade_tween: Tween = null
var _duck_tween:     Tween = null     ## 对话BGM闪避专用tween，与crossfade互不干扰

# ── 缓存：避免每次播放都查文件系统 ──────────────────────────────
var _stream_cache: Dictionary = {}    ## name -> AudioStream
var _missing_streams: Dictionary = {} ## name -> true，记录已知不存在的文件，避免反复尝试加载


func _ready() -> void:
	## ① 建立三条音频总线（幂等：已存在则跳过）
	_setup_audio_buses()

	## ② 创建两个BGM播放器用于crossfade，走 BGM 总线
	## PROCESS_MODE_ALWAYS：游戏暂停（ESC菜单/背包）时 BGM 继续播放，不会静音
	_bgm_player_a = AudioStreamPlayer.new()
	_bgm_player_a.name         = "BGMPlayerA"
	_bgm_player_a.bus          = "BGM"
	_bgm_player_a.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player_a)

	_bgm_player_b = AudioStreamPlayer.new()
	_bgm_player_b.name         = "BGMPlayerB"
	_bgm_player_b.bus          = "BGM"
	_bgm_player_b.process_mode = Node.PROCESS_MODE_ALWAYS
	add_child(_bgm_player_b)

	_active_bgm_player = _bgm_player_a

	## ③ 创建SFX播放器池，走 SFX 总线
	for i in SFX_POOL_SIZE:
		var sfx := AudioStreamPlayer.new()
		sfx.name = "SFXPlayer%d" % i
		sfx.bus  = "SFX"
		add_child(sfx)
		_sfx_pool.append(sfx)

	## ④ 监听对话信号，实现 BGM 闪避
	if not DialogueManager.dialogue_started.is_connected(_on_dialogue_duck_start):
		DialogueManager.dialogue_started.connect(_on_dialogue_duck_start)
	if not DialogueManager.dialogue_ended.is_connected(_on_dialogue_duck_end):
		DialogueManager.dialogue_ended.connect(_on_dialogue_duck_end)

	## 音量设置由 UIManager 在它的 _ready() 中通过 set_bgm_volume/set_sfx_volume 注入
	## AudioManager 自身不读文件，避免和 UIManager 的 settings.json 冲突


# ══════════════════════════════════════════════════════════════
# BGM 控制
# ══════════════════════════════════════════════════════════════

## 播放 BGM，带 crossfade
## bgm_name : 不含路径和后缀，例如 "town_day"
## fade_in  : 渐入时长（秒），0 = 直接切换
## loop     : true = 无限循环（默认），false = 播完自动停（觉醒/章节结尾等演出用）
func play_bgm(bgm_name: String, fade_in: float = BGM_DEFAULT_FADE, loop: bool = true) -> void:
	## 别名解析（shop_morning → town_day 等）
	if BGM_ALIAS.has(bgm_name):
		bgm_name = BGM_ALIAS[bgm_name] as String
	## 切换 BGM 时清理对话闪避 tween，防止残留 tween 干扰新播放器
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
		_duck_tween = null
	## 防御：_ready() 未完成前被调用
	if _active_bgm_player == null:
		return
	if bgm_name == "":
		stop_bgm(fade_in)
		return
	## 已经在播放同一首：不重启
	if bgm_name == _current_bgm_name and _active_bgm_player.playing:
		return

	var stream := _load_audio_stream(BGM_DIR, bgm_name)
	if stream == null:
		## 文件不存在：快速停掉当前 BGM（0.3 秒，与场景淡入同步）
		print("AudioManager: BGM '%s' not found, stopping current BGM." % bgm_name)
		_current_bgm_name = bgm_name  ## 记录意图，便于调试
		stop_bgm(0.3)
		return

	## 控制循环（OGG / WAV / MP3 均支持）
	if stream is AudioStreamOggVorbis:
		(stream as AudioStreamOggVorbis).loop = loop
	elif stream is AudioStreamWAV:
		(stream as AudioStreamWAV).loop_mode = (
			AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
		)
	elif stream is AudioStreamMP3:
		(stream as AudioStreamMP3).loop = loop

	## 切换到另一个BGM播放器（crossfade）
	var old_player := _active_bgm_player
	var new_player := _bgm_player_b if old_player == _bgm_player_a else _bgm_player_a

	new_player.stream = stream
	new_player.volume_db = linear_to_db(0.0001)  ## 从静音开始
	new_player.play()
	_active_bgm_player = new_player
	_current_bgm_name = bgm_name

	## crossfade
	if _bgm_fade_tween and _bgm_fade_tween.is_running():
		_bgm_fade_tween.kill()
	var target_db: float = linear_to_db(bgm_volume) if bgm_volume > 0.0 else -80.0
	if bgm_volume > 0.0 and BGM_LOUDNESS_OFFSET.has(bgm_name):
		target_db += float(BGM_LOUDNESS_OFFSET[bgm_name])
	_bgm_fade_tween = create_tween().set_parallel(true)
	if fade_in > 0.0:
		_bgm_fade_tween.tween_property(
			new_player, "volume_db", target_db, fade_in
		).set_ease(Tween.EASE_IN_OUT)
		if old_player.playing:
			_bgm_fade_tween.tween_property(
				old_player, "volume_db", linear_to_db(0.0001), fade_in
			).set_ease(Tween.EASE_IN_OUT)
			var _stop_cb := func():
				if old_player != _active_bgm_player:
					old_player.stop()
			_bgm_fade_tween.chain().tween_callback(_stop_cb)
	else:
		new_player.volume_db = target_db
		if old_player.playing:
			old_player.stop()


## 播放一次性 BGM（loop=false 的快捷写法）
## 适用于：觉醒演出、章节结尾等播完即停的场景
func play_bgm_once(bgm_name: String, fade_in: float = BGM_DEFAULT_FADE) -> void:
	play_bgm(bgm_name, fade_in, false)


## 动态渐变 BGM 音量（不停止，用于战斗紧张感过渡、感知技能演出等）
## target_vol : 目标音量（0.0 ~ 1.0，不受 bgm_volume 上限约束，可压低到 0）
## duration   : 渐变时长（秒）
## v40.11 修复: 加上 BGM_LOUDNESS_OFFSET 应用——之前只有 play_bgm 用了,
## fade_bgm_to 直接 linear_to_db(vol) 会导致带 offset 的 BGM 被拉到错误音量
## (典型症状: 战斗 tutorial 对话结束后 BGM 跳响 5dB, 因为 _on_dialogue_duck_end
## 也走 linear_to_db 没加 offset)
func fade_bgm_to(target_vol: float, duration: float = 1.0) -> void:
	if _active_bgm_player == null or not _active_bgm_player.playing:
		return
	if _bgm_fade_tween and _bgm_fade_tween.is_running():
		_bgm_fade_tween.kill()
	## 主动渐变时中止对话 duck 恢复，防止两个 tween 争抢 volume_db
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
		_duck_tween = null
	var vol: float = clamp(target_vol, 0.0, 1.0)
	var target_db: float = linear_to_db(vol) if vol > 0.0 else -80.0
	if vol > 0.0 and BGM_LOUDNESS_OFFSET.has(_current_bgm_name):
		target_db += float(BGM_LOUDNESS_OFFSET[_current_bgm_name])
	_bgm_fade_tween = create_tween()
	_bgm_fade_tween.tween_property(
		_active_bgm_player, "volume_db",
		target_db,
		duration
	).set_ease(Tween.EASE_IN_OUT)


## 停止 BGM
func stop_bgm(fade_out: float = BGM_DEFAULT_FADE) -> void:
	_current_bgm_name = ""
	if _active_bgm_player == null or not _active_bgm_player.playing:
		return
	if _bgm_fade_tween and _bgm_fade_tween.is_running():
		_bgm_fade_tween.kill()
	if fade_out > 0.0:
		_bgm_fade_tween = create_tween()
		_bgm_fade_tween.tween_property(
			_active_bgm_player, "volume_db", linear_to_db(0.0001), fade_out
		).set_ease(Tween.EASE_IN_OUT)
		_bgm_fade_tween.tween_callback(_active_bgm_player.stop)
	else:
		_active_bgm_player.stop()


# ══════════════════════════════════════════════════════════════
# SFX 控制
# ══════════════════════════════════════════════════════════════

## 停止所有正在播放的 SFX（场景切换时调用，防止音效串场）
func stop_all_sfx() -> void:
	for player in _sfx_pool:
		if player.playing:
			player.stop()


## 播放音效（一次性，不循环）
## sfx_name      : 不含路径和后缀，例如 "dialogue_advance"
## volume_scale  : 相对音量缩放（默认 1.0，0.5 = 半音量，用于同时叠加多个音效时避免爆音）
##
## 内置名称速查（对应 assets/audio/sfx/ 下同名 .ogg）：
##   UI        : button_click
##   对话      : dialogue_advance
##   战斗-技能 : attack_hit, charge, quixue, sense
##   战斗-伤害 : enemy_hurt, player_hurt
##   战斗-结果 : victory, defeat, awakening_flash
##   奖励      : gold_gain, item_get
func play_sfx(sfx_name: String, volume_scale: float = 1.0) -> void:
	if sfx_name == "":
		return
	## 防御：_ready() 未完成前被调用
	if _sfx_pool.is_empty():
		return
	var stream := _load_audio_stream(SFX_DIR, sfx_name)
	if stream == null:
		return  ## 静默忽略缺失的音效

	## 从池中取下一个空闲播放器（环形复用）
	var player: AudioStreamPlayer = _sfx_pool[_sfx_pool_index]
	_sfx_pool_index = (_sfx_pool_index + 1) % SFX_POOL_SIZE
	player.stream    = stream
	player.volume_db = linear_to_db(max(sfx_volume * clamp(volume_scale, 0.0, 2.0), 0.0001))

	## 音调微扰：在 SFX_PITCH_VARIATION 中登记的音效每次随机偏移，消除机械重复感
	if SFX_PITCH_VARIATION.has(sfx_name):
		var v: float = SFX_PITCH_VARIATION[sfx_name]
		player.pitch_scale = 1.0 + randf_range(-v, v)
	else:
		player.pitch_scale = 1.0

	player.play()


# ══════════════════════════════════════════════════════════════
# 音量控制
# ══════════════════════════════════════════════════════════════

func set_bgm_volume(linear: float) -> void:
	bgm_volume = clamp(linear, 0.0, 1.0)
	## 用户主动调音量时取消对话闪避的恢复 tween，防止 tween 把用户的值覆盖回去
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
		_duck_tween = null
	## 只更新当前活跃播放器：crossfade 期间旧播放器正被 tween 渐出，
	## 若也覆盖其 volume_db 会导致旧 BGM 跳回满音量再被拉回静音（音量弹跳）
	var target_db: float = linear_to_db(bgm_volume) if bgm_volume > 0.0 else -80.0
	if bgm_volume > 0.0 and BGM_LOUDNESS_OFFSET.has(_current_bgm_name):
		target_db += float(BGM_LOUDNESS_OFFSET[_current_bgm_name])
	if _active_bgm_player != null:
		_active_bgm_player.volume_db = target_db


func set_sfx_volume(linear: float) -> void:
	sfx_volume = clamp(linear, 0.0, 1.0)


# ══════════════════════════════════════════════════════════════
# 内部辅助
# ══════════════════════════════════════════════════════════════

## 建立三条音频总线（幂等：已存在则跳过，避免重复调用时创建重名总线）
func _setup_audio_buses() -> void:
	# BGM 总线：Limiter 只防止 crossfade 叠加时爆音，不压缩正常动态
	# 不使用 Compressor：Compressor 会把整个音量范围压平，导致音量滑块失效
	if AudioServer.get_bus_index("BGM") == -1:
		AudioServer.add_bus()
		var b: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(b, "BGM")
		AudioServer.set_bus_send(b, "Master")
		var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
		limiter.ceiling_db   = -0.5  ## 只防止真正的削峰
		limiter.threshold_db = -3.0  ## crossfade 两路同时满音量才会触发
		AudioServer.add_bus_effect(b, limiter)

	# SFX 总线：硬限幅，防止多个音效同帧叠加失真
	if AudioServer.get_bus_index("SFX") == -1:
		AudioServer.add_bus()
		var b: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(b, "SFX")
		AudioServer.set_bus_send(b, "Master")
		var limiter: AudioEffectLimiter = AudioEffectLimiter.new()
		limiter.ceiling_db   = -1.0
		limiter.threshold_db = -6.0
		AudioServer.add_bus_effect(b, limiter)

	# Voice 总线：轻混响，为将来语音配音预留（当前游戏无语音，总线空置无性能开销）
	if AudioServer.get_bus_index("Voice") == -1:
		AudioServer.add_bus()
		var b: int = AudioServer.get_bus_count() - 1
		AudioServer.set_bus_name(b, "Voice")
		AudioServer.set_bus_send(b, "Master")
		var reverb: AudioEffectReverb = AudioEffectReverb.new()
		reverb.room_size = 0.25   ## 小空间感，不显著
		reverb.damping   = 0.75
		reverb.wet       = 0.08   ## 仅 8% 混响，保持干声为主
		reverb.dry       = 1.0
		AudioServer.add_bus_effect(b, reverb)


## 对话开始：BGM 压至 40%（0.4秒渐变）
## v40.11: duck 目标也要应用 LOUDNESS_OFFSET, 否则带 offset 的 BGM duck 后比应有水平高
func _on_dialogue_duck_start(_scene_id: String) -> void:
	if not _active_bgm_player or not _active_bgm_player.playing:
		return
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var target_db: float = linear_to_db(max(bgm_volume * 0.4, 0.0001))
	if BGM_LOUDNESS_OFFSET.has(_current_bgm_name):
		target_db += float(BGM_LOUDNESS_OFFSET[_current_bgm_name])
	_duck_tween = create_tween()
	_duck_tween.tween_property(
		_active_bgm_player, "volume_db",
		target_db, 0.4
	).set_ease(Tween.EASE_OUT)


## 对话结束：等待1.5秒后缓慢恢复原音量（1.0秒渐变）
## v40.11 修复: 恢复目标也要应用 LOUDNESS_OFFSET
## (典型症状: 战斗 tutorial 对话结束后 BGM 跳响 5dB, 因为没加 offset)
func _on_dialogue_duck_end(_scene_id: String) -> void:
	if _duck_tween and _duck_tween.is_valid():
		_duck_tween.kill()
	var target_db: float = linear_to_db(max(bgm_volume, 0.0001))
	if BGM_LOUDNESS_OFFSET.has(_current_bgm_name):
		target_db += float(BGM_LOUDNESS_OFFSET[_current_bgm_name])
	_duck_tween = create_tween()
	# 先等待，再恢复（用tween串联，比SceneTreeTimer更易取消）
	_duck_tween.tween_interval(1.5)
	if _active_bgm_player:
		_duck_tween.tween_property(
			_active_bgm_player, "volume_db",
			target_db, 1.0
		).set_ease(Tween.EASE_IN_OUT)


## 加载音频文件，缓存。文件不存在返回 null
func _load_audio_stream(dir: String, audio_name: String) -> AudioStream:
	var cache_key := dir + audio_name
	if _stream_cache.has(cache_key):
		return _stream_cache[cache_key]
	if _missing_streams.has(cache_key):
		return null

	## 尝试 .ogg 优先，.wav 兜底
	var extensions: Array[String] = [".ogg", ".wav", ".mp3"]
	for ext in extensions:
		var path: String = dir + audio_name + ext
		if ResourceLoader.exists(path, "AudioStream"):
			var stream: AudioStream = load(path)
			if stream != null:
				_stream_cache[cache_key] = stream
				return stream

	## 全部找不到：标记为缺失，下次直接返回null
	_missing_streams[cache_key] = true
	return null
