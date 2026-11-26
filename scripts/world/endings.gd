## 結局（GDD 10.6）：天線塔發出的訊號 × 打倒深井時主角的感染值。每個結局最後一句是 2099 年的未來。只有三個結局，不做龐大的分支。
##   隔離（quarantine）                → 正史結局：研究站被摧毀，她搭上一架不是救援隊派來的直升機
##   救援（rescue）＋ 感染值低           → 撤離：大家得救了，但霜鳴菌也跟著樣本箱離開了這座島
##   救援但已經被感染，或要求摧毀        → 最後的光：她留在島上，親手燒掉研究站
class_name Endings
extends RefCounted

## 感染值達到這個數字就算「已經被感染」
const INFECTED_THRESHOLD := 50.0

const DATA := {
	"quarantine": {
		"title": "ENDING: QUARANTINE",
		"canon": true,
		"lines": [
			"The lift groans up through the dark. By the time you reach the hangar, the sky over Greycrow is full of engines.",
			"Nobody lands. Nobody leaves. Three days later the station burns from the air - exactly as you asked.",
			"On the fourth day a helicopter with no markings sets down on the south shore. The pilot says your name before you do.",
			"You never learn who sent it. Some nights, between stations, your radio plays music from a city that doesn't exist yet.",
			"2099. The city at the end of the century sings with one voice - a little quieter than it should. It is still waiting for you.",
		],
	},
	"evacuation": {
		"title": "ENDING: EVACUATION",
		"canon": false,
		"lines": [
			"The rescue flight comes on the third morning. Blankets, hot tea, a medic who won't stop talking.",
			"They take the survivors, the logs, the sealed sample cases. Nobody opens the sample cases.",
			"Somewhere over the sea, behind the cargo net, something begins to click.",
			"2099. The city sings with one voice, and every child learns the name of the pilot who brought the song home.",
		],
	},
	"last_light": {
		"title": "ENDING: THE LAST LIGHT",
		"canon": false,
		"lines": [
			"You know before the lift stops: there is nobody coming that you could let near this island.",
			"You open every valve on the fuel line and walk back down into the station.",
			"From the sea, the rescue crew will report a single bright light on Greycrow. Then, on every frequency, silence.",
			"2099. Nobody builds the city. On 126.05 there is nothing but snow - and once a year, very faintly, a reel-to-reel running out.",
		],
	},
}

## 被感染時「最後的光」的第一句換成這句
const INFECTED_LINE := "You know before the lift stops: the cold in your blood isn't the weather anymore."


static func resolve_id(choice: String, infection: float) -> String:
	if choice == "quarantine":
		return "quarantine"
	if choice == "rescue" and infection < INFECTED_THRESHOLD:
		return "evacuation"
	return "last_light"


## 回傳 {id, title, lines}
static func resolve(choice: String, infection: float) -> Dictionary:
	var id := resolve_id(choice, infection)
	var ending: Dictionary = DATA[id].duplicate(true)
	ending.id = id
	if id == "last_light" and infection >= INFECTED_THRESHOLD:
		ending.lines[0] = INFECTED_LINE
	return ending
