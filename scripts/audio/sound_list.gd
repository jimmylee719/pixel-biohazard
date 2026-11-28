## 所有音效、音樂、環境音的清單（id 就是檔名）。
## 檔案放在 assets/audio/sfx|music|ambience/<id>.ogg（也接受 .mp3、.wav），
## 同一個音效可以有多個版本：<id>_1.ogg、<id>_2.ogg…，播放時隨機挑一個。
## 沒有檔案時不會出聲、也不會出錯，所以可以邊做邊補。
## 提示詞（給生成工具用）在 docs/AUDIO_PROMPTS.md，id 要和這裡一致（測試會檢查）。
class_name SoundList
extends RefCounted

## vol：音量（dB）；dist：聽得到的距離（格），0 = 不分位置（介面音、主角自己的聲音也可以給 0）
const SFX := {
	# 主角
	"step_concrete": {"vol": -14.0, "dist": 8},
	"step_snow": {"vol": -12.0, "dist": 8},
	"step_metal": {"vol": -12.0, "dist": 8},
	"step_wood": {"vol": -12.0, "dist": 8},
	"step_carpet": {"vol": -16.0, "dist": 6},
	"player_hurt": {"vol": -4.0, "dist": 0},
	"player_death": {"vol": -2.0, "dist": 0},
	"shiver_breath": {"vol": -10.0, "dist": 0},
	"locker_open": {"vol": -8.0, "dist": 10},
	"locker_close": {"vol": -8.0, "dist": 10},
	"knock": {"vol": -6.0, "dist": 12},
	# 光
	"flashlight_click": {"vol": -12.0, "dist": 0},
	"lighter_flick": {"vol": -10.0, "dist": 0},
	# 武器
	"pistol_shot": {"vol": -2.0, "dist": 30},
	"shotgun_shot": {"vol": 0.0, "dist": 36},
	"revolver_shot": {"vol": -1.0, "dist": 34},
	"rifle_shot": {"vol": 0.0, "dist": 40},
	"smg_shot": {"vol": -4.0, "dist": 30},
	"suppressed_shot": {"vol": -8.0, "dist": 6},
	"crossbow_shot": {"vol": -6.0, "dist": 8},
	"nailgun_shot": {"vol": -6.0, "dist": 8},
	"flare_shot": {"vol": -4.0, "dist": 20},
	"gun_empty": {"vol": -8.0, "dist": 0},
	"reload": {"vol": -8.0, "dist": 0},
	"knife_swing": {"vol": -8.0, "dist": 8},
	"knife_hit": {"vol": -6.0, "dist": 10},
	"bullet_hit_flesh": {"vol": -6.0, "dist": 16},
	"punch_hit": {"vol": -6.0, "dist": 10},
	"kick_hit": {"vol": -4.0, "dist": 12},
	"body_slam": {"vol": -3.0, "dist": 18},
	"grab": {"vol": -8.0, "dist": 8},
	# 投擲與環境互動
	"throw_whoosh": {"vol": -10.0, "dist": 8},
	"stone_land": {"vol": -6.0, "dist": 16},
	"bottle_break": {"vol": -4.0, "dist": 20},
	"molotov_ignite": {"vol": -3.0, "dist": 20},
	"fire_loop": {"vol": -10.0, "dist": 10, "loop": true},
	"extinguisher_spray": {"vol": -6.0, "dist": 14},
	"extinguisher_clang": {"vol": -2.0, "dist": 24},
	"wood_break": {"vol": -3.0, "dist": 20},
	"drum_ignite": {"vol": -2.0, "dist": 24},
	# 物件
	"pickup_item": {"vol": -8.0, "dist": 0},
	"pickup_key": {"vol": -6.0, "dist": 0},
	"door_open": {"vol": -6.0, "dist": 0},
	"door_locked": {"vol": -6.0, "dist": 0},
	"stairs": {"vol": -8.0, "dist": 0},
	"generator_start": {"vol": -2.0, "dist": 0},
	"breaker_switch": {"vol": -4.0, "dist": 0},
	"terminal_beep": {"vol": -8.0, "dist": 0},
	"radio_static": {"vol": -8.0, "dist": 0},
	"radio_tune": {"vol": -10.0, "dist": 0},
	"save_chime": {"vol": -6.0, "dist": 0},
	"snowcat_engine": {"vol": -4.0, "dist": 0},
	"lift_machinery": {"vol": -4.0, "dist": 0},
	"uplink_transmit": {"vol": -4.0, "dist": 0},
	# 敵人
	"watcher_groan": {"vol": -6.0, "dist": 14},
	"watcher_attack": {"vol": -4.0, "dist": 12},
	"listener_click": {"vol": -6.0, "dist": 16},
	"listener_shriek": {"vol": -2.0, "dist": 30},
	"sleeper_wake": {"vol": -4.0, "dist": 16},
	"enemy_hurt": {"vol": -6.0, "dist": 14},
	"enemy_death": {"vol": -4.0, "dist": 16},
	"enemy_burn": {"vol": -6.0, "dist": 14},
	"bear_roar": {"vol": 0.0, "dist": 40},
	"bear_charge": {"vol": -2.0, "dist": 30},
	"well_pulse_charge": {"vol": -2.0, "dist": 40},
	"well_pulse_blast": {"vol": 0.0, "dist": 40},
	"well_crystal_crack": {"vol": -2.0, "dist": 40},
	# v0.16：新機制
	"choke_struggle": {"vol": -8.0, "dist": 6},
	"crystal_resonance": {"vol": -6.0, "dist": 20},
	"radio_song": {"vol": -8.0, "dist": 16},
	# 介面與提示
	"alert_sting": {"vol": -3.0, "dist": 0},
	"suspicious_sting": {"vol": -8.0, "dist": 0},
	"ui_move": {"vol": -14.0, "dist": 0},
	"ui_confirm": {"vol": -10.0, "dist": 0},
	"ui_cancel": {"vol": -12.0, "dist": 0},
	"mission_complete": {"vol": -6.0, "dist": 0},
}

## 音樂：全部要能無縫循環（ending 除外）
const MUSIC := {
	"title": {"vol": -6.0},
	"explore_station": {"vol": -10.0},
	"explore_outdoor": {"vol": -12.0},
	"safe_room": {"vol": -8.0},
	"chase": {"vol": -6.0},
	"boss_bear": {"vol": -5.0},
	"boss_well": {"vol": -5.0},
	"ending": {"vol": -6.0, "loop": false},
}

## 環境音：持續循環的底噪
const AMBIENCE := {
	"amb_blizzard": {"vol": -10.0},
	"amb_station_hum": {"vol": -16.0},
	"amb_station_dark": {"vol": -14.0},
	"amb_shaft": {"vol": -12.0},
}


static func all_ids() -> Array[String]:
	var ids: Array[String] = []
	for d in [SFX, MUSIC, AMBIENCE]:
		for id in d:
			ids.append(id)
	return ids
