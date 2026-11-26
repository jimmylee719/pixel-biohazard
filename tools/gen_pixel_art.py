#!/usr/bin/env python3
"""像素美術產生器（純 Python 標準函式庫，不用任何外部套件）。

做法：每個角色／道具用簡單的 3D 形狀（橢球、膠囊、方塊）組成，
用同一台「3/4 俯視」正交攝影機逐像素射線投射，再套固定調色盤（每種材質 4 階明暗）＋描邊。
所以 5 個方向、每個動作格子都是同一個模型轉出來的：轉向流暢、比例一致、不會破圖。

執行：python3 tools/gen_pixel_art.py            （全部重新產生）
      python3 tools/gen_pixel_art.py player hound （只產生指定項目）
輸出：assets/sprites/<角色>/<動作>_<方向>_<格>.png、props/、fx/、tiles/
之後要跑一次 Godot --headless --path . --import。
"""
import math
import os
import random
import shutil
import struct
import sys
import zlib

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.normpath(os.path.join(HERE, "..", "assets", "sprites"))

# ── 小工具 ────────────────────────────────────────────────


def add(a, b): return (a[0] + b[0], a[1] + b[1], a[2] + b[2])
def sub(a, b): return (a[0] - b[0], a[1] - b[1], a[2] - b[2])
def mul(a, k): return (a[0] * k, a[1] * k, a[2] * k)
def dot(a, b): return a[0] * b[0] + a[1] * b[1] + a[2] * b[2]
def cross(a, b): return (a[1] * b[2] - a[2] * b[1], a[2] * b[0] - a[0] * b[2], a[0] * b[1] - a[1] * b[0])


def norm(a):
    l = math.sqrt(dot(a, a)) or 1.0
    return (a[0] / l, a[1] / l, a[2] / l)


def lerp(a, b, k): return a + (b - a) * k


def hexc(s):
    s = s.lstrip("#")
    return (int(s[0:2], 16), int(s[2:4], 16), int(s[4:6], 16))


IDENT = ((1, 0, 0), (0, 1, 0), (0, 0, 1))


def _lerp_any(a, b, k):
    if isinstance(a, (tuple, list)):
        return tuple(_lerp_any(x, y, k) for x, y in zip(a, b))
    return a + (b - a) * k


def bf(f, n):
    """呼吸、搖晃這類循環動作：0 → 1 → 0（首尾相接，循環播放不會跳）"""
    return 0.5 - 0.5 * math.cos(2 * math.pi * f / max(n, 1))


def kf(keys, f, n):
    """關鍵影格內插：n 格平均分佈在 keys 之間（smoothstep 緩入緩出），格數再多都流暢"""
    if n <= 1 or len(keys) == 1:
        return keys[min(f, len(keys) - 1)]
    t = f / (n - 1) * (len(keys) - 1)
    i = min(int(t), len(keys) - 2)
    k = t - i
    k = k * k * (3 - 2 * k)
    return _lerp_any(keys[i], keys[i + 1], k)


def basis_along(x_dir, up=(0, 0, 1)):
    """x 軸對準 x_dir 的座標系（給武器、刀子對齊手臂方向）"""
    x = norm(x_dir)
    if abs(dot(x, norm(up))) > 0.95:
        up = (0, 1, 0)
    y = norm(cross(up, x))
    z = cross(x, y)
    return (x, y, z)


def rot_z(v, ang):
    c, s = math.cos(ang), math.sin(ang)
    return (v[0] * c - v[1] * s, v[0] * s + v[1] * c, v[2])


def write_png(path, w, h, px):
    raw = bytearray()
    for y in range(h):
        raw.append(0)
        for x in range(w):
            raw.extend(px[y * w + x])

    def chunk(t, d):
        return struct.pack(">I", len(d)) + t + d + struct.pack(">I", zlib.crc32(t + d) & 0xFFFFFFFF)

    data = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", w, h, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(bytes(raw), 9)) + chunk(b"IEND", b""))
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "wb") as f:
        f.write(data)


# ── 調色盤：每種材質暗→亮 4 階 ──────────────────────────────

MATS = {
    # 主角：橘紅色極地外套、深藍褲子、黑靴、深色頭髮
    "parka": ["#3a1410", "#7a2a18", "#b8461e", "#e2733a"],
    "parka_trim": ["#3c3a3a", "#6e6a66", "#a39d94", "#d6d0c4"],
    "pants": ["#121624", "#1f2840", "#2f3c5c", "#475a80"],
    "boot": ["#0c0c0e", "#1c1c20", "#2e2e34", "#46464e"],
    "skin": ["#4a2a22", "#8a5640", "#c08466", "#e6b294"],
    "hair": ["#0e0a0a", "#22181a", "#3a2a2a", "#56403a"],
    "strap": ["#141210", "#2a2622", "#423c34", "#5e564a"],
    # 值班者：灰藍工作服、蒼白發青的皮膚、冰晶
    "coverall": ["#1a2228", "#2e3c46", "#475a66", "#667c88"],
    "pale": ["#3a4448", "#6a7a80", "#9aaab0", "#c6d4d8"],
    "crystal": ["#2a6a88", "#46a8cc", "#86dcf4", "#d4f6ff"],
    "frost": ["#5a6a78", "#8a9cac", "#bccbd8", "#eaf2f8"],
    # 鳴骨者：骨白、暗紅破布、深色結晶甲
    "bone": ["#4a4238", "#857a68", "#beb29c", "#e8e0cc"],
    "rag": ["#200c0c", "#3e1616", "#5c2420", "#7c3a30"],
    "chitin": ["#0e1218", "#1e2630", "#34404e", "#526070"],
    # 人類敵人（武裝人員）：橄欖綠迷彩、黑色防彈背心、頭盔
    "olive": ["#1a1e10", "#2e361c", "#47522c", "#647440"],
    "vest": ["#0c0e0e", "#1a1e1e", "#2a3030", "#404848"],
    "helmet": ["#14180e", "#262e1a", "#3c4628", "#56643a"],
    "goggle": ["#101820", "#204050", "#3a7890", "#7cc4dc"],
    "gunmetal": ["#08080a", "#16171a", "#26282c", "#3c4046"],
    "wood": ["#2a160c", "#4a2a16", "#6e4222", "#966034"],
    "steel": ["#262a30", "#4a5058", "#7a828c", "#b4bcc6"],
    "brass": ["#3a2a0c", "#7a5a1a", "#b88c2c", "#ecc65a"],
    # 獵犬：灰白毛、潰爛的粉紅色
    "fur": ["#2c2c30", "#56565c", "#88888e", "#bcbcc0"],
    "flesh": ["#3a1218", "#6e2430", "#a2404a", "#d4707a"],
    # 道具
    "locker": ["#1c2624", "#30403c", "#4a5e58", "#6a827a"],
    "cabinet": ["#22262c", "#3a4048", "#565e68", "#7a848e"],
    "benchtop": ["#4c5458", "#7c868a", "#a8b2b6", "#d2dade"],
    "vent": ["#06080a", "#101418", "#1c2228", "#2a3238"],
    "rock": ["#16181e", "#2a2e36", "#424852", "#5e6672"],
    "snow": ["#6a7888", "#98a8b8", "#c4d2e0", "#eef4fa"],
    "red": ["#3a0a0a", "#7a1616", "#b82424", "#e44a3a"],
    "white": ["#5a6068", "#9aa2aa", "#d0d6dc", "#f4f8fa"],
    "glass": ["#123024", "#22543e", "#3c8460", "#78c09a"],
    "cloth": ["#3a3226", "#6a5c46", "#9a8a6a", "#c8b894"],
    "orange": ["#4a1e06", "#8a3e0e", "#cc6a1c", "#f4a040"],
    "black": ["#050506", "#0e0e10", "#18181c", "#24242a"],
    "fire": ["#a83a08", "#e8741a", "#ffb43a", "#fff0a0"],
    "yellow": ["#3a2e06", "#7a620e", "#c09a1c", "#ecd050"],
    # 膨脹者：灰紫腫脹的皮、潰爛
    "bloat": ["#2a2430", "#4e4458", "#786c84", "#a89cb2"],
    "pus": ["#3a3a10", "#6e6a1c", "#a8a030", "#dcd468"],
    # 詠者：瘦長、灰白、喉嚨的結晶環
    "ash": ["#24262a", "#45484e", "#6e727a", "#9ca0a8"],
    # 裝備：防護衣（黃）、防爆裝甲（深綠）、潛行服（深灰藍）、極地套裝（白）、毛帽（紅）
    "hazmat": ["#4a3a08", "#8a7012", "#c8a42a", "#ecd468"],
    "eod": ["#121a12", "#243424", "#3a503a", "#56705a"],
    "sneak": ["#0c1016", "#1a222c", "#2c3846", "#445566"],
    "knit": ["#3a0c10", "#6e1a20", "#a0303a", "#cc5a5e"],
    # 深井的核心（脈衝後裂開露出來的弱點）
    "core": ["#7a2a10", "#c4501e", "#f08a3a", "#ffd08a"],
    # 深井的肉塊（被菌落融合的研究員）
    "mass": ["#14222a", "#24404c", "#3a6070", "#5a8494"],
}
MATS = {k: [hexc(c) for c in v] for k, v in MATS.items()}
EMISSIVE = {"crystal", "goggle", "fire", "core"}

# 攝影機：3/4 俯視（往下看 35 度）；光從左上前方來
PITCH = math.radians(35)
LIGHT = norm((-0.55, -0.6, 0.85))


# ── 形狀（射線求交）─────────────────────────────────────────

class Ell:
    def __init__(self, c, r, mat, basis=IDENT):
        self.c, self.r, self.mat, self.b = c, r, mat, basis

    def bound(self):
        return self.c, max(self.r)

    def hit(self, ro, rd):
        o = sub(ro, self.c)
        ex, ey, ez = self.b
        ol = (dot(ex, o) / self.r[0], dot(ey, o) / self.r[1], dot(ez, o) / self.r[2])
        dl = (dot(ex, rd) / self.r[0], dot(ey, rd) / self.r[1], dot(ez, rd) / self.r[2])
        a = dot(dl, dl)
        b = dot(ol, dl)
        c = dot(ol, ol) - 1.0
        h = b * b - a * c
        if h < 0:
            return None
        t = (-b - math.sqrt(h)) / a
        if t < 0:
            return None
        p = add(ol, mul(dl, t))
        nl = (p[0] / self.r[0], p[1] / self.r[1], p[2] / self.r[2])
        n = add(add(mul(ex, nl[0]), mul(ey, nl[1])), mul(ez, nl[2]))
        return t, norm(n)

    def moved(self, f):
        o = Ell(f(self.c), self.r, self.mat, tuple(f(v, True) for v in self.b))
        o.layer = getattr(self, "layer", False)
        return o

    def lowest(self):
        return self.c[2] - math.sqrt(sum((self.r[i] * self.b[i][2]) ** 2 for i in range(3)))


class Cap:
    """膠囊（手腳）：a 到 b、半徑 r（可以兩端不同粗細：ra、rb，用線性內插近似）"""

    def __init__(self, a, b, r, mat, rb=None):
        self.a, self.bp, self.r, self.mat = a, b, r, mat
        self.rb = r if rb is None else rb

    def bound(self):
        return mul(add(self.a, self.bp), 0.5), math.sqrt(dot(sub(self.bp, self.a), sub(self.bp, self.a))) * 0.5 + max(self.r, self.rb)

    def hit(self, ro, rd):
        if abs(self.r - self.rb) < 0.01:
            return self._hit_r(ro, rd, self.a, self.bp, self.r)
        # 粗細不同：切成三段近似
        best = None
        for i in range(3):
            k0, k1 = i / 3, (i + 1) / 3
            a = add(self.a, mul(sub(self.bp, self.a), k0))
            b = add(self.a, mul(sub(self.bp, self.a), k1))
            h = self._hit_r(ro, rd, a, b, lerp(self.r, self.rb, (k0 + k1) * 0.5))
            if h and (best is None or h[0] < best[0]):
                best = h
        return best

    @staticmethod
    def _hit_r(ro, rd, pa, pb, r):
        ba = sub(pb, pa)
        oa = sub(ro, pa)
        baba = dot(ba, ba)
        bard = dot(ba, rd)
        baoa = dot(ba, oa)
        rdoa = dot(rd, oa)
        oaoa = dot(oa, oa)
        a = baba - bard * bard
        b = baba * rdoa - baoa * bard
        c = baba * oaoa - baoa * baoa - r * r * baba
        h = b * b - a * c
        t = None
        if h >= 0 and a > 1e-9:
            tt = (-b - math.sqrt(h)) / a
            y = baoa + tt * bard
            if 0 < y < baba:
                t = tt
            else:
                oc = oa if y <= 0 else sub(ro, pb)
                b2 = dot(rd, oc)
                c2 = dot(oc, oc) - r * r
                h2 = b2 * b2 - c2
                if h2 > 0:
                    t = -b2 - math.sqrt(h2)
        elif h >= 0:
            pass
        if t is None or t < 0:
            # 平行於軸的情況：只檢查兩端的球
            for e in (pa, pb):
                oc = sub(ro, e)
                b2 = dot(rd, oc)
                c2 = dot(oc, oc) - r * r
                h2 = b2 * b2 - c2
                if h2 > 0:
                    tt = -b2 - math.sqrt(h2)
                    if tt > 0 and (t is None or tt < t):
                        t = tt
            if t is None or t < 0:
                return None
        p = add(ro, mul(rd, t))
        k = max(0.0, min(1.0, dot(sub(p, pa), ba) / (baba or 1.0)))
        n = norm(sub(p, add(pa, mul(ba, k))))
        return t, n

    def moved(self, f):
        o = Cap(f(self.a), f(self.bp), self.r, self.mat, self.rb)
        o.layer = getattr(self, "layer", False)
        return o

    def lowest(self):
        return min(self.a[2] - self.r, self.bp[2] - self.rb)


class Box:
    def __init__(self, c, h, mat, basis=IDENT):
        self.c, self.h, self.mat, self.b = c, h, mat, basis

    def bound(self):
        return self.c, math.sqrt(dot(self.h, self.h))

    def hit(self, ro, rd):
        o = sub(ro, self.c)
        ex, ey, ez = self.b
        ol = (dot(ex, o), dot(ey, o), dot(ez, o))
        dl = (dot(ex, rd), dot(ey, rd), dot(ez, rd))
        tn, tf, axis = -1e9, 1e9, 0
        for i in range(3):
            if abs(dl[i]) < 1e-9:
                if abs(ol[i]) > self.h[i]:
                    return None
                continue
            t1 = (-self.h[i] - ol[i]) / dl[i]
            t2 = (self.h[i] - ol[i]) / dl[i]
            if t1 > t2:
                t1, t2 = t2, t1
            if t1 > tn:
                tn, axis = t1, i
            tf = min(tf, t2)
        if tn > tf or tf < 0:
            return None
        nl = [0.0, 0.0, 0.0]
        nl[axis] = -1.0 if dl[axis] > 0 else 1.0
        n = add(add(mul(ex, nl[0]), mul(ey, nl[1])), mul(ez, nl[2]))
        return tn, n

    def moved(self, f):
        o = Box(f(self.c), self.h, self.mat, tuple(f(v, True) for v in self.b))
        o.layer = getattr(self, "layer", False)
        return o

    def lowest(self):
        return self.c[2] - sum(abs(self.h[i] * self.b[i][2]) for i in range(3))


# ── 算圖 ──────────────────────────────────────────────────

