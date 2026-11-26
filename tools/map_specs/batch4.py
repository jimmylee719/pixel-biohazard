"""第四批：上一輪只換了佈景的區域，這次整個重畫格局：東翼、守門一號（廣場、基地、安全屋）、郵輪北極星號（甲板、船艙、貨艙、頂層甲板）。
原則：小房間＋走廊、每間有牆和門、家具靠牆、每間一看就知道用途；戶外用貨櫃、卡車、圍籬（= 看得穿）切開，不留大片空地。
同時拿掉潛龍諜影式的鏡頭傾斜（tilt、frame）。"""
import os
import sys
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from painter import Map

AREAS = {}


def keyed(m, rk, old, x, y, ch):
    """放一個有座標 key 的物件（names、loot、gear、stairs、safes、hidden）：old = 舊地圖上的座標。"""
    m.put(x, y, ch)
    rk[old] = "%d,%d" % (x, y)


def rects(items):
    return "[\n\t\t\t" + ",\n\t\t\t".join('{"rect": Rect2i(%d, %d, %d, %d), "set": "%s"}' % (r + (s,)) for r, s in items) + ",\n\t\t]"


def props(d):
    return "{" + ", ".join('"%d,%d": "set/%s"' % (x, y, n) for (x, y), n in d.items()) + "}"


# ── 東翼（生物實驗區，二樓走廊東端進來）：一條東西向的走廊，北邊由西到東是辦公室、實驗室 A、樣本室（詠者）、
#    低溫保存室、病房；南邊是除汙更衣室（防護裝備）、實驗室 B、解剖室、樣本倉庫、維修機房。
m = Map(44, 18)
rk = {}
m.room(1, 8, 42, 2).put(0, 8, "D")
for x0, w in ((1, 7), (9, 8), (18, 8), (27, 7), (35, 8)):
    m.room(x0, 1, w, 6).room(x0, 11, w, 6)
m.put(4, 7, "+").put(10, 7, "=").put(12, 7, "++").put(15, 7, "=").put(19, 7, "==++==").put(30, 7, "+")
m.put(36, 7, "=").put(38, 7, "++").put(41, 7, "=")
m.put(4, 10, "+").put(10, 10, "=").put(12, 10, "++").put(15, 10, "=").put(19, 10, "=").put(21, 10, "++").put(24, 10, "=")
m.put(30, 10, "+").put(39, 10, "+")
# 辦公室
m.put(1, 1, "C.C.CC").put(3, 4, "CC").put(5, 4, ":").put(1, 6, "H")
keyed(m, rk, "5,5", 2, 3, "N")
# 實驗室 A
m.put(9, 1, "CCC").put(14, 1, "C.C").put(11, 4, "CCC").put(15, 5, "n").put(10, 6, "x")
# 樣本室（孢子）
m.put(18, 1, "C.C").put(23, 1, "C.C").block(21, 3, 2, 2).put(19, 4, "a").put(24, 5, "V")
# 低溫保存室
m.block(28, 2, 2, 2).block(31, 2, 2, 2).put(27, 5, "C").put(33, 6, "H").put(30, 5, "b")
# 病房
m.put(35, 1, "CC").put(38, 1, "CC").put(41, 1, "CC").put(36, 4, "CC").put(40, 4, "C").put(42, 3, "M").put(39, 5, "x")
# 除汙更衣室：防護衣、面具、靴子掛在這裡
m.put(1, 11, "C.C.C.C").put(6, 13, "l").put(1, 15, "H")
keyed(m, rk, "2,9", 2, 13, "t")
keyed(m, rk, "3,9", 3, 13, "t")
keyed(m, rk, "4,9", 4, 13, "t")
# 實驗室 B（孢子）
m.put(9, 11, "CC").put(15, 11, "CC").put(11, 14, "CCC").put(10, 13, "d").put(16, 15, "A")
# 解剖室
m.put(18, 11, "CC").put(24, 11, "CC").put(19, 14, "CC").put(23, 14, "CC").put(21, 13, "x")
# 樣本倉庫（孢子）
m.block(27, 11, 2, 2).block(32, 11, 2, 2).block(29, 15, 3, 2).put(30, 13, "c")
# 維修機房
m.put(35, 11, "CCC").put(42, 11, "C").put(42, 12, "H").block(36, 14, 2, 2).put(40, 13, "z").put(41, 15, "m")
keyed(m, rk, "41,15", 38, 13, "N")
# 走廊
m.put(8, 8, "C").put(26, 8, "C").put(34, 9, "C").put(10, 8, "1").put(40, 9, "2").put(22, 9, "x")
AREAS["station_east_wing"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "doors": {"east_wing": (0, 8)},
    "fields": {
        "zones": '{\n\t\t\t"wing": {"rect": Rect2i(0, 0, 44, 18), "heated": false, "powered": true},\n\t\t}',
        "hazards": '[{"rect": Rect2i(18, 1, 8, 6), "kind": "spores"}, {"rect": Rect2i(9, 11, 8, 6), "kind": "spores"}, '
                   '{"rect": Rect2i(27, 11, 7, 6), "kind": "spores"}]',
        "sets": rects([((1, 1, 7, 6), "office"), ((35, 1, 8, 6), "medical"), ((1, 11, 7, 6), "dorm"),
                       ((18, 11, 8, 6), "medical"), ((27, 11, 7, 6), "storage"), ((35, 11, 8, 6), "utility")]),
        "props": props({(1, 11): "locker_gear", (3, 11): "locker_gear", (5, 11): "shelf_linen", (7, 11): "sink",
                        (36, 14): "genset"}),
    },
}

