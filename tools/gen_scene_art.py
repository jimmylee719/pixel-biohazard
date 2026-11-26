#!/usr/bin/env python3
"""場景美術：家具、設備、戶外的大型物件、地板貼圖、放道具的容器。
和 gen_pixel_art.py 用同一台 3/4 攝影機和調色盤（匯入它的算圖器），所以畫風一致。

用法：python3 tools/gen_scene_art.py [set|big|stash|tiles|wall]   不加參數 = 全部
輸出：assets/sprites/set/（家具，Level 的 SetDresser 依房間種類挑）、stash/（放道具的容器）、tiles/、decor/（牆上的東西）

尺寸：一格 16px。單格家具 16 寬、底部對齊格子底部、往上突出；寬的家具切成 _l／_m／_r 三段；
大型物件 <名稱>_<寬>x<高>（單位：格），底部對齊那一塊的底部。
"""
import math
import os
import random
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import gen_pixel_art as g  # noqa: E402
from gen_pixel_art import Box, Cap, Ell, render, write_png, hexc, texture, basis_along  # noqa: E402

OUT = g.OUT
SY = math.sin(g.PITCH)  # 深度（y）畫在畫面上縮成幾倍
SZ = math.cos(g.PITCH)  # 高度（z）畫在畫面上縮成幾倍

NEW_MATS = {
    "enamel": ["#5a6468", "#8a979c", "#b9c6ca", "#e4eef0"],      # 冰箱、醫療櫃的白色烤漆
    "steel_dk": ["#14171c", "#22272f", "#333a45", "#4a5360"],
    "lino": ["#27302f", "#39463f", "#4d5d52", "#66796a"],
    "blue_metal": ["#0f2238", "#1b3a5c", "#2a5682", "#4078aa"],
    "red_metal": ["#3a0f0c", "#6e1e16", "#a03222", "#c9553a"],
    "green_metal": ["#10261c", "#1d4230", "#2e6146", "#488463"],
    "rust": ["#2a1810", "#4e2c1a", "#7a4826", "#a06a3a"],
    "tarp": ["#1a2430", "#2a3a4c", "#3e546a", "#587288"],
    "paper": ["#7a7668", "#a8a392", "#d2ccb8", "#f0ead8"],
    "screen": ["#0c3a34", "#1a7466", "#38b89c", "#8af0d2"],
    "amber": ["#5a3208", "#a05e10", "#e09a24", "#ffd670"],
    "mattress": ["#3a4048", "#59616c", "#7f8894", "#a9b2bc"],
    "blanket": ["#2a1a1c", "#4c2c30", "#743f44", "#9a5a5e"],
    "carton": ["#3c2c1a", "#614a2c", "#8c6c42", "#b4905e"],
    "rubber": ["#08080a", "#141418", "#22222a", "#34343e"],
    "hazard": ["#5a4208", "#a07a10", "#dcae1c", "#ffd84a"],
    "leaf": ["#0e2414", "#1c4426", "#2e6a3a", "#4c9456"],
    "leather": ["#1e1410", "#3a261c", "#5a3c2c", "#7c5842"],
    "velvet": ["#2a080c", "#541018", "#861c28", "#b4343e"],
    "linen": ["#6a6a66", "#9c9c96", "#c8c8c0", "#ececE4"],
    "ice": ["#2a4a5c", "#4a7890", "#7ab0c8", "#c0e6f4"],
    "copper": ["#3a1c10", "#703a1c", "#a8602c", "#d89250"],
    "chrome": ["#2a3038", "#56606c", "#8e9aa8", "#d0dae4"],
}
g.MATS.update({k: [hexc(c) for c in v] for k, v in NEW_MATS.items()})
g.EMISSIVE.update({"screen", "amber"})


def _save(folder, name, w, h, px):
    path = os.path.join(OUT, folder)
    os.makedirs(path, exist_ok=True)
    write_png(os.path.join(path, name + ".png"), w, h, px)


def S(name, prims, h=28, w=16, folder="set"):
    """單格家具：前緣在 y = 0，往後（y+）往上（z+）長。"""
    _save(folder, name, w, h, render(prims, w, h, anchor=(w / 2.0, h - 1.5)))


def W(name, prims, h=26, folder="set"):
    """寬的家具：畫成 48 寬，切成左、中、右三段（中段可以重複）。"""
    img = render(prims, 48, h, anchor=(24, h - 1.5))
    for i, part in enumerate(("_l", "_m", "_r")):
        _save(folder, name + part, 16, h, [img[y * 48 + x] for y in range(h) for x in range(i * 16, i * 16 + 16)])


def BIG(name, wc, hc, prims, raise_=10):
    """大型物件：佔 wc x hc 格，圖比那一塊高 raise_ 像素。"""
    w, h = wc * 16, hc * 16 + raise_
    _save("set", "%s_%dx%d" % (name, wc, hc), w, h, render(prims, w, h, anchor=(w / 2.0, h - 1.5)))


def depth_for(hc, height, raise_=10):
    """佔 hc 格深、高 height 的箱子，深度（世界單位）要多少才剛好蓋滿那一塊。"""
    return max(6.0, (hc * 16 + raise_ - 3 - height * SZ) / SY)


def box(x, y0, z0, hx, d, hgt, mat):
    """用「前緣 y0、底面 z0、半寬 hx、深 d、高 hgt」描述的箱子。"""
    return Box((x, y0 + d / 2.0, z0 + hgt / 2.0), (hx, d / 2.0, hgt / 2.0), mat)


def legs(hx, d, hgt, mat="steel_dk", inset=1.0):
    return [box(sx * (hx - inset), y, 0, 0.7, 1.2, hgt, mat) for sx in (-1, 1) for y in (0.6, d - 1.6)]


def table(hx, d, top_z, top_mat, leg_mat="steel_dk", thick=1.4):
    return legs(hx, d, top_z, leg_mat) + [box(0, 0, top_z, hx, d, thick, top_mat)]


def shelf(mat, rows, items):
    """靠牆的層架：rows 層，items(i, j) 回傳那一格放的東西的材質（None = 空）。"""
    p = [box(0, 5.2, 0, 7.4, 1.0, 24, mat), box(-7.0, 0, 0, 0.5, 6, 24, mat), box(7.0, 0, 0, 0.5, 6, 24, mat)]
    step = 22.0 / rows
    for i in range(rows + 1):
        p.append(box(0, 0, 1 + i * step, 7.2, 6, 0.6, mat))
    for i in range(rows):
        for j, x in enumerate((-4.6, -1.5, 1.6, 4.7)):
            m = items(i, j)
            if m:
                hgt = step - 1.6 - ((i * 3 + j) % 3) * 0.7
                p.append(box(x, 0.3, 1.7 + i * step, 1.35, 4.6, hgt, m))
    return p


# ── 家具 ─────────────────────────────────────────────────────