def render(prims, w, h, pitch=PITCH, anchor=None, outline=True, light=LIGHT, levels=(0.34, 0.58, 0.82), layer_only=False):
    ax, ay = anchor if anchor else (w / 2.0, h - 2.0)
    d = (0.0, math.cos(pitch), -math.sin(pitch))
    right = (1.0, 0.0, 0.0)
    up = (0.0, math.sin(pitch), math.cos(pitch))
    n = w * h
    depth = [1e9] * n
    nrm = [None] * n
    mats = [None] * n
    lay = [False] * n
    for p in prims:
        c, rad = p.bound()
        sx = ax + dot(c, right)
        sy = ay - dot(c, up)
        x0, x1 = max(0, int(sx - rad - 1)), min(w, int(sx + rad + 2))
        y0, y1 = max(0, int(sy - rad - 1)), min(h, int(sy + rad + 2))
        for py in range(y0, y1):
            b = ay - (py + 0.5)
            for px in range(x0, x1):
                a = px + 0.5 - ax
                ro = add(add(mul(right, a), mul(up, b)), mul(d, -200.0))
                r = p.hit(ro, d)
                if r is None:
                    continue
                i = py * w + px
                if r[0] < depth[i]:
                    depth[i] = r[0]
                    nrm[i] = r[1]
                    mats[i] = p.mat
                    lay[i] = getattr(p, "layer", False)
    out = [(0, 0, 0, 0)] * n
    idx = [0] * n
    for i in range(n):
        m = mats[i]
        if m is None:
            continue
        if callable(m):
            m = m(nrm[i])
            mats[i] = m
        v = 0.3 + 0.75 * max(0.0, dot(nrm[i], light)) + 0.12 * max(0.0, nrm[i][2])
        k = 0 if v < levels[0] else 1 if v < levels[1] else 2 if v < levels[2] else 3
        if m in EMISSIVE:
            k = max(k, 2)
        idx[i] = k
        c = MATS[m][k]
        out[i] = (c[0], c[1], c[2], 255)
    if not outline:
        return out
    # 內部描邊：前面有東西明顯比較近（手臂擋在身體前面）→ 這一格用最暗的顏色，分得出前後
    res = list(out)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if mats[i] is None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    j = yy * w + xx
                    if mats[j] is not None and depth[j] < depth[i] - 3.0 and mats[j] != mats[i]:
                        c = MATS[mats[i]][0]
                        res[i] = (c[0], c[1], c[2], 255)
                        break
    if layer_only:
        # 裝備圖層：只留裝備贏的像素，外面一圈描邊（疊在角色本體的圖上）
        final = [(0, 0, 0, 0)] * n
        for i in range(n):
            if lay[i]:
                final[i] = res[i]
        for y in range(h):
            for x in range(w):
                i = y * w + x
                if lay[i]:
                    continue
                for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                    xx, yy = x + dx, y + dy
                    if 0 <= xx < w and 0 <= yy < h and lay[yy * w + xx]:
                        if mats[i] is None or depth[i] > depth[yy * w + xx] + 1.5:
                            c = MATS[mats[yy * w + xx]][0]
                            final[i] = (c[0] // 2, c[1] // 2, c[2] // 2 + 4, 255)
                        break
        return final
    # 外描邊：輪廓外面一圈很暗的顏色（跟著旁邊的材質）
    final = list(res)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if mats[i] is not None:
                continue
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h and mats[yy * w + xx] is not None:
                    c = MATS[mats[yy * w + xx]][0]
                    final[i] = (c[0] // 2, c[1] // 2, c[2] // 2 + 4, 255)
                    break
    return final


# ── 人形骨架 ───────────────────────────────────────────────
# 區域座標：x 往前（面向）、y 往左、z 往上。最後依面向旋轉、並讓最低點貼地。

def leg_points(hip, a, k, lu, ll):
    knee = add(hip, (lu * math.sin(a), 0, -lu * math.cos(a)))
    foot = add(knee, (ll * math.sin(a - k), 0, -ll * math.cos(a - k)))
    return knee, foot


def arm_points(sh, side, a, b, e, lu, ll):
    """side：左 +1、右 -1；a 往前抬（0 = 自然下垂、π/2 = 平舉）；b 往外張（負的 = 往內）；e 手肘彎"""
    du = norm((math.sin(a), side * math.sin(b), -math.cos(a) * math.cos(b)))
    el = add(sh, mul(du, lu))
    df = norm((math.sin(a + e), side * math.sin(b) * 0.6, -math.cos(a + e) * math.cos(b)))
    hand = add(el, mul(df, ll))
    return el, hand, df


def lean_fn(pivot, ang):
    c, s = math.cos(ang), math.sin(ang)

    def f(v):
        x, y, z = sub(v, pivot)
        return add(pivot, (x * c + z * s, y, -x * s + z * c))
    return f


HUMAN = {
    "lu": 6.5, "ll": 6.5, "hip_w": 2.1, "leg_r": 1.9, "leg_r2": 1.5,
    "torso_len": 9.5, "torso_r": (3.2, 4.0, 5.2), "sh_w": 4.3, "au": 4.6, "al": 4.4, "arm_r": 1.5,
    "head_r": (3.1, 3.0, 3.3), "neck": 1.2,
}


def default_pose():
    return {
        "legs": {1: (0.0, 0.08), -1: (0.0, 0.08)},          # (大腿角度, 膝蓋彎)
        "arms": {1: (0.05, 0.12, 0.2), -1: (0.05, 0.12, 0.2)},  # (往前抬, 往外張, 手肘)
        "lean": 0.0, "head_pitch": 0.0, "head_roll": 0.0, "head_fwd": 0.0, "hip_drop": 0.0,
    }


def walk_pose(f, n, stride=0.5, knee=0.9, arm=0.45, lean=0.05):
    p = 2 * math.pi * f / n
    pose = default_pose()
    s = math.sin(p)
    pose["legs"] = {1: (stride * s, 0.1 + knee * max(0.0, math.cos(p))),
                    -1: (-stride * s, 0.1 + knee * max(0.0, -math.cos(p)))}
    pose["arms"] = {1: (-arm * s, 0.1, 0.25 + 0.2 * max(0, -s)), -1: (arm * s, 0.1, 0.25 + 0.2 * max(0, s))}
    pose["lean"] = lean
    return pose


HURT = [0.0]


def hurt_of(model, base_anim):
    """受傷動作：拿某個動作的第一格，整個人往後仰、手甩開（三格衰減）"""
    def m(anim, f, n):
        HURT[0] = kf([1.0, 0.6, 0.15], f, n)
        try:
            return model(base_anim, 0, 2)
        finally:
            HURT[0] = 0.0
    return m


def build_human(spec, pose, mats, extras=None):
    """回傳區域座標的形狀清單與關節位置"""
    if HURT[0] > 0:
        h = HURT[0]
        pose = dict(pose)
        pose["lean"] = pose.get("lean", 0.0) - 0.45 * h
        pose["head_pitch"] = pose.get("head_pitch", 0.0) - 0.5 * h
        pose["arms"] = {1: (0.5 * h, 0.7 * h + 0.1, 0.5), -1: (0.4 * h, 0.8 * h + 0.1, 0.6)}
    P = dict(HUMAN)
    P.update(spec)
    hip_z = P["lu"] + P["ll"] - pose.get("hip_drop", 0.0)
    pelvis = (0.0, 0.0, hip_z)
    prims = []
    J = {"pelvis": pelvis}
    # 腿
    for side in (1, -1):
        a, k = pose["legs"][side]
        hip = (0.0, side * P["hip_w"], hip_z)
        knee, foot = leg_points(hip, a, k, P["lu"], P["ll"])
        prims.append(Cap(hip, knee, P["leg_r"], mats["leg"], P["leg_r"] * 0.9))
        prims.append(Cap(knee, foot, P["leg_r2"], mats["leg"], P["leg_r2"] * 0.85))
        toe = add(foot, (1.9, 0, -0.2))
        prims.append(Cap(add(foot, (-0.6, 0, 0.0)), toe, 1.35, mats["boot"]))
        J["foot%d" % side] = foot
        J["knee%d" % side] = knee
    L = lean_fn(pelvis, pose["lean"])
    tl = P["torso_len"]
    # 軀幹：腰＋胸
    tr = P["torso_r"]
    prims.append(Ell(L(add(pelvis, (0, 0, tl * 0.22))), (tr[0] * 0.85, tr[1] * 0.82, tr[2] * 0.45), mats["hip"]))
    chest_c = L(add(pelvis, (0, 0, tl * 0.6)))
    prims.append(Ell(chest_c, tr, mats["torso"], basis_lean(pose["lean"])))
    J["chest"] = chest_c
    # 頭
    neck = L(add(pelvis, (0, 0, tl + P["neck"])))
    hr = P["head_r"]
    head_c = add(neck, (pose.get("head_fwd", 0.0), pose.get("head_side", 0.0), hr[2] * 0.85))
    hb = head_basis(pose.get("head_pitch", 0.0), pose.get("head_roll", 0.0))
    prims.append(Cap(L(add(pelvis, (0, 0, tl * 0.9))), head_c, 1.2, mats["skin"]))
    prims.append(Ell(head_c, hr, mats["skin"], hb))
    J["head"] = head_c
    J["head_basis"] = hb
    # 手臂
    for side in (1, -1):
        sh = L(add(pelvis, (0.0, side * P["sh_w"], tl * 0.86)))
        a, b, e = pose["arms"][side]
        el, hand, df = arm_points(sh, side, a, b, e, P["au"], P["al"])
        prims.append(Ell(sh, (1.9, 1.9, 1.9), mats["torso"]))
        prims.append(Cap(sh, el, P["arm_r"] * 1.1, mats["arm"], P["arm_r"]))
        prims.append(Cap(el, hand, P["arm_r"], mats["arm"], P["arm_r"] * 0.9))
        prims.append(Ell(hand, (1.2, 1.1, 1.2), mats["hand"]))
        J["hand%d" % side] = hand
        J["fore%d" % side] = df
        J["sh%d" % side] = sh
        J["elbow%d" % side] = el
    return prims, J


def basis_lean(l):
    c, s = math.cos(l), math.sin(l)
    return ((c, 0, -s), (0, 1, 0), (s, 0, c))


def head_basis(pitch, roll):
    # pitch 正 = 低頭（往前）、roll 正 = 往左歪
    cp, sp = math.cos(pitch), math.sin(pitch)
    cr, sr = math.cos(roll), math.sin(roll)
    x = (cp, 0, -sp)
    z = (sp, 0, cp)
    y = (0, 1, 0)
    # roll：繞 x 軸
    y2 = add(mul(y, cr), mul(z, sr))
    z2 = add(mul(z, cr), mul(y, -sr))
    return (x, y2, z2)


def face(J, mat="black"):
    """眼睛（兩個小點）"""
    return [Box(head_local(J, (2.75, y, 0.1)), (0.3, 0.45, 0.5), mat, J["head_basis"]) for y in (1.15, -1.15)]


def head_local(J, off):
    """頭的區域座標（x 前、y 左、z 上）→ 角色座標"""
    x, y, z = J["head_basis"]
    return add(J["head"], add(add(mul(x, off[0]), mul(y, off[1])), mul(z, off[2])))


def finish(prims, yaw):
    """依面向旋轉，並讓最低點貼地"""
    def f(v, is_dir=False):
        return rot_z(v, yaw)
    moved = [p.moved(f) for p in prims]
    low = min(p.lowest() for p in moved)

    def g(v, is_dir=False):
        return v if is_dir else (v[0], v[1], v[2] - low)
    return [p.moved(g) for p in moved]


# 5 個方向（往左的用水平翻轉）。遊戲的「下」= 面向攝影機 = 世界 -y
DIRS = {"right": 0.0, "downright": -math.pi / 4, "down": -math.pi / 2, "upright": math.pi / 4, "up": math.pi / 2}


# ── 武器（區域座標的形狀；x = 槍管方向）───────────────────────

def pistol(at, basis):
    def P(o): return add(at, add(add(mul(basis[0], o[0]), mul(basis[1], o[1])), mul(basis[2], o[2])))
    return [Box(P((2.2, 0, 1.0)), (2.8, 0.55, 0.85), "gunmetal", basis),
            Box(P((0.2, 0, -0.6)), (0.8, 0.5, 1.3), "black", basis)]


def long_gun(at, basis, length=11.0, stock="wood"):
    def P(o): return add(at, add(add(mul(basis[0], o[0]), mul(basis[1], o[1])), mul(basis[2], o[2])))
    return [Box(P((length * 0.35, 0, 0.6)), (length * 0.5, 0.55, 0.7), "gunmetal", basis),
            Box(P((length * 0.45, 0, -0.3)), (length * 0.22, 0.6, 0.6), stock, basis),
            Box(P((-2.6, 0, -0.4)), (2.4, 0.6, 1.0), stock, basis)]


def axe(at, d):
    b = basis_along(d)

    def P(o): return add(at, add(add(mul(b[0], o[0]), mul(b[1], o[1])), mul(b[2], o[2])))
    return [Box(P((3.0, 0, 0)), (4.2, 0.45, 0.45), "wood", b), Box(P((6.6, 0, 1.4)), (1.0, 0.35, 1.8), "red", b),
            Box(P((6.6, 0, 3.0)), (1.3, 0.3, 0.4), "steel", b)]


def knife(at, d):
    b = basis_along(d)

    def P(o): return add(at, add(add(mul(b[0], o[0]), mul(b[1], o[1])), mul(b[2], o[2])))
    return [Box(P((0.2, 0, 0)), (1.0, 0.5, 0.5), "black", b), Box(P((3.2, 0, 0)), (2.2, 0.25, 0.55), "steel", b)]


# ── 角色 ─────────────────────────────────────────────────

## 主角的服裝（紙娃娃）：body = 本體的套裝；head / feet = 疊在上面的圖層；layer = 這次只輸出哪一層
OUTFIT = {"body": "parka", "head": "", "feet": "", "layer": ""}
BODY_STYLE = {
    "parka": ({"leg": "pants", "hip": "pants", "torso": "parka", "arm": "parka", "hand": "skin"}, {}),
    "hazmat": ({"leg": "hazmat", "hip": "hazmat", "torso": "hazmat", "arm": "hazmat", "hand": "black"},
               {"torso_r": (3.7, 4.5, 5.6)}),
    "eod": ({"leg": "eod", "hip": "eod", "torso": "eod", "arm": "eod", "hand": "black"},
            {"torso_r": (4.4, 5.2, 6.0), "arm_r": 2.0, "leg_r": 2.4, "leg_r2": 2.0, "sh_w": 4.8}),
    "sneak": ({"leg": "sneak", "hip": "sneak", "torso": "sneak", "arm": "sneak", "hand": "sneak"},
              {"torso_r": (3.0, 3.9, 5.2), "arm_r": 1.35}),
    "arctic": ({"leg": "white", "hip": "white", "torso": "white", "arm": "white", "hand": "black"},
               {"torso_r": (3.6, 4.4, 5.5)}),
}


def gear_prims(J, slot, gear_id):
    """頭部、腳部裝備的形狀（標記成圖層）"""
    p = []
    hb = J["head_basis"]
    if slot == "head":
        if gear_id == "gas_mask":
            p += [Ell(head_local(J, (-0.8, 0, 0.1)), (4.1, 3.75, 4.4), "hazmat"),
                  Box(head_local(J, (2.9, 0, 0.3)), (0.5, 2.0, 0.9), "goggle", hb),
                  Cap(head_local(J, (2.8, 0, -1.4)), head_local(J, (3.9, 0, -2.0)), 1.1, "black", 0.9)]
        elif gear_id == "eod_helmet":
            p += [Ell(head_local(J, (-0.6, 0, 0.4)), (4.4, 4.2, 4.6), "eod"),
                  Box(head_local(J, (3.3, 0, 0.3)), (0.5, 2.6, 1.8), "glass", hb)]
        elif gear_id == "balaclava":
            p += [Ell(head_local(J, (0.0, 0, 0.0)), (3.25, 3.15, 3.45), "black")]
            p += [Box(head_local(J, (3.15, y, 0.2)), (0.3, 0.55, 0.35), "white", hb) for y in (1.1, -1.1)]
        elif gear_id == "snow_goggles":
            p += [Ell(head_local(J, (0.0, 0, 0.5)), (3.25, 3.35, 1.0), "black"),
                  Box(head_local(J, (3.0, 0, 0.4)), (0.4, 2.2, 0.8), "orange", hb)]
        elif gear_id == "wool_hat":
            p += [Ell(head_local(J, (-0.3, 0, 1.8)), (3.3, 3.4, 2.2), "knit"),
                  Ell(head_local(J, (-0.6, 0, 4.1)), (1.0, 1.0, 1.0), "white")]
    elif slot == "feet":
        mat = {"hazmat_boots": "hazmat", "eod_boots": "eod", "crampons": "steel", "soft_soles": "sneak"}.get(gear_id, "boot")
        big = 1.8 if gear_id == "eod_boots" else 1.5
        for side in (1, -1):
            foot = J["foot%d" % side]
            knee = J["knee%d" % side]
            ankle = add(foot, mul(sub(knee, foot), 0.3))
            p.append(Cap(add(foot, (-0.7, 0, 0.0)), add(foot, (2.1, 0, -0.1)), big, mat))
            if gear_id != "soft_soles":
                p.append(Cap(foot, ankle, big * 0.95, mat))
            if gear_id == "crampons":
                p.append(Box(add(foot, (0.6, 0, -1.4)), (1.8, 0.9, 0.25), "gunmetal"))
    for q in p:
        q.layer = OUTFIT["layer"] == slot
    return p


def player_model(anim, f, n, pose_only=False):
    body_mats, body_spec = BODY_STYLE[OUTFIT["body"]]
    mats = {"leg": "pants", "boot": "boot", "hip": "pants", "torso": "parka", "arm": "parka", "hand": "skin",
            "skin": "skin"}
    mats.update(body_mats)
    spec = {"torso_r": (3.4, 4.2, 5.4), "lu": 6.3, "ll": 6.3}
    spec.update(body_spec)
    weapon = []
    if anim == "idle":
        pose = default_pose()
        pose["arms"][1] = (0.05, 0.14 + 0.03 * bf(f, n), 0.25)
        pose["arms"][-1] = (0.05, 0.14 + 0.03 * bf(f, n), 0.25)
        pose["hip_drop"] = 0.3 * bf(f, n)
    elif anim == "walk":
        pose = walk_pose(f, n)
    elif anim == "sneak":
        pose = walk_pose(f, n, stride=0.35, knee=0.6, arm=0.15, lean=0.32)
        for s in (1, -1):
            a, k = pose["legs"][s]
            pose["legs"][s] = (a + 0.75, k + 1.25)
        pose["arms"] = {1: (0.3, 0.25, 0.45), -1: (0.35 + 0.08 * math.sin(2 * math.pi * f / n), 0.2, 0.45)}
        pose["head_fwd"] = 0.6
    elif anim == "aim_pistol":
        pose = default_pose()
        pose["legs"] = {1: (0.2, 0.15), -1: (-0.2, 0.15)}
        pose["arms"] = {1: (1.5, -0.42, 0.0), -1: (1.5, -0.45, 0.0)}
    elif anim.startswith("shoot_"):
        # 開槍：從瞄準姿勢往上、往後彈（後座力），再回到瞄準
        base = player_model("aim_" + anim[6:], 0, 1, pose_only=True)
        pose = base
        r = kf([1.0, 0.55, 0.15], f, n)
        heavy = 1.6 if anim[6:] in ("shotgun", "rifle") else 1.0
        for s_ in (1, -1):
            a, b, e = pose["arms"][s_]
            pose["arms"][s_] = (a + 0.22 * r * heavy, b, e + 0.3 * r * heavy)
        pose["lean"] = pose.get("lean", 0.0) - 0.1 * r * heavy
    elif anim == "dodge":
        # 往前撲：壓低身體往前衝、手往前伸，落地收回
        pose = default_pose()
        pose["lean"] = kf([0.25, 0.85, 1.05, 0.6, 0.15], f, n)
        pose["hip_drop"] = kf([1.0, 3.5, 4.5, 3.0, 0.8], f, n)
        pose["legs"] = {1: kf([(0.5, 0.9), (0.9, 1.6), (1.0, 1.8), (0.7, 1.2), (0.3, 0.4)], f, n),
                        -1: kf([(-0.3, 0.6), (-0.9, 0.4), (-1.1, 0.3), (-0.5, 0.8), (-0.1, 0.3)], f, n)}
        pose["arms"] = {1: kf([(0.6, 0.3, 0.6), (1.2, 0.2, 0.2), (1.4, 0.3, 0.1), (0.9, 0.3, 0.5), (0.3, 0.2, 0.3)], f, n),
                        -1: kf([(0.4, 0.3, 0.7), (1.1, 0.25, 0.3), (1.3, 0.35, 0.1), (0.8, 0.3, 0.5), (0.3, 0.2, 0.3)], f, n)}
    elif anim == "dodge_back":
        # 往後跳：身體後仰、雙腳離地往後，手維持在前面（瞄準中）
        pose = default_pose()
        pose["lean"] = kf([-0.1, -0.35, -0.4, -0.2, 0.0], f, n)
        pose["hip_drop"] = kf([1.5, 0.0, -0.5, 0.5, 1.2], f, n)
        pose["legs"] = {1: kf([(0.3, 0.6), (0.6, 1.0), (0.5, 0.8), (0.3, 0.5), (0.1, 0.3)], f, n),
                        -1: kf([(-0.2, 0.4), (-0.6, 0.9), (-0.7, 1.0), (-0.3, 0.5), (0.0, 0.2)], f, n)}
        pose["arms"] = {1: (1.3, -0.3, 0.3), -1: (1.25, -0.35, 0.3)}
    elif anim == "hurt":
        pose = default_pose()
        r = kf([1.0, 0.6, 0.15], f, n)
        pose["lean"] = -0.4 * r
        pose["arms"] = {1: (0.6 * r, 0.5 * r + 0.1, 0.6), -1: (0.5 * r, 0.6 * r + 0.1, 0.7)}
        pose["head_pitch"] = -0.4 * r
        pose["legs"] = {1: (-0.2 * r, 0.2), -1: (0.15 * r, 0.3)}
    elif anim in ("aim_nailgun", "aim_flare_gun"):
        pose = default_pose()
        pose["legs"] = {1: (0.2, 0.15), -1: (-0.2, 0.15)}
        pose["arms"] = {1: (1.5, -0.42, 0.0), -1: (1.5, -0.45, 0.0)}
    elif anim in ("aim_shotgun", "aim_rifle"):
        pose = default_pose()
        pose["legs"] = {1: (0.25, 0.15), -1: (-0.2, 0.15)}
        pose["arms"] = {1: (1.35, -0.3, 0.2), -1: (0.75, 0.05, 1.3)}
    elif anim in ("slash", "slash_axe"):
        pose = default_pose()
        pose["legs"] = {1: (0.35, 0.2), -1: (-0.3, 0.2)}
        keys = [(0.3, 1.0, 1.6), (1.35, -0.2, 0.15), (0.9, -0.85, 0.1)]
        pose["arms"] = {1: (0.4, 0.2, 0.9), -1: kf(keys, f, n)}
        pose["lean"] = kf([0.0, 0.18, 0.12], f, n)
    elif anim == "punch":
        pose = default_pose()
        pose["legs"] = {1: (0.35, 0.2), -1: (-0.3, 0.2)}
        keys = [(0.9, 0.1, 1.7), (1.5, -0.2, 0.0), (1.1, 0.0, 1.1)]
        pose["arms"] = {1: (0.9, 0.15, 1.6), -1: kf(keys, f, n)}
        pose["lean"] = kf([0.0, 0.2, 0.1], f, n)
    elif anim == "kick":
        pose = default_pose()
        keys = [(1.1, 1.6), (1.55, 0.05), (0.8, 1.3)]
        pose["legs"] = {1: (-0.05, 0.1), -1: kf(keys, f, n)}
        pose["arms"] = {1: (0.6, 0.5, 0.9), -1: (0.4, 0.6, 0.9)}
        pose["lean"] = kf([-0.1, -0.28, -0.12], f, n)
    else:
        raise ValueError(anim)
    if pose_only:
        return pose
    prims, J = build_human(spec, pose, mats)
    gun = anim[6:] if anim.startswith("shoot_") else (anim[4:] if anim.startswith("aim_") else "")
    anim = ("aim_" + gun) if gun else anim
    # 頭髮（後腦的馬尾）、外套的毛領、斜背包
    prims.append(Ell(head_local(J, (-1.1, 0, 0.9)), (2.9, 3.25, 2.9), "hair"))
    prims.append(Ell(head_local(J, (-2.8, 0, -1.6)), (1.4, 1.2, 2.4), "hair"))
    prims += face(J)
    body = OUTFIT["body"]
    if body in ("parka", "arctic"):
        prims.append(Ell(add(J["chest"], (-0.4, 0, 3.6)), (3.2, 4.0, 1.4), "parka_trim" if body == "parka" else "fur"))
    elif body == "eod":
        prims.append(Box(add(J["chest"], (0.6, 0, 0.5)), (4.4, 4.6, 3.6), "eod", basis_lean(0.0)))
        prims.append(Ell(add(J["chest"], (-0.2, 0, 4.2)), (3.6, 4.8, 1.6), "eod"))
    elif body == "hazmat":
        prims.append(Ell(add(J["chest"], (-0.4, 0, 3.8)), (3.0, 3.8, 1.2), "hazmat"))
    prims.append(Box(add(J["chest"], (-3.4 - (0.8 if body == "eod" else 0.0), 1.6, -1.0)), (1.2, 2.2, 2.6), "strap"))
    if OUTFIT["layer"] in ("head", "feet"):
        gid = OUTFIT[OUTFIT["layer"]]
        prims += gear_prims(J, OUTFIT["layer"], gid)
    if anim == "aim_pistol":
        hand = mul(add(J["hand1"], J["hand-1"]), 0.5)
        prims += pistol(add(hand, (0.4, 0, 0.3)), basis_along((1, 0, 0)))
    elif anim == "aim_shotgun":
        prims += long_gun(add(J["hand-1"], (0.0, 0.0, 0.6)), basis_along((1, 0, 0.04)), 13.0)
    elif anim == "aim_rifle":
        prims += long_gun(add(J["hand-1"], (0.0, 0.0, 0.6)), basis_along((1, 0, 0.04)), 17.0)
        prims.append(Box(add(J["hand-1"], (4.0, 0, 2.0)), (2.0, 0.5, 0.5), "black"))  # 瞄準鏡
    elif anim in ("aim_nailgun", "aim_flare_gun"):
        hand = mul(add(J["hand1"], J["hand-1"]), 0.5)
        mat = "yellow" if anim == "aim_nailgun" else "orange"
        prims += [Box(add(hand, (2.6, 0, 1.3)), (3.0, 0.8, 1.1), mat), Box(add(hand, (0.4, 0, -0.3)), (0.8, 0.6, 1.3), "black")]
    elif anim == "slash":
        prims += knife(J["hand-1"], J["fore-1"])
    elif anim == "slash_axe":
        prims += axe(J["hand-1"], J["fore-1"])
    return prims


def watcher_model(anim, f, n):
    mats = {"leg": "coverall", "boot": "boot", "hip": "coverall", "torso": "coverall", "arm": "coverall",
            "hand": "pale", "skin": "pale"}
    spec = {"torso_r": (3.3, 4.2, 5.3)}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.38, knee=0.7, arm=0.12, lean=0.38)
        # 拖著走：一隻腳比較僵硬
        a, k = pose["legs"][-1]
        pose["legs"][-1] = (a * 0.6, k * 0.4)
        pose["arms"] = {1: (0.2 + 0.08 * math.sin(2 * math.pi * f / n), 0.18, 0.1),
                        -1: (0.35, 0.1, 0.2)}
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.42
        pose["arms"] = {1: (0.25, 0.15, 0.1), -1: (0.3, 0.12, 0.15)}
        pose["head_roll"] = 0.25 + 0.08 * bf(f, n)
    elif anim == "attack":
        pose = default_pose()
        pose["legs"] = {1: (0.4, 0.3), -1: (-0.35, 0.2)}
        k = kf([(1.0, 0.25, 0.9), (1.55, 0.1, 0.05), (1.3, -0.05, 0.3)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.3, 0.55, 0.45], f, n)
    else:
        raise ValueError(anim)
    pose["head_pitch"] = pose.get("head_pitch", 0.0) + 0.45
    pose["head_fwd"] = 1.0
    prims, J = build_human(spec, pose, mats)
    # 冰晶：從背後、肩膀長出來
    back = add(J["chest"], (-3.0, 0, 1.0))
    for off, d, ln in (((0, 1.5, 1.5), (-0.6, 0.5, 1.0), 3.6), ((0, -1.2, 0.5), (-0.7, -0.4, 0.8), 3.0),
                       ((0.3, 0.3, 3.0), (-0.3, 0.1, 1.0), 2.6)):
        base = add(back, off)
        prims.append(Cap(base, add(base, mul(norm(d), ln)), 0.95, "crystal", 0.35))
    prims.append(Cap(add(J["sh1"], (0, 0.5, 1)), add(J["sh1"], (-0.5, 1.6, 3.2)), 0.8, "crystal", 0.3))
    # 頭上結霜
    prims.append(Ell(head_local(J, (-1.4, 0.4, 2.0)), (1.8, 2.0, 1.2), "frost"))
    prims += face(J, "vent")
    return prims


def listener_model(anim, f, n):
    mats = {"leg": "bone", "boot": "bone", "hip": "rag", "torso": "rag", "arm": "bone", "hand": "bone",
            "skin": "bone"}
    spec = {"lu": 7.6, "ll": 7.4, "torso_len": 10.5, "torso_r": (2.8, 3.6, 5.6), "leg_r": 1.4, "leg_r2": 1.1,
            "au": 6.0, "al": 6.2, "arm_r": 1.05, "head_r": (2.6, 2.4, 4.0), "hip_w": 1.8, "sh_w": 3.8}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.42, knee=0.9, arm=0.3, lean=0.2)
        for s in (1, -1):
            a, b, e = pose["arms"][s]
            pose["arms"][s] = (a + 0.15, 0.3, 0.15)
        pose["head_roll"] = 0.15 * math.sin(2 * math.pi * f / n)
    elif anim == "listen":
        pose = default_pose()
        pose["lean"] = 0.12
        pose["arms"] = {1: (0.35, 0.75 + 0.05 * bf(f, n), 0.3), -1: (0.3, 0.7 + 0.05 * bf(f, n), 0.35)}
        pose["head_roll"] = 0.55 + 0.1 * bf(f, n)
        pose["head_pitch"] = -0.35
    elif anim == "attack":
        pose = default_pose()
        pose["legs"] = {1: (0.45, 0.35), -1: (-0.4, 0.25)}
        k = kf([(0.6, 0.9, 1.2), (1.5, 0.2, 0.05), (1.2, -0.1, 0.2)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.15, 0.45, 0.35], f, n)
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    # 長頭的骨冠、背上的骨刺、結晶甲片
    prims.append(Cap(head_local(J, (-0.4, 0, 2.6)), head_local(J, (-2.2, 0, 5.6)), 1.0, "bone", 0.4))
    prims.append(Box(head_local(J, (2.1, 0, -0.6)), (0.4, 1.7, 0.25), "chitin", J["head_basis"]))
    for i, z in enumerate((2.0, 4.0, 6.0)):
        base = add(J["chest"], (-2.6, 0, z - 3.5))
        prims.append(Cap(base, add(base, (-2.4, 0.0, 0.8)), 0.8, "chitin", 0.25))
    prims.append(Ell(add(J["chest"], (0.8, 0, 0.5)), (2.2, 3.2, 2.6), "chitin"))
    return prims