# ── 守門一號 安全屋（待命室）：小小一間，無線電和儲物箱。門在基地南走廊的西端。
m = Map(12, 6)
rk = {}
m.room(1, 1, 10, 4).put(5, 0, "D")
m.put(1, 1, "CC").put(8, 1, "CCH").put(8, 2, "Y").put(1, 4, "CC").put(9, 4, "M")
keyed(m, rk, "3,2", 2, 2, "R")
AREAS["gate_one_safe"] = {
    "map": m.rows(),
    "rekey": rk,
    "doors": {"g1safe": (5, 0)},
    "fields": {"set": '"barracks"', "entries": '{"radio": Vector2i(2, 3)}'},
}

# ── 守門一號 基地：兩條東西向的走廊＋中間一條南北向的通道。
#    北排：寢室 A、寢室 B、更衣室、指揮室、通訊室、指揮官辦公室（保險箱、左輪）、軍械庫（衝鋒槍）。
#    中排：餐廳、廚房、醫務室、簡報室 ｜ 拘留區（四間牢房）、發電機房。
#    南排：樣本實驗室、冷藏室、樣本倉庫（都有孢子）｜ 大廳（正門）｜ 工具間、車庫（卸貨區）。
#    左下角那塊實心的牆是安全屋貼進來的位置。
m = Map(62, 33)
rk = {}
m.room(1, 8, 60, 2).room(1, 18, 60, 2).room(30, 10, 2, 8).room(30, 20, 2, 7)
for x0, w in ((1, 8), (10, 8), (19, 8), (28, 8), (37, 8), (46, 7), (54, 7)):
    m.room(x0, 1, w, 6)
