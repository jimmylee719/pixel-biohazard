#!/usr/bin/env python3
"""場景美術：家具、設備、戶外的大型物件、地板貼圖、放道具的容器。
和 gen_pixel_art.py 用同一台 3/4 攝影機和調色盤（匯入它的算圖器），所以畫風一致。

用法：python3 tools/gen_scene_art.py [set|big|landmark|stash|tiles|wall|decal] [--sheet 總覽.png]   不加參數 = 全部
      landmark = 地標級的大型物件（反應槽、渦輪機、鑽塔……每棟建築的主廳用）；decal = 地板痕跡、光暈
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
    "fluid": ["#0a262c", "#124a52", "#1c747a", "#46b4ac"],       # 樣本槽裡的菌液
    "felt": ["#0c2a1c", "#14482e", "#1f6a42", "#34905c"],        # 撞球桌的絨布
    "concrete": ["#2c2f34", "#4c5058", "#74787f", "#a2a6ac"],    # 柱子、基座
}
g.MATS.update({k: [hexc(c) for c in v] for k, v in NEW_MATS.items()})
g.EMISSIVE.update({"screen", "amber"})


SHEET = []  # (名稱, 寬, 高, 像素)：--sheet 用


def _save(folder, name, w, h, px):
    path = os.path.join(OUT, folder)
    os.makedirs(path, exist_ok=True)
    write_png(os.path.join(path, name + ".png"), w, h, px)
    SHEET.append((folder + "/" + name, w, h, px))


def write_sheet(path, scale=3, cols_px=1500, bg=(58, 62, 70, 255), only=None):
    """開發用：把這次產生的圖排成一張總覽（放大 scale 倍，灰底），方便檢查。"""
    items = [it for it in SHEET if only is None or only(it[0])]
    x = y = row_h = 0
    place = []
    for name, w, h, px in items:
        if x + w * scale + 6 > cols_px:
            x, y, row_h = 0, y + row_h + 6, 0
        place.append((x, y, w, h, px))
        x += w * scale + 6
        row_h = max(row_h, h * scale)
    W, H = cols_px, y + row_h + 6
    out = [bg] * (W * H)
    for x0, y0, w, h, px in place:
        for j in range(h):
            for i in range(w):
                c = px[j * w + i]
                if c[3] == 0:
                    continue
                if c[3] < 255:
                    k = c[3] / 255.0
                    c = (int(bg[0] + (c[0] - bg[0]) * k), int(bg[1] + (c[1] - bg[1]) * k), int(bg[2] + (c[2] - bg[2]) * k), 255)
                for dy in range(scale):
                    base = (y0 + j * scale + dy) * W + x0 + i * scale
                    for dx in range(scale):
                        out[base + dx] = c
    write_png(path, W, H, out)


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


# ── 地標級的大型物件（每棟建築主廳的主角）─────────────────────
# 名稱和格數是和地圖規格（tools/map_specs）的約定，不要改。

class Cyl:
    """真的圓柱（兩端是平的，不像 Cap 是圓頭）：a 到 b、半徑 r。"""

    def __init__(self, a, b, r, mat):
        self.a, self.bp, self.r, self.mat = a, b, r, mat

    def bound(self):
        ba = g.sub(self.bp, self.a)
        return g.mul(g.add(self.a, self.bp), 0.5), math.sqrt(g.dot(ba, ba)) * 0.5 + self.r

    def hit(self, ro, rd):
        ba = g.sub(self.bp, self.a)
        oc = g.sub(ro, self.a)
        baba, bard, baoc = g.dot(ba, ba), g.dot(ba, rd), g.dot(ba, oc)
        k2 = baba - bard * bard
        if abs(k2) < 1e-9:
            return None
        k1 = baba * g.dot(oc, rd) - baoc * bard
        k0 = baba * g.dot(oc, oc) - baoc * baoc - self.r * self.r * baba
        h = k1 * k1 - k2 * k0
        if h < 0:
            return None
        h = math.sqrt(h)
        t = (-k1 - h) / k2
        y = baoc + t * bard
        if 0 < y < baba:
            n = g.mul(g.sub(g.add(oc, g.mul(rd, t)), g.mul(ba, y / baba)), 1.0 / self.r)
            return t, n
        if abs(bard) < 1e-9:
            return None
        t = ((0.0 if y < 0 else baba) - baoc) / bard
        if abs(k1 + k2 * t) < h:
            return t, g.mul(ba, (1.0 if y > 0 else -1.0) / math.sqrt(baba))
        return None


class Tri:
    """三角形面（帳篷的斜面、琴蓋）：兩面都看得到，法線朝鏡頭那一側。"""

    def __init__(self, a, b, c, mat):
        self.a, self.b, self.c, self.mat = a, b, c, mat
        n = g.norm(g.cross(g.sub(b, a), g.sub(c, a)))
        self.n = n if n[2] > 0 or (n[2] == 0 and n[1] < 0) else g.mul(n, -1.0)

    def bound(self):
        cen = g.mul(g.add(g.add(self.a, self.b), self.c), 1 / 3.0)
        return cen, max(math.sqrt(g.dot(g.sub(q, cen), g.sub(q, cen))) for q in (self.a, self.b, self.c))

    def hit(self, ro, rd):
        e1, e2 = g.sub(self.b, self.a), g.sub(self.c, self.a)
        h = g.cross(rd, e2)
        det = g.dot(e1, h)
        if abs(det) < 1e-9:
            return None
        f = 1.0 / det
        s_ = g.sub(ro, self.a)
        u = f * g.dot(s_, h)
        if u < -1e-6 or u > 1 + 1e-6:
            return None
        q = g.cross(s_, e1)
        v = f * g.dot(rd, q)
        if v < -1e-6 or u + v > 1 + 1e-6:
            return None
        return f * g.dot(e2, q), self.n


def quad(a, b, c, d_, mat):
    """四邊形（a-b-c-d 依序繞一圈）"""
    return [Tri(a, b, c, mat), Tri(a, c, d_, mat)]


def vc(x, y, z0, z1, r, mat):
    """直立的圓柱"""
    return Cyl((x, y, z0), (x, y, z1), r, mat)


def xc(x0, x1, y, z, r, mat):
    """橫躺、沿 x 的圓柱"""
    return Cyl((x0, y, z), (x1, y, z), r, mat)


def yc(x, y0, y1, z, r, mat):
    """沿 y（朝鏡頭）的圓柱：圓盤面對玩家（儀表、盤帶、輪子）"""
    return Cyl((x, y0, z), (x, y1, z), r, mat)


def stripes(x0, x1, y, z0, hgt, a="hazard", b="black", step=3.0):
    """貼在正面的警示條紋（黃黑相間）"""
    out, x, i = [], x0, 0
    while x < x1 - 0.01:
        w = min(step, x1 - x)
        out.append(Box((x + w / 2.0, y - 0.15, z0 + hgt / 2.0), (w / 2.0, 0.2, hgt / 2.0), a if i % 2 == 0 else b))
        x += step
        i += 1
    return out


def rbox(cx, cy, z0, hl, hw, hgt, ang, mat):
    """繞 z 軸轉 ang 度的箱子（弧形櫃台的兩翼）"""
    c, s_ = math.cos(math.radians(ang)), math.sin(math.radians(ang))
    return Box((cx, cy, z0 + hgt / 2.0), (hl, hw, hgt / 2.0), mat, ((c, s_, 0.0), (-s_, c, 0.0), (0.0, 0.0, 1.0)))


def LM(name, wc, hc, height, fn):
    """地標：佔 wc x hc 格、最高 height。fn(hx, d) 回傳形狀：x 在 ±hx 之間、y 從 0（前緣）到 d（後緣）。"""
    d = (hc * 16 - 2) / SY
    BIG(name, wc, hc, fn(wc * 8 - 1.0, d), int(height * SZ) + 4)


def lm_reactor(hx, d):
    cy = d / 2
    p = [box(0, 3, 0, hx - 0.5, d - 6, 3, "steel_dk")] + stripes(-hx + 0.5, hx - 0.5, 3, 0.5, 2.0)
    p += [vc(0, cy, 3, 6, 19.5, "steel"), vc(0, cy, 6, 30, 16.5, "enamel"),
          vc(0, cy, 10.5, 12, 17.2, "steel_dk"), vc(0, cy, 24, 25.5, 17.2, "steel_dk"),
          Ell((0, cy, 30), (16.5, 16.5, 7.5), "steel"), vc(0, cy, 35, 42, 5, "steel_dk"), vc(0, cy, 42, 43.5, 6.4, "steel"),
          Ell((0, cy, 45), (1.8, 1.8, 1.8), "alarm"),
          # 觀察窗：裡面的菌液發光
          box(0, cy - 17.3, 13.5, 6, 0.8, 9, "steel_dk"), box(0, cy - 17.6, 14.6, 4.6, 0.4, 6.8, "crystal"),
          box(0, cy - 17.8, 17.6, 4.6, 0.3, 0.7, "steel_dk"), box(-1.6, cy - 17.8, 14.6, 0.35, 0.3, 6.8, "steel_dk"),
          # 兩側的管路（銅管、冷卻水）
          xc(-21, -15, cy, 22, 2.0, "copper"), vc(-20.6, cy, 3, 22, 2.0, "copper"), vc(-20.6, cy, 11, 12.4, 2.8, "steel_dk"),
          xc(15, 21, cy + 4, 16, 2.2, "blue_metal"), vc(20.6, cy + 4, 3, 16, 2.2, "blue_metal"), vc(20.6, cy + 4, 8, 9.4, 3.0, "steel_dk"),
          Cap((4, cy - 2, 38), (12, cy - 10, 33), 1.2, "rubber"), Cap((12, cy - 10, 33), (15, cy - 14, 6), 1.2, "rubber"),
          # 控制箱、警示牌、結霜
          box(-15.5, 5, 3, 4.5, 4, 10, "steel_dk"), box(-15.5, 4.7, 8, 3.3, 0.3, 3.8, "screen"),
          box(-17.5, 4.7, 5, 0.7, 0.3, 1.0, "red"), box(-15, 4.7, 5, 0.7, 0.3, 1.0, "amber"), box(-12.8, 4.7, 5, 0.7, 0.3, 1.0, "enamel"),
          box(9.5, cy - 16.4, 15, 2.4, 0.4, 2.4, "hazard"), box(9.5, cy - 16.7, 15.8, 0.8, 0.3, 0.8, "black"),
          Ell((11, 7, 3.3), (6, 3, 1.3), "frost"), Ell((-3, 6, 3.2), (4, 2.2, 1.0), "frost"), Ell((-7, cy - 12, 31.5), (4, 3, 1.2), "frost")]
    return p


def lm_turbine(hx, d):
    cy = d / 2
    p = [box(0, 4, 0, hx - 0.5, d - 8, 3, "steel_dk")] + stripes(-hx + 0.5, hx - 0.5, 4, 0.5, 2.0)
    p += [xc(-25, 5, cy, 14.5, 11, "green_metal")]
    p += [xc(x - 0.7, x + 0.7, cy, 14.5, 12.3, "steel_dk") for x in (-24.6, -10, 4.6)]
    p += [xc(5, 22, cy, 12.5, 8.5, "steel"), xc(22, 28, cy, 12.5, 5.5, "red_metal"), xc(28, 29.4, cy, 12.5, 3, "steel_dk")]
    p += [box(x, cy - 8.9, 9.5, 0.5, 0.5, 6, "steel_dk") for x in (8, 10.5, 13, 15.5, 18)]
    p += [vc(-17, cy, 14, 34, 4.2, "steel"), vc(-17, cy, 26, 27.4, 5.4, "steel_dk"), Cap((-17, cy, 34), (-17, cy + 14, 34), 4.2, "steel"),
          box(-17, cy - 11.4, 11.5, 3.2, 0.4, 2.6, "hazard"), box(-17, cy - 11.7, 12.3, 2, 0.3, 0.9, "black"),
          vc(-3, cy, 25, 29, 1.0, "steel"), vc(-3, cy, 29, 29.8, 3, "red_metal"),
          # 儀表盤
          box(12, 1.5, 3, 6.5, 3, 9.5, "steel_dk"), yc(8.5, 0.9, 1.4, 9.4, 1.8, "enamel"), yc(13, 0.9, 1.4, 9.4, 1.8, "enamel"),
          box(8.5, 0.6, 9.2, 0.3, 0.3, 1.2, "red"), box(13.3, 0.6, 9.6, 0.9, 0.3, 0.3, "red"),
          box(16.6, 1.2, 9, 0.8, 0.3, 1.0, "amber"), box(16.6, 1.2, 6.5, 0.8, 0.3, 1.0, "screen"), box(12, 1.2, 4.2, 5, 0.3, 1.2, "paper"),
          Cap((-8, cy - 6, 3), (-8, cy - 10, 5), 1.2, "copper"), xc(-8, 5, cy - 10.5, 5, 1.2, "copper")]
    return p


def lm_drill_rig(hx, d):
    cy = d / 2
    p = [box(0, 6, 0, 21.5, d - 12, 4, "steel_dk"), box(0, 7, 4, 20.5, d - 14, 0.6, "steel")] + stripes(-21.5, 21.5, 6, 0.6, 2.6)
    p += [vc(0, cy, 4.6, 7.4, 6.5, "rust"), vc(0, cy, 7.4, 8.2, 7.5, "hazard"), vc(0, cy, 8.2, 8.5, 3, "black")]
    top = 60.0
    feet = [(-17, 12), (17, 12), (-17, d - 12), (17, d - 12)]
    tops = [(-4, cy - 4), (4, cy - 4), (-4, cy + 4), (4, cy + 4)]

    def leg(i, k):
        return (feet[i][0] + (tops[i][0] - feet[i][0]) * k, feet[i][1] + (tops[i][1] - feet[i][1]) * k, 4.6 + (top - 4.6) * k)
    for i in range(4):
        p.append(Cap(leg(i, 0), leg(i, 1), 1.2, "steel"))
    for k0, k1 in ((0.0, 0.3), (0.3, 0.56), (0.56, 0.78), (0.78, 0.96)):
        for a, b in ((0, 1), (2, 3), (0, 2), (1, 3)):
            p.append(Cap(leg(a, k1), leg(b, k1), 0.6, "steel_dk"))
        p.append(Cap(leg(0, k0), leg(1, k1), 0.5, "steel_dk"))
        p.append(Cap(leg(1, k0), leg(0, k1), 0.5, "steel_dk"))
    p += [box(0, cy - 6, top, 6.5, 12, 3, "hazard"), Ell((0, cy, top + 4.2), (1.5, 1.5, 1.5), "alarm"),
          vc(0, cy, 8.5, top, 1.3, "chrome"), box(0, cy - 3, 36, 3.2, 6, 7, "orange"), vc(0, cy, 43, top, 0.5, "steel_dk"),
          # 馬達、絞盤、控制台
          box(-12, cy + 10, 4.6, 5.5, 11, 9, "orange"), box(-12, cy + 9.7, 7, 4, 0.3, 4, "vent"), vc(-12, cy + 16, 13.6, 19, 1.2, "steel_dk"),
          xc(7, 17, cy + 16, 9.5, 4.2, "rust"), xc(6.4, 7.2, cy + 16, 9.5, 5.6, "steel"), xc(16.8, 17.6, cy + 16, 9.5, 5.6, "steel"),
          box(-15, 9, 4.6, 3, 3, 8.5, "steel_dk"), box(-15, 8.7, 9.6, 2.2, 0.3, 2.6, "screen"), box(-15.8, 8.7, 7, 0.6, 0.3, 0.9, "red"),
          # 取出來的冰芯
          box(12.5, 9, 4.6, 7, 7, 1.2, "steel_dk"), xc(6.5, 18.5, 10.6, 7, 1.3, "ice"), xc(6.5, 17, 13.6, 7, 1.3, "ice"),
          Ell((-17, d - 14, 5), (4, 3, 1.3), "snow"), Ell((16, 9, 4.7), (3, 2, 0.8), "snow")]
    return p


def lm_snow_crawler(hx, d):
    cy = d / 2
    p = []
    for y in (8.0, d - 9.0):
        p += [box(0, y - 4, 0.6, 24, 8, 6.6, "rubber"), yc(-24, y - 4, y + 4, 3.9, 3.3, "rubber"), yc(24, y - 4, y + 4, 3.9, 3.3, "rubber")]
    p += [yc(x, 3.4, 4.0, 3.9, 2.3, "steel_dk") for x in (-22, -13.2, -4.4, 4.4, 13.2, 22)]
    p += [yc(x, 3.1, 3.5, 3.9, 0.9, "chrome") for x in (-22, -13.2, -4.4, 4.4, 13.2, 22)]
    p += [box(0, 3.7, 6.6, 24, 0.3, 0.7, "steel_dk"),
          box(1, 7, 6.5, 27.5, d - 15, 8, "orange"), box(1, 6.7, 7.2, 27.5, 0.3, 1.4, "black"),
          # 駕駛艙（車頭朝左）
          box(-14.5, 7.5, 14.5, 11.5, d - 16, 9.5, "orange"), box(-14.5, 7, 24, 12, d - 15, 1.2, "orange"), box(-14.5, 12, 25.2, 5, d - 26, 0.6, "enamel"), box(-14.5, 6.7, 24, 12, 0.3, 1.2, "black"),
          box(-15.5, 7.2, 17.5, 9, 0.3, 5, "visor"), box(-15.5, 7.0, 17.5, 0.3, 0.3, 5, "black"), box(-6, 7.2, 15, 0.25, 0.3, 8.6, "black"),
          box(-26.2, 9.5, 17.5, 0.2, d - 20, 5, "visor"), box(-27.6, 9, 9, 0.2, 2.2, 1.6, "amber"), box(-27.6, d - 12.5, 9, 0.2, 2.2, 1.6, "amber"),
          box(-21, 9, 25.2, 1.2, 1.4, 1.5, "amber"), box(-21, d - 12, 25.2, 1.2, 1.4, 1.5, "amber"),
          Cap((-5, d - 11, 25), (-3.5, d - 11, 35), 0.3, "steel"),
          # 貨斗
          box(13.5, 7.5, 14.5, 14.5, d - 16, 1, "steel_dk"), box(13.5, 7.5, 15.5, 14.5, 0.8, 3.2, "orange"),
          box(27.4, 7.5, 15.5, 0.6, d - 16, 3.2, "orange"), box(13.5, d - 9.3, 15.5, 14.5, 0.8, 3.2, "orange"),
          box(7, 11, 15.5, 5, 11, 6, "carton"), box(7, 10.7, 18, 2.4, 0.3, 1.6, "paper"), box(18.5, 12, 15.5, 5, 9, 4.6, "olive"),
          vc(21, cy + 9, 15.5, 23.5, 3.2, "red_metal"), vc(21, cy + 9, 23.5, 24.2, 2.4, "steel_dk"),
          box(1.5, 6.6, 9.5, 5, 0.3, 3, "enamel"), box(1.5, 6.4, 10.4, 3.6, 0.3, 0.5, "black"), box(1.5, 6.4, 11.6, 2.4, 0.3, 0.5, "black"),
          Ell((-8, d - 12, 25.4), (4.5, 3, 0.9), "snow"), Ell((12, cy - 2, 21.6), (4, 3, 0.8), "snow")]
    return p


def lm_crane(hx, d):
    cy = d / 2
    p = [box(0, 8, 0, 13.5, d - 16, 4, "concrete")] + stripes(-13.5, 13.5, 8, 0.6, 2.8)
    p += [box(0, 14, 4, 8, d - 28, 8, "hazard"), box(0, 13.7, 6.5, 5, 0.3, 3.4, "vent"), vc(0, cy, 12, 14.4, 8.8, "steel_dk"),
          vc(0, cy, 14.4, 46, 4.2, "hazard"), vc(0, cy, 21, 22.6, 4.6, "black"), vc(0, cy, 36, 37.6, 4.6, "black"),
          # 駕駛室
          box(6.5, cy - 7, 28, 6, 11, 10, "hazard"), box(6.5, cy - 7.3, 31.5, 4.6, 0.3, 5, "visor"), box(6.5, cy - 7.4, 28, 6, 0.4, 1.2, "black"),
          box(6.5, cy - 7.5, 38, 6.4, 12, 1, "steel_dk"),
          # 吊臂、鋼索、吊鉤
          Cap((0, cy, 46), (-12.5, cy - 8, 70), 1.7, "hazard"), Cap((0, cy, 46), (-12.5, cy - 4, 70), 0.8, "steel_dk"),
          Cap((0, cy, 52), (10, cy + 2, 39), 0.6, "steel_dk"), yc(-12.5, cy - 9.4, cy - 6.6, 70, 1.8, "steel_dk"),
          vc(-12.5, cy - 8, 33, 69, 0.35, "steel_dk"), box(-12.5, cy - 9.3, 27, 1.8, 2.6, 6, "red_metal"),
          Cap((-12.5, cy - 8, 27), (-11.4, cy - 8, 23.6), 0.6, "steel"),
          box(8.5, cy + 5, 14.4, 5, 7, 9, "steel_dk"),
          # 爬梯
          box(-2.4, cy - 4.9, 14.4, 0.3, 0.3, 14, "steel"), box(-0.2, cy - 4.9, 14.4, 0.3, 0.3, 14, "steel")]
    p += [box(-1.3, cy - 5.0, 16 + i * 3, 1.2, 0.3, 0.3, "steel") for i in range(4)]
    return p


def lm_specimen_tank(hx, d):
    cy = d / 2
    f = cy - 11.6
    p = [vc(0, cy, 0, 5, 13.6, "steel_dk"), vc(0, cy, 5, 6.2, 12.6, "chrome"), vc(0, cy, 6.2, 31, 11.5, "fluid"),
         # 泡在菌液裡的東西：蜷著的人形，身上長出結晶
         Ell((0.3, f, 17), (3.3, 1.0, 6.2), "pale"), Ell((0.8, f - 0.1, 25.2), (2.4, 1.0, 2.6), "pale"),
         Cap((-2.6, f, 21), (-4.8, f + 0.4, 13.5), 0.9, "pale"), Cap((2.8, f, 21), (4.0, f + 0.3, 15.5), 0.9, "pale"),
         Cap((-0.8, f, 11.5), (-2.4, f + 0.2, 7.6), 1.1, "pale"), Cap((1.6, f, 11.5), (2.0, f + 0.2, 7.4), 1.1, "pale"),
         Cap((1.4, f - 0.5, 22), (4.6, f - 0.2, 26.6), 0.55, "crystal"), Cap((-1.2, f - 0.5, 20), (-4.4, f - 0.2, 24.4), 0.55, "crystal"),
         Cap((0.2, f - 0.5, 26.5), (-0.6, f - 0.3, 29.6), 0.5, "crystal"), Ell((0.9, f - 0.9, 25.4), (0.7, 0.4, 0.5), "black"),
         Ell((-6, cy - 10, 12), (0.6, 0.5, 0.6), "crystal"), Ell((5.5, cy - 10.4, 27), (0.5, 0.5, 0.5), "crystal"), Ell((6.6, cy - 9.6, 9.5), (0.5, 0.5, 0.5), "crystal"),
         # 玻璃的反光
         box(-8.4, cy - 8.4, 8.5, 0.5, 0.3, 20, "frost"), box(-6.8, cy - 9.8, 22, 0.4, 0.3, 6.5, "frost"),
         # 頂蓋、管線、儀表
         vc(0, cy, 31, 36, 13.2, "steel_dk"), vc(0, cy, 36, 37.2, 9, "steel"), vc(-4, cy + 2, 37.2, 40, 1.6, "steel_dk"),
         Cap((5, cy, 37), (12.5, cy + 7, 31), 1.4, "rubber"), Cap((12.5, cy + 7, 31), (13, cy + 9, 3), 1.4, "rubber"),
         Cap((-6, cy, 37), (-12.5, cy + 7, 30), 1.2, "copper"), Cap((-12.5, cy + 7, 30), (-13, cy + 9, 3), 1.2, "copper"),
         box(-6.5, cy - 12.9, 32.4, 1.1, 0.4, 1.5, "amber"), box(-3.6, cy - 13.3, 32.4, 1.1, 0.4, 1.5, "screen"),
         box(5, cy - 13.5, 1.2, 3.6, 0.4, 2.8, "paper"), box(5, cy - 13.8, 2.8, 2.6, 0.3, 0.5, "black"),
         box(-5.5, cy - 13.6, 1.0, 2.8, 0.4, 3.0, "hazard"), box(-5.5, cy - 13.9, 1.9, 0.9, 0.3, 1.2, "black"),
         Ell((9, cy - 12, 0.8), (4, 2.6, 1.0), "frost"), Ell((-11, cy - 9, 0.8), (3, 2.2, 0.9), "frost")]
    return p


def lm_scanner(hx, d):
    p = [box(0, 30, 0, 20.5, 15, 27, "enamel"), box(0, 31.5, 27, 19, 12, 1.4, "enamel"),
         yc(0, 29.3, 30.2, 14, 10.4, "steel_dk"), yc(0, 29.0, 29.6, 14, 9.2, "screen"), yc(0, 28.7, 29.3, 14, 8.2, "black"),
         # 檢查床
         box(0, 7, 0, 4.5, 18, 7, "steel"), box(0, 6.7, 1, 3.4, 0.3, 4, "steel_dk"), box(0, 2, 7, 6.8, 31, 1.6, "linen"),
         box(0, 2.6, 8.6, 6.6, 13, 0.5, "tarp"), Ell((0, 23, 9.3), (4, 3, 1.0), "enamel"), box(0, 1.7, 7.4, 6.8, 0.3, 0.8, "chrome"),
         # 機身上的面板、標示
         box(-15.5, 29.6, 16, 2.8, 0.4, 4.4, "screen"), box(-15.5, 29.6, 12.5, 0.8, 0.4, 0.9, "red"), box(-13.6, 29.6, 12.5, 0.8, 0.4, 0.9, "amber"),
         box(15.5, 29.6, 19.6, 2.6, 0.4, 1.0, "red"), box(15.5, 29.6, 18, 1.0, 0.4, 4.2, "red"),
         box(0, 29.6, 25.2, 5, 0.4, 1.4, "hazard"), box(0, 29.6, 1, 20.5, 0.4, 1.6, "steel_dk"),
         # 操作台、點滴架
         box(-18, 6, 0, 4.5, 8, 9, "cabinet"), box(-18, 5.7, 2, 3.6, 0.3, 5, "steel_dk"), box(-18, 11, 9, 4, 1.4, 6.4, "black"),
         box(-18, 10.7, 10, 3.2, 0.3, 4.4, "screen"), box(-18, 7, 9, 3.4, 2.4, 0.5, "steel_dk"),
         vc(18, 10, 0, 23, 0.5, "chrome"), box(18, 9.2, 0, 3, 1.2, 0.6, "chrome"), box(18, 9.6, 17, 1.6, 0.9, 4.4, "glass"),
         box(18, 9.3, 18, 1.2, 0.3, 2, "red")]
    return p


def lm_server_bank(hx, d):
    rnd = random.Random(31)
    cy = d / 2
    p = [box(0, 10, 0, 23, d - 16, 1.5, "steel_dk")]
    for k in (-1, 0, 1):
        x = k * 15.2
        p += [box(x, 12, 0, 7.3, d - 20, 30, "black"), box(x, 14, 30, 5.6, d - 26, 0.5, "vent")]
        for r in range(9):
            z = 2.2 + r * 3.05
            p.append(box(x, 11.7, z, 6.3, 0.3, 2.3, "steel_dk"))
            p.append(box(x + 3, 11.4, z + 0.5, 2.2, 0.3, 1.2, "vent"))
            for j in range(3):
                m = "screen" if rnd.random() < 0.6 else ("amber" if rnd.random() < 0.6 else "red")
                if rnd.random() < 0.85:
                    p.append(box(x - 4.8 + j * 1.5, 11.4, z + 0.8, 0.4, 0.3, 0.5, m))
    p += [box(0, 11.3, 20.6, 4.2, 0.3, 5, "screen"), box(0, 11.1, 23.4, 3, 0.3, 0.5, "black"), box(0, 11.1, 21.8, 2, 0.3, 0.5, "black"),
          # 頂上的線槽、冷卻管
          box(0, cy + 1, 30.5, 22.6, 5, 1.2, "steel_dk"), xc(-22.5, 22.5, cy + 2.2, 32.4, 0.8, "blue_metal"), xc(-22.5, 22.5, cy + 3.8, 32.4, 0.8, "hazard"),
          xc(-22.5, 22.5, cy + 5.2, 32.4, 0.7, "red"), xc(-22.5, 22.5, d - 11, 32, 1.7, "chrome"),
          Cap((-18, cy + 3, 32), (-21, 9, 1), 0.8, "rubber"), Cap((14, cy + 3, 32), (20, 8, 1), 0.8, "blue_metal"),
          box(0, 4, 0, 16, 4, 1.0, "rubber")] + stripes(-16, 16, 4, 0.1, 0.9, step=4.0)
    return p


def lm_workbench(hx, d):
    p = [box(-9, 28, 0, 13, 12, 9, "red_metal"), box(-9, 27, 9, 13.6, 14, 1.4, "wood"), box(-9, d - 11.6, 10.4, 13.6, 1, 13, "steel_dk"),
         box(-9, 27, 10.4, 13.6, 0.3, 0.01, "wood")]
    p += [box(-18 + i * 6.2, 27.7, 1.2 + j * 2.6, 2.7, 0.3, 2.0, "rust") for i in range(4) for j in range(3)]
    p += [box(-18 + i * 6.2, 27.4, 2.0 + j * 2.6, 1.3, 0.3, 0.4, "chrome") for i in range(4) for j in range(3)]
    p += [box(x, d - 12, 13 + (i % 3) * 2.2, 0.5, 0.3, 6 - (i % 3) * 1.4, ("steel", "red_metal", "hazard", "chrome")[i % 4]) for i, x in enumerate(range(-20, 3, 3))]
    p += [box(-18.5, 29, 10.4, 2.2, 3.4, 3.2, "blue_metal"), box(-18.5, 28.4, 12.6, 0.5, 0.6, 0.6, "chrome"),
          vc(-9, 33, 10.4, 12, 2.6, "steel"), vc(-9, 33, 12, 12.6, 1, "steel_dk"), box(-2, 30, 10.4, 2.6, 2.4, 2.6, "hazard"),
          box(0.5, 34, 10.4, 1.2, 1.2, 4, "green_metal"),
          # 引擎吊架（吊臂橫著伸出來）：吊著一顆引擎
          box(13.5, 7, 0, 9, 1.2, 1.8, "red_metal"), box(13.5, 21, 0, 9, 1.2, 1.8, "red_metal"), box(21.5, 7, 0, 1.2, 15, 2.2, "red_metal"),
          box(21.3, 13.2, 2.2, 1.3, 1.8, 34, "red_metal"), Cap((21.3, 14, 36), (7, 14, 31), 1.5, "red_metal"), yc(7, 13, 15, 31, 1.6, "steel_dk"),
          Cap((20.4, 13.6, 12), (14, 13.6, 32), 1.0, "chrome"), vc(7.6, 14, 20, 30, 0.45, "steel_dk"),
          box(8.5, 9, 9, 5.2, 9.5, 9, "steel"), box(8.5, 9.5, 18, 4.2, 8.5, 1.8, "rust"), box(8.5, 8.7, 10, 4, 0.3, 3, "steel_dk"),
          yc(6.6, 7.8, 8.7, 14.6, 2.5, "steel_dk"), yc(10.6, 7.8, 8.7, 11.4, 1.5, "rubber"), yc(6.6, 7.5, 7.9, 14.6, 0.8, "chrome"),
          Cap((4, 12, 16), (2.4, 12, 19.5), 0.9, "copper"), Cap((13, 14, 16), (14.4, 14, 19), 0.9, "copper"),
          box(8.5, 8, 0, 6.5, 12, 0.6, "steel_dk"), Ell((7.5, 13, 0.9), (3.4, 2.4, 0.3), "black"),
          # 地上：躺板、千斤頂、輪胎
          box(-10, 5, 0.8, 8.5, 5.5, 0.9, "wood"), box(-16.5, 5.6, 1.7, 2, 4.2, 0.8, "leather"),
          box(-3.5, 16, 0, 2.4, 6, 2.6, "red_metal"), Cap((-3.5, 17, 2.6), (-3.5, 11.5, 6.5), 0.5, "chrome"),
          yc(-19.5, 15.5, 19, 4.6, 4.6, "rubber"), yc(-19.5, 15.2, 15.6, 4.6, 2, "steel")]
    return p


def lm_reception(hx, d):
    p = [box(0, 9, 0, 15.5, 7.5, 11, "wood"), box(0, 8.7, 1.5, 14, 0.3, 8, "leather"), box(0, 8.2, 11, 16, 9, 1.2, "benchtop"),
         box(0, 8.2, 12.2, 16, 2.6, 3, "wood"), box(0, 8, 15.2, 16.2, 3, 0.6, "benchtop"), box(0, 7.9, 14.4, 16.2, 0.3, 0.6, "brass"),
         box(0, 8.4, 4, 5, 0.3, 3.4, "enamel"), box(0, 8.2, 5.2, 4, 0.3, 0.9, "blue_metal")]
    for sx in (-1, 1):
        ang = 90 + sx * -34
        cx, cyy = sx * 22.2, 20.6
        p += [rbox(cx, cyy, 0, 11.5, 3.6, 11, ang, "wood"), rbox(cx, cyy, 11, 11.8, 4.2, 1.2, ang, "benchtop"),
              rbox(cx + sx * 2.4, cyy - 1.6, 12.2, 11.6, 1.2, 3, ang, "wood"), rbox(cx + sx * 2.4, cyy - 1.6, 15.2, 11.8, 1.4, 0.6, ang, "benchtop"), rbox(cx + sx * 3.6, cyy - 2.4, 14.4, 11.8, 0.2, 0.6, ang, "brass")]
    p += [box(-6.5, 13, 12.2, 3.6, 1.2, 5.2, "black"), box(-6.5, 14.2, 13, 3, 0.3, 3.8, "screen"), box(-6.5, 13.4, 12.2, 1, 1, 1, "steel_dk"),
          box(5.5, 12, 12.2, 3, 2.2, 0.3, "paper"), box(9.5, 12.5, 12.2, 1.6, 2.4, 0.8, "red"), Ell((11.5, 9.6, 16.4), (1.3, 1.3, 0.9), "brass"),
          vc(-12.5, 9.6, 15.8, 20, 0.35, "steel_dk"), box(-12.5, 8.6, 20, 1.8, 1.8, 1.2, "amber"),
          # 椅子、後面的檔案櫃
          vc(1, 24, 0, 5, 0.7, "steel_dk"), box(1, 21.5, 5, 4, 5.5, 1.4, "tarp"), box(1, 26.6, 6.4, 4, 1.2, 7, "tarp"),
          box(-20, 9.5, 12.2, 2.4, 3, 0.3, "paper"), box(21, 15, 12.2, 1.6, 1.6, 4, "leaf"), vc(21, 15.8, 12.2, 13.6, 1.5, "rust")]
    return p


def lm_forklift(hx, d):
    p = [yc(-4.5, 3, 5.4, 3.2, 3.2, "rubber"), yc(-4.5, 2.6, 3.1, 3.2, 1.3, "hazard"), yc(9.5, 3, 5.4, 2.7, 2.7, "rubber"), yc(9.5, 2.6, 3.1, 2.7, 1.1, "hazard"),
         box(2.5, 4, 2.2, 9.5, 16, 7.8, "hazard"), box(11, 3.7, 2.2, 3.4, 16.6, 10, "steel_dk"), box(6, 5, 10, 5.5, 14, 2.4, "hazard"),
         box(2.5, 3.7, 3, 9.5, 0.3, 1.4, "black"), box(1.5, 8, 10, 2.6, 8, 2, "black"), box(4.4, 8, 12, 0.8, 8, 5.5, "black"),
         Cap((-2.5, 12, 10), (-3.8, 12, 15.5), 0.4, "steel_dk"), yc(-3.9, 10.6, 13.4, 15.8, 1.5, "black")]
    p += [vc(x, y, 10, 24.5, 0.55, "steel_dk") for x in (-5, 10) for y in (5, 19)]
    p += [box(2.5, 4.4, 24.5, 8.2, 15.4, 0.7, "steel_dk"), box(2.5, 11, 25.2, 1, 1, 1.6, "amber"),
          # 門架、貨叉
          box(-8.6, 5, 0, 0.8, 1.4, 28, "steel_dk"), box(-8.6, 17.6, 0, 0.8, 1.4, 28, "steel_dk"), box(-8.6, 5, 27, 0.8, 14, 1, "steel_dk"),
          box(-9.7, 5, 3, 0.5, 14, 6.5, "steel"), vc(-8.6, 11.9, 2, 22, 0.6, "chrome"),
          box(-12.3, 6.2, 0.5, 2.6, 2.2, 0.9, "steel"), box(-12.3, 15.6, 0.5, 2.6, 2.2, 0.9, "steel")]
    p += stripes(7.8, 14.2, 3.7, 5, 3, step=1.6)
    return p


def lm_console_bank(hx, d):
    p = [box(0, 6, 0, 30.6, 14, 8, "steel_dk"), box(0, 5.7, 0, 30.6, 0.3, 1.4, "black"),
         Box((0, 8.6, 10), (30.4, 4.2, 0.6), "gunmetal", basis_along((1, 0, 0), (0, -0.5, 1))),
         box(0, 14, 8, 30.6, 6.5, 13.5, "steel_dk"), box(0, 14.4, 21.5, 30.6, 5.8, 0.6, "cabinet")]

    def on_slope(x, y, hx_, hy, hz, mat):
        return Box((x, y, 10.6 + (y - 8.6) * 0.5 + hz), (hx_, hy, hz), mat, basis_along((1, 0, 0), (0, -0.5, 1)))
    for i, x in enumerate((-22.6, -7.6, 7.6, 22.6)):
        m = ("screen", "screen", "black", "amber")[i]
        p += [box(x, 13.7, 10.6, 6.6, 0.3, 9.4, "black"), box(x, 13.5, 11.4, 5.8, 0.3, 7.8, m)]
        if m == "screen":
            p += [box(x - 1.5, 13.3, 16.5, 3, 0.3, 0.5, "black"), box(x + 1, 13.3, 14.4, 3.6, 0.3, 0.5, "black"), box(x - 2.4, 13.3, 12.6, 2, 0.3, 0.5, "black")]
        if m == "black":
            p += [Cap((x - 4, 13.3, 12.5), (x + 1.5, 13.3, 17.5), 0.3, "steel"), Cap((x + 1.5, 13.3, 17.5), (x + 3.4, 13.3, 14.4), 0.3, "steel")]
        p += [on_slope(x - 4 + j * 1.9, 6.4, 0.55, 0.55, 0.25, ("amber", "enamel", "red", "enamel", "screen")[(i + j) % 5]) for j in range(5)]
        p += [on_slope(x + 0.4, 10, 4.2, 1.3, 0.2, "steel_dk"), on_slope(x - 2.2 + i, 10, 0.5, 0.9, 0.5, "enamel")]
    p += [on_slope(28, 7, 1.6, 1.8, 0.6, "red"), Cap((0, 11.5, 11.8), (0.6, 8.5, 17), 0.3, "chrome"), Ell((0.6, 8.3, 17.2), (0.8, 0.8, 0.8), "black"),
          box(-15, 15.5, 22.1, 2.4, 3, 0.3, "paper"), box(15, 16, 22.1, 1, 1, 1.6, "enamel"), box(28, 15.5, 22.1, 1.2, 1.2, 1.6, "alarm")]
    return p


def lm_tape_reel_bank(hx, d):
    p = []
    for k in (-1, 0, 1):
        x = k * 15.4
        p += [box(x, 12, 0, 7.4, 10.5, 30, "olive"), box(x, 11.7, 13, 6.5, 0.3, 15.4, "steel_dk"), box(x, 12.6, 30, 6.8, 9.4, 0.5, "steel_dk")]
        for sx in (-3.25, 3.25):
            p += [yc(x + sx, 11.1, 11.5, 23, 3.0, "linen"), yc(x + sx, 10.9, 11.2, 23, 2.0 if (sx < 0) == (k != 0) else 1.3, "leather"),
                  yc(x + sx, 10.6, 11.0, 23, 0.8, "steel_dk")]
        p += [box(x, 11.3, 15, 2.6, 0.4, 2.6, "black"), box(x, 11.0, 15.6, 1.2, 0.3, 1.0, "chrome"), box(x, 11.4, 18.4, 4.4, 0.2, 0.4, "leather"),
              box(x - 3.2, 11.4, 8.6, 2.2, 0.3, 2.8, "amber"), box(x + 3.2, 11.4, 8.6, 2.2, 0.3, 2.8, "amber"),
              box(x - 3.6, 11.2, 9.4, 0.25, 0.3, 1.8, "black"), box(x + 2.6, 11.2, 9.4, 0.25, 0.3, 1.8, "black"),
              box(x, 11.6, 1, 6, 0.3, 2.2, "vent")]
        p += [box(x - 4.4 + j * 2.9, 11.3, 4.6, 0.8, 0.4, 1.0, ("enamel", "red", "enamel", "enamel")[(j + k) % 4]) for j in range(4)]
    p += [box(-15.4, 14, 30.5, 3.4, 5, 2.4, "carton"), box(-14.4, 14.6, 32.9, 3, 4, 1.6, "carton"), yc(15.4, 13, 13.6, 33.6, 3, "linen"),
          yc(15.4, 12.7, 13.1, 33.6, 0.8, "steel_dk"), box(1, 14.5, 30.5, 1.2, 1.2, 1.6, "enamel")]
    return p


def lm_antenna_mast(hx, d):
    cy = d / 2
    top = 72.0
    p = [box(0, cy - 9, 0, 9.5, 18, 4, "concrete")] + stripes(-9.5, 9.5, cy - 9, 0.6, 2.8)
    legs = [(-4.5, cy - 4), (4.5, cy - 4), (0, cy + 4.5)]
    p += [vc(x, y, 4, top, 0.75, "steel") for x, y in legs]
    for i in range(8):
        z0, z1 = 5 + i * 8.2, 5 + (i + 1) * 8.2
        a, b = (legs[0], legs[1]) if i % 2 == 0 else (legs[1], legs[0])
        p += [Cap((a[0], a[1], z0), (b[0], b[1], z1), 0.4, "steel_dk"), Cap((legs[0][0], legs[0][1], z1), (legs[1][0], legs[1][1], z1), 0.4, "steel_dk"),
              Cap((legs[i % 2][0], legs[i % 2][1], z0), (legs[2][0], legs[2][1], z1), 0.35, "steel_dk")]
    for ax, ay in ((-14, 3), (14, 3), (-13.5, d - 3), (13.5, d - 3)):
        p += [Cap((0, cy, 52), (ax, ay, 1), 0.3, "steel_dk"), box(ax, ay - 1.2, 0, 1.4, 2.4, 1.4, "concrete")]
    p += [xc(-7.5, 7.5, cy, 60, 0.45, "steel"), xc(-5.5, 5.5, cy, 66, 0.45, "steel")]
    p += [vc(x, cy, 58, 62, 0.35, "steel") for x in (-7, -3.5, 3.5, 7)]
    p += [Ell((5.2, cy - 5, 44), (4.2, 1.4, 4.2), "enamel"), Ell((5.2, cy - 6.6, 44), (0.8, 0.8, 0.8), "steel_dk"),
          vc(0, cy, top, top + 2, 1.0, "steel_dk"), Ell((0, cy, top + 3.4), (1.6, 1.6, 1.6), "alarm"),
          box(-5.6, cy - 12, 4, 3, 3, 6.5, "olive"), box(-5.6, cy - 12.3, 7, 2, 0.3, 2.2, "screen"), Cap((-4.5, cy - 9, 9), (-4.5, cy - 4, 20), 0.5, "rubber"),
          Ell((5, cy + 3, 4.6), (4, 4, 1.2), "snow"), Ell((-11, cy + 12, 0.9), (4, 3, 1.2), "snow")]
    return p


def lm_pump_station(hx, d):
    p = [box(0, 4, 0, 22.5, d - 8, 2.5, "steel_dk")] + stripes(-22.5, 22.5, 4, 0.4, 1.8)
    for x in (-11.5, 8.5):
        p += [xc(x - 7, x + 2, 13, 8, 4.6, "green_metal"), xc(x - 7.8, x - 7, 13, 8, 3.4, "steel_dk"),
              yc(x + 5.6, 9, 17, 8, 5.6, "steel"), yc(x + 5.6, 8.6, 9.1, 8, 2.2, "steel_dk"), box(x + 2.6, 10.6, 5.4, 1.2, 4.8, 5.4, "hazard"),
              Cap((x + 5.6, 15, 12), (x + 5.6, 34, 14), 2.3, "blue_metal")]
        p += [xc(x - 5.6 + i * 1.8, x - 5.0 + i * 1.8, 13, 8, 5.0, "steel_dk") for i in range(4)]
    p += [xc(-22.5, 22.5, 34, 14, 3.6, "blue_metal")]
    p += [xc(x - 0.6, x + 0.6, 34, 14, 4.5, "steel_dk") for x in (-13, 0, 13)]
    for x in (-18, -1, 16):
        p += [vc(x, 34, 17, 24, 0.7, "steel"), vc(x, 34, 24, 24.9, 3.2, "red_metal"), vc(x, 34, 24.9, 25.4, 0.9, "steel_dk")]
    p += [vc(-7, 34, 17, 21, 0.5, "steel"), yc(-7, 33.2, 33.8, 22.6, 2.0, "enamel"), box(-7, 32.9, 22.2, 0.3, 0.3, 1.5, "red"),
          vc(8, 34, 17, 21, 0.5, "steel"), yc(8, 33.2, 33.8, 22.6, 2.0, "enamel"), box(8.6, 32.9, 22.5, 1.0, 0.3, 0.3, "red"),
          vc(-21, d - 9, 2.5, 14, 3.0, "blue_metal"),
          box(19.5, 6, 2.5, 3.2, 4, 13, "locker"), box(19.5, 5.7, 10, 2.2, 0.3, 3.4, "black"), box(18.6, 5.5, 11.6, 0.6, 0.3, 0.9, "amber"),
          box(20.4, 5.5, 11.6, 0.6, 0.3, 0.9, "screen"), box(19.5, 5.7, 5, 1.6, 0.3, 2.6, "hazard")]
    return p


def lm_stage(hx, d):
    p = [box(0, 4, 0, 46.5, d - 6, 6, "wood"), box(0, 3.7, 0.6, 46.5, 0.3, 4.4, "leather"), box(0, 3.5, 5, 46.5, 0.3, 0.6, "brass")]
    for x in range(-40, 41, 10):
        p += [box(x, 4.6, 6, 1.6, 1.6, 1.2, "brass"), box(x, 5.4, 6.3, 1.0, 0.7, 0.8, "amber")]
    p += [box(0, d - 5.2, 6, 46.5, 1.6, 30, "black")]
    for x in range(-45, 46, 3):
        if abs(x) < 5:
            continue
        gather = 1.6 if abs(x) < 9 else 0
        p.append(vc(x + (gather if x < 0 else -gather) * 0, d - 7, 6, 34 - gather * 0, 2.0, "velvet"))
    p += [box(0, d - 11, 31, 46.5, 4.6, 5.5, "velvet"), box(0, d - 11.3, 31, 46.5, 0.3, 0.9, "brass"), box(0, d - 11.3, 35.6, 46.5, 0.3, 0.6, "brass")]
    p += [Ell((x, d - 11.4, 30.6), (0.9, 0.5, 1.2), "brass") for x in range(-42, 43, 12)]
    for sx in (-1, 1):
        p += [vc(sx * 43.5, 12, 6, 33, 2.4, "velvet"), vc(sx * 40, 13, 6, 33, 2.2, "velvet"), box(sx * 41.8, 10.6, 17, 3.8, 0.4, 1.2, "brass"),
              Cap((sx * 9, d - 9.4, 22), (sx * 6.5, d - 9.4, 12), 2.2, "velvet"), box(sx * 7.6, d - 11.8, 16, 2.4, 0.4, 1.0, "brass")]
    p += [vc(0, 15, 6, 21, 0.4, "chrome"), vc(0, 15, 6, 6.6, 2.4, "steel_dk"), Ell((0, 14.4, 21.6), (0.9, 0.9, 1.2), "black"),
          vc(13, 20, 6, 12, 0.5, "steel_dk"), vc(13, 20, 12, 13.2, 2.6, "leather"),
          vc(-15, 22, 6, 16, 0.35, "steel_dk"), Box((-15, 21.4, 17.5), (3, 0.3, 2.2), "black", basis_along((1, 0, 0), (0, -0.3, 1))),
          Box((-15, 21.0, 17.6), (2.2, 0.2, 1.6), "paper", basis_along((1, 0, 0), (0, -0.3, 1))),
          box(-27, 26, 6, 5, 4, 6, "black"), box(-27, 25.7, 7, 4, 0.3, 4, "vent"), box(28, 9, 6, 3, 2.2, 0.3, "paper"),
          box(-40.5, 0.6, 0, 5, 3.4, 3, "wood"), box(-40.5, 0.4, 2.4, 5, 0.3, 0.6, "brass")]
    return p


def lm_bar_island(hx, d):
    rnd = random.Random(12)
    p = [box(0, 8, 0, 30, 8, 12, "wood"), box(0, 7.7, 1.6, 28.6, 0.3, 8.4, "leather"), box(0, 7, 12, 30.6, 9.8, 1.2, "brass")]
    for sx in (-1, 1):
        p += [box(sx * 26.6, 16, 0, 3.4, d - 23, 12, "wood"), box(sx * 26.6, 16.6, 12, 4, d - 23, 1.2, "brass")]
    p += [box(x, 7.5, 1.6, 0.35, 0.3, 8.4, "wood") for x in (-19, -9.5, 0, 9.5, 19)]
    p += [box(0, 30, 0, 20, 9, 14, "wood"), box(0, 34, 14, 20, 5, 5.5, "wood"), box(0, 29.7, 2, 18.5, 0.3, 9, "leather"),
          box(0, 38.4, 19.5, 15, 0.8, 10, "steel_dk"), box(0, 38.1, 20.6, 13.6, 0.3, 7.8, "visor"), box(0, 37.9, 29, 15, 0.3, 0.6, "brass")]
    mats = ("green_metal", "amber", "glass", "red_metal", "enamel", "leather")
    for x in range(-18, 19, 3):
        p += [vc(x, 31.6, 14, 18 + rnd.random() * 2.4, 1.0, rnd.choice(mats)), vc(x + 0.8, 35.6, 19.5, 23.5 + rnd.random() * 2.4, 1.0, rnd.choice(mats))]
    p += [xc(-29.5, 29.5, 7.0, 2.6, 0.6, "brass"), vc(-9, 11, 13.2, 18, 0.5, "chrome"), box(-9, 9.6, 17, 0.5, 1.4, 1.6, "black"),
          vc(-6, 11, 13.2, 18, 0.5, "chrome"), box(-6, 9.6, 17, 0.5, 1.4, 1.6, "red"),
          box(19, 10, 13.2, 3, 3.4, 3.2, "steel_dk"), box(19, 9.7, 14.4, 2, 0.3, 1.4, "screen"), box(8, 11, 13.2, 3, 2.4, 0.3, "linen")]
    p += [vc(x, y, 13.2, 15.2, 0.7, "glass") for x, y in ((2, 10), (4, 12.4), (-16, 11), (12.6, 12), (-21, 13))]
    for x in (-22, -11, 0, 11, 22):
        p += [vc(x, 3.4, 0, 7, 0.6, "chrome"), vc(x, 3.4, 0, 0.6, 2.2, "steel_dk"), vc(x, 3.4, 7, 8.8, 2.9, "velvet")]
    return p


def lm_pool_table(hx, d):
    p = [box(sx * 11, y, 0, 2, 4, 6, "wood") for sx in (-1, 1) for y in (10, d - 14)]
    p += [box(0, 8, 6, 14, d - 16, 4.5, "wood"), box(0, 7.7, 7, 12.6, 0.3, 2.4, "leather"), box(0, 10.5, 10.5, 11.5, d - 21, 0.5, "felt"),
          box(0, 8, 10.5, 14, 2.5, 1.7, "wood"), box(0, d - 10.5, 10.5, 14, 2.5, 1.7, "wood"),
          box(-12.75, 8, 10.5, 1.25, d - 16, 1.7, "wood"), box(12.75, 8, 10.5, 1.25, d - 16, 1.7, "wood")]
    p += [vc(sx * 11.8, y, 12.1, 12.35, 1.6, "black") for sx in (-1, 1) for y in (10.2, d / 2, d - 10.2)]
    p += [box(x, 8.4, 12.2, 0.35, 0.35, 0.2, "brass") for x in (-6, 0, 6)] + [box(x, d - 9.4, 12.2, 0.35, 0.35, 0.2, "brass") for x in (-6, 0, 6)]
    balls = (("enamel", -5, 17), ("red", 3, 31), ("hazard", 5.2, 32.4), ("blue_metal", 2, 34), ("red_metal", 4.6, 29.6), ("black", 6.5, 21), ("orange", -7, 36))
    p += [Ell((x, y, 12.0), (1.05, 1.05, 1.05), m) for m, x, y in balls]
    p += [Cap((-9.5, 13.5, 12.6), (8.5, 25, 12.6), 0.4, "cloth"), box(10, 8.6, 12.2, 0.8, 0.8, 0.8, "blue_metal")]
    return p


def lm_grand_piano(hx, d):
    p = [box(0, 1, 0, 6, 5, 5.5, "leather"), box(0, 0.7, 0, 0.6, 0.6, 5, "black"),
         vc(-11.5, 12, 0, 8, 1.2, "black"), vc(11.5, 12, 0, 8, 1.2, "black"), vc(-5.5, 42, 0, 8, 1.2, "black"),
         box(0, 11, 0, 1.4, 1, 8, "black"), box(-1, 10, 0, 0.5, 1.4, 0.6, "brass"), box(1, 10, 0, 0.5, 1.4, 0.6, "brass"),
         box(0, 9.6, 8, 13.6, 5.4, 3, "black"), box(0, 10, 11, 12.6, 3.4, 0.4, "linen")]
    p += [box(x, 11.8, 11.4, 0.4, 1.6, 0.35, "black") for x in (-11, -9.4, -6.2, -4.6, -3, 0.2, 1.8, 5, 6.6, 8.2, 11)]
    p += [box(0, 14.6, 11, 13.6, 1.2, 3.2, "black"), box(0, 14.3, 12.4, 1.8, 0.3, 0.6, "brass"),
          box(-7, 15.6, 8, 6.6, 27, 6, "black"), vc(-5, 41, 8, 14, 8.6, "black"), box(3, 15.6, 8, 10.6, 9, 6, "black"), vc(5, 26.5, 8, 14, 8.6, "black"),
          # 掀開的琴蓋底下：金色的鑄鐵框、琴弦
          box(-5.5, 17, 14, 7, 23, 0.3, "brass"), box(4, 17, 14, 6, 9, 0.3, "brass")]
    p += [box(-11.5 + i * 1.7, 17.4, 14.3, 0.2, 22 - i * 0.8, 0.15, "steel_dk") for i in range(8)]
    p += quad((-13.4, 16, 14.2), (-13.4, 44, 14.2), (-9, 46, 31), (-9, 16, 31), "black") + [Cap((2, 24, 14.3), (-9.6, 24, 27), 0.35, "brass"),
          # 譜架
          box(0, 16.2, 14, 5.4, 0.6, 5.4, "black"), box(-1.2, 15.9, 14.8, 2.2, 0.3, 3.8, "paper"), box(2.2, 15.9, 14.8, 1.4, 0.3, 3.4, "paper")]
    return p


def lm_lifeboat(hx, d):
    cy = 13.0
    p = []
    for sx in (-1, 1):
        p += [box(sx * 21, 15, 0, 1.8, 6, 2, "steel_dk"), vc(sx * 21, 18, 2, 27, 1.1, "enamel"), Cap((sx * 21, 18, 27), (sx * 16.5, 12.5, 30.5), 1.1, "enamel"),
              vc(sx * 16.5, 12.5, 18, 30.5, 0.3, "steel_dk"), box(sx * 10, cy - 4, 0, 1.4, 8, 5.4, "steel_dk")]
    p += [Cap((-12.5, cy, 11), (12.5, cy, 11), 5.8, "orange"), box(0, cy - 6.1, 13, 15.5, 0.4, 1.0, "enamel"),
          Ell((0, cy, 15), (15.5, 5.6, 5), "orange"), box(-6, cy - 5.3, 15.4, 2.2, 0.4, 1.8, "visor"), box(1, cy - 5.6, 15.4, 2.2, 0.4, 1.8, "visor"),
          box(8, cy - 5.3, 15.4, 2.2, 0.4, 1.8, "visor"), box(-12.5, cy - 2, 18.4, 2.4, 4, 1.2, "enamel"),
          box(-13, cy - 5.9, 8.6, 2.6, 0.4, 1.8, "paper"), box(-13, cy - 6.1, 9.2, 1.8, 0.3, 0.5, "black"),
          xc(-14, 14, cy - 5.2, 6.6, 0.4, "black")]
    return p


def lm_winch(hx, d):
    cy = d / 2
    p = [box(0, 6, 0, 14.4, d - 12, 3, "steel_dk")] + stripes(-14.4, 14.4, 6, 0.5, 2.0)
    p += [box(sx * 11, 14, 3, 1.6, 24, 14.5, "blue_metal") for sx in (-1, 1)]
    p += [xc(-9, 9, cy, 12.5, 6.6, "rust"), xc(-9.6, -8.4, cy, 12.5, 11, "steel"), xc(8.4, 9.6, cy, 12.5, 11, "steel")]
    p += [xc(-7.4 + i * 2.5, -5.8 + i * 2.5, cy, 12.5, 8.4, "steel") for i in range(6)]
    p += [yc(sx * 12.7, cy - 1, cy + 1, 12.5, 2.4, "steel_dk") for sx in (-1, 1)]
    p += [box(5, 38, 3, 6.5, 8, 9.5, "green_metal"), box(5, 37.7, 5, 5, 0.3, 5, "vent"), box(-6, 38, 3, 4, 7.5, 7.5, "steel"),
          yc(-6, 37.2, 38, 7.4, 2.6, "steel_dk"),
          Cap((13, 11, 3), (13.6, 8, 20.5), 0.6, "hazard"), Ell((13.7, 7.8, 21.4), (1.3, 1.3, 1.3), "red"),
          Cap((-2, cy - 8.4, 12.5), (-8, 1.5, 0.6), 0.5, "steel_dk"), box(-12, 7, 3, 1.6, 2, 5, "steel_dk"), box(-12, 6.7, 6, 1, 0.3, 1.4, "amber")]
    return p


def lm_engine_block(hx, d):
    cy = d / 2
    p = [box(0, 6, 0, 30.6, d - 12, 4, "steel_dk")] + stripes(-30.6, 30.6, 6, 0.8, 2.4)
    p += [box(0, 7, 4, 30, 8, 1, "steel"), xc(-30, 30, 7.6, 13, 0.5, "hazard"), xc(-30, 30, 7.6, 9, 0.35, "steel_dk")]
    p += [vc(x, 7.6, 5, 13, 0.5, "steel_dk") for x in range(-30, 31, 12)]
    p += [box(-3, 18, 4, 24.5, 44, 16, "green_metal"), box(-3, 17.7, 4, 24.5, 0.3, 1.6, "steel_dk")]
    for x in range(-23, 18, 8):
        p += [box(x, 17.7, 8, 3, 0.3, 7, "steel_dk"), box(x, 17.4, 11, 0.6, 0.3, 0.8, "chrome")]
    for i in range(6):
        x = -23.5 + i * 8
        p += [vc(x, cy, 20, 27, 3.5, "steel"), vc(x, cy, 27, 28.6, 2.4, "red_metal"), box(x, 22, 20, 3, 7, 3, "green_metal"),
              box(x, 21.7, 21, 2, 0.3, 1, "steel_dk"), Cap((x, cy + 3, 26), (x, cy + 13, 27), 1.5, "rust")]
    p += [xc(-26, 19, cy + 13, 27, 3.2, "rust"), xc(19, 27, cy + 13, 27, 5.2, "enamel"), xc(18.4, 19.2, cy + 13, 27, 6, "steel_dk"),
          vc(23, cy + 13, 31, 44, 3.0, "rust"), vc(23, cy + 13, 44, 45, 3.8, "steel_dk"),
          xc(-26, 18, 20, 21.6, 0.7, "copper"), xc(-26, 18, 21.8, 23.4, 0.6, "copper"),
          # 飛輪和護罩
          xc(24, 27.4, cy - 6, 15, 13, "steel"), xc(23.6, 27.8, cy - 6, 15, 4, "steel_dk"), box(25.7, 16, 4, 2.6, 2.4, 13, "hazard"),
          box(25.7, 15.7, 9, 1.6, 0.3, 2.4, "black"),
          # 儀表板
          box(-27.6, 15.5, 5, 2.8, 2, 13, "steel_dk"), yc(-28.6, 14.8, 15.3, 15, 1.4, "enamel"), yc(-26.2, 14.8, 15.3, 15, 1.4, "enamel"),
          box(-28.6, 15.1, 11, 0.7, 0.3, 1, "amber"), box(-26.6, 15.1, 11, 0.7, 0.3, 1, "red"), box(-27.6, 15.2, 7, 2, 0.3, 2.4, "paper"),
          Ell((8, 13, 5.2), (5, 2.2, 0.3), "black")]
    return p


def lm_watchtower(hx, d):
    cy = d / 2
    p = []
    for sx in (-1, 1):
        for sy in (-1, 1):
            p += [Cap((sx * 13.4, cy + sy * 17, 0), (sx * 10.5, cy + sy * 13, 38), 1.1, "wood"), Ell((sx * 13.4, cy + sy * 17, 1), (2.6, 2.4, 1.4), "cloth")]
    p += [Cap((-13.2, cy - 17, 2), (10.5, cy - 13, 35), 0.55, "wood"), Cap((13.2, cy - 17, 2), (-10.5, cy - 13, 35), 0.55, "wood"),
          Cap((-12, cy - 15.3, 18), (12, cy - 15.3, 18), 0.55, "wood"),
          box(0, cy - 15, 38, 13, 30, 1.5, "wood"), box(0, cy - 15.3, 38, 13, 0.3, 1.5, "leather"),
          box(0, cy - 15, 39.5, 13, 1, 7, "olive"), box(-12.5, cy - 15, 39.5, 0.5, 30, 7, "olive"), box(12.5, cy - 15, 39.5, 0.5, 30, 7, "olive"),
          box(0, cy + 14, 39.5, 13, 1, 7, "olive"), box(0, cy - 15.3, 41.5, 3.6, 0.3, 2.6, "hazard"), box(0, cy - 15.5, 42.2, 2.2, 0.3, 0.6, "black")]
    p += [Ell((x, cy - 14.5, 47.2), (3.2, 1.6, 1.2), "cloth") for x in (-8.5, -2.5)]
    p += [vc(sx * 12.2, cy + sy * 14.2, 46.5, 58, 0.6, "wood") for sx in (-1, 1) for sy in (-1, 1)]
    p += [box(0, cy - 17.5, 58, 14.4, 35, 1.4, "rust"), box(0, cy - 17.8, 58, 14.4, 0.3, 1.4, "steel_dk")]
    p += [box(x, cy - 17.5, 59.4, 0.35, 35, 0.3, "steel_dk") for x in range(-12, 13, 3)]
    p += [Ell((-3, cy + 9, 59.8), (10, 6.5, 1.1), "snow"), Ell((7, cy + 2, 59.7), (5, 4, 0.8), "snow"),
          yc(6.5, cy - 18, cy - 14.6, 50, 2.7, "steel_dk"), yc(6.5, cy - 18.6, cy - 18, 50, 2.1, "amber"), vc(6.5, cy - 15.6, 46.5, 48, 0.5, "steel_dk"),
          box(-7, cy - 18.8, 0, 0.4, 0.4, 38, "steel"), box(-3, cy - 18.8, 0, 0.4, 0.4, 38, "steel")]
    p += [box(-5, cy - 18.8, 3 + i * 4.4, 2, 0.3, 0.35, "steel") for i in range(8)]
    return p


def lm_gate_barrier(hx, d):
    p = [box(-18.6, 5.5, 0, 4, 11, 2, "concrete"), box(-18.6, 8, 2, 2.6, 6, 12.5, "hazard")] + stripes(-21.2, -16, 8, 2.4, 3.6, step=1.75)
    p += [box(-18.6, 10, 14.5, 1.2, 1.6, 1.8, "alarm"), box(-22, 9.6, 9.4, 1.0, 2.4, 4.4, "steel_dk")]
    x, i = -17.0, 0
    while x < 21.5:
        w = min(3.8, 21.5 - x)
        p.append(box(x + w / 2, 10, 10.4, w / 2, 1.3, 2.4, "red" if i % 2 == 0 else "enamel"))
        x += 3.8
        i += 1
    p += [vc(2, 10.6, 5.5, 10.4, 0.3, "steel_dk"), yc(2, 9.5, 10, 6, 2.8, "red"), box(2, 9.2, 5.6, 1.9, 0.3, 0.9, "enamel"),
          box(21.4, 8, 0, 1.0, 5, 10, "steel_dk"), box(21.4, 7.6, 10, 1.5, 0.6, 3, "steel_dk"), box(21.4, 12.6, 10, 1.5, 0.6, 3, "steel_dk"),
          box(21.4, 6.5, 0, 2.4, 8, 1.2, "concrete"), Ell((-14, 6.5, 0.8), (3, 2, 0.9), "snow")]
    return p


def lm_tent(hx, d):
    x0, x1, y0, y1 = -19.0, 11.0, 5.0, d - 5.0
    ap = (-4.0, (y0 + y1) / 2 + 2, 31.0)
    c = [(x0, y0, 0), (x1, y0, 0), (x1, y1, 0), (x0, y1, 0)]
    p = [Tri(c[0], c[1], ap, "orange"), Tri(c[1], c[2], ap, "orange"), Tri(c[3], c[0], ap, "orange"), Tri(c[2], c[3], ap, "orange")]

    def on_front(u, v, lift=0.4):
        """正面那片斜面上的點：u = 左右（-1..1）、v = 高度（0 底、1 頂）"""
        bx = (x0 + x1) / 2 + u * (x1 - x0) / 2 * (1 - v)
        return (bx + (ap[0] - (x0 + x1) / 2) * v, y0 + (ap[1] - y0) * v - lift, ap[2] * v + lift * 0.6)
    # 入口（圓筒袖口）、布的接縫、裙邊壓雪
    p += quad(on_front(-0.26, 0.06), on_front(0.3, 0.06), on_front(0.3, 0.5), on_front(-0.3, 0.5), "tarp")
    p += quad(on_front(-0.16, 0.1, 0.8), on_front(0.2, 0.1, 0.8), on_front(0.2, 0.42, 0.8), on_front(-0.2, 0.42, 0.8), "black")
    p += [Cap(on_front(-1, 0, 0.2), ap, 0.45, "rust"), Cap(on_front(1, 0, 0.2), ap, 0.45, "rust"), Cap((x0, y1, 0), ap, 0.4, "rust")]
    p += [Cap(ap, (ap[0] + dx, ap[1] + dy, ap[2] + 4.5), 0.4, "wood") for dx, dy in ((-2, -2), (2, -2), (2, 2), (-2, 2))]
    p += [Ell((-4, y0 - 0.5, 0.6), (13, 2.4, 2.0), "snow"), Ell((x0 - 0.5, (y0 + y1) / 2, 0.6), (2.4, 16, 1.8), "snow"),
          Ell((x1 + 0.5, (y0 + y1) / 2 + 4, 0.6), (2.2, 12, 1.6), "snow"), Ell((-8, y0 + 9, 9.4), (4, 1.6, 2.2), "snow")]
    for sx, tx in ((-1, x0 - 3.5), (1, x1 + 4)):
        p += [Cap((ap[0] + sx * 6, ap[1] - 8, 20), (tx, 1.5, 0.3), 0.25, "steel_dk")]
    # 擋風的雪磚牆、插在雪裡的滑雪板、標示旗
    p += [box(18, 20 + i * 7.5, 0, 3.6, 7, 5 if i != 2 else 9, "snow") for i in range(3)]
    p += [box(18, 20, 5, 3.2, 6, 3.6, "snow"), box(17.5, 12, 0, 0.5, 0.5, 19, "red_metal"), box(19.5, 12.6, 0, 0.5, 0.5, 18, "red_metal"),
          vc(21.5, 5, 0, 22, 0.35, "steel"), box(19.6, 4.8, 17.4, 1.8, 0.3, 2.3, "red"),
          box(15.5, 5, 0, 2.6, 4.4, 3.4, "wood"), box(15.5, 4.7, 1.2, 2.6, 0.3, 0.6, "rust")]
    return p


def lm_sled(hx, d):
    p = []
    for y in (6.0, 18.0):
        p += [box(1, y - 0.6, 0, 13, 1.2, 1, "wood"), Cap((-12, y, 0.6), (-14.6, y, 4), 0.6, "wood")]
        p += [box(x, y - 0.4, 1, 0.5, 0.8, 1.8, "steel_dk") for x in (-8, 0, 8)]
    p += [box(1, 5.4, 2.6, 12.6, 13.2, 0.8, "wood"), xc(-14.6, -14, 12, 4, 0.5, "wood"), Cap((-14.6, 6, 4), (-14.6, 18, 4), 0.5, "wood"),
          box(-3.5, 7, 3.4, 6.2, 10, 5.4, "tarp"), box(-7, 6.7, 3.4, 0.5, 10.6, 5.7, "hazard"), box(-0.5, 6.7, 3.4, 0.5, 10.6, 5.7, "hazard"),
          box(8, 8, 3.4, 4.2, 8.6, 4.2, "wood"), box(8, 7.7, 5, 4.2, 0.3, 0.8, "rust"), box(7, 9.4, 7.6, 2, 3, 3.6, "red_metal"),
          box(7, 9.1, 9.4, 1.0, 0.3, 0.9, "hazard"), vc(11, 14, 7.6, 8.4, 1.7, "cloth"), vc(11, 14, 8.4, 8.6, 0.7, "black"),
          Ell((-4, 12, 9), (5, 3.6, 0.8), "snow"), Cap((-14.6, 12, 3.4), (-15.4, 9, 0.3), 0.3, "cloth")]
    return p


def lm_ice_drill(hx, d):
    cy = d / 2
    apex = (0, cy, 40)
    p = [vc(0, cy, 0, 0.5, 9.5, "ice"), vc(0, cy, 0.5, 0.8, 3.2, "black"),
         Ell((7, cy - 6, 0.8), (3.6, 2.6, 1.3), "snow"), Ell((-7.5, cy + 3, 0.8), (3.2, 2.4, 1.2), "snow"), Ell((3, cy + 8, 0.7), (3, 2, 1.0), "snow")]
    for fx, fy in ((-12.5, cy - 12), (12.5, cy - 12), (0, cy + 17)):
        p += [Cap((fx, fy, 0.5), apex, 0.9, "steel"), box(fx, fy - 1.4, 0, 2, 2.8, 0.8, "steel_dk")]
    p += [Cap((-9.4, cy - 9, 10), (9.4, cy - 9, 10), 0.35, "steel_dk"), Ell(apex, (1.8, 1.8, 1.8), "steel_dk"),
          vc(0, cy, 0.8, 27, 1.0, "chrome"), vc(0, cy, 34, 39, 0.4, "steel_dk")]
    p += [vc(0, cy, z, z + 0.9, 3.3, "steel") for z in range(3, 26, 4)]
    p += [box(0, cy - 3.6, 27, 4.2, 7.2, 7, "orange"), box(0, cy - 3.9, 29, 2.8, 0.3, 3, "vent"), box(2.8, cy - 3.9, 32.4, 0.7, 0.3, 0.9, "red"),
          xc(-8.5, 8.5, cy, 31, 0.6, "steel_dk"), xc(-9.5, -6.5, cy, 31, 0.9, "black"), xc(6.5, 9.5, cy, 31, 0.9, "black"),
          # 冰芯盤、電池箱
          box(0, 3, 0, 9.6, 6.6, 1.5, "steel_dk"), xc(-8.6, 8.6, 4.8, 2.7, 1.15, "ice"), xc(-8.6, 6, 7.6, 2.7, 1.15, "ice"),
          box(10.4, cy + 7, 0, 3.6, 6, 5.5, "hazard"), box(10.4, cy + 6.7, 2, 2.4, 0.3, 2, "black"), Cap((9, cy + 8, 5.5), (2, cy, 30), 0.4, "rubber"),
          box(-11.5, cy + 8, 0, 2.2, 3.4, 5, "red_metal"), box(-11.5, cy + 9, 5, 0.8, 0.8, 1.2, "steel_dk")]
    return p


def gen_landmark():
    LM("reactor", 3, 3, 47, lm_reactor)
    LM("turbine", 4, 2, 39, lm_turbine)
    LM("drill_rig", 3, 3, 66, lm_drill_rig)
    LM("snow_crawler", 4, 2, 36, lm_snow_crawler)
    LM("crane", 2, 2, 73, lm_crane)
    LM("specimen_tank", 2, 2, 41, lm_specimen_tank)
    LM("scanner", 3, 2, 30, lm_scanner)
    LM("server_bank", 3, 2, 35, lm_server_bank)
    LM("workbench", 3, 2, 37, lm_workbench)
    LM("reception_desk", 4, 2, 22, lm_reception)
    LM("forklift", 2, 1, 30, lm_forklift)
    LM("console_bank", 4, 1, 25, lm_console_bank)
    LM("tape_reel_bank", 3, 1, 37, lm_tape_reel_bank)
    LM("antenna_mast", 2, 2, 78, lm_antenna_mast)
    LM("pump_station", 3, 2, 28, lm_pump_station)
    LM("stage", 6, 2, 38, lm_stage)
    LM("bar_island", 4, 2, 31, lm_bar_island)
    LM("pool_table", 2, 2, 14, lm_pool_table)
    LM("grand_piano", 2, 2, 36, lm_grand_piano)
    LM("lifeboat", 3, 1, 33, lm_lifeboat)
    LM("winch", 2, 2, 24, lm_winch)
    LM("engine_block", 4, 3, 47, lm_engine_block)
    LM("watchtower", 2, 2, 62, lm_watchtower)
    LM("gate_barrier", 3, 1, 18, lm_gate_barrier)
    LM("tent", 3, 2, 31, lm_tent)
    LM("sled", 2, 1, 12, lm_sled)
    LM("ice_drill", 2, 2, 43, lm_ice_drill)
    # 單格：結構柱（高）、欄杆（半高；橫排自動接起來，直排用 railing_v）
    S("pillar", [box(0, 3, 0, 6.6, 11, 3, "concrete"), box(0, 4, 3, 5.4, 9, 30, "concrete"), box(0, 3, 33, 6.6, 11, 3, "concrete"),
                 box(-1.5, 3.8, 20, 2, 0.2, 2.6, "paper"), box(-1.5, 3.6, 21.6, 1.2, 0.2, 0.4, "black"), box(3.2, 3.8, 16, 0.5, 0.2, 12, "rust")]
      + stripes(-5.4, 5.4, 4, 3.4, 4.2, step=2.7), 42)
    S("railing", [xc(-9, 9, 9, 10, 0.75, "hazard"), xc(-9, 9, 9, 5.5, 0.5, "steel_dk"), vc(-8, 9, 0, 10, 0.7, "steel_dk"), vc(8, 9, 0, 10, 0.7, "steel_dk"),
                  vc(0, 9, 0, 10, 0.5, "steel_dk"), box(0, 8.6, 0, 9, 0.8, 1.6, "steel_dk")], 18)
    S("railing_v", [yc(0, -2, 30, 10, 0.75, "hazard"), yc(0, -2, 30, 5.5, 0.5, "steel_dk"), vc(0, 2, 0, 10, 0.7, "steel_dk"), vc(0, 16, 0, 10, 0.6, "steel_dk"),
                    box(0, -2, 0, 0.5, 32, 1.6, "steel_dk")], 28)
    print("landmark: ok")


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
    # ── v0.10：放道具的桌子（ItemPickup.stand）、補給盒、新圖示 ──
    S("stand_wood", table(6.6, 9, 8.5, "benchtop", "wood"), 20, folder="stash")
    S("stand_steel", table(6.6, 9, 8.5, "steel", "chrome", 0.8) + [box(0, 0, 3.2, 6.2, 8, 0.5, "steel_dk")], 20, folder="stash")
    S("stand_crate", [box(0, 0.5, 0, 6.6, 9, 8.6, "wood"), box(0, 0.2, 3.6, 6.8, 0.3, 1.0, "steel_dk"),
                      box(-4.4, 0.2, 0, 0.6, 0.3, 8.6, "steel_dk"), box(4.4, 0.2, 0, 0.6, 0.3, 8.6, "steel_dk")], 20, folder="stash")
    pair("supply_box", [box(0, 1.5, 0, 5.4, 6, 4.4, "orange"), box(0, 1.3, 4.4, 5.6, 6.4, 1.2, "orange"), box(-2.6, 1, 3, 0.8, 0.3, 1.6, "black"),
                        box(2.6, 1, 3, 0.8, 0.3, 1.6, "black"), Cap((-2, 4.6, 6.4), (2, 4.6, 6.4), 0.4, "black")],
         [box(0, 1.5, 0, 5.4, 6, 4.4, "orange"), box(0, 2.1, 4, 4.8, 4.8, 0.5, "rubber"),
          Box((0, 8.6, 7), (5.6, 0.6, 3.0), "orange", basis_along((1, 0, 0), (0, 0.35, 1)))], 16, 16)
    _save("props", "ext_mag", 12, 14, render([box(0, 3, 0, 1.6, 2.2, 9, "black"), box(0, 3, 9, 1.8, 2.4, 1, "steel_dk"),
                                              box(0, 2.8, 10, 1.0, 1.4, 0.8, "brass")], 12, 14, anchor=(6, 12)))
    _save("props", "red_dot", 14, 12, render([box(0, 3, 0, 4.4, 2.4, 1.6, "steel_dk"), box(2.6, 3, 1.6, 0.5, 2.4, 4, "steel_dk"),
                                              box(2.6, 2.9, 2.4, 0.3, 1.8, 2.6, "screen"), box(-2, 3, 1.6, 1.6, 2, 1.2, "black")], 14, 12, anchor=(7, 10)))
    _save("props", "foregrip", 12, 14, render([box(0, 3, 6.5, 4, 2.2, 1.4, "steel_dk"), Cap((0, 3, 0.8), (0, 3, 6.5), 1.5, "black"),
                                               box(0, 3, 0, 1.8, 2.4, 0.8, "rubber")], 12, 14, anchor=(6, 12)))
    _save("props", "carbine", 30, 12, render([Cap((1, 3, 4), (13, 3, 4), 1.5, "steel_dk"), box(-3, 3, 3, 5, 1.6, 2.2, "gunmetal"),
                                              box(-10.5, 3, 1.6, 3.5, 1.6, 3, "wood"), box(-2, 3, 0, 1.1, 1.4, 3.2, "black"),
                                              box(-5.5, 3, 0.6, 0.9, 1.4, 2.4, "wood"), box(-2, 3, 5.2, 2.4, 1, 0.6, "black")], 30, 12, anchor=(15, 10)))
    _save("props", "harpoon", 32, 12, render([Cap((-2, 3, 4), (14.5, 3, 4), 0.6, "steel"), Cap((12.4, 3, 4), (14.6, 3, 5.6), 0.5, "steel"),
                                              Cap((12.4, 3, 4), (14.6, 3, 2.6), 0.5, "steel"), Cap((-6, 3, 4), (2, 3, 4), 1.7, "gunmetal"),
                                              box(-11, 3, 1.4, 4, 1.8, 3.4, "wood"), box(-5, 3, 0.4, 1, 1.4, 2.8, "wood"),
                                              box(-2, 3, 1.8, 1.6, 1.6, 1, "brass")], 32, 12, anchor=(16, 10)))
    _save("props", "chart", 16, 12, render([box(0, 3, 0, 6.4, 5, 0.4, "paper"), box(-2.5, 1.5, 0.4, 2.2, 0.4, 0.2, "black"),
                                            box(1.5, 3.4, 0.4, 2.8, 0.4, 0.2, "black"), box(3.4, 5.2, 0.4, 0.9, 0.9, 0.3, "red_metal"),
                                            box(-3.8, 5, 0.4, 1.6, 0.4, 0.2, "black")], 16, 12, anchor=(8, 10)))
    print("stash: ok")


# ── 地板、牆的貼圖 ────────────────────────────────────────────
# 設計原則：顏色階差小、雜訊少（大廳才不會像壁紙），靠「結構」讓地板好看：伸縮縫、磁磚縫、木板、防滑紋。
# 每張 64x64（4x4 格）可以無縫拼接；大範圍的變化（髒污、標線、陰影）由 Level 另外畫。

BAYER4 = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def hsh(a, b, seed=0):
    """固定亂數 0..1（磁磚、木板各自的深淺）"""
    v = (a * 73856093) ^ (b * 19349663) ^ (seed * 83492791)
    v = (v ^ (v >> 13)) * 1274126177
    return ((v ^ (v >> 16)) & 0xffff) / 65535.0


def ftex(pal_hex, seed, fn=None, noise=1.0, dither=0.5, w=64, h=64, cells=(16, 8)):
    """地板貼圖：值是「調色盤第幾階」（小數），先加一點雜訊，fn(x, y, v) 再加結構，最後抖色取整。"""
    pal = [hexc(c) for c in pal_hex]
    n1 = g.value_noise(w, h, cells[0], seed)
    n2 = g.value_noise(w, h, cells[1], seed + 1)
    base = (len(pal) - 1) / 2.0
    px = []
    for y in range(h):
        for x in range(w):
            v = base + ((n1(x, y) - 0.5) * 1.6 + (n2(x, y) - 0.5) * 1.0) * noise
            if fn:
                v = fn(x, y, v)
            v += (BAYER4[y % 4][x % 4] / 16.0 - 0.5) * dither
            c = pal[max(0, min(len(pal) - 1, int(round(v))))]
            px.append((c[0], c[1], c[2], 255))
    return px


def gen_tiles():
    P = lambda *cs: [hexc(c) for c in cs]  # noqa: E731

    def save(name, px, w=64, h=64):
        _save("tiles", name, w, h, px)

    tau = math.pi * 2
    # 水泥地（倉庫、車庫、軍事區）：32px 一塊的水泥板、伸縮縫、細裂縫、零星的坑
    rnd = random.Random(5)
    crack = set()
    cx, cy = 9, 38
    for _ in range(22):
        crack.add((cx % 64, cy % 64))
        cx += rnd.choice((1, 1, 0))
        cy += rnd.choice((-1, 0, 0, 1))

    def slab(x, y, v):
        if x % 32 == 0 or y % 32 == 0:
            return v - 2.3
        if x % 32 == 1 or y % 32 == 1:
            v += 0.5
        if (x, y) in crack:
            v -= 1.5
        r = hsh(x, y, 1)
        return v - 1.3 if r < 0.012 else (v + 0.9 if r > 0.992 else v)
    save("floor_slab", ftex(("#25282d", "#2b2f34", "#31353b", "#373b42", "#3d4249", "#444951"), 41, slab, 0.8))
    # 實驗室：整片的環氧樹脂地坪（幾乎沒有接縫、有一點反光的流痕、細碎的色片）
    def epoxy(x, y, v):
        if x % 64 == 0 or y % 64 == 0:
            return v - 1.1
        v += 0.45 * math.sin(tau * (x + y) / 32.0)
        r = hsh(x, y, 2)
        return v + 1.4 if r < 0.012 else (v - 1.1 if r > 0.99 else v)
    save("floor_epoxy", ftex(("#27333a", "#2b383f", "#2f3d44", "#33424a", "#38484f", "#3d4e56"), 42, epoxy, 0.55, 0.4))
    # 醫務室、浴廁：8px 的小磁磚，每塊深淺不同，有幾塊裂的
    def tile(x, y, v):
        if x % 8 == 0 or y % 8 == 0:
            return 0.3
        tv = hsh(x // 8, y // 8, 3)
        v = 3.0 + (tv - 0.5) * 1.6 + (v - 2.5) * 0.35
        if x % 8 == 1 or y % 8 == 1:
            v += 0.7
        return v - 1.3 if tv < 0.05 else v
    save("floor_tile", ftex(("#2a3336", "#323c40", "#3a464a", "#445055", "#4e5b60", "#5a686d"), 43, tile, 1.0, 0.3))
    # 餐廳、廚房：深淺相間的棋盤格
    def checker(x, y, v):
        dark = ((x // 8) + (y // 8)) % 2 == 0
        v = (1.1 if dark else 4.1) + (v - 2.5) * 0.45
        if x % 8 == 0 or y % 8 == 0:
            v -= 0.9
        return v
    save("floor_checker", ftex(("#24272b", "#2b2e33", "#33363b", "#504f49", "#5c5b54", "#68675f"), 44, checker, 1.0, 0.35))
    # 宿舍、休息室：亞麻地板（16px 一塊、暖色）
    def lino(x, y, v):
        if x % 16 == 0 or y % 16 == 0:
            return v - 1.3
        return v + (hsh(x // 16, y // 16, 4) - 0.5) * 1.3
    save("floor_lino", ftex(("#302f2a", "#37362f", "#3e3d35", "#46443a", "#4d4b40", "#555346"), 45, lino, 0.6, 0.4))
    # 辦公室：地毯（編織紋＋小菱形花紋）
    def carpet(x, y, v):
        v += 0.35 if (x + y) % 2 == 0 else -0.35
        dx, dy = abs(x % 16 - 8), abs(y % 16 - 8)
        if dx + dy == 6:
            v += 1.1
        elif dx + dy <= 1:
            v += 1.5
        return v
    save("floor_carpet", ftex(("#1c2431", "#212a39", "#263041", "#2b3749", "#313e52", "#37455b"), 46, carpet, 0.5, 0.3))
    # 劇院、郵輪：暗紅地毯（斜格紋）
    def carpet_red(x, y, v):
        v += 0.3 if (x + y) % 2 == 0 else -0.3
        if (x + y) % 16 == 0 or (x - y) % 16 == 0:
            v += 1.2
        return v
    save("floor_carpet_red", ftex(("#2a1014", "#34141a", "#3f1820", "#4a1d26", "#56222c", "#622833"), 47, carpet_red, 0.5, 0.3))
    # 木地板（小屋、酒吧）：橫的木板，每片深淺不同、接縫錯開、釘子
    def wood(x, y, v):
        r = y // 8
        off = (r * 23) % 32
        if y % 8 == 0:
            return v - 2.2
        if (x + off) % 32 == 0:
            return v - 1.8
        v += (hsh((x + off) // 32, r, 5) - 0.5) * 2.0 + 0.4 * math.sin(tau * x / 16.0 + r * 2.1)
        if y % 8 == 1:
            v += 0.5
        if (x + off) % 32 in (2, 30) and y % 8 == 4:
            v -= 1.6
        return v
    save("floor_wood", ftex(("#2b1e15", "#35261a", "#402e20", "#4b3726", "#57402c", "#634a33"), 48, wood, 0.5, 0.35))
    # 甲板：直的柚木條（8px 寬）、黑色填縫、日曬褪色
    def deck(x, y, v):
        c = x // 8
        if x % 8 == 0:
            return 0.0
        if (y + c * 19) % 32 == 0:
            return v - 1.8
        v += (hsh(c, (y + c * 19) // 32, 6) - 0.5) * 1.8 + 0.3 * math.sin(tau * y / 16.0 + c)
        if x % 8 == 1:
            v += 0.5
        return v
    save("floor_deck", ftex(("#3b2e21", "#473829", "#534231", "#604d3a", "#6d5843", "#7a644d"), 49, deck, 0.5, 0.35))
    # 花紋鋼板（機房、船艙）：32px 一塊、四角鉚釘、菱形防滑紋
    def plate(x, y, v):
        mx, my = x % 32, y % 32
        if mx == 0 or my == 0:
            return v - 2.2
        if mx == 1 or my == 1:
            v += 0.7
        if (mx, my) in ((3, 3), (29, 3), (3, 29), (29, 29)):
            return v + 2.2
        a = (x % 8, y % 8)
        if a in ((1, 2), (2, 3), (3, 4), (5, 6), (6, 5), (7, 4)):
            return v + 1.4
        if a in ((1, 3), (2, 4), (3, 5), (5, 7), (6, 6), (7, 5)):
            return v - 0.7
        return v
    save("floor_metal", ftex(("#1a1e23", "#20252b", "#272d34", "#2e353d", "#363e47", "#3f4852"), 50, plate, 0.6, 0.3))
    # 高架地板（通訊室、機房）：16px 的方板、四角螺絲，有幾片是通風孔板
    def access(x, y, v):
        mx, my = x % 16, y % 16
        if mx == 0 or my == 0:
            return 0.2
        tv = hsh(x // 16, y // 16, 7)
        v = 2.6 + (tv - 0.5) * 1.2 + (v - 2.5) * 0.3
        if mx == 1 or my == 1:
            v += 0.9
        if mx == 15 or my == 15:
            v -= 0.7
        if (mx, my) in ((3, 3), (13, 3), (3, 13), (13, 13)):
            return v + 1.6
        if tv < 0.15 and 4 <= mx <= 12 and 4 <= my <= 12 and mx % 2 == 0 and my % 2 == 0:
            return 0.2
        return v
    save("floor_access", ftex(("#1f242c", "#252b34", "#2b323c", "#323a45", "#3a434f", "#434d5a"), 51, access, 1.0, 0.3))
    # 碼頭：潮濕的水泥（偏冷、積水的地方有反光）
    wet = g.value_noise(64, 64, 16, 77)

    def dock(x, y, v):
        if x % 32 == 0 or y % 32 == 0:
            return v - 2.2
        if x % 32 == 1 or y % 32 == 1:
            v += 0.4
        k = wet(x, y)
        if k > 0.6:
            v += 0.7
            if y % 3 == 0 and hsh(x // 3, y, 8) > 0.45:
                v += 1.2
        elif k < 0.3:
            v -= 0.5
        return v
    save("floor_dock", ftex(("#1d2126", "#22272d", "#282e35", "#2f363e", "#374049", "#404a55"), 52, dock, 0.6, 0.35))
    # 雪地（壓實的雪）：很平、只有風吹出來的斜向雪紋和零星的亮點。Level 畫的時候會乘 1.5 倍亮度。
    def snowpack(x, y, v):
        v += 0.75 * math.sin(tau * (x + 3 * y) / 64.0 + 1.4 * math.sin(tau * y / 32.0))
        r = hsh(x, y, 9)
        return 5.4 if r > 0.994 else (v - 1.2 if r < 0.006 else v)
    save("floor_snowpack", ftex(("#586376", "#5e697c", "#646f83", "#6a7689", "#707c8f", "#778396"), 53, snowpack, 0.7, 0.5, cells=(32, 16)))
    # 柏油（戶外車道）、岩石地（洞穴）、冰面
    pal = P("#17181b", "#1e2023", "#26282c", "#2f3236", "#3a3d42")
    save("floor_asphalt", texture(64, 64, pal, 28, 0.5, 1.1))
    pal = P("#1a1e24", "#252b33", "#313943", "#3e4853", "#4d5864")
    save("floor_rock", texture(64, 64, pal, 29, 0.5, 1.5, None, lambda x, y, v: v - (0.25 if (x * 7 + y * 13) % 53 == 0 else 0)))
    pal = P("#2c4654", "#3a5a6c", "#4a7084", "#5e889c", "#7aa4b6")
    save("floor_ice", texture(64, 64, pal, 30, 0.5, 0.9, None, lambda x, y, v: v + (0.25 if abs((x - y * 0.6) % 37) < 0.8 else 0)))
    # 屋頂（從戶外看沒進去的建築）：浪板＋積雪
    pal = P("#14171c", "#1c2027", "#262b33", "#31373f", "#3d444d")
    save("roof_metal", texture(64, 64, pal, 31, 0.5, 0.4, lambda x, y: y % 64 == 0, lambda x, y, v: v + (0.14 if x % 4 == 0 else (-0.1 if x % 4 == 2 else 0))))
    # 積雪的屋頂：平整的雪，隱約看得到底下浪板的直條
    save("roof_snow", ftex(("#4c5666", "#525c6d", "#586374", "#5e697b", "#657082", "#6c7789"), 54,
                           lambda x, y, v: v + (0.7 if x % 8 == 0 else (-0.6 if x % 8 == 4 else 0)) + 0.5 * math.sin(tau * (x + 2 * y) / 64.0), 0.6, 0.4, cells=(32, 16)))
    # ── 牆頂（32x32）：畫成最後的顏色（Level 不再另外壓暗），乾淨、低對比，只有細的接縫
    def top(name, pal_hex, seed, fn, noise=0.5):
        save(name, ftex(pal_hex, seed, fn, noise, 0.3, 32, 32, (16, 8)), 32, 32)
    top("wall_slab", ("#1b1e24", "#1f2228", "#23272d", "#282c33", "#2d3239"), 61,
        lambda x, y, v: v - 1.3 if x % 32 == 0 else (v + (0.9 if hsh(x, y, 10) > 0.985 else 0)))
    top("wall_panel", ("#22272e", "#272c34", "#2c323b", "#323842", "#383f4a"), 62,
        lambda x, y, v: v - 1.5 if x % 16 == 0 else (v + 0.7 if x % 16 == 1 else v))
    top("wall_ship", ("#2e343c", "#343a43", "#3a414b", "#414853", "#48505c"), 63,
        lambda x, y, v: v - 1.4 if (y % 16 == 0 or x % 32 == 0) else (v + 1.6 if (x % 8 == 4 and y % 16 == 8) else v))
    top("wall_wood", ("#1f1711", "#261c15", "#2d2219", "#35281e", "#3d2f23"), 64,
        lambda x, y, v: v - 1.6 if y % 8 == 0 else v + 0.5 * math.sin(tau * x / 16.0 + (y // 8) * 2.3) + (hsh(x // 16, y // 8, 11) - 0.5), 0.4)
    top("wall_rock", ("#0f1217", "#14181e", "#1a1f27", "#212730", "#29303a"), 65, None, 1.4)
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


def gen_decal():
    """地板上的痕跡（半透明，畫在地板圖層、受光影響）和裝飾用的光暈（加色疊上去）。輸出到 decor/。"""
    def img(name, w, h, fn):
        _save("decor", name, w, h, [fn(x, y) or (0, 0, 0, 0) for y in range(h) for x in range(w)])

    def blob(x, y, cx, cy, rx, ry):
        return ((x - cx) / rx) ** 2 + ((y - cy) / ry) ** 2

    # 光暈：往外漸淡，階梯＋抖色（像素風，不用平滑漸層）
    def glow(w, h, power=1.6, peak=1.0):
        def fn(x, y):
            r = math.sqrt(blob(x + 0.5, y + 0.5, w / 2.0, h / 2.0, w / 2.0, h / 2.0))
            a = max(0.0, 1.0 - r) ** power * peak
            a = math.floor(a * 7 + BAYER4[y % 4][x % 4] / 16.0) / 7.0
            return (255, 255, 255, int(a * 255)) if a > 0 else None
        return fn
    img("glow_pool", 56, 40, glow(56, 40, 1.5))
    img("glow_small", 24, 24, glow(24, 24, 1.3))
    img("glow_wall", 28, 20, glow(28, 20, 1.2))
    # 積水：深色、邊緣一圈反光
    def puddle(x, y):
        k = blob(x + 0.5, y + 0.5, 8, 5, 7.5, 4.2) + 0.25 * math.sin(x * 1.3) * 0.3
        if k > 1.0:
            return None
        if k > 0.72 and y < 5:
            return (150, 186, 208, 120)
        if (x, y) in ((5, 3), (6, 3), (9, 6)):
            return (170, 200, 220, 150)
        return (8, 14, 22, 120)
    img("puddle", 16, 10, puddle)
    # 排水孔
    def drain(x, y):
        k = (x - 4) ** 2 + (y - 4) ** 2
        if k > 20:
            return None
        if k > 12:
            return (18, 20, 24, 255)
        return (4, 5, 7, 255) if y % 2 == 0 else (70, 76, 86, 255)
    img("drain", 9, 9, drain)
    # 人孔蓋
    def manhole(x, y):
        k = (x - 6.5) ** 2 + (y - 6.5) ** 2
        if k > 44:
            return None
        if k > 32:
            return (14, 16, 20, 255)
        return (58, 62, 70, 255) if (x + y) % 3 == 0 or (x - y) % 3 == 0 else (36, 40, 46, 255)
    img("manhole", 14, 14, manhole)
    # 大片的舊污漬（讓大廳的地板不會一成不變）
    stn = g.value_noise(32, 32, 8, 91)

    def stain(x, y):
        k = blob(x + 0.5, y + 0.5, 16, 12, 15, 11) + (stn(x, y) - 0.5) * 0.9
        if k > 0.95:
            return None
        a = 70 if k < 0.45 else 44
        return (6, 8, 12, a) if (BAYER4[y % 4][x % 4] > 3 or k < 0.3) else None
    img("stain", 32, 24, stain)
    # 輪胎的擦痕、裂縫、濕腳印、吹進來的雪
    def scuff(x, y):
        for k, (ox, oy) in enumerate(((0, 0), (3, 5))):
            xx, yy = x - ox, y - oy
            if 1 <= xx <= 12 and abs(yy - (3 + 0.06 * (xx - 6) ** 2)) < 0.9 and (xx + k) % 5 != 0:
                return (6, 7, 9, 90)
        return None
    img("scuff", 16, 12, scuff)
    rnd = random.Random(8)
    pts = set()
    cx, cy = 1, 6
    for _ in range(16):
        pts.add((cx, cy))
        cx += 1
        cy += rnd.choice((-1, 0, 0, 1))
        if rnd.random() < 0.2:
            pts.add((cx, cy + 1))
            pts.add((cx + 1, cy + 2))
    img("crack", 16, 16, lambda x, y: (6, 7, 9, 150) if (x, y) in pts else None)
    prints = {(2, 12), (3, 12), (2, 11), (3, 11), (2, 9), (3, 9), (7, 8), (8, 8), (7, 7), (8, 7), (7, 5), (8, 5), (3, 4), (4, 4), (3, 3), (4, 3), (3, 1), (4, 1)}
    img("bootprints", 12, 14, lambda x, y: (10, 14, 20, 110) if (x, y) in prints else None)

    def blown(x, y):
        k = blob(x + 0.5, y + 0.5, 8, 0, 8.5, 9) + (hsh(x, y, 12) - 0.5) * 0.7
        if k > 1.0:
            return None
        return (214, 226, 240, 190) if k < 0.5 else ((190, 204, 222, 130) if (x + y) % 2 == 0 else None)
    img("snow_blown", 16, 10, blown)
    # 雪地上的履帶／輪胎痕（橫、直各一張，一格一張接起來）
    def track(x, y):
        for c in (3, 11):
            if c <= y <= c + 2:
                if y == c + 2:
                    return (236, 242, 250, 40)
                return (30, 40, 60, 52 if (x + y) % 4 else 34)
        return None
    img("track_h", 16, 16, track)
    img("track_v", 16, 16, lambda x, y: track(y, x))
    # 地上漆的箭頭（車道、裝卸區），磨損的黃漆
    def arrow(x, y):
        on = (2 <= y <= 4 and 0 <= x <= 7) or (x >= 7 and abs(y - 3) <= 10 - x)
        if not on or hsh(x, y, 13) < 0.22:
            return None
        return (196, 156, 36, 150)
    img("arrow_r", 12, 7, arrow)
    img("arrow_l", 12, 7, lambda x, y: arrow(11 - x, y))
    print("decal: ok")


def main():
    args = sys.argv[1:]
    sheet = None
    if "--sheet" in args:
        i = args.index("--sheet")
        sheet = args[i + 1]
        del args[i:i + 2]
    which = args or ["set", "big", "landmark", "stash", "tiles", "wall", "decal"]
    for w in which:
        {"set": gen_set, "big": gen_big, "landmark": gen_landmark, "stash": gen_stash, "tiles": gen_tiles, "wall": gen_wall,
         "decal": gen_decal}[w]()
    if sheet:
        write_sheet(sheet)


if __name__ == "__main__":
    main()