def guard_model(anim, f, n):
    mats = {"leg": "olive", "boot": "boot", "hip": "olive", "torso": "olive", "arm": "olive", "hand": "black",
            "skin": "black"}
    spec = {"torso_r": (3.5, 4.4, 5.4), "sh_w": 4.6}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.45, knee=0.8, arm=0.0, lean=0.12)
        bob = 0.05 * math.sin(4 * math.pi * f / n)
        pose["arms"] = {1: (0.95 + bob, -0.25, 0.75), -1: (0.55 + bob, 0.05, 1.05)}
        aim = False
    elif anim == "idle":
        pose = default_pose()
        pose["arms"] = {1: (0.9, -0.25, 0.75 + 0.05 * bf(f, n)), -1: (0.5, 0.05, 1.05 + 0.05 * bf(f, n))}
        aim = False
    elif anim == "aim":
        pose = default_pose()
        pose["legs"] = {1: (0.3, 0.2), -1: (-0.25, 0.2)}
        pose["arms"] = {1: (1.45, -0.35, 0.15), -1: (0.85, 0.0, 1.35)}
        pose["lean"] = 0.08
        aim = True
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    # 防彈背心、頭盔、護目鏡、背後的無線電
    prims.append(Ell(add(J["chest"], (0.2, 0, -0.2)), (3.7, 4.5, 4.0), "vest"))
    prims.append(Ell(head_local(J, (-0.2, 0, 1.0)), (3.4, 3.3, 2.6), "helmet"))
    prims.append(Box(head_local(J, (2.7, 0, 0.5)), (0.5, 2.0, 0.7), "goggle", J["head_basis"]))
    prims.append(Box(add(J["chest"], (-3.8, -1.4, 0.8)), (1.0, 1.4, 2.4), "vest"))
    prims.append(Cap(add(J["chest"], (-4.2, -2.2, 3.0)), add(J["chest"], (-4.6, -2.6, 8.0)), 0.25, "black"))
    if aim:
        prims += long_gun(add(J["hand-1"], (0.0, 0.0, 0.3)), basis_along((1, 0, 0.02)), 12.0, "black")
    else:
        d = norm((1.0, 0.25, -0.5))
        prims += long_gun(add(J["hand-1"], (0.0, 0.0, 0.0)), basis_along(d), 12.0, "black")
    return prims