m.put(4, 7, "+").put(13, 7, "+").put(22, 7, "+").put(30, 7, "=++=").put(40, 7, "+").put(42, 7, "=").put(49, 7, "+").put(57, 7, "+")
# 寢室 A、B
m.put(1, 1, "CC.CC.CC").put(1, 4, "CC").put(6, 4, "CC").put(7, 6, "M")
m.put(10, 1, "CC.CC.CC").put(10, 4, "CC").put(15, 4, "CC").put(17, 6, "H").put(11, 6, "B")
# 更衣室
m.put(19, 1, "C.H.C.H.").put(20, 4, "C").put(24, 4, "C").put(26, 3, "A")
# 指揮室
m.put(28, 1, "C.C").put(33, 1, "C.C").put(30, 4, "CCC").put(35, 5, "l").put(29, 5, "3")
keyed(m, rk, "21,6", 31, 1, "N")
# 通訊室
m.put(37, 1, "C.C.C.C").put(39, 4, "CC")
keyed(m, rk, "26,17", 43, 3, "N")
# 指揮官辦公室
m.put(46, 1, "C").put(48, 3, "CCC").put(47, 3, "!").put(52, 6, "C").put(51, 6, ":").put(50, 5, "4")
keyed(m, rk, "46,2", 52, 2, "s")
keyed(m, rk, "39,6", 49, 4, "N")
# 軍械庫
m.put(54, 1, "C.C.C.C").put(56, 4, "CC").put(55, 3, "$").put(54, 5, "k").put(58, 5, "L").put(60, 5, "A").put(60, 3, "y")
keyed(m, rk, "59,1", 59, 2, "w")
# 中排（西）：餐廳、廚房、醫務室、簡報室
m.room(1, 11, 9, 6).room(11, 11, 6, 6).room(18, 11, 5, 6).room(24, 11, 5, 6)
m.put(5, 10, "+").put(5, 17, "+").put(10, 13, "+").put(14, 17, "+").put(20, 10, "+").put(29, 13, "+").put(26, 10, "=")
m.put(1, 11, "C").put(9, 11, "C").put(2, 13, "CCC").put(6, 13, "CCC").put(2, 15, "CCC").put(6, 15, "CCC").put(9, 16, "B")
m.put(11, 11, "CC.C.C").put(13, 14, "CC")
m.put(18, 11, "CC").put(21, 11, "CC").put(18, 14, "CC").put(22, 13, "M")
m.put(24, 11, "C").put(28, 11, "C").block(25, 13, 3, 2)
# 中排（東）：拘留區（上面是看守的走道，下面四間牢房，門旁邊是觀察窗）、發電機房
m.room(33, 11, 17, 2)
for x0, w in ((33, 4), (38, 3), (42, 3), (46, 4)):
    m.room(x0, 14, w, 3)
m.put(33, 13, "=+=").put(38, 13, "=+=").put(42, 13, "=+=").put(46, 13, "=+=")
m.put(32, 12, "+").put(48, 10, "+")
m.put(34, 11, "C").put(40, 11, "d")
m.put(35, 16, "CC").put(33, 15, "x").put(38, 16, "CC").put(43, 16, "CC").put(42, 15, "e").put(46, 16, "CC").put(49, 15, "V").put(48, 14, "x")
keyed(m, rk, "59,12", 40, 15, "N")
m.room(51, 11, 10, 6).put(55, 10, "+").put(55, 17, "+")
m.put(51, 11, "C.C").put(58, 11, "C.C").block(52, 13, 2, 2).block(57, 13, 2, 2).put(60, 16, "q")
# 南排：實驗室、冷藏室、樣本倉庫
m.room(14, 21, 8, 5).room(23, 21, 6, 5).room(14, 27, 7, 5)
m.put(15, 20, "=").put(17, 20, "+").put(19, 20, "=").put(22, 23, "+").put(17, 26, "+")
m.put(14, 21, "C.C").put(19, 21, "C.C").put(16, 23, "CCC").put(20, 24, "a")
keyed(m, rk, "25,26", 15, 24, "N")
m.block(24, 22, 2, 2).block(27, 22, 2, 2).put(25, 25, "b").put(28, 25, "V")
m.put(14, 27, "C").put(20, 27, "C").block(14, 29, 2, 2).put(19, 30, "c")
# 工具間
m.room(33, 21, 8, 5).put(36, 20, "+").put(33, 21, "CC").put(38, 21, "CC").block(34, 23, 2, 2).put(39, 24, "m")
# 大廳（正門在南邊）
m.room(22, 27, 19, 5).put(31, 32, "D")
m.put(22, 27, "C.C").put(38, 27, "C.C").put(26, 29, "CCC").put(35, 30, "CC").put(23, 31, "M").put(25, 28, "7").put(45, 19, "8")
# 車庫
m.room(42, 21, 19, 11).put(50, 20, "+").put(41, 29, "+").put(41, 30, "+")
m.put(42, 21, "CC").put(56, 21, "C.C.C").block(44, 23, 5, 2).block(52, 23, 4, 2).block(44, 28, 4, 2).block(51, 28, 6, 2)
m.put(60, 30, "o").put(59, 31, "o").put(42, 31, "r").put(43, 26, "5").put(50, 26, "6")
keyed(m, rk, "43,22", 58, 26, "w")
keyed(m, rk, "44,22", 59, 26, "w")
# 走廊
m.put(3, 9, "1").put(58, 8, "2").put(6, 20, "D")
m.put(12, 8, "C").put(27, 8, "C").put(45, 8, "C").put(9, 18, "C").put(26, 18, "C").put(40, 18, "C").put(58, 18, "C")
AREAS["gate_one_base"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "doors": {"base_gate": (31, 32), "g1safe": (6, 20)},
    "fields": {
        "zones": '{\n\t\t\t"base": {"rect": Rect2i(0, 0, 62, 33), "heated": true},\n\t\t}',
        "hazards": '[{"rect": Rect2i(14, 21, 8, 5), "kind": "spores"}, {"rect": Rect2i(23, 21, 6, 5), "kind": "spores"}, '
                   '{"rect": Rect2i(14, 27, 7, 5), "kind": "spores"}]',
        "sets": rects([((1, 1, 8, 6), "barracks"), ((10, 1, 8, 6), "barracks"), ((19, 1, 8, 6), "barracks"),
                       ((28, 1, 8, 6), "comms"), ((37, 1, 8, 6), "comms"), ((46, 1, 7, 6), "office"),
                       ((1, 11, 9, 6), "mess"), ((11, 11, 6, 6), "mess"), ((18, 11, 5, 6), "medical"), ((24, 11, 5, 6), "office"),
                       ((33, 11, 17, 6), "barracks"), ((51, 11, 10, 6), "utility"),
                       ((14, 21, 8, 5), "lab"), ((23, 21, 6, 5), "lab"), ((14, 27, 7, 5), "lab"),
                       ((33, 21, 8, 5), "storage"), ((42, 21, 19, 11), "garage")]),
        "props": props({(56, 4): "workbench", (26, 29): "desk_wide", (35, 30): "sofa", (44, 23): "truck", (52, 23): "truck",
                        (52, 13): "genset", (57, 13): "boiler", (34, 11): "console", (48, 3): "desk_wide"}),
    },
}