def gen_set():
    rnd = random.Random(7)
    # 層架、櫃子（靠牆）
    S("shelf_boxes", shelf("steel_dk", 3, lambda i, j: ("carton", "carton", "olive", "carton", None)[(i * 2 + j) % 5]))
    S("shelf_parts", shelf("steel_dk", 4, lambda i, j: ("red_metal", "steel", "hazard", None, "blue_metal", "rust")[(i + j * 2) % 6]))
    S("shelf_lab", shelf("enamel", 4, lambda i, j: ("glass", "amber", "glass", "paper", "screen", None)[(i * 3 + j) % 6]))
    S("shelf_food", shelf("steel_dk", 4, lambda i, j: ("red_metal", "hazard", "carton", "green_metal", "paper")[(i + j) % 5]))
    S("shelf_files", shelf("wood", 4, lambda i, j: ("paper", "carton", "olive", "paper", "red")[(i + j * 3) % 5]))
    S("shelf_linen", shelf("enamel", 3, lambda i, j: ("linen", "mattress", "linen", "blanket")[(i + j) % 4]))
    S("fridge", [box(0, 0, 0, 7, 7, 24, "enamel"), box(0, -0.2, 14.6, 6.6, 0.3, 0.5, "steel_dk"),
                 box(5.2, -0.5, 8, 0.5, 0.5, 4.5, "chrome"), box(5.2, -0.5, 17, 0.5, 0.5, 4.5, "chrome"),
                 box(-3.5, -0.3, 19, 1.6, 0.2, 2.2, "paper"), box(-4.4, -0.3, 10.5, 0.9, 0.2, 1.2, "hazard")])
    S("fridge_lab", [box(0, 0, 0, 7, 7, 24, "enamel"), box(0, -0.2, 3, 5.6, 0.3, 18, "glass"),
                     box(0, -0.4, 12, 5.6, 0.3, 0.5, "steel_dk"), box(-2.5, -0.5, 14, 1, 0.4, 3.5, "amber"),
                     box(1.5, -0.5, 14, 1, 0.4, 3, "screen"), box(-1, -0.5, 5, 1.2, 0.4, 4, "red"),
                     box(3.2, -0.5, 5, 1, 0.4, 3, "amber"), box(4.4, -0.6, 22.2, 1.4, 0.3, 0.8, "red")])
    S("vending", [box(0, 0, 0, 7, 7, 24, "red_metal"), box(-1.5, -0.2, 6, 4.6, 0.3, 15, "glass"),
                  box(5.3, -0.3, 10, 1.1, 0.3, 8, "steel_dk"), box(5.3, -0.5, 15, 0.6, 0.3, 1.2, "amber"),
                  box(0, -0.3, 1.5, 4, 0.3, 2.4, "black")]
      + [box(-4.5 + j * 2, -0.4, 7.5 + i * 3.6, 0.7, 0.3, 2.2, ("hazard", "blue_metal", "green_metal", "enamel")[(i + j) % 4])
         for i in range(4) for j in range(4)])
    S("water_cooler", [box(0, 0, 0, 4, 6, 12, "enamel"), Cap((0, 3, 13), (0, 3, 19), 3.2, "glass"),
                       box(0, -0.4, 8, 1, 0.4, 1, "blue_metal"), box(2.2, -0.4, 8, 0.7, 0.4, 1, "red")], 24)
    S("locker_gear", [box(0, 0, 0, 7.2, 6.5, 24, "locker"), box(0, -0.2, 0.5, 0.25, 0.3, 23, "black"),
                      box(-3.6, -0.3, 18, 2.2, 0.2, 0.4, "vent"), box(3.6, -0.3, 18, 2.2, 0.2, 0.4, "vent"),
                      box(-3.6, -0.3, 19.4, 2.2, 0.2, 0.4, "vent"), box(3.6, -0.3, 19.4, 2.2, 0.2, 0.4, "vent"),
                      box(-0.9, -0.4, 11, 0.4, 0.3, 1.6, "chrome"), box(0.9, -0.4, 11, 0.4, 0.3, 1.6, "chrome"),
                      box(-4, 1, 24, 2.2, 3.5, 2.2, "carton")], 30)
    S("med_cabinet", [box(0, 0, 0, 7, 6, 23, "enamel"), box(-3.4, -0.2, 9, 3, 0.3, 13, "glass"),
                      box(3.4, -0.2, 9, 3, 0.3, 13, "glass"), box(0, -0.4, 4.5, 2.4, 0.3, 0.9, "red"),
                      box(0, -0.4, 3.7, 0.8, 0.3, 2.5, "red"), box(-4.4, -0.5, 10, 0.8, 0.3, 2.6, "amber"),
                      box(-2.4, -0.5, 10, 0.8, 0.3, 2, "paper"), box(2.6, -0.5, 15.6, 1, 0.3, 2.4, "screen"),
                      box(4.6, -0.5, 10, 0.8, 0.3, 3, "paper")])
    S("gun_cabinet", [box(0, 0, 0, 7.2, 6, 24, "steel_dk"), box(0, -0.2, 3, 6, 0.3, 19, "black")]
      + [box(x, -0.5, 4, 0.55, 0.5, 15, "gunmetal") for x in (-4, -1.4, 1.2, 3.8)]
      + [box(x, -0.5, 4, 0.7, 0.6, 5, "wood") for x in (-4, -1.4, 1.2, 3.8)])
    S("radio_rack", [box(0, 0, 0, 7.2, 6.5, 24, "olive")]
      + [box(0, -0.2, 2.4 + i * 5.4, 6.2, 0.3, 4.4, "steel_dk") for i in range(4)]
      + [box(-3.4 + (i % 2) * 2, -0.5, 4 + i * 5.4, 1.5, 0.3, 1.6, "screen" if i % 2 else "amber") for i in range(4)]
      + [box(2.5 + j * 1.6, -0.5, 4 + i * 5.4, 0.5, 0.3, 0.6, ("red", "hazard", "screen")[(i + j) % 3]) for i in range(4) for j in range(2)]
      + [Cap((5.5, 3, 24), (5.5, 3, 31), 0.35, "steel")], 34)
    S("console", [box(0, 2, 0, 7.4, 5, 9, "steel_dk"), Box((0, 2.2, 11.5), (7.2, 3.2, 0.6), "gunmetal", basis_along((1, 0, 0), (0, -0.5, 1))),
                  box(0, 5.5, 9, 7.2, 1.2, 12, "steel_dk"), box(-3.4, 5.2, 12.5, 2.8, 0.3, 6.5, "screen"),
                  box(3.6, 5.2, 12.5, 2.6, 0.3, 6.5, "black"), box(3.6, 5.0, 15, 1.8, 0.3, 0.6, "amber"),
                  box(-4, 0.6, 10.4, 1.6, 1.6, 0.5, "amber"), box(1, 0.6, 10.4, 2.4, 1.6, 0.5, "paper"),
                  box(5, 0.6, 10.4, 0.8, 0.8, 0.8, "red")], 26)
    S("stove", [box(0, 0, 0, 7.3, 8, 11, "steel"), box(0, -0.2, 2, 5.4, 0.3, 5.6, "black"), box(0, -0.4, 8.6, 5.6, 0.3, 0.5, "chrome"),
                Cap((-3.4, 2.4, 11.4), (-3.4, 2.4, 11.6), 2.1, "black"), Cap((3.4, 2.4, 11.4), (3.4, 2.4, 11.6), 2.1, "black"),
                Cap((3.4, 2.4, 11.6), (3.4, 2.4, 15), 2.3, "steel_dk"), box(0, 7, 11, 7.3, 1, 10, "steel"),
                box(0, 2.5, 20, 7.3, 5.5, 1.2, "steel_dk")], 26)
    S("sink", [box(0, 0, 0, 7.3, 8, 11, "steel"), box(0, 1.2, 10.6, 5, 5, 0.5, "steel_dk"), box(0, 7, 11, 7.3, 1, 5, "enamel"),
               Cap((0, 6.2, 11), (0, 6.2, 15), 0.6, "chrome"), Cap((0, 6.2, 15), (0, 3.6, 15), 0.6, "chrome"),
               box(-4.4, -0.3, 3, 2.3, 0.2, 6, "steel_dk"), box(4.4, -0.3, 3, 2.3, 0.2, 6, "steel_dk")], 24)
    S("oven_rack", [box(0, 0, 0, 7.2, 7, 22, "steel"), box(0, -0.2, 12, 5.6, 0.3, 7.5, "black"), box(0, -0.2, 2.5, 5.6, 0.3, 7.5, "black"),
                    box(0, -0.5, 10.6, 5.2, 0.4, 0.5, "chrome"), box(0, -0.5, 20, 5.2, 0.4, 0.5, "chrome"),
                    box(4.5, -0.5, 21, 0.6, 0.3, 0.5, "amber")])
    # 桌子、工作台（靠牆或獨立，寬）
    W("counter", [box(0, 0, 0, 23.5, 9, 10.5, "steel"), box(0, 0, 10.5, 23.8, 9.4, 1, "benchtop"),
                  box(-16, 2, 11.5, 3, 3.5, 3.4, "steel_dk"), box(-6, 2.5, 11.5, 1.2, 1.2, 4.2, "enamel"),
                  box(-3, 3, 11.5, 1, 1, 2.6, "red_metal"), box(8, 2, 11.5, 4.5, 4, 0.5, "wood"),
                  box(17, 2.5, 11.5, 2.4, 2.4, 2.8, "enamel")]
      + [box(x, -0.3, 3, 3.3, 0.2, 5.6, "steel_dk") for x in (-19.5, -11.6, -3.8, 4, 11.8, 19.6)])
    W("mess_table", table(23.5, 13, 8.5, "benchtop") + [
        box(-15, 3, 9.9, 3.2, 4.6, 0.4, "blue_metal"), box(-15.6, 4, 10.3, 1.2, 1.4, 1.2, "enamel"),
        box(-3, 6, 9.9, 3.2, 4.6, 0.4, "red_metal"), box(-2, 7.4, 10.3, 1, 1, 1.6, "paper"),
        box(12, 3.6, 9.9, 1.2, 1.2, 2.4, "glass"), box(17, 6, 9.9, 3.2, 4.6, 0.4, "blue_metal"), box(7, 8, 9.9, 1.3, 1.3, 1, "hazard")]
      + [box(x, -3.6, 0, 3, 3, 5, "steel_dk") for x in (-16, -5.4, 5.4, 16)], 26)
    W("workbench", table(23.5, 10, 9.5, "wood", "steel_dk", 1.6) + [
        box(0, 8.6, 11, 23.5, 1, 10, "steel_dk"), box(-17, 2, 11.1, 3.5, 3, 3.2, "red_metal"), box(-17, 2.6, 14.3, 1, 0.8, 1, "chrome"),
        box(-6, 2, 11.1, 4, 1.2, 0.8, "steel"), box(4, 3, 11.1, 2.5, 2.5, 4, "blue_metal"), box(13, 1.6, 11.1, 5, 2, 0.6, "hazard"),
        box(19.5, 4, 11.1, 1.6, 1.6, 2.4, "rust")]
      + [box(x, 8.3, 13 + (i % 3) * 2.2, 0.5, 0.3, 4 - (i % 3), ("steel", "red_metal", "hazard")[i % 3]) for i, x in enumerate(range(-20, 21, 4))], 28)
    W("map_table", table(23.5, 13, 8.5, "wood") + [
        box(0, 1.5, 9.9, 17, 10, 0.3, "paper"), box(-8, 4, 10.2, 5, 4.6, 0.2, "tarp"), box(6, 6, 10.2, 3, 2, 0.2, "red"),
        box(15, 3, 10.2, 1.4, 1.4, 1.8, "olive"), box(-19.5, 3, 9.9, 2.4, 3.4, 2.6, "olive"), box(-19.5, 2.8, 12.5, 1.6, 0.3, 1.4, "screen"),
        box(20, 8, 9.9, 1.2, 1.2, 2.2, "enamel")], 26)
    W("desk_wide", [box(0, 0, 0, 23.5, 10, 9, "wood"), box(0, -0.2, 1, 21, 0.3, 7, "leather"), box(0, 0, 9, 23.8, 10.4, 1, "wood"),
                    box(-13, 5.5, 10, 4.4, 1, 7, "black"), box(-13, 5.2, 11, 3.8, 0.3, 5.4, "screen"), box(-13, 2, 10, 4, 2.2, 0.5, "steel_dk"),
                    box(1, 2.4, 10, 3.4, 4.6, 0.4, "paper"), box(4.6, 3.4, 10, 1, 1, 1.8, "enamel"), box(14, 4.5, 10, 4, 4, 2.4, "carton"),
                    box(19.6, 5, 10, 1.4, 1.4, 5.5, "steel_dk"), box(19.6, 3.6, 15.5, 2.4, 3.4, 1, "amber")], 26)
    W("lab_island", [box(0, 0, 0, 23.5, 12, 9.5, "cabinet"), box(0, 0, 9.5, 23.8, 12.4, 1, "benchtop"),
                     box(-17, 3, 10.5, 2.2, 4, 3.4, "enamel"), Cap((-17, 4.4, 14), (-15.6, 2.6, 17.4), 0.8, "steel_dk"),
                     box(-8, 4, 10.5, 3.4, 3.4, 4.4, "steel"), box(-8, 3.8, 12, 2.2, 0.3, 1.6, "screen"),
                     box(5, 3, 10.5, 5.5, 2, 0.5, "steel_dk")]
      + [Cap((2 + i * 1.5, 3.6, 11), (2 + i * 1.5, 3.6, 13.8), 0.55, ("amber", "glass", "screen", "red", "glass")[i]) for i in range(5)]
      + [box(16, 4, 10.5, 3.6, 3, 2.6, "enamel"), box(16, 3.8, 11, 2.6, 0.3, 1.6, "black"), box(20.6, 6, 10.5, 1.2, 1.2, 4.6, "glass")]
      + [box(x, -0.3, 2, 3.3, 0.2, 5.6, "steel_dk") for x in (-19.5, -11.6, -3.8, 4, 11.8, 19.6)], 28)
    W("bar_counter", [box(0, 0, 0, 23.5, 8, 12, "wood"), box(0, -0.3, 1, 22.5, 0.3, 9, "leather"), box(0, -1, 12, 23.8, 10, 1.2, "brass"),
                      box(-14, 3, 13.2, 1, 1, 4, "green_metal"), box(-11, 4, 13.2, 1, 1, 3.4, "amber"), box(-8, 3, 13.2, 1, 1, 4.4, "glass"),
                      box(4, 3, 13.2, 1.2, 1.2, 1.6, "glass"), box(7, 4, 13.2, 1.2, 1.2, 1.6, "glass"), box(16, 3, 13.2, 3, 3, 1, "linen")], 26)
    W("sofa", [box(0, 0, 0, 23.5, 10, 6, "leather"), box(0, 8, 6, 23.5, 3, 8, "leather"), box(-21.5, 0, 6, 2, 9, 4, "leather"),
               box(21.5, 0, 6, 2, 9, 4, "leather"), box(-10, 1, 6, 8.5, 7, 1.4, "velvet"), box(9, 1, 6, 8.5, 7, 1.4, "velvet"),
               box(-14, 5, 7.4, 3, 2.4, 3, "linen")], 24)
    W("theater_seats", [box(x, 0, 0, 3.4, 6, 5, "velvet") for x in (-20, -12, -4, 4, 12, 20)]
      + [box(x, 5, 5, 3.4, 1.6, 9, "velvet") for x in (-20, -12, -4, 4, 12, 20)]
      + [box(x, 0, 5, 0.6, 6, 2.4, "wood") for x in (-24, -16, -8, 0, 8, 16, 23.4)], 22)
    W("bunk2", [box(-22.6, 0, 0, 0.8, 11, 19, "steel_dk"), box(22.6, 0, 0, 0.8, 11, 19, "steel_dk"),
                box(0, 0, 4, 23, 11, 1, "steel_dk"), box(0, 0.5, 5, 22.5, 10, 1.6, "mattress"), box(4, 0.5, 6.6, 18, 10, 0.7, "blanket"),
                Ell((-17.5, 5.5, 7.4), (3.6, 3.6, 1.0), "linen"),
                box(0, 0, 14, 23, 11, 1, "steel_dk"), box(0, 0.5, 15, 22.5, 10, 1.6, "mattress"), box(5, 0.5, 16.6, 17, 10, 0.7, "tarp"),
                Ell((-17.5, 5.5, 17.4), (3.6, 3.6, 1.0), "linen"), box(21, -0.6, 0, 0.5, 0.6, 15, "steel")], 30)
    W("cot", [box(0, 0, 3.4, 23, 11, 0.8, "olive"), box(4, 0.5, 4.2, 18, 10, 0.8, "blanket"), Ell((-17.5, 5.5, 4.8), (3.4, 3.4, 1.0), "linen")]
      + [box(x, y, 0, 0.6, 0.8, 3.6, "steel_dk") for x in (-22, 0, 22) for y in (0.4, 10)], 18)
    W("bed", [box(0, 0, 0, 23, 12, 4.5, "wood"), box(0, 0.5, 4.5, 22.5, 11, 2, "mattress"), box(5, 0.5, 6.5, 17.5, 11, 0.8, "blanket"),
              Ell((-17, 6, 7.3), (4, 4, 1.2), "linen"), box(-23, 0, 4.5, 0.8, 12, 7, "wood")], 22)
    W("med_bed", [box(0, 0, 5.5, 23, 11, 1, "chrome"), box(0, 0.5, 6.5, 22.5, 10, 1.6, "linen"), box(6, 0.5, 8.1, 16, 10, 0.6, "tarp"),
                  Ell((-17, 5.5, 8.8), (3.6, 3.6, 1.0), "enamel"), box(-23, 0, 6.5, 0.6, 11, 5, "chrome"), box(23, 0, 6.5, 0.6, 11, 3, "chrome"),
                  Cap((-20, 10.4, 0), (-20, 10.4, 21), 0.4, "chrome"), box(-20, 10, 16.5, 1.3, 0.8, 3.6, "glass"),
                  box(-20, 9.8, 17.5, 1, 0.3, 1.6, "red")]
      + [box(x, y, 0, 0.6, 0.8, 5.6, "chrome") for x in (-21, 21) for y in (0.6, 9.6)], 28)
    W("pipe_run", [Cap((-24, 3, 3.5), (24, 3, 3.5), 2.6, "steel"), Cap((-24, 7.5, 3.2), (24, 7.5, 3.2), 2.2, "rust"),
                   box(-12, 0.2, 0, 1.2, 9.6, 1, "steel_dk"), box(12, 0.2, 0, 1.2, 9.6, 1, "steel_dk"),
                   Cap((0, 3, 3.5), (0, 3, 8.5), 0.8, "red_metal"), Cap((-2.2, 3, 8.8), (2.2, 3, 8.8), 0.7, "red_metal")], 16)
    W("barrier", [Box((x, 3.5, 3.4), (7.6, 3.4, 3.4), "ash") for x in (-16, 0, 16)]
      + [Box((x, 3.5, 8.6), (7.6, 1.6, 2), "ash") for x in (-16, 0, 16)]
      + [box(x, -0.2, 2.2, 5.5, 0.3, 1.6, "hazard") for x in (-16, 0, 16)], 16)
    W("crates_long", [box(-16, 0, 0, 7.4, 11, 9, "wood"), box(0, 0, 0, 7.4, 11, 9, "carton"), box(16, 0, 0, 7.4, 11, 9, "wood"),
                      box(-16, -0.2, 3.6, 7.4, 0.3, 1.2, "rust"), box(16, -0.2, 3.6, 7.4, 0.3, 1.2, "rust"),
                      box(-8, 1.5, 9, 6.6, 8, 6.5, "olive"), box(-8, 1.3, 11.4, 3.4, 0.3, 1.5, "paper"),
                      box(14, 2, 9, 5, 6, 0.6, "tarp")], 26)
    W("drums_row", [Cap((x, 4.5, 2.4), (x, 4.5, 12.5), 4.6, m) for x, m in ((-18.6, "blue_metal"), (-9.3, "rust"), (0, "blue_metal"), (9.3, "red_metal"), (18.6, "blue_metal"))]
      + [Cap((x, 4.5, 13.2), (x, 4.5, 13.4), 3.6, "steel_dk") for x in (-18.6, -9.3, 0, 9.3, 18.6)], 24)
    # 獨立的單格家具
    S("table_small", table(6.6, 10, 8.5, "benchtop") + [box(-2, 3, 9.9, 2.2, 3, 0.4, "paper"), box(3, 5, 9.9, 1, 1, 1.6, "enamel")], 22)
    S("table_round", [Cap((0, 6, 0), (0, 6, 7.5), 0.9, "steel_dk"), Cap((0, 6, 8), (0, 6, 8.8), 7, "linen"),
                      box(-2, 4.6, 9.2, 1.4, 1.4, 0.4, "enamel"), box(2.2, 6.4, 9.2, 0.8, 0.8, 2, "glass"), box(0.4, 8, 9.2, 0.7, 0.7, 2.6, "amber")], 22)
    S("cart_lab", table(6.4, 8.5, 9, "steel", "chrome", 0.8) + [box(0, 0, 3.5, 6.2, 8.5, 0.6, "steel"),
                    box(-2.5, 2, 9.8, 2.6, 3.4, 2.2, "enamel"), box(3, 3, 9.8, 1, 1, 3, "glass"), box(0, 2, 4.1, 4, 4, 2.5, "carton")], 22)
    S("centrifuge", [box(0, 0, 0, 7, 9, 8.5, "cabinet"), box(0, 0, 8.5, 7.2, 9.3, 0.8, "benchtop"), Cap((0, 4.6, 9.3), (0, 4.6, 12.6), 4.6, "enamel"),
                     Cap((0, 4.6, 12.8), (0, 4.6, 13.2), 3.4, "steel_dk"), box(0, -0.3, 10.2, 2, 0.3, 1.2, "screen")], 22)
    S("chair_office", [Cap((0, 5, 0), (0, 5, 4.5), 0.7, "steel_dk"), box(0, 2, 4.5, 4, 6, 1.4, "tarp"), box(0, 7.4, 5.9, 4, 1.2, 7, "tarp"),
                       box(0, 2, 0, 4.5, 0.8, 0.7, "steel_dk"), box(0, 4.6, 0, 0.6, 4, 0.7, "steel_dk")], 18)
    S("plant", [Cap((0, 4.5, 0), (0, 4.5, 5.5), 3.2, "rust", 3.8), Ell((0, 4.5, 10), (4.6, 4, 4.5), "leaf"), Ell((-3, 4, 13.5), (2.6, 2.6, 3), "leaf"),
                Ell((3, 5, 15), (2.8, 2.6, 3.2), "leaf"), Ell((0, 4.5, 18), (2.4, 2.4, 3), "leaf")], 26)
    S("copier", [box(0, 0, 0, 7, 9, 12, "enamel"), box(0, 0, 12, 7.2, 9.3, 2, "steel_dk"), box(-2, 1, 14, 4.4, 6, 0.5, "enamel"),
                 box(4.6, 1, 14, 1.4, 2.4, 0.5, "screen"), box(0, -0.3, 6, 5.6, 0.3, 0.5, "steel_dk"), box(0, -1.4, 3.2, 4.5, 1.6, 0.5, "paper")], 24)
    S("footlocker", [box(0, 0, 0, 7, 9, 6.5, "olive"), box(0, -0.3, 4.4, 7, 0.3, 0.5, "steel_dk"), box(0, -0.5, 3.2, 1, 0.3, 1.6, "brass"),
                     box(-3.6, 2.4, 6.5, 2.4, 3.6, 0.4, "paper")], 16)
    S("crate_wood", [box(0, 0, 0, 7.2, 12, 11, "wood"), box(0, -0.3, 0.6, 7.2, 0.3, 1.2, "rust"), box(0, -0.3, 9, 7.2, 0.3, 1.2, "rust"),
                     box(-6.2, -0.4, 0, 0.9, 0.3, 11, "rust"), box(6.2, -0.4, 0, 0.9, 0.3, 11, "rust"), box(0.6, -0.5, 4, 3.2, 0.3, 3, "paper")], 22)
    S("crate_stack", [box(0, 0, 0, 7.2, 12, 9, "wood"), box(0, -0.3, 3.6, 7.2, 0.3, 1.2, "rust"), box(-1, 2, 9, 5.6, 9, 7.5, "carton"),
                      box(-1, 1.8, 12.4, 5.6, 0.3, 0.9, "paper"), box(3.6, 3, 16.5, 2.4, 5, 3.2, "olive")], 30)
    S("crate_tarp", [box(0, 0, 0, 7, 12, 10, "wood"), box(0, -0.5, 4, 7.5, 13, 6.6, "tarp"), box(-7.4, -0.6, 2.4, 0.4, 0.4, 2.6, "hazard"),
                     box(7.4, -0.6, 2.4, 0.4, 0.4, 2.6, "hazard")], 22)
    S("drum", [Cap((0, 6, 2.6), (0, 6, 13), 5.2, "blue_metal"), Cap((0, 6, 13.6), (0, 6, 13.9), 4.2, "steel_dk"),
               Cap((0, 6, 6), (0, 6, 6.3), 5.5, "steel_dk"), Cap((0, 6, 10), (0, 6, 10.3), 5.5, "steel_dk")], 24)
    S("drums", [Cap((-3.4, 8, 2.6), (-3.4, 8, 12.5), 4.2, "rust"), Cap((3.6, 6.5, 2.6), (3.6, 6.5, 12.5), 4.2, "blue_metal"),
                Cap((-0.6, 2.4, 2.6), (-0.6, 2.4, 12.5), 4.2, "red_metal"), Cap((-0.6, 2.4, 13.2), (-0.6, 2.4, 13.4), 3.2, "steel_dk"),
                Cap((3.6, 6.5, 13.2), (3.6, 6.5, 13.4), 3.2, "steel_dk")], 26)
    S("gas_cylinders", [Cap((x, y, 1.6), (x, y, 17), 2.6, m) for x, y, m in ((-4, 5.6, "green_metal"), (1.2, 6.4, "hazard"), (4.6, 3, "enamel"), (-1.4, 2, "blue_metal"))]
      + [Cap((x, y, 18.5), (x, y, 21), 0.9, "chrome") for x, y in ((-4, 5.6), (1.2, 6.4), (4.6, 3), (-1.4, 2))]
      + [box(0, 0, 9, 7.4, 8.6, 0.6, "steel_dk")], 30)
    S("tool_chest", [box(0, 0, 0, 7, 8, 12, "red_metal"), box(0, 0.6, 12, 6.6, 6.8, 5, "red_metal")]
      + [box(0, -0.3, 1.6 + i * 2.6, 6, 0.3, 1.9, "rust") for i in range(4)]
      + [box(0, -0.6, 2.2 + i * 2.6, 3.4, 0.3, 0.5, "chrome") for i in range(4)]
      + [box(0, 0.3, 13.2, 5.6, 0.3, 2.6, "rust"), box(0, 0, 14.2, 3.4, 0.3, 0.5, "chrome"), box(-3, 2.6, 17, 2.6, 2, 1.2, "steel")], 28)
    S("generator_unit", [box(0, 0, 1.5, 7.2, 12, 10, "hazard"), box(0, -0.3, 3, 5.6, 0.3, 5.5, "vent"), box(0, -0.6, 9.2, 5, 0.3, 1.2, "black"),
                         box(-3, -0.9, 9.5, 0.8, 0.3, 0.6, "red"), box(2.8, -0.9, 9.5, 1.4, 0.3, 0.6, "screen"),
                         Cap((-4, 8, 11.5), (-4, 8, 17), 1.2, "steel_dk"), Cap((2.6, 5, 11.5), (2.6, 5, 13.5), 2.6, "steel"),
                         box(0, 0, 0, 7.4, 1.2, 1.5, "steel_dk"), box(0, 10.8, 0, 7.4, 1.2, 1.5, "steel_dk")], 28)
    S("pump", [box(0, 0, 0, 7.2, 11, 2.4, "steel_dk"), Cap((-2.6, 6, 6.4), (4.6, 6, 6.4), 4, "green_metal"), Cap((-6.4, 6, 6.4), (-3.4, 6, 6.4), 3, "steel"),
               Cap((2, 6, 10), (2, 6, 15), 1.2, "steel"), Cap((2, 6, 15.4), (-3.4, 6, 15.4), 1.2, "steel"), Cap((0.2, 6, 15.4), (3.8, 6, 15.4), 0.5, "red_metal"),
               Cap((2, 6, 15.4), (2, 6, 18.4), 0.5, "red_metal"), Cap((0, 6, 18.6), (4, 6, 18.6), 0.6, "red_metal")], 26)
    S("tank_v", [Cap((0, 6.4, 6), (0, 6.4, 20), 6.2, "enamel"), Cap((0, 6.4, 10.4), (0, 6.4, 10.8), 6.5, "steel_dk"),
                 Cap((0, 6.4, 16.4), (0, 6.4, 16.8), 6.5, "steel_dk"), box(-0.4, -0.4, 12, 2.6, 0.3, 2.6, "hazard"),
                 Cap((0, 6.4, 26), (0, 6.4, 28), 1.2, "chrome")]
      + [Cap((x, y, 0), (x, y, 6), 0.7, "steel_dk") for x, y in ((-4.4, 3), (4.4, 3), (-4.4, 9.8), (4.4, 9.8))], 36)
    S("switchgear", [box(0, 0, 0, 7.2, 6.5, 24, "locker"), box(-3.5, -0.2, 3, 3, 0.3, 19, "steel_dk"), box(3.5, -0.2, 3, 3, 0.3, 19, "steel_dk"),
                     box(-3.5, -0.5, 16, 1.6, 0.3, 3.4, "black"), box(3.5, -0.5, 16, 1.6, 0.3, 3.4, "black"),
                     box(-3.5, -0.7, 17.4, 0.5, 0.3, 1.4, "amber"), box(3.5, -0.7, 17.4, 0.5, 0.3, 1.4, "screen"),
                     box(-3.5, -0.5, 7, 2, 0.3, 4.6, "hazard"), box(3.5, -0.5, 9, 0.6, 0.6, 3, "red")])
    S("cable_reel", [Cap((0, 2.4, 7.5), (0, 2.8, 7.5), 7.2, "wood"), Cap((0, 3, 7.5), (0, 8, 7.5), 4.8, "rubber"), Cap((0, 8.2, 7.5), (0, 8.6, 7.5), 7.2, "wood"),
                     Cap((0, 2.2, 7.5), (0, 2.3, 7.5), 1.6, "steel_dk")], 24)
    S("tires", [Cap((0, 6, 1.6 + i * 3.4), (0, 6, 3.4 + i * 3.4), 5.6, "rubber") for i in range(4)]
      + [Cap((0, 6, 14.9), (0, 6, 15.1), 2.8, "steel_dk")], 26)
    S("sandbag_wall", [Ell((x, 4.5, 2.2 + z * 3.5), (4.2, 4.2, 2.0), "cloth") for z in range(3) for x in ((-4, 4) if z != 1 else (-7, 0, 7))], 20)
    S("ammo_stack", [box(-2, 0, 0, 5.2, 10, 5.5, "olive"), box(3, 1, 0, 3.6, 9, 4.6, "wood"), box(-2, 1, 5.5, 5, 8, 5, "olive"),
                     box(-2, -0.3, 2, 3, 0.3, 1.2, "hazard"), box(-2, 0.7, 7.4, 3, 0.3, 1.2, "paper"), box(-5, -0.4, 4.4, 0.5, 0.3, 1.5, "brass"),
                     box(2.8, 2.6, 4.6, 2.4, 5, 3.2, "steel_dk")], 22)
    S("weapon_bench", table(7, 9, 9.5, "steel") + [box(0, 7.8, 10.5, 7, 1, 9, "steel_dk"), box(0, 3, 10.5, 5.6, 1.2, 1, "gunmetal"),
                      box(-3.4, 3, 10.5, 1.2, 1.2, 2.6, "wood"), box(4, 5, 10.5, 1.6, 1.6, 1.6, "brass")]
      + [box(x, 7.5, 12.5, 0.5, 0.3, 6, "gunmetal") for x in (-4.6, -1.6, 1.4, 4.4)], 26)
    S("stretcher_stand", [Cap((0, 6, 0), (0, 6, 22), 0.5, "chrome"), box(0, 5.6, 17, 1.6, 0.9, 4, "glass"), box(0, 5.4, 18, 1.2, 0.3, 1.8, "amber"),
                          box(0, 6, 0, 3.4, 0.6, 0.6, "chrome"), box(0, 3, 0, 0.6, 6, 0.6, "chrome"), Cap((0, 5.6, 17), (-2.6, 3, 9), 0.25, "glass")], 26)
    S("luggage", [box(-2.6, 2, 0, 3.6, 8, 10, "leather"), box(3, 0, 0, 3.2, 7, 7, "blue_metal"), box(-2.6, 1.8, 3, 3.6, 0.3, 0.6, "brass"),
                  box(-2.6, 1.8, 6.6, 3.6, 0.3, 0.6, "brass"), box(3, -0.3, 3.2, 3.2, 0.3, 0.5, "chrome"), box(-2, 4, 10, 2.4, 3, 2.4, "velvet")], 22)
    S("slot_machine", [box(0, 0, 0, 6.4, 7, 9, "red_metal"), box(0, 1.5, 9, 6.4, 5.5, 11, "red_metal"), box(0, 1.2, 12, 4.6, 0.3, 4.6, "screen"),
                       box(0, -0.3, 5, 4.4, 0.3, 1.6, "brass"), box(0, 1.2, 18, 4.6, 0.3, 1.4, "amber"), Cap((7, 4, 9), (7, 4, 15), 0.5, "chrome"),
                       Cap((7, 4, 15.5), (7, 4, 16), 1.1, "red")], 26)
    S("piano", [box(0, 0, 0, 7.3, 6, 13, "black"), box(0, -3, 8, 7.3, 3.4, 1.4, "black"), box(0, -3, 9.4, 6.6, 3, 0.4, "linen"),
                box(0, -0.3, 14, 4, 0.3, 4, "paper"), box(-6.6, -3, 0, 0.7, 1, 8, "black"), box(6.6, -3, 0, 0.7, 1, 8, "black")], 26)
    S("deck_chair", [Box((0, 6, 4.4), (5, 6.4, 0.5), "linen", basis_along((1, 0, 0), (0, -0.25, 1))), box(0, 9.6, 5, 5, 0.8, 7, "linen"),
                     box(-4.6, 0, 0, 0.5, 11, 0.8, "wood"), box(4.6, 0, 0, 0.5, 11, 0.8, "wood"), box(-4.6, 9, 0, 0.5, 0.8, 11, "wood"),
                     box(4.6, 9, 0, 0.5, 0.8, 11, "wood")], 22)
    S("winch", [box(0, 0, 0, 7.2, 11, 2.2, "steel_dk"), Cap((-4.6, 6, 6.4), (4.6, 6, 6.4), 4, "rust"), Cap((-6, 6, 6.4), (-5, 6, 6.4), 5.4, "steel"),
                Cap((5, 6, 6.4), (6, 6, 6.4), 5.4, "steel"), box(6.4, 1, 2.2, 0.8, 0.8, 8.5, "hazard"), Cap((6.4, 1.4, 11), (6.4, 1.4, 12), 0.9, "red")], 22)
    S("cowl_vent", [Cap((0, 6, 0), (0, 6, 14), 3.4, "enamel"), Cap((0, 6, 14), (0, 1.5, 18.5), 3.6, "enamel", 5.2), Cap((0, 1.2, 18.7), (0, 0.9, 19), 4.4, "red_metal"),
                    Cap((0, 6, 1), (0, 6, 1.6), 4.6, "steel_dk")], 30)
    S("bollard", [Cap((0, 6, 0), (0, 6, 7), 3.2, "steel_dk"), Cap((0, 6, 7.4), (0, 6, 9), 4.4, "steel_dk"), Cap((-4.4, 6, 4.5), (4.4, 6, 4.5), 1.1, "steel_dk"),
                  Cap((0, 6, 3), (0, 6, 3.6), 3.5, "cloth"), Cap((0, 6, 4), (0, 6, 4.6), 3.5, "cloth")], 18)
    S("lamp_post", [Cap((0, 6, 0), (0, 6, 3), 1.8, "steel_dk"), Cap((0, 6, 3), (0, 6, 34), 0.8, "steel_dk"), Cap((0, 6, 34), (0, 1.6, 36), 0.7, "steel_dk"),
                    box(0, 0, 34.4, 2.4, 3, 1.4, "steel_dk"), box(0, 0.2, 33.8, 1.8, 2.4, 0.6, "amber")], 46)
    S("signpost", [Cap((0, 6, 0), (0, 6, 16), 0.6, "steel"), box(0, 5.2, 12, 6, 0.6, 7, "hazard"), box(0, 4.9, 14.6, 4.4, 0.3, 0.9, "black"),
                   box(0, 4.9, 16.6, 3, 0.3, 0.9, "black")], 30)
    S("antenna_mast", [Cap((0, 6, 0), (0, 6, 40), 0.6, "steel"), Cap((-5, 6, 30), (5, 6, 30), 0.35, "steel"), Cap((-3.4, 6, 35), (3.4, 6, 35), 0.35, "steel"),
                       Cap((-4.6, 6, 0), (0, 6, 22), 0.25, "steel_dk"), Cap((4.6, 6, 0), (0, 6, 22), 0.25, "steel_dk"), box(0, 5, 0, 3, 2, 3, "steel_dk"),
                       Cap((0, 6, 40), (0, 6, 41), 0.8, "red")], 52)
    S("wood_pile", [Cap((x, 0.6, 2 + r * 3.2), (x, 10, 2 + r * 3.2), 1.7, "wood") for r in range(3) for x in ((-5, -1.7, 1.7, 5) if r % 2 == 0 else (-3.4, 0, 3.4))]
      + [Ell((0, 5, 11.4), (6.4, 5, 1.2), "snow")], 22)
    S("snow_mound", [Ell((0, 6, 2.6), (7.4, 6, 4.6), "snow"), Ell((-3, 4, 5.4), (3.4, 3, 2.6), "snow"), box(3.6, 3, 2, 2.4, 2.4, 5.4, "rust"),
                     box(3.6, 3, 7.4, 2.6, 2.6, 0.9, "snow")], 16)
    S("sled", [box(-4.6, 0, 0, 0.6, 12, 1, "steel"), box(4.6, 0, 0, 0.6, 12, 1, "steel"), box(0, 1, 2, 5, 10, 0.8, "wood"),
               box(0, 2, 2.8, 4.4, 7, 4.5, "tarp"), box(0, 1.8, 5, 4.6, 0.3, 0.5, "hazard"), Ell((0, 5.5, 7.6), (4, 3.2, 0.9), "snow")], 20)
    S("ice_block", [Box((0, 6, 6), (6.2, 5.4, 6), "ice"), Box((3, 4, 13.5), (3, 3, 2.4), "ice"), Ell((-2, 6, 12.6), (3.6, 3.4, 1.2), "snow")], 26)
    S("stalagmite", [Cap((0, 6, 0), (0, 6, 16), 4.4, "rock", 0.8), Cap((-4, 4, 0), (-4.4, 4, 8), 2.4, "rock", 0.6), Cap((3.6, 7, 0), (4, 7, 6), 2.2, "rock", 0.5),
                     Ell((0, 6, 15.6), (1.4, 1.4, 1.2), "snow")], 26)
    S("server", [box(0, 0, 0, 7.2, 7, 24, "black")]
      + [box(0, -0.2, 2 + i * 2.7, 6.2, 0.3, 2, "steel_dk") for i in range(8)]
      + [box(-4.6 + j * 1.2, -0.5, 2.7 + i * 2.7, 0.35, 0.3, 0.5, "screen" if rnd.random() < 0.6 else ("amber" if rnd.random() < 0.6 else "red")) for i in range(8) for j in range(3)]
      + [box(3, -0.5, 2.6 + i * 2.7, 2.2, 0.3, 0.8, "vent") for i in range(8)])
    S("tape_drive", [box(0, 0, 0, 7.2, 7, 24, "olive"), box(0, -0.2, 11, 6.2, 0.3, 11.5, "steel_dk"),
                     Cap((-3, -0.3, 18), (-3, -0.6, 18), 2.5, "paper"), Cap((3, -0.3, 18), (3, -0.6, 18), 2.5, "paper"),
                     Cap((-3, -0.7, 18), (-3, -0.9, 18), 0.8, "steel_dk"), Cap((3, -0.7, 18), (3, -0.9, 18), 0.8, "steel_dk"),
                     box(0, -0.4, 12.4, 3.4, 0.3, 1.6, "black"), box(0, -0.2, 2, 6.2, 0.3, 7, "steel_dk")]
      + [box(-4 + j * 2, -0.5, 4 + i * 2.4, 0.6, 0.3, 0.8, ("amber", "red", "enamel")[(i + j) % 3]) for i in range(2) for j in range(5)])
    S("oscilloscope", table(6.8, 8, 8, "steel", "steel_dk", 1) + [box(0, 1, 9, 6, 6.5, 8, "olive"), Cap((-2.2, 0.8, 13.4), (-2.2, 0.6, 13.4), 2.8, "screen"),
                       box(3.6, 0.7, 14.5, 1.2, 0.3, 1, "amber"), box(3.6, 0.7, 11.6, 1.2, 0.3, 1, "enamel"), box(0, 2, 4, 5, 5, 3, "carton")], 26)
    print("set: ok")