def hound_model(anim, f, n):
    prims = []
    bz = 8.0
    lean = 0.0
    head_drop = 0.0
    if anim == "walk":
        p = 2 * math.pi * f / n
        legs = {}
        for name, ph in (("fl", 0), ("br", 0), ("fr", math.pi), ("bl", math.pi)):
            s = math.sin(p + ph)
            legs[name] = (0.55 * s, 0.2 + 0.9 * max(0, math.cos(p + ph)))
    elif anim == "idle":
        legs = {k: (0.0, 0.15) for k in ("fl", "fr", "bl", "br")}
        head_drop = 0.6 * bf(f, n)
    elif anim == "attack":
        k = kf([((-0.3, 0.2), (0.35, 0.5)), ((0.9, 0.6), (0.6, 0.3)), ((0.5, 0.3), (0.2, 0.2))], f, n)
        legs = {"fl": k[0], "fr": k[0], "bl": k[1], "br": k[1]}
        lean = kf([-0.15, 0.25, 0.1], f, n)
    else:
        raise ValueError(anim)
    L = lean_fn((0, 0, bz), lean)
    # 身體、胸口、潰爛處
    prims.append(Ell(L((-1.0, 0, bz + 0.8)), (8.0, 3.3, 3.6), "fur"))
    prims.append(Ell(L((4.5, 0, bz + 1.0)), (3.6, 3.6, 4.0), "fur"))
    prims.append(Ell(L((-0.5, 1.8, bz + 1.4)), (3.0, 1.8, 2.0), "flesh"))
    # 頭
    hc = L((9.0, 0, bz + 3.0 - head_drop))
    prims.append(Ell(hc, (3.0, 2.5, 2.6), "fur"))
    prims.append(Ell(add(hc, (2.8, 0, -0.8)), (2.4, 1.4, 1.3), "flesh"))
    prims.append(Box(add(hc, (-0.8, 1.6, 2.2)), (0.6, 0.4, 1.3), "fur"))
    prims.append(Box(add(hc, (-0.8, -1.6, 2.2)), (0.6, 0.4, 1.3), "fur"))
    # 背上的冰晶
    for x, ln in ((-4.0, 2.4), (-1.0, 3.2), (2.0, 2.6)):
        base = L((x, 0, bz + 3.6))
        prims.append(Cap(base, add(base, (-0.8, 0, ln)), 0.8, "crystal", 0.3))
    # 尾巴
    prims.append(Cap(L((-8.5, 0, bz + 1.5)), L((-12.0, 0, bz + 3.5)), 1.0, "fur", 0.5))
    # 腳
    for name, x, y in (("fl", 5.0, 2.2), ("fr", 5.0, -2.2), ("bl", -6.0, 2.0), ("br", -6.0, -2.0)):
        a, k = legs[name]
        hip = L((x, y, bz))
        kn, ft = leg_points(hip, a, k if name[0] == "b" else -k, 4.2, 4.4)
        prims.append(Cap(hip, kn, 1.4, "fur", 1.1))
        prims.append(Cap(kn, ft, 1.0, "fur", 0.8))
    return prims


def crawler_model(anim, f, n):
    """爬行者：四肢著地、貼著地面爬的感染者（看不見，靠聽）"""
    prims = []
    bz = 4.5
    lift = 0.0
    if anim == "walk":
        p = 2 * math.pi * f / n
        ph = {"fl": 0, "br": 0, "fr": math.pi, "bl": math.pi}
        legs = {k: (0.6 * math.sin(p + v), 0.3 + 0.8 * max(0, math.cos(p + v))) for k, v in ph.items()}
    elif anim == "idle":
        legs = {k: (0.1, 0.4) for k in ("fl", "fr", "bl", "br")}
        lift = 0.5 * bf(f, n)
    elif anim == "attack":
        k = kf([((-0.4, 0.6), (0.3, 0.8)), ((1.2, 0.2), (0.5, 0.4)), ((0.7, 0.4), (0.3, 0.5))], f, n)
        legs = {"fl": k[0], "fr": k[0], "bl": k[1], "br": k[1]}
        lift = kf([0.0, 2.0, 1.0], f, n)
    else:
        raise ValueError(anim)
    # 身體（拉長的人形軀幹，背上冰晶）
    prims.append(Ell((0.0, 0, bz + 1.5 + lift), (7.0, 3.6, 2.6), "coverall"))
    prims.append(Ell((-5.5, 0, bz + 1.0), (3.0, 3.0, 2.2), "coverall"))
    hc = (7.5, 0, bz + 1.6 + lift)
    prims.append(Ell(hc, (2.8, 2.6, 2.4), "pale"))
    prims.append(Box(add(hc, (2.4, 0, -0.6)), (0.5, 1.6, 0.5), "vent"))  # 張開的嘴
    for x in (-2.0, 1.5):
        base = (x, 0, bz + 3.6 + lift)
        prims.append(Cap(base, add(base, (-0.8, 0.3, 2.6)), 0.8, "crystal", 0.3))
    # 手腳：前面是長手臂、後面是腿
    for name, x, y, lu, ll, mat in (("fl", 4.5, 3.2, 5.0, 5.5, "pale"), ("fr", 4.5, -3.2, 5.0, 5.5, "pale"),
                                     ("bl", -5.5, 2.8, 4.0, 4.5, "coverall"), ("br", -5.5, -2.8, 4.0, 4.5, "coverall")):
        a, k = legs[name]
        hip = (x, y, bz + 1.0 + lift)
        kn, ft = leg_points(hip, a + (0.5 if name[0] == "f" else -0.5), k if name[0] == "b" else -k, lu, ll)
        kn = add(kn, (0, y * 0.4, 1.5))
        prims.append(Cap(hip, kn, 1.1, mat, 0.9))
        prims.append(Cap(kn, ft, 0.9, mat, 0.7))
    return prims


def husk_model(anim, f, n):
    """膨脹者：全身腫脹、慢、很耐打，抓到會大量感染"""
    mats = {"leg": "bloat", "boot": "bloat", "hip": "bloat", "torso": "bloat", "arm": "bloat", "hand": "bloat",
            "skin": "bloat"}
    spec = {"torso_r": (6.0, 6.8, 7.0), "torso_len": 10.0, "lu": 5.5, "ll": 5.0, "leg_r": 2.8, "leg_r2": 2.4,
            "sh_w": 6.2, "au": 5.0, "al": 5.0, "arm_r": 2.2, "head_r": (2.6, 2.6, 2.6), "hip_w": 3.2}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.3, knee=0.4, arm=0.15, lean=0.15)
        for s_ in (1, -1):
            a, b, e = pose["arms"][s_]
            pose["arms"][s_] = (a, 0.45, 0.3)
    elif anim == "idle":
        pose = default_pose()
        pose["arms"] = {1: (0.1, 0.45, 0.3), -1: (0.1, 0.45, 0.3)}
        pose["hip_drop"] = 0.4 * bf(f, n)
    elif anim == "attack":
        pose = default_pose()
        k = kf([(1.0, 0.6, 0.8), (1.5, 0.1, 0.1), (1.2, 0.2, 0.4)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.1, 0.35, 0.25], f, n)
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 1.5
    pose["head_pitch"] = 0.3
    prims, J = build_human(spec, pose, mats)
    # 膿包、裂開的肚子
    for off, r in (((4.5, 2.5, 1.0), 1.8), ((3.5, -3.0, -1.5), 1.5), ((-2.0, 4.5, 2.0), 1.6), ((5.0, 0.0, -3.0), 2.2)):
        prims.append(Ell(add(J["chest"], off), (r, r, r), "pus"))
    prims.append(Box(add(J["chest"], (5.9, 0.0, -0.5)), (0.3, 2.0, 0.5), "flesh"))
    prims += face(J, "vent")
    return prims


def chorister_model(anim, f, n):
    """詠者：瘦長、喉嚨長著結晶環，會發出呼喚把同伴叫過來"""
    mats = {"leg": "ash", "boot": "ash", "hip": "rag", "torso": "ash", "arm": "ash", "hand": "ash", "skin": "ash"}
    spec = {"lu": 7.2, "ll": 7.2, "torso_len": 10.0, "torso_r": (2.6, 3.4, 5.4), "leg_r": 1.2, "leg_r2": 1.0,
            "au": 5.4, "al": 5.4, "arm_r": 1.0, "head_r": (2.6, 2.4, 3.0), "sh_w": 3.6}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.35, knee=0.7, arm=0.2, lean=0.05)
    elif anim == "listen":
        # 仰頭呼喚、雙手張開
        pose = default_pose()
        pose["arms"] = {1: (0.6 + 0.15 * bf(f, n), 1.0, 0.3), -1: (0.6 + 0.15 * bf(f, n), 1.0, 0.3)}
        pose["head_pitch"] = -0.7
        pose["lean"] = -0.12
    elif anim == "attack":
        pose = default_pose()
        k = kf([(0.8, 0.7, 1.0), (1.5, 0.15, 0.05), (1.2, 0.0, 0.3)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.1, 0.4, 0.3], f, n)
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    neck = add(J["chest"], (0.0, 0.0, 4.2))
    for i in range(6):
        a = i * math.pi / 3
        prims.append(Cap(neck, add(neck, (math.cos(a) * 3.2, math.sin(a) * 3.2, 1.0)), 0.7, "crystal", 0.25))
    prims.append(Box(head_local(J, (2.5, 0, -1.0)), (0.4, 1.2, 1.0), "vent", J["head_basis"]))  # 張大的嘴
    prims.append(Ell(add(J["chest"], (0.5, 0, -3.5)), (3.0, 3.6, 2.4), "rag"))
    return prims


def bear_model(anim, f, n):
    """苔原之母：被感染的北極熊。背上長滿冰晶，結晶裂開的背部是弱點"""
    prims = []
    bz = 13.0
    lean = 0.0
    head_drop = 0.0
    rear = 0.0
    if anim == "walk":
        p = 2 * math.pi * f / n
        legs = {}
        for name, ph in (("fl", 0), ("br", 0), ("fr", math.pi), ("bl", math.pi)):
            legs[name] = (0.45 * math.sin(p + ph), 0.2 + 0.7 * max(0, math.cos(p + ph)))
        head_drop = 1.0 + 0.8 * math.sin(2 * p)
    elif anim == "idle":
        legs = {k: (0.0, 0.15) for k in ("fl", "fr", "bl", "br")}
        head_drop = 1.5 * bf(f, n)
    elif anim == "attack":
        # 站起來往前撲
        rear = kf([0.0, 0.55, 0.6, -0.15, 0.0], f, n)
        k = kf([(0.0, 0.2), (1.0, 1.2), (1.2, 1.0), (0.6, 0.2), (0.1, 0.2)], f, n)
        legs = {"fl": k, "fr": k, "bl": (0.2, 0.2), "br": (0.2, 0.2)}
        lean = -rear
    elif anim == "hurt":
        legs = {k: (0.0, 0.3) for k in ("fl", "fr", "bl", "br")}
        lean = kf([0.25, 0.12, 0.0], f, n)
        head_drop = -2.0 * kf([1.0, 0.5, 0.0], f, n)
    else:
        raise ValueError(anim)
    L = lean_fn((-8.0, 0, bz), lean)
    prims.append(Ell(L((-2.0, 0, bz + 2.0)), (14.0, 7.0, 7.5), "white"))
    prims.append(Ell(L((8.0, 0, bz + 2.5)), (7.0, 7.0, 8.0), "white"))
    hc = L((16.0, 0, bz + 4.0 - head_drop))
    prims.append(Ell(hc, (4.5, 4.0, 4.0), "white"))
    prims.append(Ell(add(hc, (4.0, 0, -1.2)), (2.6, 2.2, 1.8), "white"))
    prims.append(Ell(add(hc, (6.3, 0, -0.8)), (0.8, 1.2, 0.8), "black"))
    prims.append(Ell(add(hc, (0.5, 2.6, 3.0)), (1.2, 0.8, 1.2), "white"))
    prims.append(Ell(add(hc, (0.5, -2.6, 3.0)), (1.2, 0.8, 1.2), "white"))
    prims.append(Box(add(hc, (2.4, 0, -2.4)), (1.4, 1.8, 0.4), "flesh"))
    # 背上的冰晶、裂開的弱點
    for x, y, ln in ((-10, 1.5, 6.0), (-5, -2.0, 7.5), (0, 2.0, 8.0), (5, -1.0, 6.5), (-7, 3.5, 4.5), (2, -3.5, 5.0)):
        base = L((x, y, bz + 8.0))
        prims.append(Cap(base, add(base, (-1.5, y * 0.3, ln)), 1.5, "crystal", 0.5))
    prims.append(Ell(L((-3.0, 0, bz + 8.6)), (3.5, 2.0, 1.0), "flesh"))
    for name, x, y in (("fl", 9.0, 4.0), ("fr", 9.0, -4.0), ("bl", -11.0, 4.0), ("br", -11.0, -4.0)):
        a, k = legs[name]
        hip = L((x, y, bz))
        kn, ft = leg_points(hip, a, k if name[0] == "b" else -k, 6.5, 6.5)
        prims.append(Cap(hip, kn, 3.0, "white", 2.6))
        prims.append(Cap(kn, ft, 2.4, "white", 2.2))
        prims.append(Ell(add(ft, (1.0, 0, 0)), (2.6, 2.2, 1.2), "white"))
    return prims



def runner_model(anim, f, n):
    """狂奔者：剛被感染沒多久的站員。瘦、跑很快、往前衝的姿勢，很脆"""
    mats = {"leg": "pants", "boot": "boot", "hip": "pants", "torso": "parka_trim", "arm": "pale",
            "hand": "pale", "skin": "pale"}
    spec = {"torso_r": (2.9, 3.6, 5.0), "leg_r": 1.6, "leg_r2": 1.3, "arm_r": 1.2, "sh_w": 3.9}
    if anim == "walk":
        # 衝刺：大步、身體很低、手往後甩
        pose = walk_pose(f, n, stride=0.7, knee=1.2, arm=0.2, lean=0.32)
        p = 2 * math.pi * f / n
        pose["arms"] = {1: (-0.6 + 0.3 * math.sin(p), 0.25, 0.4), -1: (-0.6 - 0.3 * math.sin(p), 0.25, 0.4)}
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.35
        pose["legs"] = {1: (0.25, 0.5), -1: (-0.2, 0.5)}
        pose["hip_drop"] = 0.8 + 0.3 * bf(f, n)
        pose["arms"] = {1: (0.15, 0.3, 0.3), -1: (0.2, 0.25, 0.3)}
        pose["head_roll"] = 0.15 * bf(f, n)
    elif anim == "attack":
        # 撲上來：雙手往前抓
        pose = default_pose()
        pose["legs"] = {1: (0.6, 0.5), -1: (-0.5, 0.4)}
        k = kf([(0.4, 0.3, 0.8), (1.6, 0.15, 0.05), (1.3, 0.1, 0.3)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.4, 0.75, 0.6], f, n)
    else:
        raise ValueError(anim)
    pose["head_pitch"] = pose.get("head_pitch", 0.0) + 0.2
    pose["head_fwd"] = 1.2
    prims, J = build_human(spec, pose, mats)
    # 剛長出來的小冰晶（只有脖子和一邊肩膀）
    prims.append(Cap(add(J["sh1"], (-0.5, 0.3, 0.8)), add(J["sh1"], (-1.2, 1.0, 2.6)), 0.7, "crystal", 0.25))
    prims.append(Cap(add(J["chest"], (-2.0, -0.6, 3.5)), add(J["chest"], (-3.2, -1.0, 5.0)), 0.6, "crystal", 0.2))
    prims += face(J, "vent")
    return prims