# ── 守門一號 廣場：有圍牆的檢查哨。冰洞的隧道從西邊進來，先經過圍籬外的管制區（路障、卡車），
#    穿過大門（旁邊是門房）才進到裡面：北邊是基地正門（沙包、探照燈）、油槽和車棚，
#    南邊圍籬裡是貨櫃區，東南是車輛調度場。地圖上面 32 列空白＝基地（房間 gate_one_base）貼進來的位置。
m = Map(62, 56)
rk = {}
m.room(5, 33, 54, 22).put(31, 32, "D").put(4, 44, "D")
# 圍籬（= 看得穿、走不過去）和大門
m.wall(17, 33, 17, 54, "=")
for y in (33, 37, 45, 49, 54):
    m.put(17, y, "#")
m.put(17, 43, ".").put(17, 44, ".")
m.box(17, 38, 8, 5).put(17, 40, "=").put(24, 40, "=").put(20, 38, "=").put(21, 42, "+")
keyed(m, rk, "21,42", 18, 39, "N")
m.put(19, 39, "CC").put(22, 39, "C").put(23, 39, "l").put(23, 41, "A").put(18, 41, "x")
# 管制區（圍籬外）
m.block(7, 35, 4, 2).block(12, 37, 3, 2).block(6, 46, 2, 2).put(8, 42, "CCC").put(11, 46, "CCC").block(13, 48, 2, 4).put(15, 33, "C").put(14, 33, ";")
m.put(16, 41, "C").put(16, 46, "C").put(6, 50, "r").put(8, 52, "oo").put(9, 53, "o").put(10, 39, "5").put(10, 49, "6")
keyed(m, rk, "8,36", 6, 34, "w")
# 基地正門前：沙包、探照燈、油槽
m.put(27, 36, "CCC").put(33, 36, "CCC").put(28, 33, "C").put(34, 33, "C").block(19, 33, 5, 2)
# 車棚（三格，朝南開）
m.wall(41, 33, 41, 37).wall(47, 33, 47, 37).wall(53, 33, 53, 37)
m.block(42, 33, 4, 2).block(48, 33, 5, 2).block(55, 33, 3, 2).put(56, 36, "oo").put(57, 37, "o")
# 第二個崗亭
m.box(36, 39, 5, 4).put(36, 41, "+").put(38, 39, "=").put(38, 42, "=").put(39, 40, "C")
# 貨櫃區（圍籬裡）
m.wall(18, 46, 41, 46, "=").put(29, 46, "..").put(24, 46, "C").put(35, 46, "C")
m.wall(42, 46, 42, 54, "=").put(42, 46, "#").put(42, 54, "#").put(42, 50, ".").put(42, 51, ".")
m.block(19, 47, 4, 2).block(24, 47, 4, 2).block(32, 47, 6, 2).block(39, 47, 2, 3)
m.block(19, 51, 6, 2).block(26, 51, 3, 2).block(31, 51, 4, 2).block(36, 51, 4, 2)
m.put(41, 54, "u").put(20, 49, "7").put(37, 54, "8")
# 車輛調度場
m.block(46, 41, 5, 2).block(53, 41, 4, 2).block(50, 47, 3, 2).block(45, 52, 2, 3).block(50, 52, 4, 2)
m.put(57, 53, "C").put(58, 39, "y").put(53, 48, ";")
keyed(m, rk, "50,47", 54, 47, "w")
keyed(m, rk, "44,53", 56, 54, "k")
keyed(m, rk, "54,53", 58, 54, "M")
m.put(25, 36, "1").put(45, 39, "2").put(20, 44, "3").put(34, 43, "4").put(30, 41, "a").put(47, 45, "b")
AREAS["gate_one_yard"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "doors": {"gate_tunnel": (4, 44), "base_gate": (31, 32)},
    "fields": {
        "zones": '{\n\t\t\t"outside": {"rect": Rect2i(4, 32, 56, 24), "heated": false},\n\t\t}',
        "indoor_rects": "[Rect2i(18, 39, 6, 3), Rect2i(37, 40, 3, 2)]",
        "sets": rects([((18, 39, 6, 3), "comms"), ((37, 40, 3, 2), "comms")]),
        "props": props({(7, 35): "truck", (8, 42): "barrier", (11, 46): "barrier", (15, 33): "wood_pile", (16, 41): "lamp_post",
                        (16, 46): "lamp_post", (27, 36): "barrier", (33, 36): "barrier", (28, 33): "lamp_post", (34, 33): "lamp_post",
                        (19, 33): "tank", (42, 33): "truck", (48, 33): "truck", (55, 33): "crates", (24, 46): "lamp_post",
                        (35, 46): "lamp_post", (46, 41): "truck", (53, 41): "tank", (50, 47): "crates", (50, 52): "truck",
                        (57, 53): "snow_mound", (19, 39): "desk_wide", (22, 39): "radio_rack", (39, 40): "console"}),
    },
}