# ── 大型物件（戶外、倉庫）────────────────────────────────────

def container(wc, hc, mat, raise_=10, height=17.0):
    d = depth_for(hc, height, raise_)
    hx = wc * 8 - 1.0
    p = [box(0, 0, 0.6, hx, d, height, mat)]
    # 波浪板：側面的直條、頂面的橫條
    n = int(hx * 2 / 3)
    for i in range(n):
        x = -hx + 1.5 + i * 3.0
        if i % 2 == 0:
            p.append(box(x, -0.25, 1.6, 0.35, 0.3, height - 2.4, "steel_dk"))
    for i in range(int(d / 4)):
        p.append(box(0, 2 + i * 4.0, height + 0.6, hx - 0.6, 0.6, 0.25, mat))
    p += [box(0, -0.3, 0.6, hx, 0.3, 1.0, "steel_dk"), box(0, -0.3, height - 0.6, hx, 0.3, 1.0, "steel_dk"),
          box(-hx + 0.4, -0.35, 0.6, 0.6, 0.3, height, "steel_dk"), box(hx - 0.4, -0.35, 0.6, 0.6, 0.3, height, "steel_dk")]
    # 門閂、標示牌
    for x in (hx - 6, hx - 10):
        p.append(Cap((x, -0.6, 2.5), (x, -0.6, height - 2), 0.3, "chrome"))
    p.append(box(-hx + 7, -0.5, height - 7, 4.4, 0.3, 3.4, "paper"))
    p.append(box(-hx + 7, -0.7, height - 5.6, 3, 0.3, 0.6, "black"))
    return p


