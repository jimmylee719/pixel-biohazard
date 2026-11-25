## 聲音播放（自動載入 Sfx）：音效、音樂、環境音，外加手機震動。
## 用法：Sfx.play("pistol_shot", global_position)、Sfx.play_music("chase")、Sfx.play_ambience("amb_blizzard")。
## 清單在 SoundList；找不到檔案就安靜略過（美術、音效可以之後再補）。
## 注意：這只是「玩家聽到的聲音」。敵人聽到的聲音是 NoiseBus，兩者分開。
extends Node

const ROOT := "res://assets/audio/"
const EXTS := ["ogg", "mp3", "wav"]
const MAX_VARIANTS := 8
const POOL_2D := 14
const POOL_FLAT := 6
const MUSIC_FADE := 1.2

## 最近播過的 id（測試用，也方便除錯）
var history: Array[String] = []
var current_music := ""
var current_ambience := ""

var _cache := {}
var _pool_2d: Array[AudioStreamPlayer2D] = []
var _pool_flat: Array[AudioStreamPlayer] = []
var _next_2d := 0
var _next_flat := 0
var _music: Array[AudioStreamPlayer] = []
var _music_index := 0
var _ambience: AudioStreamPlayer
var _tweens := {}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	for bus in ["Music", "SFX", "Ambience"]:
		if AudioServer.get_bus_index(bus) == -1:
			AudioServer.add_bus()
			var i := AudioServer.bus_count - 1
			AudioServer.set_bus_name(i, bus)
			AudioServer.set_bus_send(i, "Master")
	for i in POOL_2D:
		var p := AudioStreamPlayer2D.new()
		p.bus = "SFX"
		add_child(p)
		_pool_2d.append(p)
	for i in POOL_FLAT:
		var p := AudioStreamPlayer.new()
		p.bus = "SFX"
		add_child(p)
		_pool_flat.append(p)
	for i in 2:
		var m := AudioStreamPlayer.new()
		m.bus = "Music"
		add_child(m)
		_music.append(m)
	_ambience = AudioStreamPlayer.new()
	_ambience.bus = "Ambience"
	add_child(_ambience)


# ── 音效 ─────────────────────────────────────────────

## 播一個音效。pos 是世界座標（Vector2）；不給就是不分位置（介面音、主角自己的聲音）。
func play(id: String, pos: Variant = null, pitch_jitter := 0.06, volume_offset := 0.0) -> void:
	var def: Dictionary = SoundList.SFX.get(id, {})
	if def.is_empty():
		push_warning("Sfx: 清單裡沒有音效 %s" % id)
		return
	_remember(id)
	var stream := _stream("sfx", id)
	if stream == null:
		return
	var pitch := 1.0 + randf_range(-pitch_jitter, pitch_jitter)
	var vol: float = def.get("vol", 0.0) + volume_offset
	var dist: float = def.get("dist", 0)
	if pos is Vector2 and dist > 0:
		var p := _pool_2d[_next_2d]
		_next_2d = (_next_2d + 1) % POOL_2D
		p.stream = stream
		p.global_position = pos
		p.max_distance = dist * 16.0
		p.volume_db = vol
		p.pitch_scale = pitch
		p.play()
	else:
		var p := _pool_flat[_next_flat]
		_next_flat = (_next_flat + 1) % POOL_FLAT
		p.stream = stream
		p.volume_db = vol
		p.pitch_scale = pitch
		p.play()


## 在某個節點身上放一個持續循環的音效（例如火），節點消失時聲音跟著消失。
func attach_loop(owner_node: Node2D, id: String) -> AudioStreamPlayer2D:
	var def: Dictionary = SoundList.SFX.get(id, {})
	_remember(id)
	var stream := _stream("sfx", id, true)
	if stream == null:
		return null
	var p := AudioStreamPlayer2D.new()
	p.bus = "SFX"
	p.stream = stream
	p.volume_db = def.get("vol", 0.0)
	p.max_distance = float(def.get("dist", 10)) * 16.0
	p.autoplay = true
	owner_node.add_child(p)
	return p


# ── 音樂與環境音 ─────────────────────────────────────

