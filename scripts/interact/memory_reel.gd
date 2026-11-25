## 盤式錄音機（地圖符號 &）：迴頻訊號會把聽過它的那一刻「錄」下來；播放這捲帶子＝走進那段記憶。
## 區域資料 reels：{"x,y": {to, entry, scene, prompt, flag, text}}
##   to／entry  播放後載入的區域和入口（例如地下室的錄音機 → 1962 年的燈籠站）
##   scene      播放前先演的過場（可省略）
##   flag       播放後設定的旗標（例如 memory:lantern = 看完了 1962 年的記憶）
##   needs      需要這個旗標才能播放（可省略）；沒有時顯示 text
class_name MemoryReel
extends Interactable

signal play_reel(target_area: String, entry: String, scene: String, flag: String)
signal message_shown(text: String)

var target_area := ""
var target_entry := "start"
var scene := ""
var flag := ""
var needs := ""
var locked_text := ""
var prompt_text := "Play the reel"

var _glow: PointLight2D
var _t := 0.0


func _ready() -> void:
	_glow = PointLight2D.new()
	_glow.texture = LightTextures.make_radial()
	_glow.texture_scale = 26.0 / (LightTextures.SIZE * 0.5)
	_glow.color = Color(1.0, 0.45, 0.2)
	_glow.energy = 0.7
	add_child(_glow)


func _process(delta: float) -> void:
	_t += delta
	queue_redraw()


func can_interact(player: Player) -> bool:
	return enabled and not player.is_hiding


func get_prompt(_player: Player) -> String:
	return prompt_text


func interact(_player: Player) -> void:
	Sfx.play("terminal_beep", global_position)
	if needs != "" and not WorldState.has_flag(needs):
		message_shown.emit(locked_text)
		return
	play_reel.emit(target_area, target_entry, scene, flag)


func _draw() -> void:
	# 錄音機本體＋兩個轉動的盤
	draw_rect(Rect2(-7, -4, 14, 9), Color(0.32, 0.27, 0.22))
	draw_rect(Rect2(-7, -4, 14, 1), Color(0.55, 0.48, 0.38))
	for cx: float in [-3.5, 3.5]:
		var center := Vector2(cx, -1)
		draw_circle(center, 2.6, Color(0.12, 0.1, 0.09))
		var a := _t * 3.0 + cx
		draw_line(center, center + Vector2(cos(a), sin(a)) * 2.4, Color(0.75, 0.68, 0.55))
	draw_rect(Rect2(-5, 3, 2, 1), Color(1.0, 0.3, 0.2) if int(_t * 2.0) % 2 == 0 else Color(0.4, 0.1, 0.1))
