## 區域的警戒狀態（每個 Level 一個）：
##   NONE（平常）→ ALERT（有人追著你）→ EVASION（跟丟了，大家在搜）→ CAUTION（回去巡邏，但特別警覺）→ NONE
## 敵人發現你時會呼叫同伴：
##   怪物：叫聲傳得到的範圍內（call_radius_tiles）的同伴會趕過來；範圍內沒有同伴就沒人來。
##   人類：有無線電的會先花一點時間通報（這時打倒或打斷牠，通報就失敗），通報成功 = 整個區域都知道你在哪，
##        區域資料有 reinforcements 的話還會從門口進來增援。沒有無線電就只能大喊（範圍跟怪物一樣）。
class_name AlertNetwork
extends Node

enum Phase { NONE, ALERT, EVASION, CAUTION }
const PHASE_NAMES := ["", "ALERT", "EVASION", "CAUTION"]

@export var evasion_time := 20.0
@export var caution_time := 30.0
## 警戒（CAUTION）時大家的視野加成時間（秒）
@export var caution_vigilance := 30.0

signal phase_changed(phase: Phase)
## 無線電通報成功（main 用來派增援）
signal radio_called(caller: Node, last_known: Vector2)

var phase := Phase.NONE
var timer := 0.0
var last_known := Vector2.ZERO
var calls := 0
var radio_calls := 0


func _physics_process(delta: float) -> void:
	var alert := false
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.is_dead and not e.is_boss() and e.state == Enemy.State.ALERT:
			alert = true
			if e.sees_player:
				last_known = e.last_contact()
	match phase:
		Phase.NONE, Phase.CAUTION:
			if alert:
				_set_phase(Phase.ALERT)
			elif phase == Phase.CAUTION:
				timer -= delta
				if timer <= 0.0:
					_set_phase(Phase.NONE)
		Phase.ALERT:
			if not alert:
				_set_phase(Phase.EVASION)
				timer = evasion_time
				_spread_search()
		Phase.EVASION:
			if alert:
				_set_phase(Phase.ALERT)
			else:
				timer -= delta
				if timer <= 0.0:
					_set_phase(Phase.CAUTION)
					timer = caution_time
					for node in get_tree().get_nodes_in_group("enemies"):
						if node is Enemy:
							node.set_vigilant(caution_vigilance)


func phase_name() -> String:
	return PHASE_NAMES[phase]


## 怪物的叫聲／人類的大喊：範圍內的同伴趕過來
func call_allies(caller: Enemy, radius: float, target: Vector2) -> int:
	calls += 1
	last_known = target
	var answered := 0
	if not is_inside_tree():
		return 0  # 換區域的那一幀：舊地圖已經移除
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e == null or e == caller or e.is_dead or e.is_boss():
			continue
		if e.global_position.distance_to(caller.global_position) <= radius and e.answer_call(target):
			answered += 1
	return answered


## 無線電：整個區域的人類都知道你在哪
func radio_call(caller: Enemy, target: Vector2) -> void:
	radio_calls += 1
	last_known = target
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and e != caller and not e.is_dead and e.faction == "human":
			e.answer_call(target)
	radio_called.emit(caller, target)


func _set_phase(p: Phase) -> void:
	if p == phase:
		return
	phase = p
	phase_changed.emit(p)


## 跟丟了：所有醒著的敵人到最後看到你的地方附近搜
func _spread_search() -> void:
	for node in get_tree().get_nodes_in_group("enemies"):
		var e := node as Enemy
		if e and not e.is_dead and not e.is_dormant and not e.is_boss() and e.state != Enemy.State.UNAWARE:
			e.search_near(last_known)


## v0.12：發現屍體 → 整區戒備（還沒在警戒時才降到 CAUTION；已經 ALERT 就不動）
func raise_caution(at: Vector2) -> void:
	last_known = at
	if phase == Phase.NONE or phase == Phase.CAUTION:
		_set_phase(Phase.CAUTION)
		timer = caution_time
		for node in get_tree().get_nodes_in_group("enemies"):
			if node is Enemy:
				node.set_vigilant(caution_vigilance)
