## 最終 Boss「深井」：最早被感染的那批研究員，在鑽探井底與菌落融合成一整片會共鳴的結晶體。不會移動。
## - 共鳴脈衝：每隔一段時間蓄力，然後震遍整個井底。躲在柱子後面（擋住視線）或置物櫃裡才安全。
## - 脈衝之後結晶裂開、露出核心（EXPOSED）：只有這時打得痛，其他時候子彈幾乎打不進去，
##   而且被打到會知道你在哪裡。
## - 聽到聲音：在聲音的位置預告後從地下刺出結晶。走路／奔跑在附近會被感覺到；空瓶可以把結晶刺引開。
## - 冷的時候（關掉井底的鑽頭加熱器）蓄力和預告都變慢。
## 沿用 Enemy 的受傷、死亡記錄；行動邏輯全部覆寫。
class_name BossWell
extends Enemy

enum Phase { IDLE, CHARGING, EXPOSED }

@export var boss_id := "deep_well"

@export_group("Boss 行動")
@export var pulse_interval := 5.0
@export var pulse_windup := 1.4
@export var pulse_damage := 28.0
@export var pulse_infection := 18.0
@export var exposed_time := 2.6
## 核心沒露出來時受到的傷害倍率
@export var armor_mult := 0.15
@export var spike_windup := 0.9
@export var spike_radius := 22.0
@export var spike_damage := 30.0
@export var spike_infection := 15.0
@export var spike_cooldown := 1.0
@export var max_spikes := 2
## 走路／奔跑的主角在這個距離內會被感覺到（潛行不會）
@export var boss_feel_range := 90.0

var phase := Phase.IDLE
## 正在預告的結晶刺：[{pos: Vector2, t: float}]
var spikes: Array[Dictionary] = []
## 最近一次脈衝有沒有打到主角（測試、除錯用）
var last_pulse_hit := false
var pulse_count := 0

var _phase_time := 0.0
var _spike_cd := 0.0
var _ring := 0.0
var _hit_flash := 0.0
var _fx: Node2D
## 像素圖（assets/sprites/well/：idle、charge、exposed、dead，tools/gen_pixel_art.py）；沒有圖就用原本的色塊
var _art: AnimatedSprite2D
@onready var _core: Polygon2D = $Body/Core


func _ready() -> void:
	super._ready()
	# 結晶自己會發光：本體和預告效果都不受黑暗影響
	var unshaded := CanvasItemMaterial.new()
	unshaded.light_mode = CanvasItemMaterial.LIGHT_MODE_UNSHADED
	_body.material = unshaded
	for c in _body.get_children():
		c.use_parent_material = true
	_fx = Node2D.new()
	_fx.top_level = true
	_fx.z_index = 2
	_fx.material = unshaded
	add_child(_fx)
	_fx.draw.connect(_draw_fx)
	_build_art(unshaded)


func _build_art(unshaded: Material) -> void:
	var frames := SpriteFrames.new()
	frames.remove_animation("default")
	for anim in ["idle", "charge", "exposed", "dead"]:
		var i := 0
		while ResourceLoader.exists("res://assets/sprites/well/%s_%d.png" % [anim, i]):
			if not frames.has_animation(anim):
				frames.add_animation(anim)
				frames.set_animation_speed(anim, {"idle": 5.0, "exposed": 8.0}.get(anim, 1.0))
				frames.set_animation_loop(anim, anim != "dead")
			frames.add_frame(anim, load("res://assets/sprites/well/%s_%d.png" % [anim, i]))
			i += 1
	if not frames.has_animation("idle"):
		return
	_art = AnimatedSprite2D.new()
	_art.sprite_frames = frames
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_art.material = unshaded  # 結晶自己會發光：不受黑暗影響
	_art.position = Vector2(0, -22)
	_art.play("idle")
	add_child(_art)
	_body.visible = false


## 依階段換圖：待機（呼吸）、蓄力（依進度一格一格脹大、核心透光）、核心露出（脈動）、死亡
func _update_art(charge_k: float) -> void:
	if _art == null:
		return
	if is_dead:
		_art.play("dead")
		return
	match phase:
		Phase.CHARGING:
			_art.animation = "charge"
			_art.pause()
			_art.frame = clampi(int(charge_k * 6.0), 0, _art.sprite_frames.get_frame_count("charge") - 1)
		Phase.EXPOSED:
			if _art.animation != "exposed":
				_art.play("exposed")
		_:
			if _art.animation != "idle" or not _art.is_playing():
				_art.play("idle")
	# 被打中閃一下（打在結晶上偏白、打在核心上偏紅）
	_art.modulate = Color(1, 1, 1).lerp(Color(1.6, 0.8, 0.7) if phase == Phase.EXPOSED else Color(1.5, 1.6, 1.7), _hit_flash)


func reset() -> void:
	super.reset()
	spikes.clear()
	_ring = 0.0
	_spike_cd = 0.0
	pulse_count = 0
	last_pulse_hit = false
	_set_phase(Phase.IDLE)
	_core.visible = false
	if _fx:
		_fx.queue_redraw()


func is_boss() -> bool:
	return true


func boss_suffix() -> String:
	match phase:
		Phase.CHARGING:
			return "  (RESONATING)"
		Phase.EXPOSED:
			return "  (CORE EXPOSED)"
	return ""


func is_watching_player() -> bool:
	return false


func can_be_taken_down_by(_player_node: Player) -> bool:
	return false


func is_exposed() -> bool:
	return phase == Phase.EXPOSED