def spitter_model(anim, f, n):
    """噴孢者：駝背、下巴和喉嚨腫成一個大孢子囊，從遠處吐孢子團"""
    mats = {"leg": "ash", "boot": "boot", "hip": "rag", "torso": "rag", "arm": "ash", "hand": "ash", "skin": "ash"}
    spec = {"torso_r": (3.4, 4.0, 4.8), "torso_len": 9.0, "lu": 6.0, "ll": 6.0, "au": 5.0, "al": 5.0, "arm_r": 1.2,
            "head_r": (2.6, 2.6, 2.8)}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.32, knee=0.6, arm=0.1, lean=0.5)
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.5
        pose["arms"] = {1: (0.2, 0.2, 0.2), -1: (0.25, 0.2, 0.2)}
        pose["hip_drop"] = 0.3 * bf(f, n)
    elif anim in ("attack", "aim"):
        # 往後仰、吸氣，然後往前吐
        pose = default_pose()
        pose["legs"] = {1: (0.35, 0.3), -1: (-0.3, 0.3)}
        pose["lean"] = kf([0.1, -0.15, 0.6], f, n) if anim == "attack" else -0.1
        pose["arms"] = {1: (0.3, 0.6, 0.4), -1: (0.3, 0.6, 0.4)}
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 1.4
    pose["head_pitch"] = pose.get("head_pitch", 0.0) + 0.1
    prims, J = build_human(spec, pose, mats)
    # 喉嚨的孢子囊（會脹）
    swell = 1.0 + 0.15 * math.sin(2 * math.pi * f / max(n, 1))
    sac = head_local(J, (1.2, 0, -2.6))
    prims.append(Ell(sac, (2.6 * swell, 2.6 * swell, 2.2 * swell), "pus"))
    prims.append(Ell(add(sac, (1.0, 1.0, 0.6)), (0.9, 0.9, 0.9), "glass"))
    prims.append(Ell(add(sac, (0.8, -1.2, -0.2)), (0.8, 0.8, 0.8), "glass"))
    # 背上的菌斑
    for off in ((-3.0, 1.2, 1.5), (-3.2, -1.4, 0.0), (-2.6, 0.2, 3.0)):
        prims.append(Ell(add(J["chest"], off), (1.4, 1.4, 1.2), "pus"))
    prims.append(Box(head_local(J, (2.4, 0, -0.8)), (0.4, 1.4, 0.8), "vent", J["head_basis"]))
    return prims


def brute_model(anim, f, n):
    """冰甲巨人：骨頭礦化成一整片冰晶甲殼的巨大宿主。正面很硬，背後是弱點"""
    mats = {"leg": "coverall", "boot": "boot", "hip": "coverall", "torso": "coverall", "arm": "pale", "hand": "pale",
            "skin": "pale"}
    spec = {"torso_r": (5.6, 6.8, 7.2), "torso_len": 11.0, "lu": 6.0, "ll": 5.6, "leg_r": 2.6, "leg_r2": 2.3,
            "sh_w": 6.4, "au": 5.8, "al": 6.2, "arm_r": 2.3, "head_r": (2.4, 2.4, 2.4), "hip_w": 3.0}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.32, knee=0.5, arm=0.25, lean=0.25)
        for s_ in (1, -1):
            a, b, e = pose["arms"][s_]
            pose["arms"][s_] = (a, 0.35, 0.25)
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.2
        pose["arms"] = {1: (0.1, 0.35, 0.2), -1: (0.1, 0.35, 0.2)}
        pose["hip_drop"] = 0.3 * bf(f, n)
    elif anim == "attack":
        # 雙手舉高往下砸
        pose = default_pose()
        k = kf([(0.6, 0.3, 0.3), (2.6, 0.2, 0.1), (1.0, 0.25, 0.5)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.0, -0.2, 0.55], f, n)
        pose["legs"] = {1: (0.4, 0.3), -1: (-0.4, 0.3)}
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 1.8
    pose["head_pitch"] = 0.35
    prims, J = build_human(spec, pose, mats)
    # 胸前和肩膀的冰晶甲殼
    for off, r in (((4.8, 2.4, 1.2), (1.2, 2.0, 2.4)), ((4.8, -2.4, 1.2), (1.2, 2.0, 2.4))):
        prims.append(Ell(add(J["chest"], off), r, "crystal"))
    for side in (1, -1):
        sh = J["sh%d" % side]
        prims.append(Ell(add(sh, (0.5, side * 0.6, 1.2)), (2.0, 2.0, 1.6), "crystal"))
        prims.append(Cap(add(sh, (0, side * 0.5, 2.0)), add(sh, (-1.0, side * 1.6, 5.0)), 0.9, "crystal", 0.3))
    # 背後：甲殼裂開、露出肉（弱點）
    prims.append(Ell(add(J["chest"], (-4.0, 0, 0.5)), (1.6, 3.0, 3.4), "flesh"))
    prims += face(J, "vent")
    return prims

CHARACTERS = {
    "player": (player_model, dict({"idle": 4, "walk": 8, "sneak": 8, "slash": 6, "slash_axe": 6, "punch": 6, "kick": 6,
                                   "hurt": 3, "dodge": 5, "dodge_back": 5},
                                  **{"aim_" + w: 1 for w in ("pistol", "shotgun", "rifle", "nailgun", "flare_gun")},
                                  **{"shoot_" + w: 3 for w in ("pistol", "shotgun", "rifle", "nailgun", "flare_gun")})),
    "watcher": (watcher_model, {"walk": 8, "idle": 4, "attack": 5, "hurt": 3}),
    "listener": (listener_model, {"walk": 8, "listen": 4, "attack": 5, "hurt": 3}),
    "guard": (guard_model, {"walk": 8, "idle": 4, "aim": 1, "hurt": 3}),
    "hound": (hound_model, {"walk": 8, "idle": 4, "attack": 5}),
    "crawler": (crawler_model, {"walk": 8, "idle": 4, "attack": 5}),
    "husk": (husk_model, {"walk": 8, "idle": 4, "attack": 5, "hurt": 3}),
    "chorister": (chorister_model, {"walk": 8, "listen": 4, "attack": 5, "hurt": 3}),
    "bear": (bear_model, {"walk": 8, "idle": 4, "attack": 5, "hurt": 3}),
    "runner": (runner_model, {"walk": 8, "idle": 4, "attack": 5, "hurt": 3}),
    "spitter": (spitter_model, {"walk": 8, "idle": 4, "attack": 5, "aim": 1, "hurt": 3}),
    "brute": (brute_model, {"walk": 8, "idle": 4, "attack": 5, "hurt": 3}),
}
# 人形敵人的受傷動作（共用姿勢修正）
HURT_BASE = {"runner": "idle", "spitter": "idle", "brute": "idle", "watcher": "idle", "listener": "listen", "guard": "idle", "husk": "idle", "chorister": "listen"}
CANVAS = {"player": (36, 32), "watcher": (32, 32), "listener": (32, 36), "guard": (32, 32), "hound": (36, 30),
          "crawler": (36, 26), "husk": (36, 34), "chorister": (32, 36), "bear": (64, 48),
          "runner": (32, 32), "spitter": (32, 32), "brute": (40, 40)}


# 紙娃娃：本體套裝、頭部圖層、腳部圖層（遊戲裡依裝備組合疊起來）
OUTFIT_SETS = {
    "player_hazmat": {"body": "hazmat"}, "player_eod": {"body": "eod"}, "player_sneak": {"body": "sneak"},
    "player_arctic": {"body": "arctic"},
    "player_head_gas_mask": {"layer": "head", "head": "gas_mask"},
    "player_head_eod_helmet": {"layer": "head", "head": "eod_helmet"},
    "player_head_balaclava": {"layer": "head", "head": "balaclava"},
    "player_head_snow_goggles": {"layer": "head", "head": "snow_goggles"},
    "player_head_wool_hat": {"layer": "head", "head": "wool_hat"},
    "player_feet_hazmat_boots": {"layer": "feet", "feet": "hazmat_boots"},
    "player_feet_eod_boots": {"layer": "feet", "feet": "eod_boots"},
    "player_feet_crampons": {"layer": "feet", "feet": "crampons"},
    "player_feet_soft_soles": {"layer": "feet", "feet": "soft_soles"},
}


def gen_outfit(name):
    cfg = OUTFIT_SETS[name]
    OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
    OUTFIT.update(cfg)
    _model, anims = CHARACTERS["player"]
    w, h = CANVAS["player"]
    folder = os.path.join(OUT, name)
    if os.path.isdir(folder):
        for fn in os.listdir(folder):
            if fn.endswith(".png") or fn.endswith(".png.import"):
                os.remove(os.path.join(folder, fn))
    count = 0
    layer = OUTFIT["layer"] != ""
    for anim, n in anims.items():
        for d, yaw in DIRS.items():
            for f in range(n):
                prims = finish(player_model(anim, f, n), yaw)
                write_png(os.path.join(folder, "%s_%s_%d.png" % (anim, d, f)), w, h, render(prims, w, h, layer_only=layer))
                count += 1
    OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
    print("%s: %d 張" % (name, count))


def gen_character(name):
    model, anims = CHARACTERS[name]
    base_model = model
    w, h = CANVAS[name]
    folder = os.path.join(OUT, name)
    if os.path.isdir(folder):
        for fn in os.listdir(folder):
            if fn.endswith(".png") or fn.endswith(".png.import"):
                os.remove(os.path.join(folder, fn))
    count = 0
    for anim, n in anims.items():
        for d, yaw in DIRS.items():
            for f in range(n):
                m = hurt_of(base_model, HURT_BASE[name]) if anim == "hurt" and name in HURT_BASE else base_model
                prims = finish(m(anim, f, n), yaw)
                write_png(os.path.join(folder, "%s_%s_%d.png" % (anim, d, f)), w, h, render(prims, w, h))
                count += 1
    print("%s: %d 張" % (name, count))


# ── 道具 ─────────────────────────────────────────────────

def snow_or(mat, k=0.55):
    return lambda n: "snow" if n[2] > k else mat


def gen_props():
    folder = os.path.join(OUT, "props")
    os.makedirs(folder, exist_ok=True)

    def save(name, prims, w, h, anchor=None):
        write_png(os.path.join(folder, name + ".png"), w, h, render(prims, w, h, anchor=anchor))

    # 置物櫃：正面有通風口、把手（寬 14、深 9、高 22）
    def locker(open_):
        p = [Box((0, 4.5, 11), (7, 4.5, 11), "locker")]
        if open_:
            p.append(Box((0, -0.1, 11), (6, 0.3, 10), "black"))
            p.append(Box((-6.5, -4.5, 11), (0.4, 4.5, 10), "locker", basis_along((0.3, -1, 0))))
        else:
            for z in (17.5, 16.0, 14.5):
                p.append(Box((0, -0.05, z), (4.5, 0.2, 0.35), "vent"))
            p.append(Box((4.5, -0.3, 10), (0.4, 0.4, 1.6), "steel"))
            p.append(Box((0, -0.1, 11), (0.15, 0.2, 10.5), "vent"))
        return p
    save("locker", locker(False), 16, 26)
    save("locker_open", locker(True), 16, 26)
    # 檔案櫃（三層抽屜）
    p = [Box((0, 4.5, 8.5), (7, 4.5, 8.5), "cabinet")]
    for z in (13.5, 8.5, 3.5):
        p.append(Box((0, -0.05, z + 1.6), (5.5, 0.2, 0.3), "vent"))
        p.append(Box((0, -0.3, z), (1.6, 0.3, 0.45), "steel"))
    save("cabinet", p, 16, 22)
    # 實驗桌：切成左、中、右三段（每段 16 寬），橫向拼接
    p = [Box((0, 5, 11.0), (23.5, 6.0, 0.8), "benchtop"), Box((0, 5, 5.5), (22.5, 5.5, 4.7), "cabinet")]
    for x in (-16, 0, 16):
        p.append(Box((x, -0.6, 7.8), (6, 0.2, 0.3), "vent"))
        p.append(Box((x, -0.7, 5.5), (1.6, 0.3, 0.4), "steel"))
    p.append(Box((-12, 6, 13.5), (1.2, 1.2, 1.8), "glass"))
    p.append(Box((9, 7, 13.0), (2.5, 1.6, 1.2), "steel"))
    img = render(p, 48, 22, anchor=(24, 20))
    for i, part in enumerate(("bench_l", "bench_m", "bench_r")):
        sub_img = [img[y * 48 + x] for y in range(22) for x in range(i * 16, i * 16 + 16)]
        write_png(os.path.join(folder, part + ".png"), 16, 22, sub_img)
    # 戶外的岩石（三種），頂上積雪
    rnd = random.Random(7)
    for v in range(3):
        p = []
        p.append(Ell((0, 5, 5 + v), (7.5, 6.5, 6.0 + v), snow_or("rock", 0.9)))
        for _ in range(2 + v):
            c = (rnd.uniform(-4, 4), rnd.uniform(1, 6), rnd.uniform(3, 8 + v))
            r = (rnd.uniform(3.5, 5.5), rnd.uniform(3, 5), rnd.uniform(3, 5 + v))
            p.append(Ell(c, r, snow_or("rock", 0.9)))
        save("rock_%d" % v, finish(p, rnd.uniform(0, 6.28)), 24, 28, anchor=(12, 24))
    # 配電箱（掛在牆上，正面）
    p = [Box((0, 1, 6), (5, 1, 6), "cabinet"), Box((0, -0.1, 8), (3.5, 0.2, 2.5), "vent"),
         Box((2.5, -0.5, 3), (0.5, 0.5, 1.8), "red"), Box((-2.5, -0.2, 3.5), (1.2, 0.2, 0.6), "brass")]
    save("breaker", p, 14, 16)
    print("props: ok")


# ── 物品圖示（側面，躺在地上也看得出輪廓）────────────────────

