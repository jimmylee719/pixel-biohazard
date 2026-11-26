## 過場的內容（用遊戲畫面演出，見 CutscenePlayer、main.play_cutscene）。
## 區域資料的 "cutscene" 欄位 = 第一次進入這個區域（或房間）時播放哪一段，看過就不再播（旗標 scene:<id>）。
## 步驟：
##   {"caption": 文字, "time": 秒}      畫面上方的地點字幕
##   {"say": 說話的人, "text": 對白}    下方黑邊的對白（按鍵下一句）。說話的人用 [ ] 括起來 = 無線電
##   {"pan": Vector2i(格子), "time": 秒, "light": 半徑}  鏡頭移過去（light = 在那裡放一盞燈，看得清楚）
##   {"pan_enemy": 第幾隻, "time": 秒}  鏡頭移到這個區域的某隻敵人（並讓它顯示出來；合併進來的區域從自己的第一隻算）
##   {"back": 秒}                       鏡頭回到主角
##   {"wait": 秒}、{"sfx": 音效 id}
##   {"era": "1962"／"2099"／""}  換時代的畫面色調（過場結束後回到區域本來的時代）
## 電影式的鏡頭語言（好萊塢電影的節奏：冷開場、硬切、片名卡、人物名牌、特寫、震動）：
##   {"fade_out": 秒}／{"fade_in": 秒}   淡到黑／從黑淡回來（0 = 硬切）
##   {"title_card": 大字, "sub": 小字, "time": 秒}  黑畫面中間的片名卡
##   {"name": 名字, "role": 身分, "time": 秒}       人物第一次登場的名牌（左上滑進來，不擋接下來的步驟）
##   {"credit": 文字, "time": 秒}                   右上角的片頭小字幕
##   {"flash": 強度}、{"shake": 像素, "time": 秒}、{"zoom": 倍率, "time": 秒}、{"music": 音樂 id}
## 文字一律英文原文，中文在 tools/locale/zh_TW.py。
class_name Cutscenes
extends RefCounted

const SHEN := "Shen"

