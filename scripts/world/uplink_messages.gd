## 天線塔上行終端機可以發出的訊息（結局方向），以及收到的回覆。
## 正史結局是「隔離」（GDD 10.6）；三個選擇都會收到同一則不明回覆（系列伏筆，對應 126.05）。
## 結局本身在鑽探井之後決定：訊號 × 主角最後的感染值。
class_name UplinkMessages
extends RefCounted

const INTRO := [
	"GREYCROW UPLINK  -  CARRIER LOCKED",
	"",
	"The tower battery is almost gone. One transmission, then nothing.",
	"Whatever you send decides who comes to this island - and who leaves it.",
]

const DATA := [
	{
		"id": "rescue",
		"label": "EVACUATE - send aircraft, get the survivors off the island",
		"sent": "[OUT] GREYCROW TO ANY STATION. SURVIVORS AT NORTH LATITUDE STATION. REQUEST IMMEDIATE EVACUATION.",
		"reply": "[IN] RESCUE CENTRE: Copy, Greycrow. Evacuation flight tasked, weather permitting. Seventy-two hours. Hang on.",
	},
	{
		"id": "quarantine",
		"label": "QUARANTINE - seal Greycrow, nobody leaves, nothing lands",
		"sent": "[OUT] GREYCROW TO ANY STATION. BIOLOGICAL CONTAMINATION. QUARANTINE THE ISLAND. DO NOT LAND. NOBODY LEAVES.",
		"reply": "[IN] RESCUE CENTRE: ...Say again, Greycrow? Copy quarantine. Passing it up the chain. Stay off the air.",
	},
	{
		"id": "destroy",
		"label": "DESTROY - the station must burn, with everything in it",
		"sent": "[OUT] GREYCROW TO ANY STATION. THE STATION IS LOST. DESTROY IT. DO NOT SEND PEOPLE.",
		"reply": "[IN] RESCUE CENTRE: Greycrow, we can't act on that. Who is transmitting? Identify yourself.",
	},
]

## 不管選哪一個，最後都會收到這則（不是救援中心）
const HOLD_REPLY := [
	"[IN 126.05] Hold position. Do not transmit again. We will come to you.",
	"That wasn't the rescue centre. That was the voice from the 1962 reel. Below the station, the drill shaft is humming.",
]


static func get_option(choice_id: String) -> Dictionary:
	for d in DATA:
		if d.id == choice_id:
			return d
	return {}