# ── 北極星號 散步甲板：繞著上層建築（房間 cruise_interior，貼在中間那塊空白）走一圈的甲板。
#    北舷、南舷的欄杆邊吊著救生艇；船尾（西）是絞盤和貨物，棧橋在南舷靠船尾；船頭（東）有樓梯間（往頂層甲板、貨艙）。
m = Map(64, 33)
rk = {}
m.room(1, 1, 62, 3).room(1, 26, 62, 6).room(1, 4, 5, 22).room(56, 4, 7, 22)
m.put(33, 25, "D").put(6, 32, "D")
for x in (8, 16, 24, 34, 42, 50):
    m.block(x, 1, 4, 2)
for x in (12, 20, 38, 46):
    m.block(x, 30, 4, 2)
m.put(10, 26, "C").put(18, 26, "C").put(40, 26, "C").put(48, 26, "C").put(9, 29, "CC").put(28, 31, "C").put(31, 31, "C")
keyed(m, rk, "11,7", 3, 30, "w")
# 船尾
m.put(3, 6, "C").block(2, 10, 3, 2).put(1, 15, "C").put(5, 15, "C").block(2, 19, 2, 2).put(4, 21, ";").put(5, 8, "o").put(1, 23, "r")
# 船頭：樓梯間
m.box(58, 12, 5, 6).put(58, 15, "+")
keyed(m, rk, "59,5", 59, 13, "G")
keyed(m, rk, "61,5", 61, 13, "G")
m.put(60, 6, "C").put(60, 22, "C").put(62, 20, "C").put(61, 20, "|").put(59, 25, "C").put(62, 3, "C").put(62, 29, "C")
m.put(14, 28, "1").put(44, 28, "2").put(13, 3, "3").put(46, 3, "4").put(57, 8, "5")
AREAS["cruise_deck"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "doors": {"gangway": (6, 32), "atrium": (33, 25)},
    "fields": {
        "tilt": None,
        "outdoor_set": '"deck"',
        "zones": '{"deck": {"rect": Rect2i(0, 0, 64, 33), "heated": false}}',
        "indoor_rects": "[Rect2i(59, 13, 3, 4)]",
        "sets": rects([((59, 13, 3, 4), "hold")]),
        "entries": '{"stairs": Vector2i(60, 14)}',
        "props": props(dict([((x, 1), "lifeboat") for x in (8, 16, 24, 34, 42, 50)] + [((x, 30), "lifeboat") for x in (12, 20, 38, 46)]
                            + [((9, 29), "barrier"), ((2, 10), "crates"), ((2, 19), "crates"), ((3, 6), "winch"), ((59, 25), "winch"),
                               ((62, 20), "crate_tarp"), ((28, 31), "bollard"), ((31, 31), "bollard")])),
    },
}