def crate_block(wc, hc, raise_=10):
    height = 12.0
    d = depth_for(hc, height + 6, raise_)
    hx = wc * 8 - 1.0
    p = []
    n = wc
    rnd = random.Random(wc * 10 + hc)
    for i in range(n):
        x = -hx + 8 + i * 16 - 1
        m = rnd.choice(("wood", "wood", "carton", "olive"))
        p.append(box(x, 0, 0, 7.2, d * 0.48, height, m))
        p.append(box(x, -0.3, 4.6, 7.2, 0.3, 1.2, "rust"))
        m2 = rnd.choice(("wood", "carton", "tarp"))
        p.append(box(x, d * 0.52, 0, 7.2, d * 0.48, height + rnd.choice((0, 4)), m2))
        if rnd.random() < 0.7:
            p.append(box(x + rnd.uniform(-2, 2), 1.5, height, 4.6, d * 0.3, 6, rnd.choice(("carton", "olive", "wood"))))
            p.append(box(x, 1.3, height + 2.4, 2.4, 0.3, 1.4, "paper"))
    return p


def tank_h(wc, hc, raise_=10):
    r = min(hc * 8.0, 12.0)
    hx = wc * 8 - 2.0
    y = depth_for(hc, 2 * r + 3, raise_) / 2.0 + 1
    return [Cap((-hx + r, y, r + 3), (hx - r, y, r + 3), r, "enamel"),
            Cap((-hx * 0.45, y, r + 3), (-hx * 0.45 + 0.6, y, r + 3), r + 0.5, "steel_dk"),
            Cap((hx * 0.45, y, r + 3), (hx * 0.45 + 0.6, y, r + 3), r + 0.5, "steel_dk"),
            box(-hx * 0.6, y - r * 0.8, 0, 2, r * 1.6, 4, "steel_dk"), box(hx * 0.6, y - r * 0.8, 0, 2, r * 1.6, 4, "steel_dk"),
            box(0, y - r - 0.6, r + 1, 4.6, 0.3, 4.6, "hazard"), box(0, y - r - 0.8, r + 2.2, 3, 0.3, 2.2, "red"),
            Cap((0, y, 2 * r + 3), (0, y, 2 * r + 6), 1.6, "steel"), Cap((-3, y, 2 * r + 6.4), (3, y, 2 * r + 6.4), 0.7, "red_metal")]