def gen_items():
    folder = os.path.join(OUT, "props")
    os.makedirs(folder, exist_ok=True)
    side = math.radians(18)

    def save(name, prims, w, h, yaw=0.0):
        prims = [p.moved(lambda v, d=False: rot_z(v, yaw)) for p in prims]
        img = render(prims, w, h, pitch=side, anchor=(w / 2.0, h / 2.0 + 1))
        write_png(os.path.join(folder, name + ".png"), w, h, img)

    X = basis_along((1, 0, 0))
    save("pistol", [Box((1.2, 0, 1.4), (4.0, 0.7, 1.1), "cabinet", X), Box((-1.6, 0, -1.2), (1.1, 0.6, 2.2), "black",
                    basis_along((1, 0, -0.25))), Box((0.6, 0, -0.4), (0.9, 0.3, 0.6), "gunmetal", X),
                    Box((5.0, 0, 1.6), (0.5, 0.5, 0.5), "black", X)], 16, 12)
    save("shotgun", [Box((2.5, 0, 0.9), (8.0, 0.6, 0.6), "gunmetal", X), Box((4.0, 0, -0.3), (3.0, 0.7, 0.6), "wood", X),
                     Box((-7.2, 0, -0.4), (3.2, 0.7, 1.2), "wood", basis_along((1, 0, 0.2))),
                     Box((-3.2, 0, 0.2), (1.4, 0.7, 1.0), "gunmetal", X)], 26, 10)
    save("knife", [Box((-3.0, 0, 0), (2.2, 0.6, 0.8), "black", X), Box((2.2, 0, 0.1), (3.2, 0.3, 0.9), "steel", X),
                   Box((-0.6, 0, 0), (0.3, 0.6, 1.4), "steel", X)], 16, 8)
    # 9mm 子彈盒、散彈盒
    save("ammo", [Box((0, 0, 0), (4.0, 2.5, 2.2), "olive"), Box((0, -2.55, 0.4), (2.6, 0.1, 1.0), "brass")], 14, 12,
         yaw=0.35)
    shells = [Box((0, 0, -0.6), (4.2, 2.6, 1.6), "red")]
    for i in range(4):
        shells.append(Cap((-3 + i * 2.0, -1.0, 1.0), (-3 + i * 2.0, -1.0, 2.6), 0.8, "red"))
        shells.append(Cap((-3 + i * 2.0, -1.0, 0.6), (-3 + i * 2.0, -1.0, 1.1), 0.85, "brass"))
    save("shells", shells, 14, 12, yaw=0.35)
    save("med", [Box((0, 0, 0), (4.5, 2.5, 3.0), "white"), Box((0, -2.55, 0), (0.6, 0.1, 2.0), "red"),
                 Box((0, -2.55, 0), (2.0, 0.1, 0.6), "red"), Box((0, 0, 3.4), (1.5, 0.6, 0.5), "black")], 14, 12, yaw=0.3)
    save("antibiotic", [Cap((-3.5, 0, 0), (2.5, 0, 0), 1.3, "white"), Box((-0.5, -1.2, 0), (2.0, 0.2, 0.9), "glass"),
                        Box((-4.3, 0, 0), (0.4, 1.6, 1.6), "steel"), Cap((2.5, 0, 0), (5.5, 0, 0), 0.25, "steel")],
         16, 8, yaw=0.2)
    bottle = [Cap((0, 0, -3.0), (0, 0, 1.0), 2.0, "glass"), Cap((0, 0, 1.5), (0, 0, 4.2), 0.8, "glass")]
    save("bottle", bottle, 10, 14)
    save("molotov", bottle + [Cap((0, 0, 4.0), (0.8, 0, 6.0), 0.6, "cloth"), Ell((1.0, -0.5, 6.4), (0.8, 0.8, 1.0), "fire")],
         10, 16)
    save("ethanol", [Box((0, 0, -0.5), (2.2, 1.6, 3.5), "white"), Box((0, -1.65, -0.5), (1.6, 0.1, 1.6), "orange"),
                     Cap((0, 0, 3.0), (0, 0, 4.4), 0.7, "black")], 10, 14, yaw=0.3)
    save("stone", [Ell((0, 0, 0), (3.2, 2.6, 2.0), "rock")], 10, 8, yaw=0.4)
    # 手電筒（快捷選單的「光源」）
    save("flashlight", [Cap((-3.5, 0, 0), (2.5, 0, 0), 1.3, "black"), Cap((2.5, 0, 0), (4.5, 0, 0), 2.1, "gunmetal"),
                        Ell((4.9, 0, 0), (0.4, 1.7, 1.7), "goggle"), Box((-0.5, -1.3, 0.3), (0.8, 0.2, 0.4), "orange")], 14, 8)
    # 獵槍（栓動、瞄準鏡）、釘槍（工地用，很安靜）、信號槍、消防斧，和它們的彈藥
    save("rifle", [Box((4.0, 0, 0.9), (10.0, 0.55, 0.55), "gunmetal", X), Box((-1.0, 0, 0.0), (6.0, 0.7, 0.8), "wood", X),
                   Box((-8.5, 0, -0.6), (3.0, 0.7, 1.3), "wood", basis_along((1, 0, 0.2))),
                   Box((1.0, 0, 2.3), (3.0, 0.6, 0.6), "black", X), Box((-2.5, 0, 1.2), (0.4, 0.8, 0.4), "steel", X)], 32, 10)
    save("nailgun", [Box((1.0, 0, 1.2), (4.2, 1.2, 1.6), "yellow", X), Box((-2.0, 0, -1.8), (1.1, 0.8, 2.2), "black",
                     basis_along((1, 0, -0.2))), Box((5.6, 0, 0.6), (0.8, 0.6, 0.8), "steel", X),
                     Box((1.6, 0, -1.2), (1.8, 0.6, 0.9), "gunmetal", X)], 18, 14)
    save("flare_gun", [Box((1.5, 0, 1.2), (3.6, 0.8, 1.2), "orange", X), Box((-1.4, 0, -1.2), (1.0, 0.6, 2.0), "orange",
                       basis_along((1, 0, -0.25))), Box((5.2, 0, 1.2), (0.6, 1.0, 1.0), "black", X)], 16, 12)
    save("fire_axe", [Box((-1.5, 0, 0), (7.0, 0.6, 0.7), "wood", X), Box((5.5, 0, 0.9), (1.4, 0.5, 2.4), "red", X),
                      Box((5.5, 0, 3.4), (1.6, 0.4, 0.5), "steel", X), Box((5.5, 0, -1.6), (0.8, 0.5, 0.8), "red", X)], 22, 14)
    save("rifle_rounds", [Box((0, 0, 0), (3.6, 2.2, 2.0), "wood"), Box((0, -2.25, 0.3), (2.6, 0.1, 0.9), "brass")], 12, 10, yaw=0.35)
    nails = [Box((0, 0, -0.4), (3.0, 1.6, 2.4), "steel")]
    for i in range(5):
        nails.append(Box((-2.4 + i * 1.2, -1.7, 0.6), (0.25, 0.1, 1.2), "gunmetal"))
    save("nails", nails, 10, 10, yaw=0.3)
    save("flares", [Cap((-2.5, 0, 0), (2.5, 0, 0), 1.6, "red"), Cap((2.5, 0, 0), (3.5, 0, 0), 1.7, "black"),
                    Cap((-2.5, 2.0, 0.3), (2.5, 2.0, 0.3), 1.6, "red")], 14, 10, yaw=0.3)
    save("heat_pack", [Box((0, 0, 0), (3.8, 0.8, 2.6), "orange"), Box((0, -0.85, 0), (2.4, 0.1, 1.0), "white")], 12, 10,
         yaw=0.3)
    print("items: ok")


# ── 特效（子彈、槍口火光、彈殼、影子）─────────────────────────

def gen_fx():
    folder = os.path.join(OUT, "fx")
    os.makedirs(folder, exist_ok=True)
    Y = (255, 248, 200, 255)
    O = (255, 180, 70, 255)
    R = (220, 90, 30, 255)
    _ = (0, 0, 0, 0)
    # 子彈（曳光）：往右飛，畫的時候依方向旋轉
    bullet = [
        [_, _, (255, 200, 120, 90), O, Y, Y, (255, 255, 255, 255), _],
        [_, (255, 200, 120, 60), O, Y, (255, 255, 255, 255), (255, 255, 255, 255), (255, 255, 255, 255), Y],
        [_, _, (255, 200, 120, 90), O, Y, Y, (255, 255, 255, 255), _],
    ]
    write_png(os.path.join(folder, "bullet.png"), 8, 3, [c for row in bullet for c in row])
    # 散彈的彈丸（小）
    pellet = [[_, O, _], [O, Y, O], [_, O, _]]
    write_png(os.path.join(folder, "pellet.png"), 3, 3, [c for row in pellet for c in row])
    # 槍口火光三格（往右）
    rnd = random.Random(3)
    for f in range(3):
        w, h = 11, 9
        px = [_] * (w * h)
        cy = h // 2
        length = [10, 8, 5][f]
        for x in range(length):
            half = int((1 - x / length) * [3.5, 3, 2][f] + (rnd.random() * 1.2 if x > 1 else 0))
            for dy in range(-half, half + 1):
                y = cy + dy
                if 0 <= y < h:
                    core = abs(dy) <= max(0, half - 2) and x < length * 0.6
                    px[y * w + x] = Y if core else (O if abs(dy) < half else R)
        # 兩側的小火花
        if f < 2:
            for (x, y) in ((3, 0), (3, h - 1), (5, 1), (5, h - 2)):
                px[y * w + x] = O
        write_png(os.path.join(folder, "muzzle_%d.png" % f), w, h, px)
    # 彈殼（黃銅）、散彈殼（紅）
    write_png(os.path.join(folder, "casing.png"), 3, 2,
              [(236, 198, 90, 255), (184, 140, 44, 255), (122, 90, 26, 255),
               (184, 140, 44, 255), (122, 90, 26, 255), (58, 42, 12, 255)])
    write_png(os.path.join(folder, "shell_casing.png"), 4, 2,
              [(236, 198, 90, 255), (228, 74, 58, 255), (184, 36, 36, 255), (122, 22, 22, 255),
               (184, 140, 44, 255), (184, 36, 36, 255), (122, 22, 22, 255), (58, 10, 10, 255)])
    # 刀光（揮刀的弧線，往右揮）
    w, h = 20, 20
    px = [_] * (w * h)
    for i in range(48):
        a = -1.1 + 2.2 * i / 47
        for rr, col in ((9.5, (255, 255, 255, 230)), (8.5, (200, 230, 255, 160)), (7.5, (150, 200, 255, 70))):
            x = int(10 + math.cos(a) * rr)
            y = int(10 + math.sin(a) * rr)
            if 0 <= x < w and 0 <= y < h and px[y * w + x][3] < col[3]:
                px[y * w + x] = col
    write_png(os.path.join(folder, "slash.png"), w, h, px)

    # ── 多格特效（流暢的動作感）──
    # 刀光 5 格：弧線從後往前掃、最後淡出
    for f in range(5):
        w, h = 22, 22
        px = [_] * (w * h)
        head = -1.2 + 2.6 * min(1.0, (f + 1) / 3.5)
        tail = -1.2 + 2.6 * max(0.0, (f - 1) / 3.5)
        fade = 1.0 if f < 3 else (0.6 if f == 3 else 0.3)
        for i in range(60):
            a = tail + (head - tail) * i / 59
            k = i / 59
            for rr, col in ((10.0, (255, 255, 255)), (9.0, (210, 235, 255)), (8.0, (150, 200, 255))):
                x = int(11 + math.cos(a) * rr)
                y = int(11 + math.sin(a) * rr)
                al = int(255 * fade * (0.35 + 0.65 * k) * (1.0 if rr == 10.0 else 0.6 if rr == 9.0 else 0.3))
                if 0 <= x < w and 0 <= y < h and px[y * w + x][3] < al:
                    px[y * w + x] = col + (al,)
        write_png(os.path.join(folder, "slash_%d.png" % f), w, h, px)
    # 命中：冰晶碎片＋暗紅飛濺（感染體被打中）4 格
    rnd = random.Random(11)
    shards = [(rnd.uniform(0, 6.28), rnd.uniform(0.6, 1.0), rnd.random() < 0.6) for _ in range(10)]
    for f in range(4):
        w, h = 15, 15
        px = [_] * (w * h)
        r = 1.5 + f * 1.8
        for a, sp, ice in shards:
            x = int(7 + math.cos(a) * r * sp)
            y = int(7 + math.sin(a) * r * sp)
            col = (200, 245, 255) if ice else (150, 30, 40)
            if 0 <= x < w and 0 <= y < h:
                px[y * w + x] = col + (255 - f * 50,)
        if f == 0:
            for dx, dy in ((0, 0), (1, 0), (-1, 0), (0, 1), (0, -1)):
                px[(7 + dy) * w + 7 + dx] = (255, 255, 255, 255)
        write_png(os.path.join(folder, "hit_%d.png" % f), w, h, px)
    # 拳腳的衝擊圈 4 格
    for f in range(4):
        w, h = 17, 17
        px = [_] * (w * h)
        r = 2.5 + f * 2.0
        for i in range(48):
            a = i / 48 * 6.283
            x = int(8 + math.cos(a) * r)
            y = int(8 + math.sin(a) * r * 0.75)
            if 0 <= x < w and 0 <= y < h:
                px[y * w + x] = (255, 240, 200, 230 - f * 55)
        write_png(os.path.join(folder, "impact_%d.png" % f), w, h, px)
    # 槍口白煙 4 格
    for f in range(4):
        w, h = 12, 12
        px = [_] * (w * h)
        r = 2 + f * 1.3
        for y in range(h):
            for x in range(w):
                d = math.hypot(x - 6, (y - 6 + f * 0.8) * 1.1)
                if d < r and rnd.random() < 0.85:
                    px[y * w + x] = (200, 205, 210, int(150 - f * 35 - d * 6))
        write_png(os.path.join(folder, "smoke_%d.png" % f), w, h, px)
    # 散彈槍的大火光 3 格（扇形）
    for f in range(3):
        w, h = 16, 15
        px = [_] * (w * h)
        length = [15, 12, 7][f]
        for x in range(length):
            half = int(x * [0.55, 0.45, 0.35][f] + 1.5 + (rnd.random() * 1.5 if x > 2 else 0))
            for dy in range(-half, half + 1):
                y = 7 + dy
                if 0 <= y < h:
                    core = abs(dy) <= half * 0.45 and x < length * 0.7
                    px[y * w + x] = Y if core else (O if abs(dy) < half else R)
        write_png(os.path.join(folder, "muzzle_big_%d.png" % f), w, h, px)
    # 釘子、信號彈
    write_png(os.path.join(folder, "nail.png"), 5, 1, [(120, 128, 140, 255), (160, 168, 180, 255), (160, 168, 180, 255),
                                                    (200, 208, 220, 255), (230, 235, 240, 255)])
    flare = [[_, (255, 120, 80, 120), _], [(255, 120, 80, 120), (255, 230, 200, 255), (255, 120, 80, 120)],
             [_, (255, 120, 80, 120), _]]
    write_png(os.path.join(folder, "flare.png"), 3, 3, [c for row in flare for c in row])
    # 角色腳下的影子（橢圓、半透明）
    w, h = 16, 6
    px = []
    for y in range(h):
        for x in range(w):
            dx = (x + 0.5 - w / 2) / (w / 2)
            dy = (y + 0.5 - h / 2) / (h / 2)
            d = dx * dx + dy * dy
            px.append((0, 0, 8, 120 if d < 0.55 else 70 if d < 1.0 else 0))
    write_png(os.path.join(folder, "shadow.png"), w, h, px)
    print("fx: ok")


# ── 地板、牆頂貼圖（雜訊＋固定調色盤＋抖色）────────────────────

BAYER = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


def value_noise(w, h, cell, seed):
    rnd = random.Random(seed)
    gw, gh = w // cell + 1, h // cell + 1
    g = [[rnd.random() for _ in range(gw)] for _ in range(gh)]

    def at(x, y):
        fx, fy = x / cell, y / cell
        x0, y0 = int(fx) % (gw - 1), int(fy) % (gh - 1)
        tx, ty = fx - int(fx), fy - int(fy)
        tx, ty = tx * tx * (3 - 2 * tx), ty * ty * (3 - 2 * ty)
        x1, y1 = (x0 + 1) % (gw - 1), (y0 + 1) % (gh - 1)
        a = lerp(g[y0][x0], g[y0][x1], tx)
        b = lerp(g[y1][x0], g[y1][x1], tx)
        return lerp(a, b, ty)
    return at


def texture(w, h, pal, seed, base=0.5, contrast=1.0, seams=None, extra=None):
    n1 = value_noise(w, h, 16, seed)
    n2 = value_noise(w, h, 4, seed + 1)
    px = []
    for y in range(h):
        for x in range(w):
            v = base + (n1(x, y) - 0.5) * 0.5 * contrast + (n2(x, y) - 0.5) * 0.35 * contrast
            if seams and seams(x, y):
                v -= 0.35
            if extra:
                v = extra(x, y, v)
            v += (BAYER[y % 4][x % 4] / 16.0 - 0.5) * 0.18
            k = max(0, min(len(pal) - 1, int(v * len(pal))))
            c = pal[k]
            px.append((c[0], c[1], c[2], 255))
    return px