# ── 北極星號 船艙：中間一條客艙走廊，兩邊是小客艙（最東邊是船長室、船醫室）；
#    走廊中段往南的通道下到中庭（大門通甲板），中庭西邊是酒吧、廚房（配膳室通走廊），東邊是小劇院和後台。
m = Map(50, 22)
rk = {}
m.room(1, 5, 48, 2).room(27, 7, 2, 5).put(27, 21, "D")
for x0 in (1, 6, 11, 16, 21, 26, 31, 36):
    m.room(x0, 1, 4, 3).put(x0 + 1, 4, "+").put(x0 + 2, 1, "CC").put(x0, 1, "C")
for x0 in (1, 6, 11, 16, 36):
    m.room(x0, 8, 4, 3).put(x0 + 1, 7, "+").put(x0 + 2, 8, "CC")
m.put(1, 10, "C").put(14, 10, "C").put(19, 10, "H").put(39, 10, "C").put(4, 3, "H").put(12, 3, "x").put(24, 3, "y").put(39, 3, "M").put(32, 3, "x")
# 配膳室（走廊 ↔ 廚房）
m.room(6, 8, 4, 3).put(7, 7, "+").put(7, 11, "+").put(9, 8, "C").put(9, 9, "C").put(6, 10, "C")
# 船長室
m.room(41, 1, 8, 3).put(44, 4, "+").put(41, 1, "CC").put(45, 1, "CC").put(48, 1, "C").put(48, 3, ":")
keyed(m, rk, "9,1", 46, 2, "N")
# 事務長室（保險箱）
m.room(21, 8, 5, 3).put(23, 7, "+").put(24, 8, "CC").put(21, 8, "C").put(25, 10, "l")
keyed(m, rk, "6,22", 21, 9, "s")
# 走道東邊的客艙、船醫室
m.room(30, 8, 5, 3).put(32, 7, "+").put(33, 8, "CC").put(30, 10, "H")
m.room(41, 8, 8, 3).put(44, 7, "+").put(41, 8, "CC").put(46, 8, "CC").put(48, 10, "M").put(42, 10, "x")
# 廚房
m.room(1, 12, 8, 9).put(9, 16, "+").put(1, 12, "CCCC").put(3, 15, "CCC").put(3, 18, "CCC").put(1, 16, "C").put(1, 17, "C").put(8, 20, "C").put(6, 14, "4")
# 酒吧
m.room(10, 12, 12, 9).put(22, 15, "+").put(22, 16, "+").put(22, 13, "=").put(22, 18, "=")
m.put(12, 12, "CCCCCC").put(19, 12, "C").put(21, 12, "C")
for x, y in ((12, 15), (15, 15), (18, 15), (12, 18), (15, 18), (18, 18)):
    m.put(x, y, "C")
