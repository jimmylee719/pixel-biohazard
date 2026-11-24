## 主角：8 方向移動（潛行／走路／奔跑）、手電筒、發出聲音。
## 所有輸入只透過 InputMap 動作名稱讀取，之後加觸控和手把不用改這裡。
class_name Player
extends CharacterBody2D

enum Gait { IDLE, SNEAK, WALK, RUN }

const TILE := 16.0

@export_group("移動")
@export var sneak_speed := 36.0
@export var walk_speed := 62.0
@export var run_speed := 108.0
@export var acceleration := 900.0
@export var turn_smoothing := 14.0

@export_group("視野與光")
@export var flashlight_range := 150.0
@export var flashlight_half_angle_deg := 28.0
## 不開手電筒時，看得到身邊多遠
@export var dark_sight_radius := 56.0

@export_group("聲音（半徑單位：格）")
@export var walk_noise_tiles := 2.0
@export var run_noise_tiles := 6.0
@export var walk_noise_interval := 0.5
@export var run_noise_interval := 0.3

var facing := Vector2.DOWN
var gait := Gait.IDLE
var sneaking := false
var flashlight_on := true
var input_enabled := true

var _noise_timer := 0.0

@onready var _flashlight: PointLight2D = $Flashlight
@onready var _ambient: PointLight2D = $AmbientLight
@onready var _facing_marker: Node2D = $FacingMarker


func _ready() -> void:
	_flashlight.texture = LightTextures.make_cone(flashlight_half_angle_deg)
	_flashlight.texture_scale = flashlight_range / (LightTextures.SIZE * 0.5)
	_ambient.texture = LightTextures.make_radial()
	_ambient.texture_scale = (dark_sight_radius * 1.4) / (LightTextures.SIZE * 0.5)
	_apply_flashlight()


func _physics_process(delta: float) -> void:
	var move_input := Vector2.ZERO
	if input_enabled:
		move_input = Input.get_vector("move_left", "move_right", "move_up", "move_down")
		if Input.is_action_just_pressed("sneak"):
			sneaking = not sneaking
		if Input.is_action_just_pressed("flashlight"):
			flashlight_on = not flashlight_on
			_apply_flashlight()

	var running := input_enabled and Input.is_action_pressed("run") and move_input != Vector2.ZERO
	if running:
		sneaking = false

	var speed := walk_speed
	if running:
		speed = run_speed
	elif sneaking:
		speed = sneak_speed
	velocity = velocity.move_toward(move_input * speed, acceleration * delta)
	move_and_slide()

	if move_input.length() > 0.1:
		facing = facing.slerp(move_input.normalized(), 1.0 - exp(-turn_smoothing * delta)).normalized()

	if velocity.length() < 4.0:
		gait = Gait.IDLE
	elif running:
		gait = Gait.RUN
	elif sneaking:
		gait = Gait.SNEAK
	else:
		gait = Gait.WALK

	_flashlight.rotation = facing.angle()
	_facing_marker.rotation = facing.angle()
	_update_noise(delta)


func reset_to(spawn: Vector2) -> void:
	global_position = spawn
	velocity = Vector2.ZERO
	facing = Vector2.UP
	sneaking = false
	_noise_timer = 0.0


## 主角看不看得到某一點：沒被牆擋住，而且在身邊微光或手電筒光錐範圍內。
func can_see_point(point: Vector2) -> bool:
	var dist := global_position.distance_to(point)
	var lit := dist <= dark_sight_radius or is_in_flashlight(point)
	return lit and Sight.is_clear(self, global_position, point)


func is_in_flashlight(point: Vector2) -> bool:
	return flashlight_on and Sight.in_cone(
		global_position, facing, point, deg_to_rad(flashlight_half_angle_deg), flashlight_range)


## 敵人的視野距離倍率：開手電筒的人在黑暗中很顯眼。
func get_detection_range_mult() -> float:
	var mult := 1.4 if flashlight_on else 0.7
	if gait == Gait.SNEAK or (gait == Gait.IDLE and sneaking):
		mult *= 0.85
	return mult


## 敵人的察覺速度倍率：動作越大、越亮，越快被發現。
func get_detection_rate_mult() -> float:
	var mult := 1.5 if flashlight_on else 0.8
	match gait:
		Gait.RUN:
			mult *= 1.6
		Gait.SNEAK:
			mult *= 0.55
		Gait.IDLE:
			mult *= 0.5 if sneaking else 0.7
	return mult


func get_gait_name() -> String:
	return ["IDLE", "SNEAK", "WALK", "RUN"][gait]


func _apply_flashlight() -> void:
	_flashlight.enabled = flashlight_on


func _update_noise(delta: float) -> void:
	var radius := 0.0
	var interval := 0.0
	match gait:
		Gait.WALK:
			radius = walk_noise_tiles * TILE
			interval = walk_noise_interval
		Gait.RUN:
			radius = run_noise_tiles * TILE
			interval = run_noise_interval
		_:
			_noise_timer = 0.0
			return
	_noise_timer -= delta
	if _noise_timer <= 0.0:
		_noise_timer = interval
		NoiseBus.emit_noise(global_position, radius, self)