def gen_tiles():
    folder = os.path.join(OUT, "tiles")
    os.makedirs(folder, exist_ok=True)
    concrete = [hexc(c) for c in ("#1c1e22", "#26292e", "#2f3238", "#383c42", "#42464d")]
    frost = [hexc(c) for c in ("#26303a", "#334050", "#435466", "#5a6e80", "#7a92a6")]
    lab = [hexc(c) for c in ("#2a3236", "#353f44", "#414c52", "#4e5a60", "#5e6a70")]
    snow = [hexc(c) for c in ("#3a4250", "#465060", "#525e70", "#5e6a7c", "#6c788a")]
    wall = [hexc(c) for c in ("#2a2e36", "#343943", "#3e4450", "#4a505c", "#565e6a")]

    def slabs(x, y):  # 每 32px 一塊水泥板
        return x % 32 == 0 or y % 32 == 0

    def crack(seed):
        rnd = random.Random(seed)
        pts = set()
        for _ in range(3):
            x, y = rnd.randrange(64), rnd.randrange(64)
            for _ in range(rnd.randrange(6, 14)):
                pts.add((x % 64, y % 64))
                x += rnd.choice((1, 1, 0, -1))
                y += rnd.choice((1, 0, 1, -1))
        return lambda x, y, v: v - 0.3 if (x, y) in pts else v

    write_png(os.path.join(folder, "floor_concrete.png"), 64, 64,
              texture(64, 64, concrete, 11, 0.5, 1.0, slabs, crack(5)))
    write_png(os.path.join(folder, "floor_frost.png"), 64, 64,
              texture(64, 64, frost, 12, 0.5, 0.9, slabs, crack(6)))
    # 無菌室：方形地磚（每 16px 一塊），亮一點
    write_png(os.path.join(folder, "floor_lab.png"), 64, 64,
              texture(64, 64, lab, 13, 0.6, 0.6, lambda x, y: x % 16 == 0 or y % 16 == 0,
                      lambda x, y, v: v + 0.15 if (x % 16 == 1 or y % 16 == 1) else v))
    # 雪地：柔和的起伏、偶爾有腳印般的凹痕
    write_png(os.path.join(folder, "floor_snow.png"), 64, 64, texture(64, 64, snow, 14, 0.5, 1.6))
    # 牆頂：水泥塊、邊緣亮一點
    write_png(os.path.join(folder, "wall_concrete.png"), 32, 32,
              texture(32, 32, wall, 15, 0.5, 0.9, lambda x, y: (y % 16 == 0) or (x % 32 == (0 if y < 16 else 16)),
                      lambda x, y, v: v + 0.2 if (y % 16 == 1) else v))
    print("tiles: ok")


# ── 頭像（同一個角色模型拉近算圖：狀態 App、過場對白用）────────────────

def scale_prims(prims, k, origin):
    out = []
    for p in prims:
        if isinstance(p, Ell):
            out.append(Ell(mul(sub(p.c, origin), k), mul(p.r, k), p.mat, p.b))
        elif isinstance(p, Cap):
            out.append(Cap(mul(sub(p.a, origin), k), mul(sub(p.bp, origin), k), p.r * k, p.mat, p.rb * k))
        elif isinstance(p, Box):
            out.append(Box(mul(sub(p.c, origin), k), mul(p.h, k), p.mat, p.b))
    return out


def portrait_human(spec, mats, extra, yaw=-math.pi / 2 + 0.45):
    pose = default_pose()
    pose["arms"] = {1: (0.05, 0.15, 0.2), -1: (0.05, 0.15, 0.2)}
    prims, J = build_human(spec, pose, mats)
    prims += extra(J)
    head = J["head"]
    prims = [p.moved(lambda v, d=False: v) for p in prims]
    prims = scale_prims(prims, 3.4, add(head, (0, 0, -1.5)))
    return [p.moved(lambda v, d=False: rot_z(v, yaw)) for p in prims]


def gen_portraits():
    folder = os.path.join(OUT, "portraits")
    os.makedirs(folder, exist_ok=True)

    def save(name, prims):
        write_png(os.path.join(folder, name + ".png"), 48, 48,
                  render(prims, 48, 48, pitch=math.radians(8), anchor=(24, 26)))

    def mouth(J, mat="flesh", w=0.9):
        return [Box(head_local(J, (2.9, 0, -1.5)), (0.25, w, 0.22), mat, J["head_basis"])]

    def shen(state):
        skin = "pale" if state == "danger" else "skin"
        mats = {"leg": "pants", "boot": "boot", "hip": "pants", "torso": "parka", "arm": "parka", "hand": skin, "skin": skin}

        def extra(J):
            p = [Ell(head_local(J, (-1.1, 0, 0.9)), (2.9, 3.25, 2.9), "hair"),
                 Ell(head_local(J, (-2.8, 0, -1.6)), (1.4, 1.2, 2.4), "hair"),
                 Ell(head_local(J, (1.4, 0, 2.1)), (1.6, 3.1, 0.9), "hair")]
            p += face(J)
            p += [Box(head_local(J, (2.8, y, 0.75)), (0.2, 0.7, 0.18), "hair", J["head_basis"]) for y in (1.15, -1.15)]
            p += mouth(J, "flesh", 0.7 if state != "fine" else 0.9)
            p.append(Ell(add(J["chest"], (-0.4, 0, 3.6)), (3.2, 4.0, 1.4), "parka_trim"))
            if state == "danger":
                p += [Cap(head_local(J, (2.2, -2.0, -0.8)), head_local(J, (1.6, -2.8, 0.4)), 0.45, "crystal", 0.15),
                      Cap(head_local(J, (1.0, -2.6, 1.2)), head_local(J, (0.4, -3.1, 2.2)), 0.4, "crystal", 0.12),
                      Ell(head_local(J, (-0.5, -0.5, 2.6)), (1.8, 2.0, 0.6), "frost")]
            elif state == "caution":
                p.append(Ell(head_local(J, (-0.8, 0.8, 2.6)), (1.6, 1.6, 0.5), "frost"))
            return p
        return portrait_human({"torso_r": (3.4, 4.2, 5.4)}, mats, extra)

    for st in ("fine", "caution", "danger"):
        save("shen_" + st, shen(st))

    # 科瓦契：灰色短髮、眼鏡、白袍
    def kovac_extra(J):
        p = [Ell(head_local(J, (-1.0, 0, 1.2)), (2.8, 3.2, 2.6), "ash"), Ell(head_local(J, (0.8, 0, 2.2)), (1.8, 3.0, 0.8), "ash")]
        p += face(J)
        p += [Box(head_local(J, (2.95, y, 0.1)), (0.15, 0.85, 0.7), "steel", J["head_basis"]) for y in (1.15, -1.15)]
        p.append(Box(head_local(J, (2.95, 0, 0.3)), (0.15, 0.4, 0.12), "steel", J["head_basis"]))
        p += mouth(J)
        return p
    save("kovac", portrait_human({}, {"leg": "white", "boot": "boot", "hip": "white", "torso": "white", "arm": "white",
                                     "hand": "skin", "skin": "skin"}, kovac_extra))

    # 守門派：頭盔、護目鏡、黑色面罩
    def gate_extra(J):
        return [Ell(head_local(J, (-0.2, 0, 1.0)), (3.4, 3.3, 2.6), "helmet"),
                Box(head_local(J, (2.7, 0, 0.5)), (0.5, 2.0, 0.7), "goggle", J["head_basis"]),
                Ell(add(J["chest"], (0.2, 0, -0.2)), (3.7, 4.5, 4.0), "vest")]
    save("gate", portrait_human({"torso_r": (3.5, 4.4, 5.4)}, {"leg": "olive", "boot": "boot", "hip": "olive",
                                 "torso": "olive", "arm": "olive", "hand": "black", "skin": "black"}, gate_extra))
    print("portraits: ok")


# ── 互動物件（取代程式畫的色塊）──────────────────────────────

def gen_objects():
    folder = os.path.join(OUT, "props")
    os.makedirs(folder, exist_ok=True)

    def save(name, prims, w=16, h=18):
        write_png(os.path.join(folder, name + ".png"), w, h, render(prims, w, h, anchor=(w / 2.0, h - 3.0)))

    save("crate", [Box((0, 3, 5.5), (6, 5.5, 5.5), "wood"), Box((0, -2.6, 5.5), (5.6, 0.2, 0.6), "cloth"),
                   Box((0, -2.6, 5.5), (0.6, 0.2, 5.0), "cloth"), Box((-5.8, -2.6, 5.5), (0.4, 0.3, 5.4), "wood")])
    save("boards", [Box((0, 1, 7 + z * 4.2 - 4), (7.4, 0.8, 1.6), "wood", basis_along((1, 0, 0.08 * (z - 1))))
                    for z in range(3)] + [Box((x, 0.2, 6), (0.3, 0.3, 0.3), "steel") for x in (-5, 5)], 16, 20)
    save("extinguisher", [Cap((0, 1, 1.5), (0, 1, 8.5), 2.2, "red"), Box((0, 1, 10.0), (0.8, 0.8, 1.0), "black"),
                          Cap((0.5, 1, 10.5), (2.8, 0, 8.0), 0.4, "black")], 12, 16)
    save("generator", [Box((0, 4, 5), (7, 5, 5), "olive"), Box((0, -1.05, 6), (4.5, 0.1, 2.5), "vent"),
                       Cap((4.5, 4, 10.5), (4.5, 4, 13), 0.7, "gunmetal"), Box((-5, -1.1, 3), (1.2, 0.2, 1.2), "steel")], 16, 20)
    save("fuel_can", [Box((0, 2, 4.5), (4.5, 3, 4.5), "red"), Box((-2.0, 2, 9.6), (1.0, 1.0, 0.8), "black"),
                      Box((1.5, 2, 9.8), (2.0, 0.6, 0.5), "red")], 12, 16)
    save("oil_drum", [Cap((0, 3, 1.0), (0, 3, 10.0), 5.5, "olive"), Cap((0, 3, 4.0), (0, 3, 4.4), 5.7, "gunmetal"),
                      Cap((0, 3, 7.5), (0, 3, 7.9), 5.7, "gunmetal")], 16, 20)
    save("note", [Box((0, 0, 0.3), (5, 3.8, 0.2), "white"), Box((0, 0, 0.5), (3.5, 0.3, 0.1), "vent"),
                  Box((0, 1.2, 0.5), (3.5, 0.3, 0.1), "vent"), Box((-0.5, -1.2, 0.5), (3.0, 0.3, 0.1), "vent")], 14, 12)
    save("tape", [Box((0, 0, 1.0), (4.5, 2.8, 1.0), "black"), Cap((-1.8, -1.0, 2.1), (-1.8, -1.0, 2.2), 0.9, "white"),
                  Cap((1.8, -1.0, 2.1), (1.8, -1.0, 2.2), 0.9, "white")], 12, 10)
    save("radio", [Box((0, 2, 4), (6.5, 3.5, 4), "olive"), Box((-2.5, -1.6, 4.5), (2.5, 0.2, 2.0), "brass"),
                   Cap((3.5, -1.7, 4.5), (3.5, -2.0, 4.5), 1.4, "black"), Cap((5, 3, 8), (6.5, 4, 14), 0.3, "steel")], 16, 18)
    save("storage_box", [Box((0, 3, 4.5), (7, 4.5, 4.5), "steel"), Box((0, -1.6, 5.5), (6.8, 0.2, 0.4), "gunmetal"),
                         Box((0, -1.7, 3.5), (1.4, 0.3, 0.8), "brass")], 16, 16)
    save("stone_pile", [Ell((x, y, 1.2), (2.2, 1.8, 1.4), "rock") for x, y in ((-3, 1), (2, 2), (-0.5, -1.5), (3.5, -1))]
         + [Ell((0, 0.5, 2.8), (1.8, 1.6, 1.2), "rock")], 14, 10)
    save("supply_crate", [Box((0, 3, 4.5), (7, 4.5, 4.5), "olive"), Box((0, -1.6, 4.5), (1.0, 0.2, 4.4), "red"),
                          Box((0, 3, 9.1), (7, 4.5, 0.2), "olive"), Box((-4, -1.6, 6.5), (1.8, 0.2, 1.2), "white")], 16, 16)
    save("terminal", [Box((0, 3, 2.5), (6, 3.5, 2.5), "cabinet"), Box((0, 4, 8), (5.5, 1.5, 4), "cabinet",
                      basis_along((1, 0, 0), (0, -0.4, 1))), Box((0, 2.4, 8.2), (4.5, 0.2, 3.0), "goggle",
                      basis_along((1, 0, 0), (0, -0.4, 1)))], 16, 18)
    save("uplink", [Box((0, 3, 4), (7, 4, 4), "cabinet"), Box((0, -1.1, 5), (5, 0.2, 2.2), "goggle"),
                    Cap((5, 3, 8), (7.5, 4, 15), 0.35, "steel"), Ell((7.5, 4, 15.5), (2.5, 0.5, 2.5), "steel")], 16, 22)
    save("lift", [Box((0, 2, 0.6), (7.5, 7, 0.6), "gunmetal")] + [Box((x, 2, 0.7), (0.4, 7, 0.4), "brass") for x in (-6, -2, 2, 6)]
         + [Cap((-7, 8, 1), (-7, 8, 14), 0.5, "yellow"), Cap((7, 8, 1), (7, 8, 14), 0.5, "yellow")], 16, 22)
    save("access_card", [Box((0, 0, 0.3), (3.8, 2.5, 0.2), "white"), Box((0, -1.4, 0.5), (3.8, 0.8, 0.1), "goggle")], 10, 8)
    save("gear_case", [Box((0, 2, 3), (6, 4, 3), "olive"), Box((0, -2.1, 3.5), (4.5, 0.2, 1.2), "white"),
                       Box((0, 2, 6.4), (3, 1, 0.5), "black")], 16, 14)
    save("area_map", [Box((0, 0, 0.3), (5.5, 4, 0.2), "cloth"), Box((-2, -1, 0.5), (1.5, 1.5, 0.1), "goggle"),
                      Box((2, 1, 0.5), (2, 1, 0.1), "glass"), Box((1, -2, 0.5), (0.4, 0.4, 0.15), "red")], 14, 12)
    save("safe", [Box((0, 3, 5.5), (6, 4.5, 5.5), "gunmetal"), Cap((1.5, -1.6, 6), (1.5, -1.9, 6), 1.8, "steel"),
                  Box((-4, -1.6, 6), (0.6, 0.3, 2.5), "steel")], 16, 18)
    save("safe_open", [Box((0, 3, 5.5), (6, 4.5, 5.5), "gunmetal"), Box((0, -1.4, 5.5), (5, 0.1, 4.5), "black"),
                       Box((-6.5, -4.0, 5.5), (0.6, 3.5, 5.2), "gunmetal", basis_along((0.5, -1, 0)))], 18, 18)
    # 雪地車（寬）
    save("snowcat", [Box((0, 4, 3), (11, 5, 2.2), "black"), Box((0, 4, 7), (10, 4.5, 2.5), "orange"),
                     Box((3, 4, 11), (5, 4, 2.2), "orange"), Box((5.5, -0.5, 11), (2.0, 0.2, 1.6), "glass"),
                     Box((0.5, -0.5, 11), (2.0, 0.2, 1.6), "glass"), Cap((-8, 4, 10), (-8, 4, 13), 0.5, "gunmetal")], 28, 22)
    print("objects: ok")


# ── 最終 Boss「深井」：最早被感染的研究員，在井底和菌落融合成一整片會共鳴的結晶體（不會移動）──