func _physics_process(delta: float) -> void:
	if _player == null:
		return
	visible_to_player = true
	_body.modulate.a = 1.0
	if is_dead:
		_update_art(0.0)
		_fx.queue_redraw()
		return
	_hit_flash = maxf(_hit_flash - delta * 6.0, 0.0)
	in_cold = _level != null and _level.is_cold(global_position)
	var slow := cold_speed_mult if in_cold else 1.0
	_phase_time += delta
	_spike_cd = maxf(_spike_cd - delta, 0.0)
	_ring = maxf(_ring - delta, 0.0)
	state = State.ALERT
	awareness = 1.0
	winding_up = phase == Phase.CHARGING
	_feel_player()

	match phase:
		Phase.IDLE:
			if _phase_time >= pulse_interval / slow:
				_set_phase(Phase.CHARGING)
		Phase.CHARGING:
			if _phase_time >= pulse_windup / slow:
				_pulse()
				_set_phase(Phase.EXPOSED)
		Phase.EXPOSED:
			if _phase_time >= exposed_time:
				_set_phase(Phase.IDLE)
	_core.visible = phase == Phase.EXPOSED

	for spike in spikes.duplicate():
		spike.t += delta
		if spike.t >= spike_windup / slow:
			spikes.erase(spike)
			if _can_hit_at(spike.pos, spike_radius):
				_player.take_hit(spike_damage, spike_infection, spike.pos)
	# 蓄力時整團結晶微微脹大
	var k := clampf(_phase_time / (pulse_windup / slow), 0.0, 1.0) if phase == Phase.CHARGING else 0.0
	_body.scale = Vector2.ONE * (1.0 + 0.15 * k)
	_update_art(k)
	_fx.queue_redraw()


## 共鳴脈衝：沒被柱子擋住、沒躲起來就會被震到。
func _pulse() -> void:
	Sfx.play("well_pulse_blast", global_position, 0.0)
	Sfx.rumble(250, 0.9)
	pulse_count += 1
	_ring = 0.4
	last_pulse_hit = false
	if _player.is_dead or _player.is_hiding:
		return
	if Sight.is_clear(self, global_position, _player.global_position):
		last_pulse_hit = true
		_player.take_hit(pulse_damage, pulse_infection, global_position)


func _can_hit_at(pos: Vector2, reach: float) -> bool:
	return not _player.is_dead and not _player.is_hiding \
		and pos.distance_to(_player.global_position) <= reach


func _feel_player() -> void:
	if _player.is_hiding or _player.is_dead:
		return
	if _player.gait != Player.Gait.WALK and _player.gait != Player.Gait.RUN:
		return
	if global_position.distance_to(_player.global_position) <= boss_feel_range:
		_hear(_player.global_position)


func _on_noise(pos: Vector2, radius: float, source: Node) -> void:
	if _player == null or source == self or is_dead:
		return
	# 井底很小，結晶貼著岩壁：整個井底的聲音都聽得到（牆後面的減半）
	var effective := radius * hearing_mult
	if not Sight.is_clear(self, global_position, pos):
		effective *= 0.5
	if global_position.distance_to(pos) <= effective:
		_hear(pos)


## 聽到聲音：在那個位置預告一根結晶刺（核心露出來的時候不會）。
func _hear(pos: Vector2) -> void:
	if phase == Phase.EXPOSED or _spike_cd > 0.0 or spikes.size() >= max_spikes:
		return
	spikes.append({"pos": pos, "t": 0.0})
	_spike_cd = spike_cooldown


func _set_phase(p: Phase) -> void:
	phase = p
	_phase_time = 0.0
	match p:
		Phase.CHARGING:
			Sfx.play("well_pulse_charge", global_position, 0.0)
		Phase.EXPOSED:
			Sfx.play("well_crystal_crack", global_position)


func take_damage(amount: float, from_pos: Vector2, _stagger: float) -> void:
	if is_dead:
		return
	_hit_flash = 1.0
	if phase != Phase.EXPOSED:
		amount *= armor_mult
		_hear(from_pos)  # 打在結晶上：牠知道你在哪
	health -= amount
	if health <= 0.0:
		_die()


func _die() -> void:
	spikes.clear()
	_core.visible = false
	super._die()
	_update_art(0.0)
	WorldState.set_flag("defeated:" + boss_id)
	WorldState.emit_event("defeat", boss_id)


func _draw_fx() -> void:
	if is_dead:
		return
	var center := global_position
	# 蓄力：一圈越收越緊的光環
	if phase == Phase.CHARGING:
		var slow := cold_speed_mult if in_cold else 1.0
		var k := clampf(_phase_time / (pulse_windup / slow), 0.0, 1.0)
		_fx.draw_arc(center, lerpf(140.0, 22.0, k), 0.0, TAU, 48, Color(0.6, 1.0, 1.0, 0.35 + 0.5 * k), 1.0)
	# 脈衝：往外擴散的波
	if _ring > 0.0:
		var r := lerpf(20.0, 280.0, 1.0 - _ring / 0.4)
		_fx.draw_arc(center, r, 0.0, TAU, 64, Color(0.8, 1.0, 1.0, _ring / 0.4), 2.0)
	# 結晶刺的預告：地面上的裂紋圈
	for spike in spikes:
		var k2 := clampf(spike.t / spike_windup, 0.0, 1.0)
		_fx.draw_circle(spike.pos, spike_radius * k2, Color(0.5, 0.95, 1.0, 0.25))
		_fx.draw_arc(spike.pos, spike_radius, 0.0, TAU, 20, Color(0.6, 1.0, 1.0, 0.8), 1.0)