def truck(wc, hc, raise_=12):
    """蓋著帆布的卡車（橫的，車頭朝左）。"""
    hx = wc * 8 - 1.5
    d = depth_for(hc, 20, raise_)
    cab = 13.0
    return [box(-hx + cab / 2 + 0.5, 1, 4, cab / 2, d - 2, 13, "olive"), box(-hx + cab / 2 + 0.5, 0.7, 10.5, cab / 2 - 1.6, 0.3, 4.6, "glass"),
            box(-hx + 1, 0.6, 5, 0.6, d - 1.2, 3, "steel_dk"), box(-hx + 0.6, 2, 6.4, 0.3, 2, 1.4, "amber"), box(-hx + 0.6, d - 4, 6.4, 0.3, 2, 1.4, "amber"),
            box(cab / 2 + 0.5, 0.6, 5, hx - cab / 2 - 0.5, d - 1.2, 2, "steel_dk"), box(cab / 2 + 0.5, 0.4, 7, hx - cab / 2 - 0.5, d - 0.8, 13, "tarp"),
            box(cab / 2 + 0.5, 0.1, 7, hx - cab / 2 - 0.5, 0.3, 1, "olive")]
      # 輪子



def gen_big():
    cols = ("blue_metal", "red_metal", "green_metal", "rust", "ash")
    for wc, hc in ((2, 2), (3, 2), (4, 2), (5, 2), (6, 2), (2, 3), (2, 4), (3, 3), (4, 3)):
        for ci, m in enumerate(cols[:3] if wc * hc > 6 else cols):
            BIG("container%d" % ci, wc, hc, container(wc, hc, m))
    for wc, hc in ((2, 2), (3, 2), (4, 2), (2, 3), (3, 3), (4, 3), (6, 2)):
        BIG("crates", wc, hc, crate_block(wc, hc))
    for wc, hc in ((3, 2), (4, 2), (5, 2), (6, 2)):
        BIG("tank", wc, hc, tank_h(wc, hc))
    for wc, hc in ((4, 2), (5, 2)):
        wheels = []
        hx = wc * 8 - 1.5
        d = depth_for(hc, 20, 12)
        for x in (-hx + 6, hx - 14, hx - 6):
            wheels.append(Cap((x, 0.2, 3.4), (x, 2.4, 3.4), 3.4, "rubber"))
            wheels.append(Cap((x, 0.0, 3.4), (x, 0.1, 3.4), 1.4, "steel"))
        BIG("truck", wc, hc, truck(wc, hc) + wheels, 12)
    # 救生艇（郵輪甲板）：橘色船身、白色頂蓋，架在吊架上
    for wc in (3, 4):
        hx = wc * 8 - 2.0
        d = depth_for(2, 15, 10)
        BIG("lifeboat", wc, 2, [Cap((-hx + 6, d / 2, 7), (hx - 6, d / 2, 7), 6, "orange"), box(0, d / 2 - 5, 9, hx - 4, 10, 5.5, "enamel"),
                                box(-hx * 0.4, d / 2 - 5.3, 10.6, 2, 0.3, 2, "glass"), box(hx * 0.2, d / 2 - 5.3, 10.6, 2, 0.3, 2, "glass"),
                                box(-hx + 2, d / 2 - 1, 0, 1, 2, 17, "steel_dk"), box(hx - 2, d / 2 - 1, 0, 1, 2, 17, "steel_dk"),
                                box(0, d / 2 - 6.4, 5.5, hx - 5, 0.3, 0.8, "enamel")])
    # 直升機（開場的停機坪；5x3 格）
    hx = 38.0
    BIG("helicopter", 5, 3, [Cap((-18, 20, 12), (2, 20, 12), 9.5, "olive"), Cap((2, 20, 13), (32, 20, 16), 5, "olive", 2.2),
                             Ell((-22, 20, 12), (8, 8.6, 8), "glass"), box(31, 19.4, 16, 1, 1.2, 10, "olive"), box(31, 14, 24, 1, 12, 0.8, "steel_dk"),
                             Cap((-8, 20, 21), (-8, 20, 25), 1.6, "steel_dk"), Box((-8, 20, 25.6), (30, 1.4, 0.4), "steel_dk"),
                             Box((-8, 20, 25.8), (1.4, 26, 0.4), "steel_dk"), box(-8, 10.2, 5, 9, 0.4, 9, "steel_dk"),
                             box(-8, 10, 12, 4, 0.3, 1.6, "hazard"), Cap((-22, 10, 1), (8, 10, 1), 0.9, "steel_dk"), Cap((-22, 30, 1), (8, 30, 1), 0.9, "steel_dk"),
                             Cap((-14, 10, 1), (-14, 13, 5), 0.6, "steel_dk"), Cap((2, 10, 1), (2, 13, 5), 0.6, "steel_dk")], 14)
    # 天線碟（天線塔頂的平台）：6x4
    BIG("dish", 6, 4, [Cap((0, 40, 0), (0, 40, 16), 5, "steel_dk"), box(0, 28, 0, 14, 24, 3, "steel_dk"),
                       Ell((0, 34, 30), (40, 30, 9), "enamel"), Ell((0, 33, 32.5), (35, 26, 7), "steel"),
                       Cap((0, 34, 30), (0, 16, 48), 0.9, "steel_dk"), Cap((-26, 34, 32), (0, 16, 48), 0.5, "steel_dk"),
                       Cap((26, 34, 32), (0, 16, 48), 0.5, "steel_dk"), Ell((0, 16, 48), (2.6, 2.6, 2.6), "red"),
                       box(-30, 4, 0, 5, 8, 9, "olive"), box(-30, 3.7, 3, 3, 0.3, 3, "screen")], 30)
    # 郵輪的煙囪（頂層甲板中央）：6x3
    BIG("funnel", 6, 3, [Cap((-18, 22, 0), (18, 22, 0), 15, "enamel"), Cap((-18, 22, 0), (-18, 22, 34), 15, "enamel"),
                         Cap((18, 22, 0), (18, 22, 34), 15, "enamel"), Box((0, 22, 17), (18, 15, 17), "enamel"),
                         Box((0, 6.8, 24), (30, 0.4, 3.4), "red_metal"), Box((0, 22, 35), (30, 13, 1.2), "steel_dk"),
                         Box((0, 6.6, 9), (6, 0.3, 4), "blue_metal")], 34)
    # 小艇（碼頭）：3x2
    d = depth_for(2, 9, 8)
    BIG("boat", 3, 2, [Cap((-14, d / 2, 4.6), (12, d / 2, 4.6), 5.6, "steel_dk"), Cap((12, d / 2, 4.6), (21, d / 2, 5.6), 5.2, "steel_dk", 1.4),
                       box(-2, d / 2 - 4.4, 5, 12, 8.8, 2.4, "ash"), box(-9, d / 2 - 3.6, 7.4, 4, 7.2, 5.4, "enamel"), box(-9, d / 2 - 3.9, 9.6, 3, 0.3, 2.4, "glass"),
                       box(2, d / 2 - 3, 7.4, 4.4, 6, 2.6, "tarp"), box(-17.5, d / 2 - 2, 4, 1.6, 4, 6.5, "black")], 8)
    # 發電機組、鍋爐（機房）：2x2
    d = depth_for(2, 17, 10)
    BIG("genset", 2, 2, [box(0, 0, 2, 14.5, d, 14, "hazard"), box(0, -0.3, 0, 15, d + 0.6, 2, "steel_dk"), box(-6, -0.3, 5, 6.4, 0.3, 8, "vent"),
                         box(7.5, -0.3, 8, 4.6, 0.3, 5, "black"), box(6, -0.6, 10.4, 1.6, 0.3, 1.4, "screen"), box(9.6, -0.6, 10.6, 0.6, 0.3, 0.8, "red"),
                         box(9.6, -0.6, 9, 0.6, 0.3, 0.8, "amber"), Cap((-9, d * 0.6, 16), (-9, d * 0.6, 26), 1.8, "steel_dk"),
                         Cap((4, d * 0.4, 16), (4, d * 0.4, 18.5), 4.4, "steel"), box(0, d * 0.5, 16, 12, 0.6, 0.5, "steel_dk")])
    BIG("boiler", 2, 2, [Cap((0, d / 2 + 2, 9), (0, d / 2 + 2, 22), 11.5, "rust"), Cap((0, d / 2 + 2, 14), (0, d / 2 + 2, 14.5), 12, "steel_dk"),
                         Cap((0, d / 2 + 2, 20), (0, d / 2 + 2, 20.5), 12, "steel_dk"), box(0, d / 2 - 10, 3, 4.6, 0.6, 6, "black"),
                         box(0, d / 2 - 10.4, 4, 3.4, 0.3, 3.6, "amber"), Cap((8, d / 2 - 6, 2), (8, d / 2 - 6, 12), 1, "copper"),
                         Cap((-9.6, d / 2 - 2, 26), (-9.6, d / 2 - 2, 34), 1.6, "steel"), box(4, d / 2 - 10.2, 15, 1.6, 0.3, 1.6, "enamel"),
                         box(0, 2, 0, 13, d - 2, 3, "steel_dk")], 14)
    # 沉積槽／樣本槽（實驗室中央）：2x2
    BIG("cryo_tank", 2, 2, [Cap((0, d / 2 + 2, 4), (0, d / 2 + 2, 22), 10.5, "glass"), Cap((0, d / 2 + 2, 0), (0, d / 2 + 2, 4), 12, "steel_dk"),
                            Cap((0, d / 2 + 2, 22), (0, d / 2 + 2, 25), 12, "steel_dk"), Ell((0, d / 2 + 2, 12), (4.6, 4, 7.4), "ice"),
                            Ell((-1, d / 2 + 2, 19.4), (2.6, 2.4, 2), "crystal"), box(9.6, d / 2 - 9.4, 1, 3, 2, 8, "steel_dk"),
                            box(9.6, d / 2 - 9.7, 5.4, 1.8, 0.3, 2.4, "screen")], 14)
    # 撞球桌大小的戰術桌、會議桌：3x2
    d = depth_for(2, 9, 6)
    BIG("meeting_table", 3, 2, legs(22, d, 8, "wood", 3) + [box(0, 0, 8, 22.5, d, 1.4, "wood"), box(-10, 4, 9.4, 4, 5, 0.3, "paper"),
                                box(4, 8, 9.4, 5, 6, 0.3, "paper"), box(13, 4, 9.4, 1.2, 1.2, 1.8, "enamel"), box(-2, d - 7, 9.4, 3.4, 4.6, 0.4, "black"),
                                box(-2, d - 6.6, 9.8, 2.6, 3.6, 0.2, "screen"), box(-16, d - 8, 9.4, 1.2, 1.2, 1.8, "enamel")], 6)
    BIG("mess_block", 2, 2, legs(14, d, 8, "steel_dk", 2) + [box(0, 0, 8, 14.5, d, 1.2, "benchtop"), box(-7, 3, 9.2, 3.2, 4.6, 0.4, "blue_metal"),
                             box(6, 5, 9.2, 3.2, 4.6, 0.4, "red_metal"), box(-5, d - 9, 9.2, 3.2, 4.6, 0.4, "blue_metal"), box(7, d - 7, 9.2, 1, 1, 2.2, "glass"),
                             box(0, d / 2, 9.2, 1.2, 1.2, 2.6, "hazard"), box(-6, 3.6, 9.6, 1.2, 1.4, 1.2, "enamel")], 6)
    print("big: ok")