## 換音樂（交叉淡入淡出）。id 空字串 = 停掉。
func play_music(id: String, fade := MUSIC_FADE) -> void:
	if id == current_music:
		return
	current_music = id
	if id != "":
		_remember(id)
	var old := _music[_music_index]
	_fade(old, -60.0, fade, true)
	var def: Dictionary = SoundList.MUSIC.get(id, {})
	if id != "" and def.is_empty():
		push_warning("Sfx: 清單裡沒有音樂 %s" % id)
	var stream: AudioStream = null
	if not def.is_empty():
		stream = _stream("music", id, def.get("loop", true))
	if stream == null:
		return
	_music_index = 1 - _music_index
	var m := _music[_music_index]
	m.stream = stream
	m.volume_db = -40.0
	m.play()
	_fade(m, def.get("vol", -8.0), fade, false)


func play_ambience(id: String, fade := 2.0) -> void:
	if id == current_ambience:
		return
	current_ambience = id
	if id == "":
		_fade(_ambience, -60.0, fade, true)
		return
	_remember(id)
	var stream := _stream("ambience", id, true)
	if stream == null:
		_ambience.stop()
		return
	_ambience.stream = stream
	_ambience.volume_db = -40.0
	_ambience.play()
	_fade(_ambience, SoundList.AMBIENCE[id].get("vol", -12.0), fade, false)


func set_bus_volume(bus: String, linear: float) -> void:
	var i := AudioServer.get_bus_index(bus)
	if i != -1:
		AudioServer.set_bus_volume_db(i, linear_to_db(maxf(linear, 0.0001)))


# ── 震動（只在手機上） ───────────────────────────────

func rumble(duration_ms: int, amplitude := 0.5) -> void:
	if OS.has_feature("mobile"):
		Input.vibrate_handheld(duration_ms, amplitude)


## 這個 id 有沒有聲音檔（測試、除錯用）
func has_file(id: String) -> bool:
	var folder := "sfx"
	if SoundList.MUSIC.has(id):
		folder = "music"
	elif SoundList.AMBIENCE.has(id):
		folder = "ambience"
	return _stream(folder, id) != null


# ── 內部 ─────────────────────────────────────────────

func _remember(id: String) -> void:
	history.append(id)
	if history.size() > 64:
		history.pop_front()


func _fade(player: AudioStreamPlayer, to_db: float, duration: float, stop_after: bool) -> void:
	if _tweens.has(player) and _tweens[player].is_valid():
		_tweens[player].kill()
	if not player.playing:
		return
	var t := create_tween()
	t.tween_property(player, "volume_db", to_db, duration)
	if stop_after:
		t.tween_callback(player.stop)
	_tweens[player] = t


## 找檔案：<id>.ogg 或 <id>_1.ogg、<id>_2.ogg…（有多個就隨機挑）
func _stream(folder: String, id: String, loop := false) -> AudioStream:
	var key := folder + "/" + id
	if not _cache.has(key):
		var found: Array[AudioStream] = []
		var names: Array[String] = [id]
		for i in range(1, MAX_VARIANTS + 1):
			names.append("%s_%d" % [id, i])
		# 先找正式素材；沒有的話用程式合成的暫代版（assets/audio/synth/，tools/synth_audio.py 產生）
		for base in [ROOT + folder, ROOT + "synth/" + folder]:
			for n in names:
				for ext in EXTS:
					var path := "%s/%s.%s" % [base, n, ext]
					if ResourceLoader.exists(path):
						var s := load(path) as AudioStream
						if s:
							found.append(s)
						break
			if not found.is_empty():
				break
		_cache[key] = found
	var list: Array = _cache[key]
	if list.is_empty():
		return null
	var stream: AudioStream = list[randi() % list.size()]
	if loop:
		_set_loop(stream)
	return stream


func _set_loop(stream: AudioStream) -> void:
	if stream is AudioStreamOggVorbis:
		stream.loop = true
	elif stream is AudioStreamMP3:
		stream.loop = true
	elif stream is AudioStreamWAV:
		var wav := stream as AudioStreamWAV
		if wav.loop_mode == AudioStreamWAV.LOOP_DISABLED:
			wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
			wav.loop_begin = 0
			wav.loop_end = int(wav.get_length() * wav.mix_rate)