def well_model(anim, f, n):
    rnd = random.Random(31)
    prims = []
    breathe = bf(f, n) if anim == "idle" else 0.0
    swell = kf([0.0, 1.0], f, n) if anim == "charge" else 0.0
    open_ = 1.0 if anim == "exposed" else 0.0
    dead = anim == "dead"
    s_ = 1.0 + 0.04 * breathe + 0.12 * swell
    sink = 4.0 if dead else 0.0
    # 底座：一大團融合的肉塊
    for c, r in (((0, 4, 5), (17, 13, 7)), ((-8, 6, 9), (8, 7, 7)), ((8, 7, 9), (8, 7, 6)), ((0, 8, 13), (10, 8, 7))):
        prims.append(Ell(mul(c, s_) if not dead else (c[0], c[1], c[2] - sink), mul(r, s_), "mass"))
    # 埋在裡面的臉、伸出來的手（以前的研究員）
    for (x, y, z), sc in (((-8, -9, 9), 1.0), ((7, -9, 10), 1.1), ((0, -8, 15), 1.2), ((-14, -5, 5), 0.8),
                          ((14, -5, 5), 0.8)):
        c = (x * s_, y * s_, z * s_ - sink)
        prims.append(Ell(c, (3.0 * sc, 2.4 * sc, 3.4 * sc), "pale"))
        # 黑洞般的眼窩、張開的嘴
        for ex in (-1.1, 1.1):
            prims.append(Ell(add(c, (ex * sc, -2.1 * sc, 0.9 * sc)), (0.7 * sc, 0.5, 0.6 * sc), "vent"))
        mouth_open = 0.5 + 0.6 * swell + 0.3 * open_
        prims.append(Ell(add(c, (0, -2.1 * sc, -1.3 * sc)), (0.8 * sc, 0.5, mouth_open * sc), "vent"))
    for (x, y, z), (dx, dz) in (((-14, -2, 5), (-6, 4)), ((14, -1, 6), (6, 5)), ((-4, -9, 4), (-3, 2)), ((5, -9, 4), (4, 3))):
        reach = 1.0 + 0.25 * breathe + 0.3 * swell
        a = (x * s_, y * s_, z - sink)
        b = add(a, (dx * reach, -2.0, dz * reach))
        prims.append(Cap(a, b, 1.2, "pale", 0.8))
        prims.append(Ell(b, (1.1, 1.0, 1.0), "pale"))
    # 結晶：從肉塊往外、往上長；裂開時中間的往兩邊倒，露出核心
    for i in range(16):
        ang = rnd.uniform(0, 6.283)
        rad = rnd.uniform(3, 14)
        base = (math.cos(ang) * rad * s_, math.sin(ang) * rad * 0.7 * s_ + 4, rnd.uniform(9, 16) * s_ - sink)
        ln = rnd.uniform(6, 13) * (1.0 + 0.25 * swell) * (0.4 if dead else 1.0)
        out = (math.cos(ang) * rnd.uniform(0.2, 0.7), math.sin(ang) * 0.4, 1.0)
        if rad < 8 and open_ > 0:
            out = (math.cos(ang) * 1.6, math.sin(ang) * 0.6, 0.5)  # 裂開往外倒
        tip = add(base, mul(norm(out), ln))
        prims.append(Cap(base, tip, rnd.uniform(1.2, 2.0), "crystal" if not dead else "frost", 0.35))
    # 核心：裂開時露出來，脈動
    if open_ > 0:
        pulse = 1.0 + 0.2 * math.sin(2 * math.pi * f / max(n, 1))
        prims.append(Ell((0, -1, 17), (4.0 * pulse, 3.4 * pulse, 4.0 * pulse), "core"))
        prims.append(Ell((0, -1, 17), (6.0, 5.0, 2.0), "flesh"))
    elif anim == "charge":
        # 蓄力時核心的光從縫隙透出來
        prims.append(Ell((0, -2, 17), (2.0 + 2.0 * swell, 1.6 + 1.6 * swell, 2.0 + 2.0 * swell), "core"))
    return prims


def gen_well():
    folder = os.path.join(OUT, "well")
    if os.path.isdir(folder):
        for fn in os.listdir(folder):
            if fn.endswith(".png") or fn.endswith(".png.import"):
                os.remove(os.path.join(folder, fn))
    os.makedirs(folder, exist_ok=True)
    count = 0
    for anim, n in (("idle", 6), ("charge", 6), ("exposed", 4), ("dead", 1)):
        for f in range(n):
            prims = scale_prims(well_model(anim, f, n), 1.6, (0, 0, 0))
            write_png(os.path.join(folder, "%s_%d.png" % (anim, f)), 112, 92, render(prims, 112, 92, anchor=(56, 80)))
            count += 1
    print("well: %d 張" % count)


# ── 室內的豐富度：主題家具、地板痕跡、牆上的細節 ─────────────────

def gen_decor():
    folder = os.path.join(OUT, "decor")
    os.makedirs(folder, exist_ok=True)

    def save(name, prims, w=16, h=26, anchor=None):
        write_png(os.path.join(folder, name + ".png"), w, h, render(prims, w, h, anchor=anchor or (w / 2.0, h - 2.0)))

    # 單格家具（底部對齊格子底部，往上突出）
    save("server_rack", [Box((0, 4.5, 10), (6.5, 4.5, 10), "black")]
         + [Box((0, -0.1, 4 + i * 3.2), (5.5, 0.2, 1.1), "vent") for i in range(5)]
         + [Box((4, -0.3, 4 + i * 3.2), (0.5, 0.2, 0.4), "goggle" if i % 2 else "red") for i in range(5)])
    save("specimen_tank", [Cap((0, 4, 2), (0, 4, 18), 5.2, "glass"), Box((0, 4, 1), (6.5, 5.5, 1.2), "gunmetal"),
                           Box((0, 4, 20), (6, 5, 1.2), "gunmetal"), Ell((0, 3, 10), (2.0, 1.6, 4.5), "pale"),
                           Ell((0, 3, 15.5), (1.6, 1.4, 1.6), "pale")])
    save("fume_hood", [Box((0, 4.5, 4), (6.8, 4.5, 4), "cabinet"), Box((0, 4.5, 14), (6.8, 4.5, 6), "benchtop"),
                       Box((0, 0.1, 13), (5.5, 0.2, 4), "glass"), Box((0, 4.5, 20.5), (6.8, 4.5, 0.6), "steel")])
    save("desk_computer", [Box((0, 4, 7.5), (7, 4.5, 0.6), "wood"), Box((-5.5, 4, 3.5), (0.8, 4, 3.5), "wood"),
                           Box((5.5, 4, 3.5), (0.8, 4, 3.5), "wood"), Box((0, 5.5, 11), (3.5, 0.6, 2.8), "black"),
                           Box((0, 4.9, 11), (3.0, 0.1, 2.3), "goggle"), Box((0, 2, 8.3), (3, 1.2, 0.2), "steel")], 16, 20)
    save("bookshelf", [Box((0, 4.5, 11), (7, 4.5, 11), "wood")]
         + [Box((0, -0.15, 2.6 + i * 5), (6.6, 0.2, 0.35), "black") for i in range(4)]
         + [Box((x, -0.3, 4.4 + i * 5), (0.75, 0.3, 1.6), ("red", "olive", "white", "goggle", "orange")[(i + j) % 5])
            for i in range(4) for j, x in enumerate((-5, -3, -1, 1, 3, 5))])
    save("wardrobe", [Box((0, 4.5, 11), (7, 4.5, 11), "wood"), Box((0, -0.1, 11), (0.2, 0.2, 10), "black"),
                      Box((-1.2, -0.3, 11), (0.4, 0.3, 1.2), "brass"), Box((1.2, -0.3, 11), (0.4, 0.3, 1.2), "brass")])
    save("machinery", [Box((0, 4, 6), (7, 5, 6), "olive"), Cap((-4, 4, 12), (-4, 4, 18), 1.4, "gunmetal"),
                       Cap((3, 2, 12), (3, 8, 12), 1.2, "steel"), Box((2, -1.1, 6), (2.5, 0.2, 2), "vent"),
                       Box((-3, -1.2, 8), (0.8, 0.2, 0.8), "red")])
    save("pallet", [Box((0, 4, 0.8), (7, 5, 0.8), "wood"), Box((-2.5, 3, 4.5), (3.2, 3, 3), "cloth"),
                    Box((3.5, 5, 4.0), (2.6, 2.6, 2.6), "cloth"), Box((0, 4, 9.5), (2.6, 2.6, 2.2), "olive")])
    save("ammo_crates", [Box((0, 4, 3), (6.5, 4, 3), "olive"), Box((0, 4, 8.6), (6.5, 4, 2.4), "olive"),
                         Box((0, -0.1, 3), (3.5, 0.2, 1.0), "white"), Box((0, -0.1, 8.6), (3.5, 0.2, 0.9), "white")], 16, 20)
    save("weapon_rack", [Box((0, 5, 10), (7, 1, 10), "wood")]
         + [Box((x, 3.5, 10), (0.6, 0.6, 7.5), "gunmetal") for x in (-4.5, -1.5, 1.5, 4.5)])
    save("sandbags", [Ell((x, 3, 2.2 + z * 3.6), (3.4, 3.4, 2.0), "cloth") for z in range(3)
                      for x in ((-3.5, 3.5) if z != 1 else (-5.5, 0, 5.5))], 18, 18)
    save("ice_pillar", [Cap((0, 4, 0), (0, 4, 20), 4.5, "crystal", 2.5), Cap((-3, 3, 0), (-4, 2, 10), 2.4, "frost", 1.0),
                        Cap((3, 5, 0), (4, 6, 13), 2.2, "crystal", 0.8)], 16, 26)
    # 寬的家具（左、中、右三段）
    def wide(name, prims, h=22):
        img = render(prims, 48, h, anchor=(24, h - 2))
        for i, part in enumerate(("_l", "_m", "_r")):
            sub_img = [img[y * 48 + x] for y in range(h) for x in range(i * 16, i * 16 + 16)]
            write_png(os.path.join(folder, name + part + ".png"), 16, h, sub_img)
    wide("desk_row", [Box((0, 5, 8), (23.5, 5.5, 0.6), "wood"), Box((0, 8.5, 4), (22.5, 0.6, 4), "wood")]
         + [Box((x, 7, 11.5), (3.2, 0.6, 2.6), "black") for x in (-16, 0, 16)]
         + [Box((x, 6.4, 11.5), (2.7, 0.1, 2.1), "goggle") for x in (-16, 0, 16)]
         + [Box((x, 2.5, 8.8), (2.5, 1.0, 0.2), "steel") for x in (-16, 0, 16)])
    wide("bunk", [Box((0, 5, 4), (23.5, 5.5, 1.0), "gunmetal"), Box((0, 5, 5.4), (23, 5, 0.6), "white"),
                  Box((0, 5, 12), (23.5, 5.5, 0.8), "gunmetal"), Box((0, 5, 13.2), (23, 5, 0.6), "white"),
                  Box((-22, 5, 7), (0.8, 5.5, 7), "gunmetal"), Box((22, 5, 7), (0.8, 5.5, 7), "gunmetal"),
                  Ell((-17, 5, 6.4), (3, 4, 0.8), "white"), Ell((-17, 5, 14.2), (3, 4, 0.8), "white"),
                  Box((4, 5, 6.2), (12, 5, 0.5), "olive")], 24)
    wide("crate_row", [Box((x, 4, 5), (7.4, 5, 5), "wood") for x in (-16, 0, 16)]
         + [Box((x, -1.1, 5), (5.5, 0.2, 0.5), "cloth") for x in (-16, 0, 16)]
         + [Box((-8, 4, 12), (6, 4, 2.5), "olive")])
    # 地板痕跡（16x16，半透明，畫在地板上）
    rnd = random.Random(5)
    _ = (0, 0, 0, 0)

    def decal(name, fn):
        px = [_] * 256
        for y in range(16):
            for x in range(16):
                c = fn(x, y)
                if c:
                    px[y * 16 + x] = c
        write_png(os.path.join(folder, name + ".png"), 16, 16, px)
    for v in range(3):
        spots = [(rnd.uniform(3, 13), rnd.uniform(3, 13), rnd.uniform(1.2, 3.5)) for _i in range(4 + v)]
        decal("blood_%d" % v, lambda x, y, sp=spots: (90, 14, 18, 170) if any((x - a) ** 2 + (y - b) ** 2 < r * r for a, b, r in sp)
              else ((70, 10, 14, 90) if any((x - a) ** 2 + (y - b) ** 2 < (r + 1) ** 2 for a, b, r in sp) else None))
    decal("papers", lambda x, y: (200, 200, 190, 220) if (2 <= x <= 7 and 3 <= y <= 9) or (8 <= x <= 13 and 8 <= y <= 13)
          else ((120, 120, 130, 220) if (x in (3, 9) and y in (5, 7, 10, 11)) else None))
    decal("cables", lambda x, y: (25, 25, 30, 230) if abs(y - (8 + 3 * math.sin(x * 0.6))) < 0.8 or abs(x - (6 + 2 * math.sin(y * 0.5))) < 0.7 else None)
    decal("grate", lambda x, y: ((30, 34, 38, 230) if (x % 3 == 0 or y % 3 == 0) else (60, 66, 72, 200)) if 1 <= x <= 14 and 1 <= y <= 14 else None)
    decal("frost", lambda x, y: (200, 230, 245, 70 + rnd.randrange(60)) if rnd.random() < 0.35 * (1 - ((x - 8) ** 2 + (y - 8) ** 2) / 70) else None)
    decal("oil", lambda x, y: (10, 10, 14, 150) if ((x - 8) / 6.5) ** 2 + ((y - 9) / 4.0) ** 2 < 1 else None)
    decal("debris", lambda x, y: (90, 92, 98, 230) if rnd.random() < 0.08 else None)
    decal("stripes", lambda x, y: ((210, 170, 30, 200) if ((x + y) // 3) % 2 == 0 else (20, 20, 20, 200)) if y >= 12 else None)
    decal("drag", lambda x, y: (80, 12, 16, 120) if abs(x - 8 - (y - 8) * 0.2) < 1.6 and rnd.random() < 0.8 else None)
    # 牆上的細節（畫在牆面上）
    def wall(name, w, h, fn):
        px = [_] * (w * h)
        for y in range(h):
            for x in range(w):
                c = fn(x, y)
                if c:
                    px[y * w + x] = c
        write_png(os.path.join(folder, name + ".png"), w, h, px)
    wall("poster", 8, 10, lambda x, y: (20, 20, 24, 255) if x in (0, 7) or y in (0, 9) else
         ((200, 60, 40, 255) if y < 4 else ((230, 225, 210, 255) if (x + y) % 3 else (60, 60, 70, 255))))
    wall("monitor", 10, 8, lambda x, y: (15, 15, 18, 255) if x in (0, 9) or y in (0, 7) else
         ((60, 180, 140, 255) if (y % 2 == 1 and x < 3 + (y * 3) % 6) else (16, 50, 40, 255)))
    wall("vent", 10, 6, lambda x, y: (20, 22, 26, 255) if x in (0, 9) or y in (0, 5) or y % 2 == 0 else (70, 74, 80, 255))
    wall("pipe", 16, 4, lambda x, y: [(40, 44, 50, 255), (110, 116, 124, 255), (80, 86, 94, 255), (30, 34, 40, 255)][y]
         if x % 8 else (20, 22, 26, 255))
    wall("alarm", 5, 5, lambda x, y: (220, 40, 30, 255) if 0 < x < 4 and 0 < y < 4 else (40, 10, 10, 255))
    wall("sign_bio", 9, 8, lambda x, y: (230, 190, 30, 255) if 0 < x < 8 and 0 < y < 7 else (30, 25, 10, 255))
    wall("board", 12, 8, lambda x, y: (60, 40, 25, 255) if x in (0, 11) or y in (0, 7) else
         ((220, 220, 200, 255) if (x // 3 + y // 3) % 2 == 0 else (150, 110, 70, 255)))
    wall("lamp", 6, 4, lambda x, y: (255, 230, 160, 255) if y >= 2 else (40, 40, 44, 255))
    print("decor: ok")


def main():
    want = sys.argv[1:]
    jobs = list(CHARACTERS) + list(OUTFIT_SETS) + ["props", "items", "fx", "tiles", "portraits", "objects", "well", "decor"]
    for j in jobs:
        if want and j not in want:
            continue
        if j in CHARACTERS:
            gen_character(j)
        elif j in OUTFIT_SETS:
            gen_outfit(j)
        elif j == "props":
            gen_props()
        elif j == "items":
            gen_items()
        elif j == "fx":
            gen_fx()
        elif j == "tiles":
            gen_tiles()
        elif j == "portraits":
            gen_portraits()
        elif j == "objects":
            gen_objects()
        elif j == "well":
            gen_well()
        elif j == "decor":
            gen_decor()


if __name__ == "__main__":
    main()