const DATA := {
	"opening": [
		# 冷開場（好萊塢式）：黑畫面 → 1962 年的監聽站 → 訊號說出她的名字 → 硬切 → 片名 → 六十四年後
		{"fade_out": 0.0},
		{"era": "1962"},
		{"credit": "From the LANTERN recordings, reel 9 of 9", "time": 3.0},
		{"caption": "LANTERN Listening Post - March 1962", "time": 2.2},
		{"fade_in": 1.6},
		{"sfx": "radio_static"},
		{"say": "[SATO]", "text": "Carrier on one-two-six-oh-five. Again. It's coming from under the ice."},
		{"say": "[SATO]", "text": "It isn't Morse, Major. It's music. And under the music... a city."},
		{"flash": 0.7},
		{"shake": 3.0, "time": 0.6},
		{"era": "2099"},
		{"say": "[THE CHOIR]", "text": "...hold position. we will come to you. we always come to you..."},
		{"era": "1962"},
		{"say": "[SATO]", "text": "It just said my name."},
		{"fade_out": 0.0},
		{"wait": 1.2},
		{"title_card": "A F T E R S I G N A L", "sub": "Sixty-four years later", "time": 2.4},
		{"era": ""},
		{"pan": Vector2i(11, 9), "time": 0.05, "light": 90.0},
		{"caption": "Greycrow Island, Arctic Ocean - November 2026", "time": 2.0},
		{"fade_in": 2.0},
		{"credit": "78°N  -  120 km from the nearest settlement", "time": 3.0},
		{"say": SHEN, "text": "North Latitude Station. Thirty-one people work there. Not one light on."},
		{"back": 2.4},
		{"name": "SHEN RUONING", "role": "Supply pilot - run 17", "time": 3.2},
		{"say": SHEN, "text": "Supply run seventeen. Drop the crates, refuel, home before dark."},
		{"say": SHEN, "text": "Nobody answered the landing call. Nobody came out for the crates."},
		{"say": SHEN, "text": "The rotor iced up on the way in. I'm not flying anywhere tonight."},
		{"zoom": 1.5, "time": 1.4},
		{"say": SHEN, "text": "Somebody in there has a radio. Find it."},
		{"zoom": 1.0, "time": 0.8},
	],
	"station_first": [
		{"say": SHEN, "text": "Hello? It's the supply pilot. Your landing pad is buried..."},
		{"pan_enemy": 0, "time": 1.6},
		{"zoom": 1.6, "time": 0.7},
		{"sfx": "watcher_groan"},
		{"shake": 2.0, "time": 0.4},
		{"wait": 0.8},
		{"say": SHEN, "text": "...That was a person. The eyes are gone. Frost is growing out of the skin."},
		{"say": SHEN, "text": "It turned toward my voice - not toward my light."},
		{"zoom": 1.0, "time": 0.6},
		{"back": 1.0},
		{"say": SHEN, "text": "Quiet, then. Stay out of its way."},
	],
	"clean_room": [
		{"say": SHEN, "text": "A clean room. Sealed door, its own air. Nothing followed me in."},
		{"say": SHEN, "text": "And a radio. I can save what I know here - and listen. Somebody might be talking."},
		{"sfx": "radio_static"},
		{"name": "DR. INA KOVAC", "role": "Microbiologist - mainland relay", "time": 3.0},
		{"say": "[KOVAC]", "text": "...anyone at North Latitude? This is Ana Kovac, on the mainland relay. Is anyone still alive up there?"},
		{"say": SHEN, "text": "Supply pilot. Shen Ruoning. Your station is full of people who aren't people anymore."},
		{"say": "[KOVAC]", "text": "Then listen carefully. They can't see you. They hear everything. Stay quiet, stay cold - and stay away from the drill shaft."},
	],
	"hangar": [
		{"pan_enemy": 0, "time": 1.8},
		{"say": SHEN, "text": "Something big is breathing in there."},
		{"zoom": 1.4, "time": 0.8},
		{"sfx": "bear_roar"},
		{"shake": 4.0, "time": 0.9},
		{"name": "TUNDRA MOTHER", "role": "Infected polar bear", "time": 2.6},
		{"wait": 1.0},
		{"say": SHEN, "text": "The hangar isn't empty. It's hers."},
		{"zoom": 1.0, "time": 0.6},
		{"back": 1.0},
	],
	"tower": [
		{"say": SHEN, "text": "The antenna tower. If the battery holds, one message reaches the mainland."},
		{"say": SHEN, "text": "One message. I'd better be sure who I'm calling."},
	],
	"shaft": [
		{"fade_out": 0.6},
		{"caption": "Drill Shaft - 400 m below the station", "time": 1.6},
		{"fade_in": 1.4},
		{"say": SHEN, "text": "Four hundred meters, straight down."},
		{"say": SHEN, "text": "The director's last note said only three words. 'It sings back.'"},
	],
	"harbor": [
		{"sfx": "radio_static"},
		{"say": "[GATE-2]", "text": "Gate One, Gate Two. Harbor perimeter is set. Nothing leaves this island."},
		{"pan_enemy": 0, "time": 1.6},
		{"name": "THE GATEKEEPERS", "role": "Quiet Accord containment unit", "time": 3.0},
		{"say": "[GATE-1]", "text": "Copy. Survivors are to be held, not evacuated. Anything that runs, you stop."},
		{"say": SHEN, "text": "Soldiers. That isn't a rescue."},
		{"say": SHEN, "text": "Whoever sent them knew exactly what was on this island."},
		{"back": 1.0},
		{"say": SHEN, "text": "They carry radios. If one of them calls it in, the whole harbor comes down on me."},
	],
	"caves": [
		{"say": SHEN, "text": "The ice is glowing. The whole cave is full of it."},
		{"say": SHEN, "text": "And something down here is moving across the floor. On its hands."},
	],
	"east_wing": [
		{"say": SHEN, "text": "The east wing. Biology labs. The doors were sealed from this side."},
		{"pan_enemy": 1, "time": 1.6},
		{"say": SHEN, "text": "...Something in there is singing."},
		{"back": 1.0},
		{"say": SHEN, "text": "If it sees me, everything on this floor will hear it."},
	],
	"gate_one": [
		{"caption": "Gate One - Gatekeeper forward base", "time": 2.0},
		{"sfx": "radio_static"},
		{"say": "[GATE-1]", "text": "All posts, Gate One. Ice tunnel is unwatched since the dogs went bad. Double the yard."},
		{"pan_enemy": 0, "time": 1.6},
		{"say": SHEN, "text": "Their headquarters. Fences, trucks, a gatehouse - and somewhere inside, whoever gives the orders."},
		{"back": 1.0},
		{"say": SHEN, "text": "If anyone on this island knows what's really going on, it's in there."},
	],
	"reel_b1": [
		{"say": SHEN, "text": "A reel-to-reel recorder. Older than the station. The label says LANTERN, 15-III-1962."},
		{"say": SHEN, "text": "The tape is warm. It shouldn't be warm."},
		{"sfx": "radio_static"},
		{"era": "1962"},
		{"say": SHEN, "text": "The hiss fills the room - and the room changes around it."},
	],
	"lantern_enter": [
		{"caption": "LANTERN Listening Post - 15 March 1962, 02:40", "time": 2.2},
		{"say": SHEN, "text": "This is the basement. Sixty-four years ago. I can smell the cigarettes."},
		{"say": SHEN, "text": "The colony in the ice sings - and its song kept everything that ever heard it. Including this night."},
		{"pan_enemy": 0, "time": 1.6},
		{"say": SHEN, "text": "Soldiers. If they see me, the memory starts over. The recording room is at the far end of the post."},
		{"back": 1.0},
	],
	"lantern_signal": [
		{"caption": "Recording room - 03:12", "time": 1.8},
		{"sfx": "radio_static"},
		{"name": "CPL. KENJI SATO", "role": "LANTERN radio operator - 1962", "time": 3.0},
		{"say": "[SATO]", "text": "Last reel. If the Major finds this one, it goes to Geneva with the rest."},
		{"say": "[SATO]", "text": "Whoever is playing this: the thing in the ice is alive. It sings on this frequency - and the song is coming from the future."},
		{"flash": 0.8},
		{"shake": 3.0, "time": 0.6},
		{"era": "2099"},
		{"caption": "126.05 MHz - origin: 2099", "time": 2.0},
		{"say": "[THE CHOIR]", "text": "we are the city at the end of your century. one voice. no cold, no dark, no alone."},
		{"say": "[THE CHOIR]", "text": "we are sending ourselves back so that you will build us. thank you for listening."},
		{"era": "1962"},
		{"say": "[SATO]", "text": "The Accord is meeting on the twentieth. They'll bury it under the ice and call it a weather station."},
		{"say": "[SATO]", "text": "I hid supplies in the maintenance room. For whoever comes next. It said someone would."},
		{"era": ""},
		{"say": SHEN, "text": "The reel runs out. Sixty-four years, and it's the same voice on the same frequency."},
	],
	"deep_well": [
		{"fade_out": 0.0},
		{"caption": "Shaft Bottom - 400 m", "time": 1.4},
		{"fade_in": 1.6},
		{"pan_enemy": 0, "time": 2.0},
		{"zoom": 1.3, "time": 1.0},
		{"sfx": "well_pulse_charge"},
		{"shake": 3.0, "time": 1.0},
		{"name": "THE DEEP WELL", "role": "What was waiting under the ice", "time": 3.0},
		{"say": SHEN, "text": "Forty thousand years under the ice. And the whole time, it's been singing."},
		{"say": SHEN, "text": "Same pitch as the reel. Same pitch as the city."},
		{"zoom": 1.0, "time": 0.8},
		{"back": 1.2},
		{"say": SHEN, "text": "Then let's end the song."},
	],
	"gate_base": [
		{"say": SHEN, "text": "Barracks, an armory, holding cells. They built a whole base in a month."},
		{"pan_enemy": 4, "time": 1.8},
		{"say": SHEN, "text": "...and a lab. With the same thing in it as the station."},
		{"back": 1.0},
		{"say": SHEN, "text": "They weren't containing it. They were collecting it."},
	],
}