# ── 放道具的容器（關著／打開）────────────────────────────────

def gen_stash():
    def pair(name, closed, opened, w=16, h=18):
        S(name, closed, h, w, "stash")
        S(name + "_open", opened, h, w, "stash")

    # 牆上的急救箱（白底紅十字）
    pair("medbox", [box(0, 2, 6, 5.5, 3, 9, "enamel"), box(0, 1.7, 9.6, 2.6, 0.3, 1.2, "red"), box(0, 1.7, 8.4, 0.9, 0.3, 3.6, "red"), box(4.4, 1.6, 10, 0.4, 0.3, 1.6, "chrome")],
         [box(0, 2, 6, 5.5, 3, 9, "enamel"), box(0, 1.8, 6.8, 4.8, 0.3, 7.4, "steel_dk"), box(0, 1.6, 10.4, 4.8, 0.3, 0.5, "enamel"),
          Box((-7.6, -0.4, 10.5), (0.4, 2.6, 4.5), "enamel", basis_along((0.5, -1, 0)))], 16, 20)
    # 藥品冷藏箱
    pair("cooler", [box(0, 1, 0, 5.6, 7, 6.5, "enamel"), box(0, 0.8, 6.5, 5.8, 7.4, 1.6, "blue_metal"), box(0, 0.5, 3, 2.4, 0.3, 1.6, "screen"),
                    Cap((-4.6, 4.4, 8.4), (4.6, 4.4, 8.4), 0.5, "steel_dk")],
         [box(0, 1, 0, 5.6, 7, 6.5, "enamel"), box(0, 1.6, 6, 4.8, 5.8, 0.6, "steel_dk"), box(0, 0.5, 3, 2.4, 0.3, 1.6, "black"),
          Box((0, 9.4, 9.5), (5.8, 0.8, 3.6), "blue_metal", basis_along((1, 0, 0), (0, 0.3, 1)))])
    # 彈藥箱（軍綠鐵盒）
    pair("ammo_box", [box(0, 1.5, 0, 5, 6, 5.5, "olive"), box(0, 1.3, 5.5, 5.2, 6.4, 1, "olive"), box(0, 1, 2.2, 3, 0.3, 1.4, "hazard"),
                      Cap((-2.6, 4.6, 7), (2.6, 4.6, 7), 0.4, "steel_dk"), box(5, 3, 3.4, 0.4, 1.4, 1.6, "brass")],
         [box(0, 1.5, 0, 5, 6, 5.5, "olive"), box(0, 2.1, 5, 4.4, 4.8, 0.6, "black"), box(0, 1, 2.2, 3, 0.3, 1.4, "hazard"),
          Box((0, 8.6, 8), (5.2, 0.6, 3.2), "olive", basis_along((1, 0, 0), (0, 0.35, 1)))], 16, 16)
    # 抽屜櫃（辦公室、宿舍、實驗室）
    pair("drawer", [box(0, 1, 0, 5.6, 7, 10, "cabinet")] + [box(0, 0.7, 1 + i * 3, 4.8, 0.3, 2.4, "steel_dk") for i in range(3)]
         + [box(0, 0.4, 1.8 + i * 3, 1.6, 0.3, 0.5, "chrome") for i in range(3)] + [box(-2, 3, 10, 2.4, 3, 0.4, "paper")],
         [box(0, 1, 0, 5.6, 7, 10, "cabinet")] + [box(0, 0.7, 1 + i * 3, 4.8, 0.3, 2.4, "steel_dk") for i in (0, 2)]
         + [box(0, -3, 3.6, 4.8, 4.4, 2.6, "steel_dk"), box(0, -2.6, 5.6, 4.2, 3.6, 0.5, "black"), box(-2, 3, 10, 2.4, 3, 0.4, "paper")], 16, 20)
    # 武器箱（長的硬殼箱）
    pair("weapon_case", [box(0, 1, 0, 7.2, 6, 3.6, "steel_dk"), box(0, 0.8, 3.6, 7.3, 6.4, 1, "steel_dk"), box(-4, 0.5, 2.6, 0.8, 0.3, 1.4, "chrome"),
                         box(4, 0.5, 2.6, 0.8, 0.3, 1.4, "chrome"), Cap((-1.6, 0.4, 1.6), (1.6, 0.4, 1.6), 0.4, "black"), box(0, 2.4, 4.6, 2.6, 2.4, 0.2, "hazard")],
         [box(0, 1, 0, 7.2, 6, 3.6, "steel_dk"), box(0, 1.6, 3.2, 6.6, 4.8, 0.5, "rubber"),
          Box((0, 8.4, 6), (7.3, 0.6, 3.2), "steel_dk", basis_along((1, 0, 0), (0, 0.35, 1)))], 16, 14)
    # 工具箱（紅色）
    pair("toolbox", [box(0, 1.5, 0, 5.4, 5.4, 4.6, "red_metal"), box(0, 1.3, 4.6, 5.6, 5.8, 1.2, "red_metal"), Cap((-2.4, 4.2, 6.6), (2.4, 4.2, 6.6), 0.45, "chrome"),
                     box(-3.4, 1.2, 3.4, 0.6, 0.3, 1.4, "chrome"), box(3.4, 1.2, 3.4, 0.6, 0.3, 1.4, "chrome")],
         [box(0, 1.5, 0, 5.4, 5.4, 4.6, "red_metal"), box(0, 2.1, 4.2, 4.8, 4.2, 0.5, "black"),
          Box((0, 8, 7), (5.6, 0.6, 2.8), "red_metal", basis_along((1, 0, 0), (0, 0.35, 1)))], 16, 14)
    # 行軍袋
    pair("duffel", [Cap((-4, 4, 3.2), (4, 4, 3.2), 3.4, "olive"), Cap((-1.6, 4, 6.8), (1.6, 4, 6.8), 0.5, "strap"), box(0, 0.4, 2.2, 0.5, 0.3, 2.6, "strap")],
         [Cap((-4, 4, 2.4), (4, 4, 2.4), 2.6, "olive"), box(0, 2.6, 3.8, 3.6, 2.8, 0.5, "black"), Cap((-4.4, 1, 0.8), (-1, 0, 0.6), 0.5, "strap")], 16, 12)
    # 化學品紙箱（酒精）／空瓶箱
    pair("chem_crate", [box(0, 1, 0, 5.4, 7, 6, "carton"), box(0, 0.7, 2, 2.6, 0.3, 2.6, "hazard")]
         + [Cap((x, y, 6), (x, y, 9), 1.1, "glass") for x in (-2.8, 0, 2.8) for y in (3, 6)]
         + [Cap((x, y, 9.2), (x, y, 10.2), 0.5, "enamel") for x in (-2.8, 0, 2.8) for y in (3, 6)],
         [box(0, 1, 0, 5.4, 7, 6, "carton"), box(0, 0.7, 2, 2.6, 0.3, 2.6, "hazard"), box(0, 1.6, 5.6, 4.6, 5.8, 0.5, "black")], 16, 18)
    pair("bottle_crate", [box(0, 1, 0, 5.6, 7, 5, "blue_metal")] + [Cap((x, y, 5), (x, y, 8.4), 1.1, "green_metal") for x in (-3, 0, 3) for y in (3, 6)],
         [box(0, 1, 0, 5.6, 7, 5, "blue_metal"), box(0, 1.6, 4.6, 4.8, 5.8, 0.5, "black")], 16, 16)
    # 背包（暖暖包、雜物）
    pair("backpack", [Ell((0, 4, 5), (4.4, 3.4, 5), "tarp"), box(0, 0.8, 2, 2.6, 0.5, 3, "steel_dk"), Cap((-2.6, 4, 10.4), (2.6, 4, 10.4), 0.5, "strap"),
                      box(0, 0.5, 6.6, 3.4, 0.3, 0.6, "hazard")],
         [Ell((0, 4, 3.4), (4.6, 3.6, 3.4), "tarp"), box(0, 2.4, 5.6, 3, 2.6, 0.5, "black"), Cap((-4.6, 1, 0.8), (-1.4, 0, 0.5), 0.5, "strap")], 16, 16)
    # 牆上的消防斧箱
    pair("axe_case", [box(0, 2, 5, 6, 2.6, 12, "red_metal"), box(0, 1.7, 6, 5, 0.3, 10, "glass"), Cap((-2, 1.4, 7), (2.4, 1.4, 15), 0.5, "wood"),
                      box(2.6, 1.3, 13.6, 1.6, 0.3, 2, "steel")],
         [box(0, 2, 5, 6, 2.6, 12, "red_metal"), box(0, 1.7, 6, 5, 0.3, 10, "black")], 16, 22)
    # 物品圖示：消音器（物品欄、手機物品 App 用）
    _save("props", "suppressor", 16, 12, render([Cap((-5, 3, 3), (4.5, 3, 3), 2.2, "steel_dk"), Cap((4.5, 3, 3), (6.5, 3, 3), 1.4, "gunmetal"),
                                                 Cap((-5.6, 3, 3), (-5.2, 3, 3), 1.2, "black")], 16, 12, anchor=(8, 10)))
    print("stash: ok")


