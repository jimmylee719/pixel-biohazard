## 主線的無線電通話：主角在安全屋用無線電時，柯瓦奇依主線進度說的話（把劇情講清楚用）。
## 每一段只播一次（旗標 call:<任務 id>）。after = 完成了哪個主線任務之後才會聽到。
## 設定依據：docs/SERIES_BIBLE.md 第 8 節（本篇劇情）、第 11 節（每個角色的語氣）。
## 文字一律英文原文，中文在 tools/locale/zh_TW.py。
class_name RadioCalls
extends RefCounted

const DATA := [
	{"after": "find_shelter", "lines": [
		"KOVAC: \"The rules, once. They are blind. They hear a dropped spoon from two rooms away. And they hate the cold - it puts them back to sleep.\"",
		"KOVAC: \"I called it Frostchime. Forty thousand years in the permafrost, and we drilled straight into its bed.\"",
	]},
	{"after": "director_records", "lines": [
		"KOVAC: \"The Ark. So that's who paid for the drill. Halvorsen told us it was a polar foundation.\"",
		"KOVAC: \"He wasn't a monster, Shen. He thought he could keep them asleep and sort it out in the spring. That's worse, in a way.\"",
		"KOVAC: \"You can't call out without power. The generator is in the basement. The diesel is at the depot, out in the snow.\"",
	]},
	{"after": "restore_power", "lines": [
		"KOVAC: \"That basement is older than the station. In 1962 it was a listening post. They heard something down there and signed a treaty to forget it.\"",
		"KOVAC: \"If the antenna still stands, you get one message out. Think about who you want to answer.\"",
	]},
	{"after": "hangar_snowcat", "lines": [
		"KOVAC: \"A bear. Then it doesn't need people. It needs anything warm that can hear.\"",
		"KOVAC: \"Take the snowcat to the tower. And Shen - if something answers that isn't the rescue centre, don't talk to it.\"",
	]},
	{"after": "send_signal", "lines": [
		"KOVAC: \"I heard it too. One-two-six-oh-five. 'Hold position.' It said that to you like it knew you.\"",
		"KOVAC: \"It isn't coming from the mainland. It's coming from under your feet - and from somewhere that hasn't happened yet.\"",
		"KOVAC: \"The bed of the colony is at the bottom of the shaft. As long as it sings, something will keep answering. I'm sorry. I should be the one going down.\"",
	]},
]


## 回傳這次用無線電會聽到的新通話（並記下已經聽過）
static func receive() -> Array:
	var out: Array = []
	for call in DATA:
		var flag: String = "call:" + call.after
		if WorldState.has_flag(flag) or not Missions.is_done(call.after):
			continue
		WorldState.set_flag(flag)
		out.append_array(call.lines)
	return out