m.put(14, 16, "3").put(19, 19, "5").put(10, 20, "x")
# 中庭
m.room(23, 12, 10, 9).put(33, 15, "+").put(33, 16, "+").put(33, 13, "=").put(33, 18, "=")
m.put(23, 12, "C").put(32, 12, "C").put(25, 15, "C").put(30, 18, "CC").put(24, 19, "CC").put(23, 20, "C").put(32, 20, "C").put(29, 16, "6")
keyed(m, rk, "22,13", 26, 15, "N")
# 劇院、後台
m.room(34, 12, 11, 9).room(46, 12, 3, 9).put(45, 14, "+")
for y in (14, 16, 18):
    m.put(35, y, "CCCCCC")
m.put(43, 13, "C").put(43, 16, "a").put(42, 20, "C").put(44, 20, "C")
m.put(46, 12, "C").put(48, 12, "C").put(48, 20, "H").put(47, 18, "A").put(46, 16, "C")
m.put(4, 6, "1").put(45, 5, "2").put(40, 6, "b").put(10, 5, "C").put(25, 5, "C").put(35, 5, "C").put(20, 6, "x")
AREAS["cruise_interior"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "doors": {"atrium": (27, 21)},
    "fields": {
        "hidden": None,
        "camera_zones": None,
        "set": '"cabin"',
        "zones": '{"ship": {"rect": Rect2i(0, 0, 50, 22), "heated": false}}',
        "sets": rects([((1, 12, 8, 9), "mess"), ((6, 8, 4, 3), "mess"), ((10, 12, 12, 9), "saloon"), ((23, 12, 10, 9), "saloon"),
                       ((34, 12, 11, 9), "theater"), ((21, 8, 5, 3), "office"), ((41, 8, 8, 3), "medical")]),
        "props": props({(45, 1): "desk_wide", (25, 15): "piano", (43, 13): "piano", (23, 12): "plant", (32, 12): "plant",
                        (23, 20): "plant", (32, 20): "plant", (30, 18): "sofa", (24, 19): "sofa", (19, 12): "slot_machine",
                        (21, 12): "slot_machine", (12, 12): "bar_counter", (42, 20): "plant", (44, 20): "plant"}),
    },
}

# ── 北極星號 貨艙：樓梯下來是船員區（樓梯間、船員艙、泵浦室），一條南北向的走道，
#    中間是貨艙（一排一排的貨櫃，中間是走道；第三排藏著東西），東邊是輪機室和放冰芯的冷藏庫。
m = Map(48, 17)
rk = {}
m.room(1, 1, 7, 4).room(1, 6, 7, 5).room(1, 12, 7, 4).room(9, 1, 2, 15).room(12, 1, 22, 15).room(35, 1, 12, 8).room(35, 10, 12, 6)
m.put(8, 2, "+").put(8, 8, "+").put(8, 13, "+").put(11, 7, "+").put(11, 8, "+").put(11, 2, "+").put(11, 14, "+")
m.put(34, 4, "+").put(34, 5, "+").put(34, 12, "+").put(40, 9, "+")
keyed(m, rk, "2,1", 2, 1, "G")
m.put(6, 1, "CC").put(5, 4, "x")
m.put(1, 6, "CC").put(4, 6, "CC").put(7, 6, "C").put(1, 9, "CC").put(7, 10, "H").put(5, 10, ":")
m.put(1, 12, "C.C.C").put(3, 14, "CC")
m.block(13, 2, 4, 2).block(18, 2, 6, 2).block(25, 2, 4, 2).block(30, 2, 3, 2)
m.block(14, 6, 6, 2).block(22, 6, 4, 2).block(27, 6, 6, 2)
m.block(13, 10, 4, 2).block(18, 10, 4, 2).block(24, 10, 6, 2).block(31, 10, 2, 3)
m.block(13, 14, 6, 2).block(21, 14, 4, 2).block(27, 14, 4, 2)
keyed(m, rk, "37,13", 22, 11, "A")
keyed(m, rk, "40,13", 23, 11, "M")
m.put(20, 4, "1").put(26, 9, "2").put(16, 12, "c").put(33, 1, "x").put(12, 15, "x")
m.block(36, 2, 2, 2).block(39, 2, 2, 2).block(43, 2, 2, 2).put(37, 6, "CCCC").put(46, 1, "C").put(46, 7, "C").put(42, 5, "a").put(38, 7, "b")
m.block(36, 11, 2, 2).block(39, 11, 2, 2).block(42, 11, 2, 2).block(36, 14, 2, 2).block(39, 14, 2, 2).block(42, 14, 2, 2)
m.put(45, 13, "d").put(46, 15, "k")
keyed(m, rk, "37,3", 46, 10, "N")
AREAS["cruise_hold"] = {
    "map": m.rows(),
    "rekey": rk,
    "allow_diff": True,
    "fields": {
        "camera_zones": None,
        "hidden": '{"22,11": "reveal:cache_ship", "23,11": "reveal:cache_ship"}',
        "set": '"hold"',
        "zones": '{"hold": {"rect": Rect2i(0, 0, 48, 17), "heated": false}}',
        "entries": '{"stairs": Vector2i(2, 2)}',
        "sets": rects([((1, 1, 7, 4), "storage"), ((1, 6, 7, 5), "cabin"), ((1, 12, 7, 4), "utility"),
                       ((35, 1, 12, 8), "utility"), ((35, 10, 12, 6), "lab")]),
        "props": props({(36, 2): "boiler", (39, 2): "boiler", (43, 2): "genset", (37, 6): "pipe_run", (3, 14): "pipe_run"}),
    },
}