# ── 地板、牆的貼圖 ────────────────────────────────────────────

def gen_tiles():
    P = lambda *cs: [hexc(c) for c in cs]  # noqa: E731

    def save(name, px, w=64, h=64):
        _save("tiles", name, w, h, px)

    # 實驗室：淺色塑膠地磚，每 16px 一塊，交錯深淺
    pal = P("#2c3438", "#364046", "#424e55", "#4f5c64", "#5f6d76")
    save("floor_tile", texture(64, 64, pal, 21, 0.55, 0.45, lambda x, y: x % 16 == 0 or y % 16 == 0,
                               lambda x, y, v: v + (0.1 if ((x // 16) + (y // 16)) % 2 == 0 else -0.04) + (0.12 if (x % 16 == 1 or y % 16 == 1) else 0)))
    # 辦公室：地毯（細的編織紋）
    pal = P("#1c2430", "#243042", "#2c3b50", "#34465e", "#3e526c")
    save("floor_carpet", texture(64, 64, pal, 22, 0.5, 0.5, None, lambda x, y, v: v + (0.1 if (x + y) % 2 == 0 else -0.06) + (0.08 if y % 8 == 0 else 0)))
    # 宿舍、餐廳：亞麻地板（大塊、暖色）
    pal = P("#2a2a26", "#38372f", "#474539", "#575444", "#676450")
    save("floor_lino", texture(64, 64, pal, 23, 0.5, 0.55, lambda x, y: x % 32 == 0 or y % 32 == 0,
                               lambda x, y, v: v + (0.07 if ((x // 32) + (y // 32)) % 2 == 0 else -0.03)))
    # 木頭地板（小屋、船艙）：橫的木板，接縫錯開
    pal = P("#2a1d14", "#3a281b", "#4b3423", "#5d412c", "#6f4f36")
    save("floor_wood", texture(64, 64, pal, 24, 0.5, 0.7, lambda x, y: y % 8 == 0 or (x + (y // 8) * 23) % 32 == 0,
                               lambda x, y, v: v + 0.07 * math.sin(x * 0.7 + (y // 8) * 2.1) + (0.1 if y % 8 == 1 else 0)))
    # 甲板：直的柚木條、黑色填縫
    pal = P("#3a2c1e", "#4e3c28", "#644e34", "#7a6242", "#907650")
    save("floor_deck", texture(64, 64, pal, 25, 0.5, 0.6, lambda x, y: x % 6 == 0 or (y + (x // 6) * 17) % 48 == 0,
                               lambda x, y, v: v + 0.05 * math.sin(y * 0.5 + (x // 6))))
    # 鋼板（機房、船艙、鑽井）：防滑花紋
    pal = P("#181c20", "#22272d", "#2d333a", "#394048", "#474f58")

    def tread(x, y, v):
        a = (x % 8, y % 8)
        if a in ((1, 2), (2, 3), (3, 4), (5, 6), (6, 5), (7, 4)):
            return v + 0.22
        return v
    save("floor_metal", texture(64, 64, pal, 26, 0.5, 0.5, lambda x, y: x % 32 == 0 or y % 32 == 0, tread))
    # 水泥地（碼頭、倉庫、停機坪）：大塊、有油漬和裂縫
    pal = P("#22252a", "#2c3036", "#373b42", "#42474f", "#4e535c")
    rnd = random.Random(3)
    stains = [(rnd.randrange(64), rnd.randrange(64), rnd.uniform(3, 7)) for _ in range(5)]

    def stain(x, y, v):
        for sx, sy, r in stains:
            dx, dy = min(abs(x - sx), 64 - abs(x - sx)), min(abs(y - sy), 64 - abs(y - sy))
            if dx * dx + dy * dy < r * r:
                return v - 0.16
        return v
    save("floor_dock", texture(64, 64, pal, 27, 0.55, 0.8, lambda x, y: x % 64 == 0 or y % 64 == 0, stain))
    # 柏油（戶外車道）
    pal = P("#17181b", "#1e2023", "#26282c", "#2f3236", "#3a3d42")
    save("floor_asphalt", texture(64, 64, pal, 28, 0.5, 1.1))
    # 岩石地（洞穴）
    pal = P("#1a1e24", "#252b33", "#313943", "#3e4853", "#4d5864")
    save("floor_rock", texture(64, 64, pal, 29, 0.5, 1.5, None, lambda x, y, v: v - (0.25 if (x * 7 + y * 13) % 53 == 0 else 0)))
    # 冰面
    pal = P("#2c4654", "#3a5a6c", "#4a7084", "#5e889c", "#7aa4b6")
    save("floor_ice", texture(64, 64, pal, 30, 0.5, 0.9, None, lambda x, y, v: v + (0.25 if abs((x - y * 0.6) % 37) < 0.8 else 0)))
    # 屋頂（從戶外看沒進去的建築）：浪板＋積雪
    pal = P("#14171c", "#1c2027", "#262b33", "#31373f", "#3d444d")
    save("roof_metal", texture(64, 64, pal, 31, 0.5, 0.4, lambda x, y: y % 64 == 0, lambda x, y, v: v + (0.14 if x % 4 == 0 else (-0.1 if x % 4 == 2 else 0))))
    pal = P("#3e4654", "#4b5464", "#586374", "#667284", "#768294")
    save("roof_snow", texture(64, 64, pal, 32, 0.55, 1.2))
    # 船體鋼板牆頂（白漆、鉚釘）
    pal = P("#3a4048", "#4a525c", "#5c6570", "#707a86", "#86909c")
    save("wall_ship", texture(32, 32, pal, 33, 0.55, 0.5, lambda x, y: y % 16 == 0 or x % 32 == 0, lambda x, y, v: v + (0.2 if (x % 8 == 4 and y % 16 == 8) else 0)), 32, 32)
    # 預鑄板牆頂（研究站）：比水泥乾淨
    pal = P("#2e343c", "#3a424c", "#48525c", "#58626e", "#6a7480")
    save("wall_panel", texture(32, 32, pal, 34, 0.55, 0.5, lambda x, y: x % 16 == 0 or y % 32 == 0, lambda x, y, v: v + (0.16 if x % 16 == 1 else 0)), 32, 32)
    # 木牆頂（小屋）
    pal = P("#2a1e16", "#3a2a1e", "#4c3828", "#5e4632", "#72563e")
    save("wall_wood", texture(32, 32, pal, 35, 0.5, 0.7, lambda x, y: y % 8 == 0, lambda x, y, v: v + 0.06 * math.sin(x * 0.9 + (y // 8) * 3)), 32, 32)
    # 岩壁頂
    pal = P("#14181e", "#1d232b", "#28303a", "#343e4a", "#424e5c")
    save("wall_rock", texture(32, 32, pal, 36, 0.5, 1.7), 32, 32)
    print("tiles: ok")


# ── 牆上的東西（畫在牆面上；透明底）────────────────────────────

def gen_wall():
    _ = (0, 0, 0, 0)

    def wall(name, w, h, fn):
        _save("decor", name, w, h, [fn(x, y) or _ for y in range(h) for x in range(w)])

    K = (16, 17, 20, 255)
    # 滅火器箱、緊急出口、時鐘、配線槽、窗型告示、布告欄、管線、舷窗、救生圈、相框、地圖、掛鉤上的外套
    wall("exit_sign", 11, 5, lambda x, y: K if x in (0, 10) or y in (0, 4) else ((70, 220, 130, 255) if (x + y) % 3 else (20, 90, 50, 255)))
    wall("clock", 7, 7, lambda x, y: None if (x - 3) ** 2 + (y - 3) ** 2 > 12 else (K if (x - 3) ** 2 + (y - 3) ** 2 > 7 else
         ((30, 30, 34, 255) if (x == 3 and y <= 3) or (y == 3 and 3 <= x <= 4) else (226, 222, 206, 255))))
    wall("notice", 10, 9, lambda x, y: (60, 44, 28, 255) if x in (0, 9) or y in (0, 8) else
         ((232, 228, 210, 255) if (1 < x < 5 and 1 < y < 5) else ((220, 190, 90, 255) if (5 < x < 9 and 2 < y < 7) else
          ((200, 80, 60, 255) if (1 < x < 4 and y == 6) else (128, 96, 62, 255)))))
    wall("conduit", 16, 3, lambda x, y: [(50, 54, 60, 255), (120, 126, 134, 255), (36, 40, 46, 255)][y] if x % 16 not in (7, 8) else (26, 28, 32, 255))
    wall("porthole", 9, 9, lambda x, y: None if (x - 4) ** 2 + (y - 4) ** 2 > 18 else ((150, 124, 60, 255) if (x - 4) ** 2 + (y - 4) ** 2 > 9 else
         ((120, 170, 200, 255) if x + y < 7 else (30, 60, 90, 255))))
    wall("life_ring", 9, 9, lambda x, y: None if not (5 < (x - 4) ** 2 + (y - 4) ** 2 <= 18) else ((220, 70, 40, 255) if (x < 3 or x > 5) == (y < 3 or y > 5) else (236, 232, 220, 255)))
    wall("frame", 9, 8, lambda x, y: (96, 72, 40, 255) if x in (0, 8) or y in (0, 7) else ((70, 100, 120, 255) if y < 4 else (50, 70, 60, 255)))
    wall("wall_map", 13, 9, lambda x, y: K if x in (0, 12) or y in (0, 8) else ((200, 196, 170, 255) if ((x * 5 + y * 3) % 7) else
         ((90, 130, 150, 255) if x < 6 else (200, 80, 60, 255))))
    wall("coat_hooks", 12, 10, lambda x, y: (70, 74, 80, 255) if y == 0 else ((190, 96, 40, 255) if (1 <= x <= 4 and 1 <= y <= 8) else
         ((60, 70, 90, 255) if (7 <= x <= 10 and 1 <= y <= 6) else None)))
    wall("fuse_panel", 8, 10, lambda x, y: K if x in (0, 7) or y in (0, 9) else ((90, 96, 104, 255) if y % 3 else
         ((230, 180, 40, 255) if x % 2 else (40, 44, 50, 255))))
    wall("hazard_plate", 12, 5, lambda x, y: K if x in (0, 11) or y in (0, 4) else ((224, 178, 30, 255) if ((x + y) // 2) % 2 == 0 else (24, 24, 24, 255)))
    wall("speaker", 7, 7, lambda x, y: K if x in (0, 6) or y in (0, 6) else ((60, 64, 72, 255) if (x + y) % 2 else (110, 116, 126, 255)))
    wall("cctv", 7, 5, lambda x, y: (40, 44, 50, 255) if (y < 3 and x < 6) else ((200, 40, 30, 255) if (x == 5 and y == 1) else
         ((70, 74, 82, 255) if (y >= 3 and x in (2, 3)) else None)))
    wall("valve", 8, 8, lambda x, y: (160, 40, 30, 255) if 5 < (x - 3.5) ** 2 + (y - 3.5) ** 2 < 13 or x in (3, 4) and 1 < y < 6 or y in (3, 4) and 1 < x < 6 else None)
    wall("window_dark", 12, 8, lambda x, y: K if x in (0, 11) or y in (0, 7) or x == 6 else ((40, 66, 92, 255) if x + y < 9 else (22, 38, 58, 255)))
    wall("flag", 10, 8, lambda x, y: (150, 30, 30, 255) if y < 3 else ((226, 222, 206, 255) if y < 5 else (40, 60, 100, 255)))
    wall("gauge", 6, 6, lambda x, y: None if (x - 2.5) ** 2 + (y - 2.5) ** 2 > 9 else (K if (x - 2.5) ** 2 + (y - 2.5) ** 2 > 5 else
         ((200, 50, 40, 255) if x == y else (226, 222, 206, 255))))
    wall("stencil", 12, 6, lambda x, y: (222, 218, 200, 150) if (y in (1, 4) and 1 <= x <= 10) or (x in (1, 5, 6, 10) and 1 <= y <= 4) else None)
    wall("mirror", 9, 10, lambda x, y: (150, 156, 166, 255) if x in (0, 8) or y in (0, 9) else ((150, 190, 210, 255) if x + y < 8 else (70, 100, 124, 255)))
    wall("curtain", 14, 12, lambda x, y: (110, 26, 34, 255) if x % 4 < 2 else (150, 40, 48, 255))
    print("wall: ok")


def main():
    which = sys.argv[1:] or ["set", "big", "stash", "tiles", "wall"]
    for w in which:
        {"set": gen_set, "big": gen_big, "stash": gen_stash, "tiles": gen_tiles, "wall": gen_wall}[w]()


if __name__ == "__main__":
    main()
