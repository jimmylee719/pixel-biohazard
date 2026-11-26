"""第三批：北港重新設計；冰洞、守門一號、1962 燈籠站、郵輪北極星號指定房間種類。"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Map

AREAS = {}

# ── 北港：暴風雪中的軍用碼頭。北邊是海（北極星號靠在棧橋邊），東邊是港務辦公室（守門派的崗哨）和裝備籠，
#    院子裡是貨櫃、卡車、路障。南邊的路回氣象小屋，東邊的洞口進冰洞。
m = Map(44, 24)
m.room(1, 4, 42, 19)
m.room(1, 1, 18, 3, "~").room(22, 1, 21, 3, "~")
m.room(19, 1, 3, 3).put(20, 0, "D")
m.put(8, 23, "D").put(43, 18, "D")
m.box(26, 8, 15, 8)
m.wall(36, 9, 36, 14).put(36, 11, "+").put(31, 15, "++").put(26, 11, "=").put(30, 8, "=").put(34, 8, "=")
m.put(28, 13, "s").put(33, 10, "N").put(28, 10, "v").put(29, 9, "CCC").put(30, 12, "CC").put(31, 11, "a").put(34, 13, "b")
m.put(37, 9, "t").put(39, 9, "t").put(37, 11, "t").put(38, 13, "H").put(39, 14, "M").put(27, 14, "C").put(35, 9, "C")
m.block(4, 7, 4, 2).block(10, 10, 4, 2).block(4, 13, 2, 2).block(13, 16, 5, 2).block(22, 10, 2, 2).block(36, 18, 3, 2).block(24, 20, 4, 2)
m.put(15, 5, "CCC").put(23, 5, "CCC").put(2, 10, "C").put(21, 14, "C").put(42, 12, "C")
for x in (5, 12, 28, 36):
    m.put(x, 4, "C")
m.put(12, 6, "y").put(30, 18, "k").put(8, 19, "w").put(20, 17, "x").put(18, 20, "o").put(9, 21, "u").put(11, 22, "l").put(14, 12, "r")
m.put(3, 5, "1").put(40, 5, "2").put(19, 7, "3").put(19, 13, "4").put(5, 17, "5").put(31, 17, "6").put(16, 21, "7").put(40, 21, "8")
AREAS["north_harbor"] = {
    "map": m.rows(),
    "doors": {"harbor": (8, 23), "caves": (43, 18), "gangway": (20, 0)},
    "fields": {
        "zones": '{\n\t\t\t"outside": {"rect": Rect2i(0, 0, 44, 24), "heated": false},\n\t\t}',
        "indoor_rects": "[Rect2i(27, 9, 13, 6)]",
        "sets": '[{"rect": Rect2i(37, 9, 3, 6), "set": "barracks"}, {"rect": Rect2i(27, 9, 9, 6), "set": "comms"}]',
        "props": '{"13,16": "set/truck", "15,5": "set/barrier", "23,5": "set/barrier", "2,10": "set/lamp_post", "21,14": "set/lamp_post", '
                 '"42,12": "set/lamp_post", "5,4": "set/bollard", "12,4": "set/bollard", "28,4": "set/bollard", "36,4": "set/bollard", '
                 '"29,9": "set/desk_wide", "30,12": "set/map_table", "27,14": "set/radio_rack", "35,9": "set/gun_cabinet"}',
    },
}

AREAS["ice_caves"] = {"rekey": {"42,5": "41,5"}, "fields": {}}
AREAS["gate_one_yard"] = {"fields": {"sets": '[{"rect": Rect2i(19, 41, 7, 4), "set": "comms"}]'}}
AREAS["gate_one_base"] = {"fields": {"sets": '''[
			{"rect": Rect2i(1, 1, 10, 7), "set": "barracks"}, {"rect": Rect2i(12, 1, 7, 7), "set": "barracks"},
			{"rect": Rect2i(20, 1, 17, 7), "set": "comms"}, {"rect": Rect2i(38, 1, 10, 7), "set": "office"},
			{"rect": Rect2i(1, 12, 10, 8), "set": "mess"}, {"rect": Rect2i(21, 12, 7, 8), "set": "medical"},
			{"rect": Rect2i(29, 12, 12, 8), "set": "lab"}, {"rect": Rect2i(21, 20, 20, 12), "set": "lab"},
			{"rect": Rect2i(42, 20, 19, 11), "set": "garage"},
		]'''}}
AREAS["gate_one_safe"] = {"fields": {"set": '"barracks"'}}
AREAS["lantern_1962"] = {"fields": {"sets": '''[
			{"rect": Rect2i(1, 1, 6, 6), "set": "barracks"}, {"rect": Rect2i(8, 1, 14, 6), "set": "comms"},
			{"rect": Rect2i(23, 1, 16, 6), "set": "comms"}, {"rect": Rect2i(1, 12, 10, 5), "set": "barracks"},
			{"rect": Rect2i(12, 12, 14, 5), "set": "mess"}, {"rect": Rect2i(27, 12, 12, 5), "set": "office"},
		]''', "props": '{"25,2": "set/tape_drive", "25,3": "set/tape_drive", "33,2": "set/radio_rack", "36,3": "set/server", "36,4": "set/tape_drive"}'}}
AREAS["cruise_deck"] = {"fields": {"outdoor_set": '"deck"', "sets": '[{"rect": Rect2i(58, 5, 5, 3), "set": "hold"}]'}}
AREAS["cruise_sundeck"] = {"fields": {"outdoor_set": '"deck"', "props": '{"19,7": "set/funnel"}'}}
AREAS["cruise_interior"] = {"fields": {"hidden": None, "set": '"cabin"', "sets": '''[
			{"rect": Rect2i(1, 8, 10, 12), "set": "saloon"}, {"rect": Rect2i(12, 8, 25, 13), "set": "saloon"},
			{"rect": Rect2i(38, 8, 17, 12), "set": "theater"}, {"rect": Rect2i(1, 21, 54, 2), "set": "office"},
		]'''}}
AREAS["cruise_hold"] = {"fields": {"hidden": '{"37,13": "reveal:cache_ship", "40,13": "reveal:cache_ship"}', "set": '"hold"', "sets": '[{"rect": Rect2i(32, 1, 13, 6), "set": "utility"}, {"rect": Rect2i(1, 1, 6, 13), "set": "storage"}]'}}

if __name__ == "__main__":
    m.show()