# ── 北極星號 頂層甲板（Boss 典獄長）：北邊是欄杆後面的艦橋平台（三個制高點 1、2、3，欄杆看得穿、有三個缺口可以衝上去），
#    下面是泳池甲板：中間的煙囪、泳池（子彈飛得過去、人過不去）、兩舷的救生艇、吧台和躺椅是掩體，掩體之間是他的射界。
m = Map(44, 25)
rk = {}
m.room(1, 1, 42, 23)
m.wall(1, 4, 42, 4, "=").put(8, 4, "...").put(21, 4, "...").put(33, 4, "...")
m.put(4, 2, "1").put(22, 2, "2").put(39, 2, "3")
m.block(19, 6, 6, 3)
m.room(16, 12, 12, 5, "~")
for y in (7, 13, 19):
    m.block(1, y, 4, 2).block(39, y, 4, 2)
m.put(8, 10, "CCCC").put(32, 10, "CCCC").block(9, 17, 3, 2).block(32, 17, 3, 2)
m.put(14, 13, "C").put(14, 15, "C").put(29, 13, "C").put(29, 15, "C").put(19, 20, "C").put(25, 20, "C").put(12, 6, "C").put(31, 6, "C")
keyed(m, rk, "22,23", 22, 23, "G")
AREAS["cruise_sundeck"] = {
    "map": m.rows(),
    "rekey": rk,
    "fields": {
        "tilt": None,
        "outdoor_set": '"deck"',
        "zones": '{"sundeck": {"rect": Rect2i(0, 0, 44, 25), "heated": false}}',
        "entries": '{"stairs": Vector2i(22, 22)}',
        "props": props({(1, 7): "lifeboat", (1, 13): "lifeboat", (1, 19): "lifeboat", (39, 7): "lifeboat", (39, 13): "lifeboat",
                        (39, 19): "lifeboat", (19, 6): "funnel", (8, 10): "bar_counter", (32, 10): "bar_counter", (9, 17): "crates", (32, 17): "crates",
                        (14, 13): "deck_chair", (14, 15): "deck_chair", (29, 13): "deck_chair", (29, 15): "deck_chair",
                        (19, 20): "cowl_vent", (25, 20): "cowl_vent", (12, 6): "cowl_vent", (31, 6): "cowl_vent"}),
    },
}

if __name__ == "__main__":
    for k, v in AREAS.items():
        if len(sys.argv) > 1 and k not in sys.argv[1:]:
            continue
        print(k)
        m2 = Map(len(v["map"][0]), len(v["map"]))
        m2.g = [list(r) for r in v["map"]]
        m2.show()
