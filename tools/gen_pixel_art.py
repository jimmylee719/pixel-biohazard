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
# PIXEL_ART_OUT：試畫時輸出到別的資料夾（不動到遊戲的圖）
OUT = os.environ.get("PIXEL_ART_OUT") or os.path.normpath(os.path.join(HERE, "..", "assets", "sprites"))

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
    # 主角的頭盔（一律戴著，不露臉）：消光深色外殼、亮面深色面罩、琥珀色指示燈、耳罩式通訊
    "helm": ["#0d0f14", "#1b1f28", "#2d333f", "#49525f"],
    "helm_trim": ["#1e2229", "#383f4a", "#566070", "#7c8898"],
    "visor": ["#07121c", "#0e2c40", "#1a5a78", "#58b0d0"],
    "amber": ["#b85a08", "#f08c14", "#ffb428", "#ffe08a"],
    "glove": ["#0e0e12", "#1d1e24", "#30323a", "#4a4c56"],
    "mitt": ["#4a4238", "#857a68", "#beb29c", "#e8e0cc"],
    "blade": ["#7c8a9a", "#b4c2d0", "#e4eef8", "#ffffff"],
    # 感染體：髒掉的白袍、死灰的皮膚、乾掉的血、整片的冰甲、深色結晶（陰影面）、裸露的肌肉
    "labcoat": ["#3e4448", "#767e82", "#b4bab8", "#e2e4dc"],
    "dead": ["#1e2628", "#3e4c4c", "#667a76", "#98aaa2"],
    "blood": ["#1c0608", "#40090e", "#681418", "#8e2420"],
    "ice": ["#1e3a52", "#427090", "#7eaeca", "#cfeaf6"],
    "crystal_d": ["#102e40", "#1c5878", "#3494b8", "#7cd0ec"],
    "gum": ["#2a0c12", "#541824", "#86303a", "#b4545a"],
    "shirt": ["#34383c", "#636a6e", "#959c9c", "#c4c8c2"],
    "sac": ["#4a4a14", "#868a24", "#c0c63e", "#eef090"],
    "spore": ["#1e3a1c", "#356a30", "#58a24a", "#9ad880"],
    "husky": ["#1c1e24", "#3a3e48", "#646a76", "#9298a4"],
    # 武裝人員：雪地迷彩（白底灰斑）、深灰戰術背心
    "camo": ["#59626c", "#929ca6", "#c8d0d6", "#f0f4f6"],
    "camo_d": ["#3a424c", "#646e7a", "#8e98a4", "#b4bcc6"],
    "rig": ["#101316", "#20262a", "#343c40", "#4c565a"],
    "lens": ["#3a1c04", "#8a4a0c", "#d88a1c", "#ffd070"],
    # 主角頭像：起霧的面罩、紅色警示燈
    "visor_fog": ["#16222c", "#2e4252", "#56707f", "#93adbb"],
    "alarm": ["#7a0c0c", "#c81a14", "#ff4030", "#ffa090"],
}
MATS = {k: [hexc(c) for c in v] for k, v in MATS.items()}
EMISSIVE = {"crystal", "goggle", "fire", "core", "amber", "blade", "lens", "alarm"}

# 攝影機：3/4 俯視（往下看 35 度）；光從左上前方來
PITCH = math.radians(35)
LIGHT = norm((-0.55, -0.6, 0.85))


# ── 形狀（射線求交）─────────────────────────────────────────

def _keep(o, src):
    """複製形狀時保留標記：layer（裝備圖層）、part（身體部位：描邊用）"""
    o.layer = getattr(src, "layer", False)
    o.part = getattr(src, "part", None)
    return o


def tag(prims, part):
    """把一批形狀標成同一個身體部位（還沒標過的才標）"""
    for q in prims:
        if getattr(q, "part", None) is None:
            q.part = part
    return prims


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
        return _keep(o, self)

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
        return _keep(o, self)

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
        return _keep(o, self)

    def lowest(self):
        return self.c[2] - sum(abs(self.h[i] * self.b[i][2]) for i in range(3))


# 身體部位的描邊：深度差超過這個值 = 一前一後；PART_PRIO = 並排時線畫在誰身上（小的被畫）
PART_EDGE = 0.9
PART_PRIO = {"torso": 0, "hip": 1, "head": 3, "leg": 4, "arm": 6, "gear": 7}


def _part_prio(p):
    return PART_PRIO.get(p.rstrip("-1"), 2) * 4 + (1 if p.endswith("-1") else 2 if p.endswith("1") else 0)


def _same_limb(a, b):
    """腰和腿是同一條褲子：不描（不然大腿上會多一條橫線）"""
    return (a == "hip" and b.startswith("leg")) or (b == "hip" and a.startswith("leg"))


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
    parts = [None] * n
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
                    parts[i] = getattr(p, "part", None)
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
    # 內部描邊（角色看起來不會糊成一團的關鍵）：
    # 1. 不同的身體部位（手臂／軀幹／腿／頭，形狀上的 part 標記）交界：比較後面的那一格畫成最暗的顏色。
    #    就算材質一樣（橘色的手臂擋在橘色的外套前面）也分得出來。
    # 2. 兩個部位並排、深度差不多（正面看手臂貼著身體、兩條腿併在一起）：畫在比較「底層」的部位上（PART_PRIO 小的）。
    # 3. 沒有標部位的東西照舊：前面的東西明顯比較近、材質又不一樣才畫。
    res = list(out)
    for y in range(h):
        for x in range(w):
            i = y * w + x
            if mats[i] is None:
                continue
            pi = parts[i]
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                xx, yy = x + dx, y + dy
                if 0 <= xx < w and 0 <= yy < h:
                    j = yy * w + xx
                    if mats[j] is None:
                        continue
                    pj = parts[j]
                    edge = False
                    if pi is not None and pj is not None and pi != pj and not _same_limb(pi, pj):
                        dd = depth[i] - depth[j]
                        if dd > PART_EDGE or (dd > -PART_EDGE and _part_prio(pi) < _part_prio(pj)):
                            edge = True
                    elif depth[j] < depth[i] - 3.0 and mats[j] != mats[i]:
                        edge = True
                    if edge:
                        c = MATS[mats[i]][0]
                        if idx[i] == 0 and mats[i] not in EMISSIVE:
                            c = (c[0] * 2 // 3, c[1] * 2 // 3, c[2] * 2 // 3 + 2)
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
        "arms": {1: (0.05, 0.2, 0.2), -1: (0.05, 0.2, 0.2)},  # (往前抬, 往外張, 手肘)
        "lean": 0.0, "head_pitch": 0.0, "head_roll": 0.0, "head_fwd": 0.0, "hip_drop": 0.0,
    }


def walk_pose(f, n, stride=0.5, knee=0.9, arm=0.45, lean=0.05):
    p = 2 * math.pi * f / n
    pose = default_pose()
    s = math.sin(p)
    pose["legs"] = {1: (stride * s, 0.1 + knee * max(0.0, math.cos(p))),
                    -1: (-stride * s, 0.1 + knee * max(0.0, -math.cos(p)))}
    pose["arms"] = {1: (-arm * s, 0.2, 0.25 + 0.2 * max(0, -s)), -1: (arm * s, 0.2, 0.25 + 0.2 * max(0, s))}
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


def kt(keys, t):
    """依時間的關鍵影格：keys = [(時間 0～1, 值), ...]，中間 smoothstep。出招的節奏（預備慢、出手快、收招慢）用這個排"""
    if t <= keys[0][0]:
        return keys[0][1]
    for i in range(len(keys) - 1):
        t0, v0 = keys[i]
        t1, v1 = keys[i + 1]
        if t <= t1:
            k = (t - t0) / max(t1 - t0, 1e-6)
            k = k * k * (3 - 2 * k)
            return _lerp_any(v0, v1, k)
    return keys[-1][1]


def build_human(spec, pose, mats, extras=None):
    """回傳區域座標的形狀清單與關節位置。
    pose 另外可以有：twist（上半身繞垂直軸轉，正 = 往左）、hip_x（整個人往前移，重心）、head_yaw。
    mats 可以分左右：arm1／arm-1、fore（前臂）、leg1／leg-1、shin（小腿）、hand1、boot1、neck、head。
    spec 可以有 arm_len／arm_rad／leg_rad = {side: 倍率}（左右不對稱）、claw（指爪長度）、no_head。"""
    if HURT[0] > 0:
        h = HURT[0]
        pose = dict(pose)
        pose["lean"] = pose.get("lean", 0.0) - 0.45 * h
        pose["head_pitch"] = pose.get("head_pitch", 0.0) - 0.5 * h
        pose["arms"] = {1: (0.5 * h, 0.7 * h + 0.1, 0.5), -1: (0.4 * h, 0.8 * h + 0.1, 0.6)}
        pose["twist"] = pose.get("twist", 0.0) + 0.35 * h
    P = dict(HUMAN)
    P.update(spec)

    def M(key, side=None, fallback=None):
        if side is not None and ("%s%d" % (key, side)) in mats:
            return mats["%s%d" % (key, side)]
        if key in mats:
            return mats[key]
        return M(fallback, side) if fallback else mats["skin"]

    hip_z = P["lu"] + P["ll"] - pose.get("hip_drop", 0.0)
    pelvis = (pose.get("hip_x", 0.0), 0.0, hip_z)
    prims = []
    J = {"pelvis": pelvis}
    # 腿
    for side in (1, -1):
        a, k = pose["legs"][side]
        lr = P.get("leg_rad", {}).get(side, 1.0)
        hip = (pelvis[0], side * P["hip_w"], hip_z)
        knee, foot = leg_points(hip, a, k, P["lu"], P["ll"])
        prims.append(Cap(hip, knee, P["leg_r"] * lr, M("leg", side), P["leg_r"] * 0.9 * lr))
        prims.append(Cap(knee, foot, P["leg_r2"] * lr, M("shin", side, "leg"), P["leg_r2"] * 0.85 * lr))
        th = a - k
        fw = max(0.0, min(1.0, (abs(th) - 0.5) / 0.6))  # 腳抬高（踢、跑）時腳掌跟著小腿轉，不然永遠平平的
        fd = norm((lerp(1.0, math.cos(th), fw), 0, lerp(0.0, math.sin(th), fw)))
        toe = add(foot, add(mul(fd, 1.9), (0, 0, -0.2)))
        prims.append(Cap(add(foot, mul(fd, -0.6)), toe, 1.35 * P.get("boot_k", 1.0), M("boot", side)))
        tag(prims, "leg%d" % side)
        J["foot%d" % side] = foot
        J["knee%d" % side] = knee
        J["hip%d" % side] = hip
    lean = pose["lean"]
    twist = pose.get("twist", 0.0)
    Ln = lean_fn(pelvis, lean)

    def L(v):
        q = Ln(v)
        d = rot_z(sub(q, pelvis), twist)
        return add(pelvis, d)

    tb = tuple(rot_z(v, twist) for v in basis_lean(lean))
    tl = P["torso_len"]
    # 軀幹：腰＋胸
    tr = P["torso_r"]
    prims.append(Ell(L(add(pelvis, (0, 0, tl * 0.22))), (tr[0] * 0.85, tr[1] * 0.82, tr[2] * 0.45), mats["hip"],
                     tuple(rot_z(v, twist * 0.5) for v in IDENT)))
    tag(prims, "hip")
    chest_c = L(add(pelvis, (0, 0, tl * 0.6)))
    prims.append(Ell(chest_c, tr, mats["torso"], tb))
    tag(prims, "torso")
    J["chest"] = chest_c
    J["torso_basis"] = tb
    # 頭（頭只跟著身體轉一半：眼睛還是看著前面）
    head_yaw = twist * pose.get("head_follow", 0.45) + pose.get("head_yaw", 0.0)
    neck = L(add(pelvis, (0, 0, tl + P["neck"])))
    hr = P["head_r"]
    head_c = add(neck, add(rot_z((pose.get("head_fwd", 0.0), pose.get("head_side", 0.0), 0.0), head_yaw), (0, 0, hr[2] * 0.85)))
    hb = tuple(rot_z(v, head_yaw) for v in head_basis(pose.get("head_pitch", 0.0), pose.get("head_roll", 0.0)))
    J["head"] = head_c
    J["head_basis"] = hb
    J["neck"] = neck
    if not P.get("no_head"):
        prims.append(Cap(L(add(pelvis, (0, 0, tl * 0.9))), head_c, P.get("neck_r", 1.2), M("neck", None, "skin")))
        prims.append(Ell(head_c, hr, M("head", None, "skin"), hb))
    tag(prims, "head")
    # 手臂
    for side in (1, -1):
        sh0 = add(pelvis, (0.0, side * P["sh_w"], tl * 0.86))
        a, b, e = pose["arms"][side]
        al = P.get("arm_len", {}).get(side, 1.0)
        ar = P["arm_r"] * P.get("arm_rad", {}).get(side, 1.0)
        el0, hand0, df0 = arm_points(Ln(sh0), side, a, b, e, P["au"] * al, P["al"] * al)

        def T(v):
            return add(pelvis, rot_z(sub(v, pelvis), twist))
        sh, el, hand, df = L(sh0), T(el0), T(hand0), rot_z(df0, twist)
        prims.append(Ell(sh, (ar * 1.25, ar * 1.25, ar * 1.25), M("shoulder", side, "torso")))
        prims.append(Cap(sh, el, ar * 1.1, M("arm", side), ar))
        prims.append(Cap(el, hand, ar, M("fore", side, "arm"), ar * 0.9))
        hk = P.get("hand_k", {}).get(side, 1.0) if isinstance(P.get("hand_k"), dict) else P.get("hand_k", 1.0)
        # 手掌比前臂粗一點、往前突出去：顏色又和袖子不一樣，才看得出「手」
        prims.append(Ell(add(hand, mul(df, 0.7)), (1.35 * hk, 1.25 * hk, 1.35 * hk), M("hand", side)))
        claw = P.get("claw", 0.0)
        if claw > 0:
            for off in (0.5, -0.5):
                tip = add(hand, add(mul(df, claw), (0, off * 1.2, -claw * 0.25)))
                prims.append(Cap(hand, tip, 0.5, M("claw", side, "hand"), 0.2))
        tag(prims, "arm%d" % side)
        J["hand%d" % side] = hand
        J["fore%d" % side] = df
        J["sh%d" % side] = sh
        J["elbow%d" % side] = el
    return prims, J


def auto_tag(prims, J):
    """還沒標部位的形狀：靠近頭的算頭、其他算軀幹（結晶、背包、衣服下襬……）。武器要先自己標成 gear"""
    head = J["head"]
    for q in prims:
        if getattr(q, "part", None) is None:
            c = q.c if not isinstance(q, Cap) else mul(add(q.a, q.bp), 0.5)
            d = sub(c, head)
            q.part = "head" if dot(d, d) < 30.0 else "torso"
    return prims


def chest_local(J, off):
    """胸口的區域座標（x 前、y 左、z 上；跟著身體前傾、扭轉）→ 角色座標"""
    x, y, z = J["torso_basis"]
    return add(J["chest"], add(add(mul(x, off[0]), mul(y, off[1])), mul(z, off[2])))


def spike(a, d, ln, r=0.8, mat="crystal", tip=0.2):
    """一根結晶：從 a 往 d 方向長 ln，越來越尖"""
    return Cap(a, add(a, mul(norm(d), ln)), r, mat, tip)


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

def _P(at, basis):
    return lambda o: add(at, add(add(mul(basis[0], o[0]), mul(basis[1], o[1])), mul(basis[2], o[2])))


def pistol(at, basis):
    """制式手槍：方正的滑套（比槍身亮一階，才看得出槍的形狀）、深色槍身、往後斜的握把"""
    P = _P(at, basis)
    return [Box(P((2.6, 0, 0.75)), (3.0, 0.6, 0.6), "cabinet", basis),
            Box(P((2.0, 0, -0.05)), (2.2, 0.55, 0.35), "gunmetal", basis),
            Box(P((-0.1, 0, -1.0)), (0.8, 0.5, 1.2), "black", basis_along(add(basis[0], mul(basis[2], -0.3))))]


def revolver(at, basis):
    """左輪：長槍管、鼓起來的彈巢、木頭握把"""
    P = _P(at, basis)
    return [Box(P((4.2, 0, 0.9)), (2.8, 0.42, 0.42), "steel", basis),
            Ell(P((1.5, 0, 0.6)), (1.3, 1.0, 1.05), "steel", basis),
            Box(P((0.6, 0, 0.6)), (1.6, 0.5, 0.75), "cabinet", basis),
            Box(P((-0.5, 0, -1.0)), (0.75, 0.5, 1.15), "wood", basis_along(add(basis[0], mul(basis[2], -0.45))))]


def nailgun(at, basis):
    P = _P(at, basis)
    return [Box(P((2.2, 0, 0.9)), (3.0, 0.8, 1.1), "yellow", basis), Box(P((5.4, 0, 0.5)), (0.5, 0.5, 0.6), "steel", basis),
            Box(P((2.6, 0, -1.2)), (0.9, 0.6, 1.2), "gunmetal", basis), Box(P((0.0, 0, -0.9)), (0.8, 0.6, 1.3), "black", basis)]


def flare_gun(at, basis):
    P = _P(at, basis)
    return [Box(P((2.0, 0, 0.8)), (2.4, 0.9, 0.95), "orange", basis), Box(P((4.5, 0, 0.8)), (0.4, 1.0, 1.05), "black", basis),
            Box(P((0.0, 0, -0.9)), (0.8, 0.6, 1.3), "orange", basis_along(add(basis[0], mul(basis[2], -0.3))))]


def smg(at, basis):
    """衝鋒槍：短槍身、機匣下面一根直彈匣、伸縮槍托、短槍管"""
    P = _P(at, basis)
    return [Box(P((2.6, 0, 0.5)), (3.4, 0.7, 0.95), "cabinet", basis),
            Box(P((6.8, 0, 0.6)), (1.0, 0.38, 0.38), "steel", basis),
            Box(P((3.2, 0, -1.9)), (0.6, 0.5, 1.6), "black", basis),
            Box(P((-2.4, 0, 0.6)), (1.9, 0.45, 0.4), "gunmetal", basis),
            Box(P((-4.1, 0, 0.1)), (0.35, 0.55, 1.0), "gunmetal", basis),
            Box(P((2.4, 0, 1.75)), (1.2, 0.4, 0.3), "black", basis)]


def crossbow(at, basis):
    """十字弓：木頭槍托、前端橫著的弓臂（看得出「十字」）、拉到後面的弦、上好的箭"""
    P = _P(at, basis)
    p = [Box(P((1.5, 0, 0.2)), (5.6, 0.6, 0.7), "wood", basis),
         Box(P((-3.4, 0, -0.3)), (1.6, 0.6, 1.1), "wood", basis),
         Cap(P((1.0, 0, 1.1)), P((8.2, 0, 1.1)), 0.32, "blade")]
    for sgn in (1, -1):
        p.append(Cap(P((6.6, 0, 0.8)), P((5.2, sgn * 5.4, 0.8)), 0.6, "gunmetal", 0.4))   # 弓臂（往後彎）
        p.append(Cap(P((5.2, sgn * 5.4, 0.8)), P((1.2, 0, 1.0)), 0.22, "steel"))           # 弦
    return p


def crowbar(at, d, k=1.0):
    """鐵撬：一根長鐵條，前端彎鉤、尾端扁平。k = 揮出去那幾格放大"""
    b = basis_along(d)
    P = _P(at, b)
    return [Cap(P((-1.6, 0, 0)), P((8.8 * k, 0, 0)), 0.55, "steel"),
            Cap(P((8.8 * k, 0, 0)), P((9.8 * k, 0, 1.9 * k)), 0.6, "steel", 0.4),
            Box(P((4.0 * k, 0, 0)), (1.6, 0.62, 0.62), "red", b)]


def long_gun(at, basis, length=11.0, stock="wood"):
    def P(o): return add(at, add(add(mul(basis[0], o[0]), mul(basis[1], o[1])), mul(basis[2], o[2])))
    return [Box(P((length * 0.35, 0, 0.6)), (length * 0.5, 0.55, 0.7), "gunmetal", basis),
            Box(P((length * 0.45, 0, -0.3)), (length * 0.22, 0.6, 0.6), stock, basis),
            Box(P((-2.6, 0, -0.4)), (2.4, 0.6, 1.0), stock, basis)]


def assault_rifle(at, basis):
    """武裝人員的突擊步槍：深色槍身、彎彈匣、槍托、亮一點的槍管和瞄具（在深色背心前面也看得出來）"""
    def P(o): return add(at, add(add(mul(basis[0], o[0]), mul(basis[1], o[1])), mul(basis[2], o[2])))
    return [Box(P((1.5, 0, 0.6)), (4.6, 0.7, 0.95), "gunmetal", basis),            # 機匣＋護木
            Box(P((8.2, 0, 0.8)), (2.4, 0.4, 0.4), "steel", basis),                # 槍管
            Box(P((-4.6, 0, 0.1)), (2.0, 0.6, 1.0), "gunmetal", basis),            # 槍托
            Box(P((1.6, 0, -1.6)), (0.75, 0.55, 1.5), "black", basis_along(add(basis[0], mul(basis[2], 0.25)))),  # 彈匣
            Box(P((1.0, 0, 1.9)), (1.5, 0.45, 0.4), "steel", basis)]               # 瞄具


def axe(at, d, k=1.0):
    """消防斧。k = 揮出去那幾格放大（看得清楚）"""
    b = basis_along(d)

    def P(o): return add(at, add(add(mul(b[0], o[0]), mul(b[1], o[1])), mul(b[2], o[2])))
    return [Box(P((3.6, 0, 0)), (5.2, 0.5, 0.5), "wood", b),
            Box(P((7.8, 0, 1.3 * k)), (1.4 * k, 0.5, 1.9 * k), "red", b),
            Box(P((7.8, 0, 3.3 * k)), (1.7 * k, 0.45, 0.55 * k), "blade", b),
            Box(P((7.8, 0, -0.9)), (0.9, 0.45, 0.6), "steel", b)]


def knife(at, d, k=1.0):
    """求生刀。刀身用會發亮的材質（暗的地方也看得到），k = 揮出去那幾格放大"""
    b = basis_along(d)

    def P(o): return add(at, add(add(mul(b[0], o[0]), mul(b[1], o[1])), mul(b[2], o[2])))
    return [Box(P((0.2, 0, 0)), (1.1, 0.55, 0.55), "black", b),
            Box(P((1.3, 0, 0)), (0.3, 0.6, 1.0), "gunmetal", b),
            Box(P((1.5 + 2.7 * k, 0, 0.1)), (2.7 * k, 0.3, 0.75 * k), "blade", b)]


# ── 角色 ─────────────────────────────────────────────────

## 主角的服裝（紙娃娃）：body = 本體的套裝；head / feet = 疊在上面的圖層；layer = 這次只輸出哪一層
## 主角一律戴頭盔、面罩遮住臉（臉留到續作才揭曉）：頭部裝備都是「頭盔的外罩／配件」，不會露出臉或頭髮。
OUTFIT = {"body": "parka", "head": "", "feet": "", "layer": ""}
BODY_STYLE = {
    "parka": ({"leg": "pants", "hip": "pants", "torso": "parka", "arm": "parka", "hand": "mitt"}, {}),
    "hazmat": ({"leg": "hazmat", "hip": "hazmat", "torso": "hazmat", "arm": "hazmat", "hand": "glove"},
               {"torso_r": (3.7, 4.5, 5.6)}),
    "eod": ({"leg": "eod", "hip": "eod", "torso": "eod", "arm": "eod", "hand": "mitt"},
            {"torso_r": (4.4, 5.2, 6.0), "arm_r": 2.0, "leg_r": 2.4, "leg_r2": 2.0, "sh_w": 4.8}),
    "sneak": ({"leg": "sneak", "hip": "sneak", "torso": "sneak", "arm": "sneak", "hand": "helm_trim"},
              {"torso_r": (3.0, 3.9, 5.2), "arm_r": 1.35}),
    "arctic": ({"leg": "white", "hip": "white", "torso": "white", "arm": "white", "hand": "glove"},
               {"torso_r": (3.6, 4.4, 5.5)}),
}


def helmet_prims(J, visor="visor", light="amber"):
    """主角的頭盔（訊號偵察兵用的小型戰術頭盔）：消光外殼、整片亮面面罩、右臉頰一顆琥珀色指示燈、
    兩側耳罩式通訊、左耳罩一根短天線。portrait、遊戲裡的小人都用這一份。"""
    hb = J["head_basis"]
    p = [Ell(head_local(J, (-0.3, 0, 0.5)), (3.7, 3.5, 3.45), "helm", hb),          # 外殼
         Ell(head_local(J, (0.5, 0, -1.4)), (3.0, 2.95, 2.2), "helm", hb),          # 下巴護罩
         Ell(head_local(J, (1.25, 0, 0.15)), (2.7, 2.95, 1.65), visor, hb),         # 面罩
         Box(head_local(J, (2.3, 0, 2.05)), (1.0, 2.5, 0.35), "helm_trim", hb),     # 眉框
         Ell(head_local(J, (-0.3, 3.3, -0.3)), (1.6, 0.95, 1.7), "helm_trim", hb),  # 耳罩
         Ell(head_local(J, (-0.3, -3.3, -0.3)), (1.6, 0.95, 1.7), "helm_trim", hb),
         Cap(head_local(J, (-0.9, 3.7, 0.6)), head_local(J, (-1.3, 3.8, 4.0)), 0.3, "helm_trim", 0.25)]  # 天線
    if light:
        p.append(Box(head_local(J, (3.3, -1.9, -1.1)), (0.45, 0.55, 0.5), light, hb))
    return p


def gear_prims(J, slot, gear_id):
    """頭部、腳部裝備的形狀（標記成圖層）。頭部裝備都是套在頭盔外面的外罩或配件"""
    p = []
    hb = J["head_basis"]
    if slot == "head":
        if gear_id == "gas_mask":
            # 防護頭罩＋掛在下巴護罩兩側的濾毒罐、面罩外加一片護目片
            p += [Ell(head_local(J, (-0.7, 0, 0.6)), (3.9, 3.8, 3.75), "hazmat", hb),
                  Box(head_local(J, (3.75, 0, 0.2)), (0.3, 2.1, 0.85), "goggle", hb),
                  Ell(head_local(J, (1.2, 0, -1.9)), (2.9, 2.6, 1.6), "black", hb)]
            p += [Cap(head_local(J, (2.6, y, -1.9)), head_local(J, (4.0, y * 1.35, -2.5)), 1.05, "steel", 0.95) for y in (1.5, -1.5)]
        elif gear_id == "eod_helmet":
            # 防爆頭盔：整個罩在外面的大外殼＋防爆面板
            p += [Ell(head_local(J, (-0.5, 0, 0.5)), (4.6, 4.5, 4.6), "eod", hb),
                  Box(head_local(J, (3.9, 0, 0.2)), (0.5, 2.8, 1.9), "glass", hb),
                  Ell(head_local(J, (0.2, 0, -3.0)), (4.2, 4.6, 1.4), "eod", hb)]
        elif gear_id == "balaclava":
            # 黑色頭盔罩：外殼、耳罩全部包起來，面罩貼上消光膜，指示燈遮掉
            p += [Ell(head_local(J, (-0.3, 0, 0.45)), (3.9, 3.95, 3.65), "black", hb),
                  Ell(head_local(J, (0.5, 0, -1.4)), (3.3, 3.2, 2.4), "black", hb),
                  Box(head_local(J, (3.75, 0, 0.2)), (0.3, 2.0, 0.6), "sneak", hb)]
        elif gear_id == "snow_goggles":
            # 白色頭盔罩＋橘色雪鏡片
            p += [Ell(head_local(J, (-0.5, 0, 0.9)), (3.95, 3.75, 3.3), "white", hb),
                  Box(head_local(J, (3.8, 0, 0.3)), (0.35, 2.3, 0.85), "orange", hb),
                  Ell(head_local(J, (-0.3, 0, 0.3)), (3.85, 3.7, 0.5), "black", hb)]
        elif gear_id == "wool_hat":
            # 毛線頭盔套（有毛球）
            p += [Ell(head_local(J, (-0.3, 0, 1.7)), (4.0, 3.8, 2.7), "knit", hb),
                  Ell(head_local(J, (-0.3, 0, 0.9)), (4.05, 3.85, 0.7), "knit", hb),
                  Ell(head_local(J, (-0.7, 0, 4.7)), (1.15, 1.15, 1.15), "white")]
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


## 近戰每一招的節奏（時間 0～1）：預備 → 出手 → 收招。出手那一段（STRIKE）武器會放大、身體轉最多
STRIKE = {"slash": (0.2, 0.56), "slash_axe": (0.3, 0.62), "punch": (0.22, 0.55), "kick": (0.3, 0.62),
          "slash_back": (0.2, 0.56), "stab": (0.26, 0.64), "hook": (0.26, 0.64), "slash_crowbar": (0.3, 0.66),
          "jab_l": (0.18, 0.5), "jab_r": (0.18, 0.5), "cross_l": (0.22, 0.55), "cross_r": (0.22, 0.55),
          "hook_l": (0.26, 0.64), "hook_r": (0.26, 0.64)}

## 空手拳擊（v0.14）：刺拳 → 直拳 → 勾拳，左右兩套（右手開頭 = 整套鏡像）
## 名稱 → (底稿動作, 要不要左右鏡像, 轉腰幅度, 出拳的手 1 = 左、-1 = 右)
## 底稿：punch = 左直拳（手 1）、hook = 右勾拳（手 -1）
FIST_ANIMS = {"jab_l": ("punch", False, 0.55, 1), "cross_r": ("punch", True, 1.2, -1), "hook_l": ("hook", True, 1.0, 1),
              "jab_r": ("punch", True, 0.55, -1), "cross_l": ("punch", False, 1.2, 1), "hook_r": ("hook", False, 1.0, -1)}


def fist_variant(pose, mirror, twist_k):
    """把底稿的拳改成另一種：鏡像 = 左右手腳交換、轉腰方向相反；twist_k = 轉腰幅度（刺拳小、直拳大）"""
    pose = dict(pose)
    if mirror:
        pose["arms"] = {1: pose["arms"][-1], -1: pose["arms"][1]}
        pose["legs"] = {1: pose["legs"][-1], -1: pose["legs"][1]}
    tw = pose.get("twist", 0.0) * twist_k
    pose["twist"] = -tw if mirror else tw
    if twist_k < 1.0:  # 刺拳：重心幾乎不動
        pose["hip_x"] = pose.get("hip_x", 0.0) * 0.6
        pose["lean"] = pose.get("lean", 0.0) * 0.6
    return pose

## 槍：手槍類（雙手握）、長槍類（抵肩）
HANDGUNS = ("pistol", "revolver", "nailgun", "flare_gun")
LONGGUNS = ("shotgun", "rifle", "smg", "crossbow")
GUNS = ("pistol", "shotgun", "rifle", "nailgun", "flare_gun", "revolver", "smg", "crossbow")


def aim_pose(gun):
    """瞄準姿勢。手槍：雙手在身體中線前方合握（慣用手握槍、輔助手包住），手肘微彎不鎖死，槍舉到視線高度，
    上身微微前傾、膝蓋微彎、輔助手那側的腳在前。長槍：槍托抵右肩，右手握把（手肘彎）、左手往前托護木。"""
    pose = default_pose()
    pose["lean"] = 0.1
    pose["hip_drop"] = 0.45
    if gun in HANDGUNS:
        pose["legs"] = {1: (0.24, 0.22), -1: (-0.2, 0.2)}
        pose["arms"] = {-1: (1.44, -0.46, 0.08), 1: (1.4, -0.52, 0.12)}
        pose["head_pitch"] = 0.08
    else:
        pose["legs"] = {1: (0.3, 0.22), -1: (-0.22, 0.2)}
        fwd = {"smg": (1.2, -0.4, 0.5), "crossbow": (1.3, -0.32, 0.3)}.get(gun, (1.35, -0.3, 0.2))
        pose["arms"] = {1: fwd, -1: (0.75, 0.05, 1.3)}
        pose["head_pitch"] = 0.12
        pose["head_roll"] = -0.12
    return pose


def gun_prims(gun, J):
    X = basis_along((1, 0, 0))
    if gun in HANDGUNS:
        at = add(mul(add(J["hand1"], J["hand-1"]), 0.5), (1.0, 0, 0.7))
        return {"pistol": pistol, "revolver": revolver, "nailgun": nailgun, "flare_gun": flare_gun}[gun](at, X)
    at = add(J["hand-1"], (0.4, 0.0, 0.8))
    b = basis_along((1, 0, 0.04))
    if gun == "shotgun":
        return long_gun(at, b, 13.0)
    if gun == "rifle":
        return long_gun(at, b, 17.0) + [Box(add(at, (4.0, 0, 1.6)), (2.0, 0.5, 0.5), "black")]  # 瞄準鏡
    if gun == "smg":
        return smg(at, b)
    return crossbow(at, b)


def player_model(anim, f, n, pose_only=False):
    body_mats, body_spec = BODY_STYLE[OUTFIT["body"]]
    mats = {"leg": "pants", "boot": "boot", "hip": "pants", "torso": "parka", "arm": "parka", "hand": "mitt",
            "skin": "glove", "head": "helm"}
    mats.update(body_mats)
    spec = {"torso_r": (3.3, 4.0, 5.3), "lu": 6.4, "ll": 6.4, "sh_w": 4.7, "hip_w": 2.3, "arm_r": 1.55,
            "hand_k": 1.2, "boot_k": 1.15}
    spec.update(body_spec)
    weapon = []
    t = f / max(n - 1, 1)
    blade_k = 1.0
    if anim == "idle":
        pose = default_pose()
        pose["arms"][1] = (0.05, 0.22 + 0.03 * bf(f, n), 0.25)
        pose["arms"][-1] = (0.05, 0.22 + 0.03 * bf(f, n), 0.25)
        pose["hip_drop"] = 0.3 * bf(f, n)
    elif anim == "walk":
        pose = walk_pose(f, n)
        pose["twist"] = 0.12 * math.sin(2 * math.pi * f / n)
    elif anim == "sneak":
        pose = walk_pose(f, n, stride=0.35, knee=0.6, arm=0.15, lean=0.32)
        for s in (1, -1):
            a, k = pose["legs"][s]
            pose["legs"][s] = (a + 0.75, k + 1.25)
        pose["arms"] = {1: (0.3, 0.25, 0.45), -1: (0.35 + 0.08 * math.sin(2 * math.pi * f / n), 0.2, 0.45)}
        pose["head_fwd"] = 0.6
    elif anim.startswith("aim_"):
        pose = aim_pose(anim[4:])
    elif anim.startswith("aimwalk_"):
        # 舉槍移動：上半身 = 瞄準姿勢（槍口不晃），腳 = 小步、壓低重心的走路循環
        pose = aim_pose(anim[8:])
        w_ = walk_pose(f, n, stride=0.36, knee=0.75, arm=0.0)
        ph = 2 * math.pi * f / n
        pose["legs"] = {s_: (w_["legs"][s_][0], w_["legs"][s_][1] + 0.12) for s_ in (1, -1)}
        pose["hip_drop"] = 0.55 + 0.25 * math.cos(2 * ph)
        pose["twist"] = pose.get("twist", 0.0) + 0.05 * math.sin(ph)
    elif anim.startswith("shoot_"):
        # 開槍：從瞄準姿勢往上、往後彈（後座力），再回到瞄準
        base = player_model("aim_" + anim[6:], 0, 1, pose_only=True)
        pose = base
        r = kf([1.0, 0.55, 0.15], f, n)
        heavy = {"shotgun": 1.6, "rifle": 1.6, "revolver": 1.4, "smg": 0.7, "crossbow": 0.6, "nailgun": 0.7}.get(anim[6:], 1.0)
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
        pose["twist"] = 0.3 * r
    elif anim == "choke":
        # 裸絞（v0.14）：從背後兩手環過對方的脖子（胸口高度、前臂橫在前面）、往後收緊，身體微微後仰；一緊一鬆
        pose = default_pose()
        sq = bf(f, n)
        pose["arms"] = {1: (0.9 + 0.06 * sq, -0.75, 2.0 + 0.1 * sq), -1: (0.85 + 0.06 * sq, -0.6, 2.15 + 0.1 * sq)}
        pose["lean"] = -0.1 - 0.06 * sq
        pose["hip_drop"] = 0.6 + 0.2 * sq
        pose["legs"] = {1: (0.22, 0.35), -1: (-0.2, 0.25)}
        pose["twist"] = 0.06 * sq
    elif anim in FIST_ANIMS:
        base, mirror, twist_k, _hand = FIST_ANIMS[anim]
        pose = fist_variant(player_model(base, f, n, pose_only=True), mirror, twist_k)
    elif anim == "slash":
        # 橫砍（右手反手往左前方掃）：右肩往後收 → 轉腰、踏步、手臂掃過身體前方 → 掃到左邊收住 → 回正
        pose = default_pose()
        pose["twist"] = kt([(0.0, -0.35), (0.12, -0.8), (0.36, 0.15), (0.5, 0.8), (0.7, 0.9), (1.0, 0.25)], t)
        pose["arms"] = {
            -1: kt([(0.0, (0.8, 0.8, 1.5)), (0.12, (1.0, 1.25, 1.75)), (0.36, (1.45, 0.25, 0.25)),
                    (0.5, (1.3, -0.75, 0.1)), (0.7, (1.05, -1.0, 0.35)), (1.0, (0.6, -0.2, 1.0))], t),
            1: kt([(0.0, (0.8, 0.2, 1.4)), (0.12, (1.0, 0.0, 1.2)), (0.45, (0.2, 0.6, 1.3)), (1.0, (0.5, 0.3, 1.2))], t)}
        pose["lean"] = kt([(0.0, 0.05), (0.12, -0.06), (0.45, 0.3), (0.7, 0.26), (1.0, 0.08)], t)
        pose["hip_x"] = kt([(0.0, 0.0), (0.12, -0.9), (0.45, 2.2), (0.7, 2.0), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.4), (0.12, 0.9), (0.45, 1.5), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.2, 0.3)), (0.12, (0.1, 0.5)), (0.45, (0.6, 0.75)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.2, 0.25)), (0.12, (-0.25, 0.55)), (0.45, (-0.55, 0.2)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "slash_axe":
        # 斧頭：舉過右肩 → 整個人壓下去斜劈到左下 → 斧頭沉到地面附近 → 拉回來
        pose = default_pose()
        pose["twist"] = kt([(0.0, -0.25), (0.2, -0.75), (0.45, 0.1), (0.62, 0.75), (0.8, 0.8), (1.0, 0.2)], t)
        pose["arms"] = {
            -1: kt([(0.0, (1.4, 0.5, 1.4)), (0.2, (2.7, 0.55, 0.9)), (0.45, (1.75, 0.15, 0.2)),
                    (0.62, (0.75, -0.55, 0.1)), (0.8, (0.5, -0.7, 0.2)), (1.0, (0.6, -0.1, 0.9))], t),
            1: kt([(0.0, (1.0, 0.1, 1.2)), (0.2, (1.6, -0.1, 0.9)), (0.55, (0.3, 0.6, 1.1)), (1.0, (0.5, 0.3, 1.1))], t)}
        pose["lean"] = kt([(0.0, 0.0), (0.2, -0.2), (0.55, 0.45), (0.8, 0.5), (1.0, 0.12)], t)
        pose["hip_x"] = kt([(0.0, 0.0), (0.2, -1.2), (0.55, 2.4), (0.8, 2.4), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.4), (0.2, 0.3), (0.6, 2.4), (0.8, 2.4), (1.0, 0.7)], t)
        pose["legs"] = {1: kt([(0.0, (0.2, 0.3)), (0.2, (0.05, 0.3)), (0.6, (0.75, 1.1)), (1.0, (0.4, 0.5))], t),
                        -1: kt([(0.0, (-0.2, 0.25)), (0.2, (-0.2, 0.4)), (0.6, (-0.6, 0.3)), (1.0, (-0.3, 0.3))], t)}
    elif anim == "slash_back":
        # 反手回砍（接在橫砍後面）：刀從左邊收著 → 轉腰往右掃回來 → 掃到右邊收住 → 回正。路線和 slash 左右相反
        pose = default_pose()
        pose["twist"] = kt([(0.0, 0.7), (0.12, 0.95), (0.36, 0.1), (0.5, -0.6), (0.7, -0.75), (1.0, -0.2)], t)
        pose["arms"] = {
            -1: kt([(0.0, (1.05, -0.9, 0.5)), (0.12, (1.1, -1.15, 0.9)), (0.36, (1.45, -0.3, 0.15)),
                    (0.5, (1.35, 0.7, 0.05)), (0.7, (1.1, 1.05, 0.3)), (1.0, (0.7, 0.4, 1.0))], t),
            1: kt([(0.0, (0.3, 0.5, 1.3)), (0.12, (0.4, 0.4, 1.4)), (0.45, (0.9, 0.1, 1.5)), (1.0, (0.7, 0.3, 1.3))], t)}
        pose["lean"] = kt([(0.0, 0.2), (0.12, 0.1), (0.45, 0.3), (0.7, 0.24), (1.0, 0.08)], t)
        pose["hip_x"] = kt([(0.0, 1.2), (0.12, 0.6), (0.45, 2.4), (0.7, 2.2), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.8), (0.12, 1.0), (0.45, 1.5), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.45, 0.55)), (0.45, (0.6, 0.75)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.4, 0.25)), (0.45, (-0.55, 0.2)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "stab":
        # 直刺：右手收到腰邊（手肘往後拉）→ 轉腰送肩、整隻手臂打直刺出去 → 停一下 → 抽回
        pose = default_pose()
        pose["twist"] = kt([(0.0, -0.3), (0.16, -0.7), (0.42, 0.75), (0.62, 0.8), (1.0, 0.15)], t)
        pose["arms"] = {
            -1: kt([(0.0, (0.5, 0.35, 1.5)), (0.16, (-0.35, 0.3, 1.9)), (0.42, (1.5, -0.12, 0.0)),
                    (0.62, (1.48, -0.12, 0.05)), (1.0, (0.7, 0.2, 1.3))], t),
            1: kt([(0.0, (1.0, -0.2, 1.1)), (0.16, (1.25, -0.3, 0.7)), (0.42, (0.3, 0.55, 1.5)), (1.0, (0.7, 0.3, 1.3))], t)}
        pose["lean"] = kt([(0.0, 0.05), (0.16, -0.04), (0.42, 0.34), (0.62, 0.34), (1.0, 0.1)], t)
        pose["hip_x"] = kt([(0.0, 0.0), (0.16, -1.0), (0.42, 2.8), (0.62, 2.8), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.5), (0.16, 0.9), (0.42, 1.4), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.2, 0.3)), (0.16, (0.1, 0.5)), (0.42, (0.7, 0.85)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.2, 0.25)), (0.16, (-0.25, 0.5)), (0.42, (-0.6, 0.15)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "hook":
        # 右勾拳（接在左直拳後面）：右拳往外拉開、手肘彎著 → 轉腰，拳頭畫一個大弧掃到身體前面 → 停一下 → 收回
        pose = default_pose()
        pose["twist"] = kt([(0.0, -0.5), (0.16, -0.85), (0.42, 0.7), (0.62, 0.85), (1.0, 0.15)], t)
        pose["arms"] = {
            -1: kt([(0.0, (0.8, 0.5, 1.6)), (0.16, (0.9, 1.25, 1.5)), (0.3, (1.25, 0.9, 1.35)), (0.42, (1.4, -0.1, 1.3)),
                    (0.62, (1.4, -0.45, 1.35)), (1.0, (0.9, 0.3, 1.5))], t),
            1: kt([(0.0, (1.3, -0.1, 0.5)), (0.16, (1.0, 0.1, 1.3)), (0.42, (0.6, 0.45, 1.7)), (1.0, (0.9, 0.3, 1.5))], t)}
        pose["lean"] = kt([(0.0, 0.2), (0.16, 0.05), (0.42, 0.28), (0.62, 0.28), (1.0, 0.1)], t)
        pose["hip_x"] = kt([(0.0, 1.2), (0.16, 0.3), (0.42, 2.2), (0.62, 2.2), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.7), (0.42, 1.2), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.45, 0.55)), (0.42, (0.5, 0.7)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.45, 0.2)), (0.42, (-0.35, 0.45)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "slash_crowbar":
        # 鐵撬（雙手橫掃，打得遠）：雙手握著拉到右後方 → 整個人轉過去掃一大圈到左邊 → 順勢帶過去 → 拉回來
        pose = default_pose()
        pose["twist"] = kt([(0.0, -0.4), (0.22, -1.0), (0.44, 0.0), (0.6, 0.85), (0.8, 1.0), (1.0, 0.25)], t)
        pose["arms"] = {
            -1: kt([(0.0, (1.0, 0.5, 1.2)), (0.22, (1.15, 1.0, 1.1)), (0.44, (1.45, 0.2, 0.15)),
                    (0.6, (1.35, -0.6, 0.1)), (0.8, (1.1, -0.95, 0.4)), (1.0, (0.7, -0.1, 1.0))], t),
            1: kt([(0.0, (1.1, -0.5, 1.0)), (0.22, (1.25, -0.9, 0.9)), (0.44, (1.4, -0.55, 0.5)),
                   (0.6, (1.3, -0.1, 0.7)), (0.8, (1.0, 0.3, 1.1)), (1.0, (0.7, 0.2, 1.1))], t)}
        pose["lean"] = kt([(0.0, 0.05), (0.22, -0.08), (0.5, 0.32), (0.8, 0.3), (1.0, 0.1)], t)
        pose["hip_x"] = kt([(0.0, 0.0), (0.22, -1.2), (0.5, 2.4), (0.8, 2.2), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.4), (0.22, 1.0), (0.5, 1.6), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.2, 0.3)), (0.22, (0.05, 0.5)), (0.5, (0.65, 0.8)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.2, 0.25)), (0.22, (-0.3, 0.6)), (0.5, (-0.6, 0.2)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "punch":
        # 左直拳（接在橫砍後面：腰往反方向轉回來）：左肩往後收 → 轉腰送肩、手臂打直 → 停一下 → 收回
        pose = default_pose()
        pose["twist"] = kt([(0.0, 0.35), (0.14, 0.6), (0.4, -0.7), (0.6, -0.75), (1.0, -0.1)], t)
        pose["arms"] = {
            1: kt([(0.0, (0.9, 0.3, 1.7)), (0.14, (0.7, 0.5, 2.0)), (0.4, (1.52, -0.1, 0.0)),
                   (0.6, (1.5, -0.1, 0.08)), (1.0, (1.0, 0.2, 1.4))], t),
            -1: kt([(0.0, (1.0, -0.6, 0.6)), (0.14, (1.0, -0.2, 1.2)), (0.4, (0.5, 0.5, 1.7)), (1.0, (0.8, 0.3, 1.5))], t)}
        pose["lean"] = kt([(0.0, 0.1), (0.14, 0.0), (0.4, 0.3), (0.6, 0.3), (1.0, 0.1)], t)
        pose["hip_x"] = kt([(0.0, 0.5), (0.14, -0.3), (0.4, 2.4), (0.6, 2.4), (1.0, 0.6)], t)
        pose["hip_drop"] = kt([(0.0, 0.5), (0.4, 1.1), (1.0, 0.5)], t)
        pose["legs"] = {1: kt([(0.0, (0.3, 0.4)), (0.4, (0.6, 0.7)), (1.0, (0.35, 0.4))], t),
                        -1: kt([(0.0, (-0.3, 0.25)), (0.4, (-0.55, 0.15)), (1.0, (-0.3, 0.25))], t)}
    elif anim == "kick":
        # 前踢（右腳）：收膝 → 髖往前送、腿彈直 → 停一下 → 收膝 → 落地。上半身後仰、雙手張開平衡
        pose = default_pose()
        pose["legs"] = {-1: kt([(0.0, (0.5, 1.0)), (0.2, (1.35, 2.0)), (0.42, (1.55, 0.05)), (0.6, (1.5, 0.1)),
                                (0.8, (1.1, 1.6)), (1.0, (0.3, 0.5))], t),
                        1: kt([(0.0, (-0.1, 0.2)), (0.42, (-0.3, 0.35)), (1.0, (-0.1, 0.2))], t)}
        pose["arms"] = {1: kt([(0.0, (0.7, 0.4, 1.1)), (0.42, (0.3, 0.9, 0.7)), (1.0, (0.6, 0.5, 1.0))], t),
                        -1: kt([(0.0, (0.5, 0.5, 1.0)), (0.42, (-0.3, 0.8, 0.6)), (1.0, (0.4, 0.5, 1.0))], t)}
        pose["lean"] = kt([(0.0, 0.05), (0.2, -0.1), (0.42, -0.42), (0.6, -0.4), (1.0, -0.05)], t)
        pose["twist"] = kt([(0.0, -0.2), (0.42, 0.45), (0.6, 0.45), (1.0, 0.1)], t)
        pose["hip_x"] = kt([(0.0, 0.0), (0.2, -0.4), (0.42, 2.0), (0.6, 2.0), (1.0, 0.4)], t)
        pose["hip_drop"] = kt([(0.0, 0.3), (0.2, 0.9), (0.42, 0.2), (1.0, 0.4)], t)
    else:
        raise ValueError(anim)
    if pose_only:
        return pose
    if anim in STRIKE:
        s0, s1 = STRIKE[anim]
        blade_k = 1.0 + 0.55 * max(0.0, 1.0 - abs((t - (s0 + s1) * 0.5) / ((s1 - s0) * 0.75)))
        if anim in FIST_ANIMS:
            hand = FIST_ANIMS[anim][3]
            spec["hand_k"] = {hand: 1.2 + 0.5 * (blade_k - 1.0) / 0.55, -hand: 1.2}
        elif anim == "hook":
            spec["hand_k"] = {-1: 1.2 + 0.5 * (blade_k - 1.0) / 0.55, 1: 1.2}
        elif anim == "punch":
            spec["hand_k"] = {1: 1.2 + 0.5 * (blade_k - 1.0) / 0.55, -1: 1.2}
        elif anim == "kick":
            spec["boot_k"] = 1.15 + 0.25 * (blade_k - 1.0) / 0.55
    prims, J = build_human(spec, pose, mats)
    gun = anim[6:] if anim.startswith("shoot_") else anim[4:] if anim.startswith("aim_") else anim[8:] if anim.startswith("aimwalk_") else ""
    anim = ("aim_" + gun) if gun else anim
    # 頭盔（一律戴著）、外套的毛領和下襬、背上的無線電包、腰帶
    prims += tag(helmet_prims(J), "head")
    body = OUTFIT["body"]
    tb = J["torso_basis"]
    if body in ("parka", "arctic"):
        prims.append(Ell(chest_local(J, (-0.4, 0, 3.6)), (3.2, 4.0, 1.4), "parka_trim" if body == "parka" else "fur", tb))
        prims.append(Ell(chest_local(J, (0.0, 0, -3.6)), (3.5, 4.3, 1.9), "parka" if body == "parka" else "white", tb))
        prims.append(Box(chest_local(J, (3.1, 1.7, 0.6)), (0.5, 1.0, 1.1), "strap", tb))  # 胸前的對講機
    elif body == "eod":
        prims.append(Box(chest_local(J, (0.6, 0, 0.5)), (4.4, 4.6, 3.6), "eod", tb))
        prims.append(Ell(chest_local(J, (-0.2, 0, 4.2)), (3.6, 4.8, 1.6), "eod", tb))
    elif body == "hazmat":
        prims.append(Ell(chest_local(J, (-0.4, 0, 3.8)), (3.0, 3.8, 1.2), "hazmat", tb))
    # 腰帶（深色一圈，把上半身和腿分開）＋右腰的槍套
    wide = 1.0 if body != "eod" else 1.2
    prims.append(Ell(chest_local(J, (0.0, 0, -2.2)), (3.8 * wide, 4.6 * wide, 0.8), "strap", tb))
    prims.append(Box(chest_local(J, (0.4, -4.3 * wide, -3.6)), (1.0, 0.6, 1.4), "strap", tb))
    tag(prims, "torso")
    back = -3.6 - (0.9 if body == "eod" else 0.0)
    prims.append(Box(chest_local(J, (back, 0.0, -0.2)), (1.3, 2.7, 2.9), "strap", tb))
    prims.append(Box(chest_local(J, (back - 0.2, 0.0, 2.2)), (1.0, 2.2, 0.5), "helm_trim", tb))
    tag(prims, "pack")
    if OUTFIT["layer"] in ("head", "feet"):
        gid = OUTFIT[OUTFIT["layer"]]
        prims += tag(gear_prims(J, OUTFIT["layer"], gid), "head" if OUTFIT["layer"] == "head" else "boots")
    held = []
    if gun:
        held = gun_prims(gun, J)
    elif anim in ("slash", "slash_back", "stab"):
        held = knife(J["hand-1"], J["fore-1"], blade_k)
    elif anim == "slash_axe":
        held = axe(J["hand-1"], J["fore-1"], 1.0 + (blade_k - 1.0) * 0.5)
    elif anim == "slash_crowbar":
        held = crowbar(J["hand-1"], J["fore-1"], 1.0 + (blade_k - 1.0) * 0.25)
    prims += tag(held, "gear")
    return prims


def eyeless(J, crust="frost", mouth=0.8, jaw=1.1, hr=2.9):
    """感染體的臉：沒有眼睛（眼窩被霜和結晶封住）、張著的嘴。hr = 頭的前後半徑"""
    hb = J["head_basis"]
    p = [Box(head_local(J, (hr - 0.25, 0, 0.6)), (0.5, 1.8, 0.5), crust, hb)]
    if mouth > 0:
        p.append(Box(head_local(J, (hr * 0.9 - 0.2, 0, -1.25)), (0.5, jaw, mouth), "vent", hb))
    return p


def watcher_model(anim, f, n):
    """值班者：還穿著白袍的站員。駝背、頭歪一邊，右手袖子破了、前臂長出結晶爪，左肩和背上一叢冰晶"""
    mats = {"leg": "coverall", "boot": "boot", "hip": "labcoat", "torso": "labcoat", "arm": "labcoat",
            "fore-1": "dead", "hand": "dead", "skin": "dead", "claw-1": "crystal", "claw1": "dead"}
    spec = {"torso_r": (3.3, 4.2, 5.3), "arm_len": {-1: 1.22, 1: 1.0}, "claw": 1.9, "head_r": (2.9, 2.8, 3.1)}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.38, knee=0.7, arm=0.12, lean=0.38)
        # 拖著走：一隻腳比較僵硬
        a, k = pose["legs"][-1]
        pose["legs"][-1] = (a * 0.6, k * 0.4)
        sw = math.sin(2 * math.pi * f / n)
        pose["arms"] = {1: (0.2 + 0.08 * sw, 0.18, 0.1), -1: (0.4 - 0.1 * sw, 0.16, 0.25)}
        pose["twist"] = 0.1 * sw
        pose["head_roll"] = 0.3 + 0.06 * sw
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.42
        pose["arms"] = {1: (0.25, 0.15, 0.1), -1: (0.3, 0.14, 0.15)}
        pose["head_roll"] = 0.3 + 0.1 * bf(f, n)
    elif anim == "attack":
        pose = default_pose()
        pose["legs"] = {1: (0.4, 0.3), -1: (-0.35, 0.2)}
        pose["arms"] = {-1: kf([(1.3, 0.9, 1.2), (1.6, 0.0, 0.05), (1.2, -0.5, 0.3)], f, n),
                        1: kf([(0.8, 0.3, 0.9), (1.3, 0.1, 0.3), (1.1, 0.0, 0.4)], f, n)}
        pose["lean"] = kf([0.25, 0.6, 0.45], f, n)
        pose["twist"] = kf([-0.5, 0.35, 0.5], f, n)
        pose["hip_x"] = kf([-0.5, 1.6, 1.0], f, n)
        pose["head_roll"] = 0.2
    else:
        raise ValueError(anim)
    pose["head_pitch"] = pose.get("head_pitch", 0.0) + 0.4
    pose["head_fwd"] = 1.1
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    # 白袍的下襬（背後比較長、破破的）、胸口乾掉的血
    prims.append(Ell(chest_local(J, (-0.9, 0.3, -5.6)), (2.6, 4.0, 3.2), "labcoat", tb))
    prims.append(Box(chest_local(J, (2.75, 0.0, -0.6)), (0.6, 1.25, 4.4), "coverall", tb))   # 白袍敞開：中間露出深色工作服
    prims.append(Ell(chest_local(J, (0.2, 0, 4.3)), (2.6, 3.3, 0.9), "coverall", tb))       # 領口
    prims.append(Ell(chest_local(J, (3.0, -1.6, -0.2)), (0.8, 1.5, 2.0), "blood", tb))
    # 冰晶：左肩一大叢、背上幾根
    sh = J["sh1"]
    for d, ln, r in (((-0.3, 0.5, 1.0), 4.6, 1.0), ((-0.9, 0.9, 0.6), 3.4, 0.85), ((0.4, 0.8, 0.8), 2.8, 0.75),
                     ((-0.2, -0.2, 1.0), 3.0, 0.7)):
        prims.append(spike(add(sh, (-0.3, 0.3, 0.6)), rot_z(d, pose.get("twist", 0.0)), ln, r))
    for off, d, ln in (((-3.0, -1.4, 1.5), (-0.8, -0.3, 0.7), 3.2), ((-3.1, 0.6, -1.0), (-0.9, 0.2, 0.5), 2.6)):
        prims.append(spike(chest_local(J, off), d, ln, 0.8))
    prims.append(Ell(head_local(J, (-1.2, 0.5, 1.9)), (1.9, 2.0, 1.2), "frost", J["head_basis"]))
    prims += eyeless(J)
    auto_tag(prims, J)
    return prims


def listener_model(anim, f, n):
    """鳴骨者：瘦得只剩骨架，頭骨往兩邊長成一大一小兩片結晶「耳扇」，永遠歪著頭在聽。肋骨一根一根看得到"""
    ribs = lambda nn: "bone" if math.sin(nn[2] * 8.0 + 0.6) > -0.1 else "rag"
    mats = {"leg": "bone", "boot": "bone", "hip": "rag", "torso": ribs, "arm": "bone", "hand": "bone",
            "skin": "bone", "claw": "bone"}
    spec = {"lu": 7.6, "ll": 7.4, "torso_len": 10.5, "torso_r": (2.7, 3.5, 5.6), "leg_r": 1.35, "leg_r2": 1.05,
            "au": 6.2, "al": 6.6, "arm_r": 1.0, "head_r": (2.7, 2.3, 3.3), "hip_w": 1.8, "sh_w": 3.9, "claw": 2.2}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.42, knee=0.9, arm=0.3, lean=0.24)
        for s in (1, -1):
            a, b, e = pose["arms"][s]
            pose["arms"][s] = (a + 0.2, 0.32, 0.25)
        pose["head_roll"] = 0.45 + 0.15 * math.sin(2 * math.pi * f / n)
        pose["twist"] = 0.1 * math.sin(2 * math.pi * f / n)
    elif anim == "listen":
        pose = default_pose()
        pose["lean"] = 0.16
        pose["arms"] = {1: (0.35, 0.7 + 0.06 * bf(f, n), 0.4), -1: (0.3, 0.5 + 0.06 * bf(f, n), 0.5)}
        pose["head_roll"] = 0.6 + 0.12 * bf(f, n)
        pose["head_pitch"] = -0.25
        pose["head_yaw"] = 0.25 * bf(f, n)
    elif anim == "attack":
        pose = default_pose()
        pose["legs"] = {1: (0.45, 0.35), -1: (-0.4, 0.25)}
        k = kf([(0.6, 1.0, 1.3), (1.55, 0.2, 0.05), (1.2, -0.2, 0.2)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.1, 0.5, 0.38], f, n)
        pose["hip_x"] = kf([-0.5, 1.5, 1.0], f, n)
        pose["head_roll"] = 0.3
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    hb = J["head_basis"]
    tb = J["torso_basis"]
    # 耳扇：左邊大、右邊小。骨質的碟子，邊緣長出一排結晶
    for side, k in ((1, 1.5), (-1, 0.95)):
        c = head_local(J, (-0.4, side * 2.7, 1.0 * k))
        prims.append(Ell(c, (2.3 * k, 0.75, 3.1 * k), "bone", hb))
        prims.append(Ell(head_local(J, (-0.2, side * 2.2, 0.8 * k)), (1.5 * k, 0.9, 2.0 * k), "crystal_d", hb))
        for ang, ln in ((0.0, 3.0), (0.7, 2.6), (-0.7, 2.4), (1.4, 1.8)):
            d = add(add(mul(hb[2], math.cos(ang)), mul(hb[0], -math.sin(ang))), mul(hb[1], side * 0.45))
            prims.append(spike(add(c, mul(norm(d), 2.2 * k)), d, ln * k, 0.7 * k))
    # 嘴（下巴垂著）、平滑沒有眼睛的臉
    prims.append(Box(head_local(J, (2.2, 0, -1.6)), (0.45, 0.9, 0.9), "vent", hb))
    # 脊椎的骨刺、掛在腰上的破布
    for z in (-2.5, 0.0, 2.5):
        prims.append(spike(chest_local(J, (-2.3, 0, z)), add(mul(tb[0], -1.0), mul(tb[2], 0.5)), 2.6, 0.75, "bone"))
    prims.append(Ell(chest_local(J, (-0.2, 0, -5.6)), (2.6, 3.3, 2.6), "rag", tb))
    auto_tag(prims, J)
    return prims


def guard_model(anim, f, n):
    """武裝人員（守門派）：雪地迷彩、頭盔＋橘色雪鏡＋黑色面罩、戰術背心和彈匣袋、背後的無線電、步槍"""
    # 配色分三塊：白色的外套和頭盔、灰色的褲子、深色的背心／手套／靴子／面罩 → 遠遠看也分得出頭、身體、手、腳
    mats = {"leg": "camo_d", "boot": "boot", "hip": "camo_d", "torso": "camo", "arm": "camo", "hand": "glove",
            "skin": "black", "fore": "camo"}
    spec = {"torso_r": (3.5, 4.4, 5.4), "sh_w": 4.6, "leg_r": 2.0, "arm_r": 1.6}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.45, knee=0.8, arm=0.0, lean=0.12)
        bob = 0.05 * math.sin(4 * math.pi * f / n)
        pose["arms"] = {1: (0.95 + bob, -0.25, 0.75), -1: (0.55 + bob, 0.05, 1.05)}
        aim = False
    elif anim == "idle":
        pose = default_pose()
        pose["arms"] = {1: (0.9, -0.25, 0.75 + 0.05 * bf(f, n)), -1: (0.5, 0.05, 1.05 + 0.05 * bf(f, n))}
        pose["head_yaw"] = 0.25 * math.sin(2 * math.pi * f / n)
        aim = False
    elif anim == "aim":
        pose = default_pose()
        pose["legs"] = {1: (0.3, 0.25), -1: (-0.25, 0.2)}
        pose["arms"] = {1: (1.45, -0.35, 0.15), -1: (0.85, 0.0, 1.35)}
        pose["lean"] = 0.1
        pose["hip_drop"] = 0.5
        aim = True
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    hb = J["head_basis"]
    tb = J["torso_basis"]
    # 戰術背心＋胸前三個彈匣袋、腰帶
    prims.append(Ell(chest_local(J, (0.2, 0, -0.4)), (4.0, 4.75, 4.3), "rig", tb))
    for y in (-2.0, 0.0, 2.0):
        prims.append(Box(chest_local(J, (3.9, y, -1.5)), (0.7, 0.75, 1.3), "olive", tb))
    prims.append(Ell(chest_local(J, (0.0, 0, -4.4)), (3.3, 4.0, 0.8), "rig", tb))
    # 迷彩的灰斑
    for off, r in (((-0.5, 3.4, 2.6), (1.6, 1.4, 1.2)), ((0.5, -3.6, 2.2), (1.4, 1.3, 1.4))):
        prims.append(Ell(chest_local(J, off), r, "camo_d", tb))
    for side in (1, -1):
        prims.append(Ell(add(J["knee%d" % side], (0.9, 0, 0.2)), (1.4, 1.7, 1.5), "rig"))            # 護膝
        prims.append(Box(add(J["hip%d" % side], (0.2, side * 1.9, -2.4)), (1.1, 0.6, 1.3), "rig"))  # 腿掛的彈匣袋
    # 頭盔（白色盔罩＋灰斑）、雪鏡、面罩
    prims.append(Ell(head_local(J, (-0.3, 0, 1.7)), (3.55, 3.45, 2.35), "camo", hb))
    prims.append(Ell(head_local(J, (-0.3, 0, 0.75)), (3.65, 3.55, 0.55), "rig", hb))   # 盔緣的深色帶子
    prims.append(Ell(head_local(J, (-1.2, 1.4, 2.6)), (1.6, 1.5, 1.0), "camo_d", hb))
    prims.append(Box(head_local(J, (2.8, 0, 0.3)), (0.55, 2.2, 0.8), "lens", hb))
    prims.append(Ell(head_local(J, (0.3, 0, -0.9)), (3.0, 3.0, 2.4), "black", hb))
    # 背後的無線電＋天線
    prims.append(Box(chest_local(J, (-3.9, -0.8, 0.6)), (1.2, 2.2, 2.8), "rig", tb))
    prims.append(Cap(chest_local(J, (-4.2, -2.4, 3.0)), chest_local(J, (-4.8, -2.8, 8.5)), 0.3, "helm_trim", 0.25))
    auto_tag(prims, J)
    if aim:
        prims += assault_rifle(add(J["hand-1"], (0.0, 0.0, 0.3)), basis_along((1, 0, 0.02)))
    else:
        d = norm((1.0, 0.25, -0.5))
        prims += assault_rifle(add(J["hand-1"], (0.0, 0.0, 0.0)), basis_along(d))
    tag(prims, "gear")
    return prims


def hound_model(anim, f, n):
    """獵犬：被感染的雪橇犬。還套著紅色的拉橇胸帶，背上一排冰晶，一邊的肋骨露在外面，下巴裂開"""
    prims = []
    bz = 8.4
    lean = 0.0
    head_drop = 0.0
    jaw = 0.5
    if anim == "walk":
        p = 2 * math.pi * f / n
        legs = {}
        for name, ph in (("fl", 0), ("br", 0.4), ("fr", math.pi), ("bl", math.pi + 0.4)):
            s = math.sin(p + ph)
            legs[name] = (0.6 * s, 0.25 + 0.9 * max(0, math.cos(p + ph)))
        head_drop = 0.4 * math.sin(2 * p)
        lean = 0.04 * math.sin(2 * p)
    elif anim == "idle":
        legs = {k: (0.0, 0.2) for k in ("fl", "fr", "bl", "br")}
        head_drop = 1.2 + 0.6 * bf(f, n)
    elif anim == "attack":
        k = kf([((-0.4, 0.3), (0.45, 0.9)), ((1.0, 0.5), (-0.5, 0.2)), ((0.5, 0.3), (0.2, 0.3))], f, n)
        legs = {"fl": k[0], "fr": k[0], "bl": k[1], "br": k[1]}
        lean = kf([0.18, -0.3, -0.1], f, n)
        jaw = kf([0.6, 1.5, 1.0], f, n)
        head_drop = kf([1.0, -1.0, 0.0], f, n)
    else:
        raise ValueError(anim)
    L = lean_fn((-4.0, 0, bz), -lean)
    # 身體：深灰的背、白色的肚子和胸口（哈士奇的配色）
    prims.append(Ell(L((-1.5, 0, bz + 1.1)), (7.6, 3.7, 3.5), "husky"))
    prims.append(Ell(L((-1.5, 0, bz + 0.1)), (7.0, 3.3, 2.9), "white"))
    prims.append(Ell(L((4.4, 0, bz + 1.4)), (3.8, 3.7, 4.2), "husky"))
    prims.append(Ell(L((5.0, 0, bz + 0.2)), (3.0, 3.0, 3.4), "white"))
    prims.append(Ell(L((-7.0, 0, bz + 1.0)), (3.2, 3.0, 3.3), "husky"))
    # 拉橇的紅色胸帶
    prims.append(Ell(L((2.6, 0, bz + 1.2)), (0.9, 3.75, 4.3), "red"))
    prims.append(Box(L((-1.0, 0, bz + 4.4)), (3.6, 0.6, 0.35), "red"))
    # 露出來的肋骨（左邊）
    prims.append(Ell(L((-2.2, 2.2, bz + 0.8)), (3.0, 1.5, 2.2), "gum"))
    for x in (-3.6, -2.2, -0.8):
        prims.append(Box(L((x, 3.3, bz + 0.9)), (0.35, 0.5, 1.8), "bone"))
    tag(prims, "torso")
    # 頭：寬額頭、尖耳朵、白色口鼻、裂開的下巴
    hc = L((9.2, 0, bz + 3.4 - head_drop))
    prims.append(Ell(hc, (3.0, 2.7, 2.6), "husky"))
    prims.append(Ell(add(hc, (2.9, 0, -0.5)), (2.5, 1.45, 1.25), "white"))
    prims.append(Ell(add(hc, (5.1, 0, -0.2)), (0.7, 0.8, 0.7), "black"))
    prims.append(Box(add(hc, (2.6, 0, -1.5 - jaw * 0.5)), (2.2, 1.1, 0.4), "gum", basis_lean(-0.25 * jaw)))
    prims.append(Box(add(hc, (3.9, 0, -1.2)), (0.5, 0.9, 0.35), "bone"))
    prims.append(Box(add(hc, (1.6, 0, 0.9)), (0.5, 2.0, 0.4), "frost"))  # 眼睛被霜封住
    for y in (1.6, -1.6):
        prims.append(Cap(add(hc, (-0.9, y, 1.6)), add(hc, (-1.5, y * 1.25, 4.4)), 1.0, "husky", 0.3))
    tag(prims, "head")
    # 背上的冰晶：肩膀最大，往後越來越小
    for x, ln, r in ((3.2, 4.6, 1.1), (0.6, 3.8, 1.0), (-2.2, 3.0, 0.9), (-5.0, 2.4, 0.8), (-7.6, 1.8, 0.7)):
        prims.append(spike(L((x, 0.3 * math.sin(x), bz + 4.0)), (-0.35, 0.1 * math.sin(x * 2), 1.0), ln, r))
    # 尾巴（捲起來的）
    t1, t2, t3 = L((-9.5, 0, bz + 2.0)), L((-12.0, 0, bz + 4.6)), L((-10.6, 0, bz + 6.6))
    prims += [Cap(t1, t2, 1.25, "husky", 1.1), Cap(t2, t3, 1.1, "white", 0.6)]
    tag(prims, "back")
    # 腳
    for name, x, y in (("fl", 5.0, 2.7), ("fr", 5.0, -2.7), ("bl", -6.6, 2.6), ("br", -6.6, -2.6)):
        a, k = legs[name]
        hip = L((x, y, bz))
        kn, ft = leg_points(hip, a + (0.25 if name[0] == "b" else 0.0), k if name[0] == "b" else -k, 4.2, 4.6)
        prims.append(Cap(hip, kn, 1.7, "husky", 1.25))
        prims.append(Cap(kn, ft, 1.15, "white", 0.95))
        prims.append(Ell(add(ft, (0.6, 0, 0.0)), (1.5, 1.2, 0.9), "white"))
        tag(prims, "leg" + name)
    return prims


def crawler_model(anim, f, n):
    """爬行者：腰以下已經不能動，用兩隻長得不成比例的手把自己往前拖。頭抬著在聽，脊椎上一整排結晶"""
    prims = []
    bz = 3.6
    lift = 0.0
    reach = {1: 0.5, -1: 0.5}   # 0 = 手收在肩膀旁邊、1 = 往前伸到最遠
    up = {1: 0.0, -1: 0.0}      # 手離地
    drag = 0.0
    if anim == "walk":
        p = 2 * math.pi * f / n
        for s, ph in ((1, 0.0), (-1, math.pi)):
            reach[s] = 0.5 + 0.5 * math.sin(p + ph)
            up[s] = 2.2 * max(0.0, math.cos(p + ph))
        lift = 0.6 + 0.5 * math.sin(2 * p)
        drag = 0.5 * math.sin(p)
    elif anim == "idle":
        lift = 0.8 + 0.6 * bf(f, n)
        reach = {1: 0.35, -1: 0.55}
    elif anim == "attack":
        r = kf([0.0, 1.25, 0.9], f, n)
        reach = {1: r, -1: r}
        u = kf([3.5, 4.5, 1.0], f, n)
        up = {1: u, -1: u}
        lift = kf([1.5, 3.2, 1.8], f, n)
    else:
        raise ValueError(anim)
    # 軀幹（破掉的工作服）、垮在地上的骨盆、拖在後面的兩條腿
    chest = (2.6, 0, bz + 2.2 + lift)
    prims.append(Ell(chest, (4.2, 3.7, 2.7), "coverall", basis_lean(-0.12 * lift)))
    prims.append(Ell((-2.6, 0, bz + 1.0 + lift * 0.4), (4.4, 3.2, 2.3), "coverall"))
    prims.append(Ell((-6.6, 0, bz + 0.2), (2.8, 3.0, 2.0), "coverall"))
    prims.append(Ell((-0.4, 0.4, bz + 2.6 + lift * 0.6), (2.6, 2.2, 1.2), "dead"))  # 背上衣服破了露出來的皮
    tag(prims, "torso")
    for s in (1, -1):
        k1 = (-11.0, s * (1.7 + 0.5 * drag * s), 1.6)
        k2 = (-15.0, s * (1.0 + 0.9 * drag * s), 1.3)
        prims.append(Cap((-7.6, s * 1.6, bz - 0.4), k1, 1.6, "coverall", 1.3))
        prims.append(Cap(k1, k2, 1.2, "dead", 0.9))
        prims.append(Ell(add(k2, (-0.9, 0, 0)), (1.3, 0.9, 0.8), "dead"))
        tag(prims, "leg%d" % s)
    # 頭：抬起來、歪一邊，嘴張著
    hc = (7.4, 0, bz + 3.6 + lift * 1.2)
    hb = head_basis(-0.35, 0.3)
    prims.append(Cap(add(chest, (2.6, 0, 0.6)), hc, 1.2, "dead"))
    prims.append(Ell(hc, (2.8, 2.6, 2.6), "dead", hb))
    J = {"head": hc, "head_basis": hb}
    prims += eyeless(J, mouth=0.9, hr=2.8)
    prims.append(Ell(head_local(J, (-1.0, 0.3, 1.6)), (1.8, 1.9, 1.1), "frost", hb))
    tag(prims, "head")
    # 脊椎的結晶
    for x, ln, r in ((3.6, 2.6, 0.8), (1.2, 3.8, 1.0), (-1.4, 3.2, 0.9), (-4.0, 2.4, 0.8), (-6.4, 1.8, 0.7)):
        z = bz + 3.9 + lift * max(0.0, min(1.0, (x + 7) / 10))
        prims.append(spike((x, 0, z - 0.6), (-0.4, 0.15 * math.sin(x), 1.0), ln, r))
    tag(prims, "back")
    # 手臂：上臂往外撐、前臂很長、手指是結晶爪
    for s in (1, -1):
        sh = add(chest, (1.8, s * 3.6, 0.0))
        hand = (6.0 + 7.5 * reach[s], s * (6.2 - 1.2 * reach[s]), 1.0 + up[s])
        mid = mul(add(sh, hand), 0.5)
        el = add(mid, (-1.2, s * 2.6, 3.6 - 1.4 * reach[s]))
        prims.append(Ell(sh, (1.7, 1.6, 1.6), "coverall"))
        prims.append(Cap(sh, el, 1.5, "coverall", 1.3))
        prims.append(Cap(el, hand, 1.25, "dead", 1.05))
        prims.append(Ell(hand, (1.7, 1.6, 1.1), "dead"))
        for off in (-0.9, 0.0, 0.9):
            prims.append(Cap(hand, add(hand, (2.6, off * 1.3, -0.5)), 0.6, "crystal", 0.25))
        tag(prims, "arm%d" % s)
    return prims


def husk_model(anim, f, n):
    """膨脹者：肚子脹到把工作服撐破，肚皮裂開一條縫、裡面的結晶頂出來。頭陷在肩膀裡，左手腫得比右手大很多"""
    mats = {"leg": "coverall", "shin": "bloat", "boot": "bloat", "hip": "coverall", "torso": "bloat", "arm": "bloat",
            "arm-1": "coverall", "hand": "bloat", "skin": "bloat"}
    spec = {"torso_r": (5.4, 6.4, 6.6), "torso_len": 10.0, "lu": 5.5, "ll": 5.0, "leg_r": 2.9, "leg_r2": 2.5,
            "sh_w": 6.0, "au": 5.0, "al": 5.0, "arm_r": 2.0, "head_r": (2.8, 2.7, 2.8), "hip_w": 3.3,
            "arm_rad": {1: 1.4, -1: 0.95}, "hand_k": {1: 1.6, -1: 1.1}, "neck": 0.8}
    wob = 0.0
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.3, knee=0.4, arm=0.12, lean=0.12)
        for s_ in (1, -1):
            a, b, e = pose["arms"][s_]
            pose["arms"][s_] = (a, 0.5, 0.3)
        wob = math.sin(2 * math.pi * f / n)
        pose["twist"] = 0.14 * wob
        pose["head_roll"] = 0.12 * wob
    elif anim == "idle":
        pose = default_pose()
        pose["arms"] = {1: (0.1, 0.5, 0.3), -1: (0.1, 0.45, 0.3)}
        pose["hip_drop"] = 0.4 * bf(f, n)
        pose["lean"] = 0.08
    elif anim == "attack":
        pose = default_pose()
        pose["arms"] = {1: kf([(1.9, 0.7, 0.6), (1.4, 0.0, 0.1), (1.0, -0.1, 0.4)], f, n),
                        -1: kf([(0.8, 0.6, 0.8), (1.4, 0.1, 0.2), (1.1, 0.2, 0.4)], f, n)}
        pose["lean"] = kf([-0.05, 0.4, 0.3], f, n)
        pose["twist"] = kf([0.4, -0.3, -0.2], f, n)
        pose["hip_x"] = kf([-0.5, 1.5, 1.0], f, n)
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 2.2
    pose["head_pitch"] = 0.25
    breathe = 1.0 + 0.04 * bf(f, n) if anim == "idle" else 1.0 + 0.03 * wob
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    # 垂下來的大肚子、裂縫、頂出來的結晶
    prims.append(Ell(chest_local(J, (1.9, 0, -3.2)), (5.6 * breathe, 6.3 * breathe, 4.8), "bloat", tb))
    prims.append(Ell(chest_local(J, (6.2 * breathe, 0.3, -3.0)), (1.5, 1.5, 3.4), "gum", tb))
    for z, ln in ((-1.2, 2.6), (-3.0, 3.4), (-4.8, 2.4)):
        prims.append(spike(chest_local(J, (7.0 * breathe, 0.3, z)), add(tb[0], mul(tb[2], 0.25 * (z + 3))), ln, 0.9))
    # 撐破的工作服：只剩一條肩帶和右邊的袖子
    prims.append(Box(chest_local(J, (0.6, -3.2, 3.6)), (4.6, 1.1, 2.0), "coverall", tb))
    # 膿包（集中在左邊）
    for off, r in (((3.4, 3.8, 1.8), 2.3), ((0.6, 5.8, -1.4), 2.0), ((-3.4, 3.4, 2.6), 2.1), ((-4.6, -2.0, -0.6), 1.8),
                   ((4.4, -4.0, -2.0), 1.5)):
        prims.append(Ell(chest_local(J, off), (r, r, r), "pus"))
    prims.append(Ell(add(J["elbow1"], (0.4, 1.4, 0.4)), (1.5, 1.5, 1.5), "pus"))
    prims += eyeless(J, mouth=0.7, jaw=1.0, hr=2.8)
    auto_tag(prims, J)
    return prims


def chorister_model(anim, f, n):
    """詠者：胸骨往兩邊翻開，肋骨變成一排像管風琴的結晶管（外側高、中間矮），仰著頭「唱」。破布像長袍一樣垂到膝蓋"""
    mats = {"leg": "ash", "boot": "ash", "hip": "rag", "torso": "ash", "arm": "ash", "hand": "ash", "skin": "ash",
            "claw": "ash"}
    spec = {"lu": 7.2, "ll": 7.2, "torso_len": 10.0, "torso_r": (2.7, 3.5, 5.4), "leg_r": 1.25, "leg_r2": 1.0,
            "au": 5.6, "al": 5.8, "arm_r": 1.0, "head_r": (2.5, 2.3, 2.9), "sh_w": 3.8, "claw": 1.5}
    sing = 0.0
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.33, knee=0.7, arm=0.12, lean=0.02)
        for s in (1, -1):
            a, b, e = pose["arms"][s]
            pose["arms"][s] = (a + 0.1, 0.45, 0.35)
        pose["head_pitch"] = -0.3
        sing = 0.3
    elif anim == "listen":
        # 仰頭呼喚、雙手張開
        sing = bf(f, n)
        pose = default_pose()
        pose["arms"] = {1: (0.5 + 0.2 * sing, 1.0 + 0.1 * sing, 0.4), -1: (0.5 + 0.2 * sing, 1.0 + 0.1 * sing, 0.4)}
        pose["head_pitch"] = -0.6 - 0.2 * sing
        pose["lean"] = -0.1 - 0.06 * sing
    elif anim == "attack":
        pose = default_pose()
        k = kf([(0.8, 0.9, 1.0), (1.5, 0.15, 0.05), (1.2, -0.1, 0.3)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.0, 0.4, 0.3], f, n)
        pose["hip_x"] = kf([-0.4, 1.4, 0.9], f, n)
        pose["head_pitch"] = -0.2
    else:
        raise ValueError(anim)
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    hb = J["head_basis"]
    # 打開的胸腔（黑洞）、翻開的肋骨
    prims.append(Ell(chest_local(J, (1.5, 0, 0.6)), (1.9, 2.5, 3.6), "vent", tb))
    for side in (1, -1):
        for z in (-1.4, 0.6, 2.6):
            prims.append(Cap(chest_local(J, (1.6, side * 2.4, z)), chest_local(J, (3.6, side * 3.9, z + 0.8)), 0.55, "bone", 0.3))
    # 結晶管：外側高、中間矮，像兩片翅膀框住頭
    grow = 1.0 + 0.12 * sing
    for y, top in ((-3.6, 10.0), (-1.9, 6.4), (1.9, 7.0), (3.6, 11.0)):
        a = chest_local(J, (2.2, y * 0.8, -2.2))
        b = chest_local(J, (2.4 + 0.1 * top, y * 1.5, -2.2 + top * grow))
        prims.append(Cap(a, b, 1.05, "crystal", 0.95))
        prims.append(Ell(b, (1.25, 1.25, 0.55), "crystal_d", tb))
    # 張大的嘴、被霜封住的眼窩
    prims += eyeless(J, mouth=1.1 + 0.3 * sing, jaw=1.0, hr=2.5)
    # 長袍一樣的破布
    prims.append(Ell(chest_local(J, (-0.3, 0, -6.2)), (2.7, 3.5, 4.6), "rag", tb))
    prims.append(Ell(chest_local(J, (-1.0, 0, 2.6)), (2.4, 3.8, 2.6), "rag", tb))
    auto_tag(prims, J)
    return prims


def bear_model(anim, f, n):
    """苔原之母：被感染的北極熊。肩膀高高拱起、頭壓低，背上一整片冰晶森林，中間結晶裂開露出肉的地方是弱點"""
    prims = []
    bz = 13.0
    lean = 0.0
    head_drop = 2.0
    rear = 0.0
    jaw = 0.4
    if anim == "walk":
        p = 2 * math.pi * f / n
        legs = {}
        for name, ph in (("fl", 0), ("br", 0.5), ("fr", math.pi), ("bl", math.pi + 0.5)):
            legs[name] = (0.45 * math.sin(p + ph), 0.2 + 0.7 * max(0, math.cos(p + ph)))
        head_drop = 2.6 + 0.9 * math.sin(2 * p)
    elif anim == "idle":
        legs = {k: (0.0, 0.15) for k in ("fl", "fr", "bl", "br")}
        head_drop = 2.2 + 1.5 * bf(f, n)
    elif anim == "attack":
        # 站起來往前撲
        rear = kf([0.0, 0.55, 0.6, -0.15, 0.0], f, n)
        k = kf([(0.0, 0.2), (1.0, 1.2), (1.2, 1.0), (0.6, 0.2), (0.1, 0.2)], f, n)
        legs = {"fl": k, "fr": k, "bl": (0.2, 0.2), "br": (0.2, 0.2)}
        lean = -rear
        jaw = kf([0.5, 1.4, 1.6, 1.0, 0.5], f, n)
        head_drop = kf([2.0, -1.0, -1.0, 2.5, 2.0], f, n)
    elif anim == "hurt":
        legs = {k: (0.0, 0.3) for k in ("fl", "fr", "bl", "br")}
        lean = kf([0.25, 0.12, 0.0], f, n)
        head_drop = 2.0 - 3.0 * kf([1.0, 0.5, 0.0], f, n)
        jaw = 1.2
    else:
        raise ValueError(anim)
    L = lean_fn((-8.0, 0, bz), lean)
    # 身體：後半身、肚子、拱起來的肩膀、脖子
    prims.append(Ell(L((-4.0, 0, bz + 1.6)), (12.0, 7.2, 7.4), "white"))
    prims.append(Ell(L((-10.0, 0, bz + 1.0)), (6.0, 6.6, 6.8), "white"))
    prims.append(Ell(L((7.0, 0, bz + 3.4)), (7.2, 7.0, 8.2), "white"))
    prims.append(Ell(L((12.6, 0, bz + 2.6 - head_drop * 0.4)), (4.6, 4.6, 4.8), "white"))
    # 毛上結的髒霜、肚子下面的陰影
    prims.append(Ell(L((-3.0, 0, bz - 3.6)), (9.0, 5.4, 2.4), "frost"))
    tag(prims, "torso")
    # 頭：寬額頭、長口鼻、黑鼻子、小耳朵、裂開的嘴
    hc = L((17.4, 0, bz + 4.6 - head_drop))
    prims.append(Ell(hc, (4.4, 4.0, 3.8), "white"))
    prims.append(Ell(add(hc, (4.2, 0, -1.0)), (3.2, 2.2, 1.9), "white"))
    prims.append(Ell(add(hc, (7.0, 0, -0.6)), (0.9, 1.3, 0.9), "black"))
    for y in (2.9, -2.9):
        prims.append(Ell(add(hc, (-0.6, y, 3.0)), (1.2, 0.9, 1.3), "frost"))
    prims.append(Box(add(hc, (4.0, 0, -2.6 - jaw * 0.7)), (2.6, 1.7, 0.5), "gum", basis_lean(-0.2 * jaw)))
    prims.append(Box(add(hc, (4.2, 0, -2.2)), (2.4, 1.9, 0.25), "blood"))
    for y in (1.3, -1.3):
        prims.append(Cap(add(hc, (5.8, y, -2.0)), add(hc, (5.9, y, -3.4)), 0.45, "bone", 0.15))
    prims.append(Box(add(hc, (2.6, 0, 1.3)), (0.7, 3.0, 0.5), "crystal_d"))   # 眼睛的位置：一條結晶
    for y in (2.0, -2.0):
        prims.append(spike(add(hc, (2.4, y, 1.4)), (0.2, y * 0.3, 1.0), 2.0, 0.6))
    tag(prims, "head")
    # 背上的冰晶森林（肩膀最高），中間裂開的肉是弱點
    rnd = random.Random(7)
    for x, y, ln, r in ((8, 2.5, 9.5, 1.9), (6, -2.6, 8.0, 1.7), (3, 0.6, 10.5, 2.0), (0, 3.6, 7.0, 1.6), (-1, -3.4, 7.5, 1.6),
                        (-4, 2.4, 6.0, 1.5), (-6, -2.2, 6.5, 1.5), (-9, 1.0, 5.0, 1.4), (-12, -1.0, 3.6, 1.2),
                        (10, 0.0, 6.0, 1.4), (4, 4.6, 4.5, 1.2), (2, -4.8, 5.0, 1.2)):
        base = L((x, y, bz + 7.2 + (1.6 if x > 2 else 0.0)))
        prims.append(spike(base, (-0.3 + rnd.uniform(-0.2, 0.2), y * 0.09, 1.0), ln, r, "crystal", 0.35))
    prims.append(Ell(L((-2.0, 0, bz + 8.4)), (4.2, 2.4, 1.3), "gum"))
    prims.append(Ell(L((-2.0, 0, bz + 8.9)), (2.6, 1.3, 1.0), "flesh"))
    # 左邊肋骨的傷口
    prims.append(Ell(L((-1.0, 6.4, bz + 1.0)), (4.0, 1.4, 3.2), "gum"))
    for x in (-3.0, -1.0, 1.0):
        prims.append(Box(L((x, 7.4, bz + 1.0)), (0.5, 0.5, 2.6), "bone"))
    tag(prims, "back")
    # 腳：粗腿、大腳掌、黑爪子
    for name, x, y in (("fl", 8.5, 4.4), ("fr", 8.5, -4.4), ("bl", -11.5, 4.4), ("br", -11.5, -4.4)):
        a, k = legs[name]
        hip = L((x, y, bz))
        kn, ft = leg_points(hip, a, k if name[0] == "b" else -k, 6.5, 6.5)
        prims.append(Cap(hip, kn, 3.4, "white", 2.9))
        prims.append(Cap(kn, ft, 2.7, "white", 2.5))
        prims.append(Ell(add(ft, (1.4, 0, 0)), (3.0, 2.6, 1.4), "white"))
        for dy in (-1.4, 0.0, 1.4):
            prims.append(Cap(add(ft, (3.6, dy, -0.2)), add(ft, (5.0, dy, -0.8)), 0.5, "black", 0.2))
        tag(prims, "leg" + name)
    return prims



def runner_model(anim, f, n):
    """狂奔者：剛被感染沒多久的站員。衣服撕爛、一隻褲管沒了、光著腳，身體壓得很低往前衝；結晶才剛從脖子和右前臂冒出來"""
    mats = {"leg": "pants", "shin-1": "dead", "boot": "dead", "hip": "pants", "torso": "shirt", "arm": "dead",
            "arm1": "shirt", "fore1": "dead", "hand": "dead", "skin": "dead", "claw": "dead"}
    spec = {"torso_r": (2.9, 3.7, 5.0), "leg_r": 1.6, "leg_r2": 1.3, "arm_r": 1.2, "sh_w": 3.9, "claw": 1.4}
    if anim == "walk":
        # 衝刺：大步、身體很低、手往後甩
        pose = walk_pose(f, n, stride=0.75, knee=1.3, arm=0.2, lean=0.42)
        p = 2 * math.pi * f / n
        pose["arms"] = {1: (-0.5 + 0.55 * math.sin(p), 0.3, 0.7), -1: (-0.5 - 0.55 * math.sin(p), 0.3, 0.7)}
        pose["twist"] = 0.25 * math.sin(p)
        pose["hip_drop"] = 0.8 + 0.5 * math.cos(2 * p)
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.4
        pose["legs"] = {1: (0.3, 0.6), -1: (-0.2, 0.5)}
        pose["hip_drop"] = 0.9 + 0.35 * bf(f, n)
        pose["arms"] = {1: (0.15, 0.4, 0.5), -1: (0.25, 0.3, 0.6)}
        pose["head_roll"] = -0.2 + 0.4 * bf(f, n)
        pose["twist"] = 0.15 * math.sin(2 * math.pi * f / n)
    elif anim == "attack":
        # 撲上來：雙手往前抓
        pose = default_pose()
        pose["legs"] = {1: (0.7, 0.6), -1: (-0.6, 0.4)}
        k = kf([(0.3, 0.5, 1.0), (1.6, 0.15, 0.05), (1.3, 0.0, 0.3)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.35, 0.8, 0.6], f, n)
        pose["hip_x"] = kf([-1.0, 2.0, 1.2], f, n)
    else:
        raise ValueError(anim)
    pose["head_pitch"] = pose.get("head_pitch", 0.0) - 0.15
    pose["head_fwd"] = 1.4
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    hb = J["head_basis"]
    # 撕爛的內衣上的血、還沒掉光的頭髮
    prims.append(Ell(chest_local(J, (2.3, 0.6, 1.0)), (1.0, 2.2, 2.4), "blood", tb))
    prims.append(Ell(chest_local(J, (-0.2, -2.6, -2.6)), (2.2, 1.6, 1.8), "dead", tb))
    prims.append(Ell(head_local(J, (-0.9, 0.2, 1.3)), (2.6, 2.8, 2.3), "hair", hb))
    # 剛長出來的冰晶：脖子後面、右前臂
    for d, ln in (((-0.7, 0.3, 1.0), 3.0), ((-1.0, -0.4, 0.6), 2.4)):
        prims.append(spike(chest_local(J, (-1.6, 0.0, 4.2)), d, ln, 0.75))
    el, hd = J["elbow-1"], J["hand-1"]
    for k in (0.3, 0.65):
        prims.append(spike(add(el, mul(sub(hd, el), k)), (-0.3, -0.8, 0.7), 2.2, 0.6))
    prims += eyeless(J, mouth=0.9)
    auto_tag(prims, J)
    return prims


def spitter_model(anim, f, n):
    """噴孢者：駝得很厲害，下巴到胸口掛著一顆半透明的大孢子囊，背上一叢一叢的孢子莢。左手已經萎縮"""
    mats = {"leg": "ash", "boot": "boot", "hip": "rag", "torso": "rag", "arm": "ash", "hand": "ash", "skin": "ash"}
    spec = {"torso_r": (3.5, 4.0, 4.8), "torso_len": 9.0, "lu": 6.0, "ll": 6.0, "au": 5.0, "al": 5.2, "arm_r": 1.15,
            "head_r": (2.6, 2.5, 2.7), "arm_len": {1: 0.7, -1: 1.1}}
    swell = 1.0 + 0.1 * math.sin(2 * math.pi * f / max(n, 1))
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.32, knee=0.6, arm=0.1, lean=0.5)
        pose["twist"] = 0.1 * math.sin(2 * math.pi * f / n)
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.5
        pose["arms"] = {1: (0.4, 0.2, 0.9), -1: (0.25, 0.2, 0.2)}
        pose["hip_drop"] = 0.3 * bf(f, n)
    elif anim in ("attack", "aim"):
        # 往後仰、吸氣（囊脹大），然後往前吐（囊縮小）
        pose = default_pose()
        pose["legs"] = {1: (0.35, 0.3), -1: (-0.3, 0.3)}
        pose["lean"] = kf([0.15, -0.2, -0.25, 0.65, 0.5], f, n) if anim == "attack" else -0.15
        pose["arms"] = {1: (0.4, 0.5, 0.9), -1: (0.3, 0.7, 0.4)}
        pose["head_pitch"] = kf([0.0, -0.4, -0.5, 0.2, 0.1], f, n) if anim == "attack" else -0.4
        swell = kf([1.1, 1.4, 1.5, 0.75, 0.85], f, n) if anim == "attack" else 1.35
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 1.6
    pose["head_pitch"] = pose.get("head_pitch", 0.0) - 0.15
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    hb = J["head_basis"]
    # 喉嚨的孢子囊（會脹）：大囊＋旁邊兩顆小的、裡面亮亮的孢子
    sac = head_local(J, (1.3, 0, -3.3))
    prims.append(Ell(sac, (3.1 * swell, 3.2 * swell, 2.9 * swell), "sac"))
    prims.append(Ell(add(sac, (0.4, 2.3 * swell, 0.9)), (1.4, 1.4, 1.4), "sac"))
    prims.append(Ell(add(sac, (1.9 * swell, -1.3, -1.0)), (1.0, 1.0, 1.0), "spore"))
    prims.append(Ell(add(sac, (2.2 * swell, 1.0, 0.6)), (0.8, 0.8, 0.8), "spore"))
    prims.append(Ell(add(sac, (-0.6, -2.6 * swell, 0.2)), (1.1, 1.0, 1.1), "spore"))
    # 背上的孢子莢（一根莖頂著一顆）
    for off, ln in (((-3.2, 1.4, 2.0), 3.2), ((-3.4, -1.6, 0.6), 2.6), ((-2.6, 0.0, 3.6), 3.8), ((-3.2, 0.4, -1.6), 2.0)):
        a = chest_local(J, off)
        b = add(a, mul(norm(add(mul(tb[0], -0.7), (0, off[1] * 0.15, 1.0))), ln))
        prims.append(Cap(a, b, 0.6, "ash", 0.45))
        prims.append(Ell(b, (1.35, 1.35, 1.2), "spore"))
    prims += eyeless(J, crust="spore", mouth=0.8, jaw=1.2, hr=2.6)
    prims.append(Ell(chest_local(J, (-0.2, 0, -5.0)), (2.9, 3.6, 2.6), "rag", tb))
    auto_tag(prims, J)
    return prims


def brute_model(anim, f, n):
    """冰甲巨人：骨頭礦化成整片的冰甲——胸甲、肩甲、前臂的護甲、蓋住臉的面甲，縫隙透出結晶的光。背後甲殼裂開露出肉（弱點）。
    手長到指節快碰到地"""
    mats = {"leg": "coverall", "boot": "boot", "hip": "coverall", "torso": "chitin", "arm": "chitin", "fore": "chitin",
            "hand": "ice", "skin": "chitin"}
    spec = {"torso_r": (5.6, 6.8, 7.2), "torso_len": 11.0, "lu": 6.0, "ll": 5.6, "leg_r": 2.7, "leg_r2": 2.4,
            "sh_w": 6.6, "au": 6.2, "al": 6.8, "arm_r": 2.4, "head_r": (2.4, 2.4, 2.4), "hip_w": 3.1, "hand_k": 1.9,
            "neck": 0.0}
    if anim == "walk":
        pose = walk_pose(f, n, stride=0.32, knee=0.5, arm=0.25, lean=0.3)
        for s_ in (1, -1):
            a, b, e = pose["arms"][s_]
            pose["arms"][s_] = (a + 0.1, 0.3, 0.2)
        pose["twist"] = 0.16 * math.sin(2 * math.pi * f / n)
    elif anim == "idle":
        pose = default_pose()
        pose["lean"] = 0.28
        pose["arms"] = {1: (0.15, 0.3, 0.15), -1: (0.15, 0.3, 0.15)}
        pose["hip_drop"] = 0.4 * bf(f, n)
    elif anim == "attack":
        # 雙手舉高往下砸
        pose = default_pose()
        k = kf([(0.6, 0.3, 0.3), (2.7, 0.3, 0.2), (2.8, 0.25, 0.1), (1.0, 0.1, 0.3), (0.8, 0.2, 0.5)], f, n)
        pose["arms"] = {1: k, -1: k}
        pose["lean"] = kf([0.1, -0.2, -0.25, 0.6, 0.5], f, n)
        pose["legs"] = {1: (0.4, 0.3), -1: (-0.4, 0.3)}
        pose["hip_drop"] = kf([0.5, 0.0, 0.0, 1.6, 1.2], f, n)
    else:
        raise ValueError(anim)
    pose["head_fwd"] = 2.2
    pose["head_pitch"] = 0.3
    prims, J = build_human(spec, pose, mats)
    tb = J["torso_basis"]
    hb = J["head_basis"]
    # 胸甲（兩大片＋中間的縫透出結晶的光）、腹甲
    for side in (1, -1):
        prims.append(Box(chest_local(J, (4.6, side * 2.9, 1.2)), (1.5, 2.5, 3.4), "ice", tb))
        prims.append(Box(chest_local(J, (4.9, side * 2.2, -3.6)), (1.2, 1.9, 1.5), "ice", tb))
    prims.append(Box(chest_local(J, (5.5, 0, 0.4)), (0.9, 0.55, 4.4), "crystal", tb))
    # 肩甲：往上翹的大片、邊緣長出結晶
    for side in (1, -1):
        sh = J["sh%d" % side]
        prims.append(Ell(add(sh, (0.4, side * 1.0, 1.4)), (3.4, 3.3, 2.5), "ice"))
        for d, ln in (((0.0, side * 0.5, 1.0), 4.8),):
            prims.append(spike(add(sh, (0.2, side * 1.4, 2.6)), rot_z(d, pose.get("twist", 0.0)), ln, 1.5))
        # 前臂的護甲比手臂粗一圈，手肘一根刺
        el, hd = J["elbow%d" % side], J["hand%d" % side]
        prims.append(Cap(add(el, mul(sub(hd, el), 0.3)), add(el, mul(sub(hd, el), 0.8)), 2.9, "ice", 2.7))
    # 面甲：整片蓋住臉，只有一條發光的縫
    prims.append(Ell(head_local(J, (0.5, 0, 0.3)), (2.9, 2.8, 2.7), "ice", hb))
    prims.append(Box(head_local(J, (3.2, 0, 0.2)), (0.5, 1.7, 0.4), "crystal", hb))
    for y in (1.5, -1.5):
        prims.append(spike(head_local(J, (0.0, y, 2.0)), add(mul(hb[2], 1.0), mul(hb[1], y * 0.3)), 2.6, 0.8))
    # 背後：甲殼裂開、露出肉（弱點）
    prims.append(Ell(chest_local(J, (-4.2, 0, 0.6)), (1.7, 3.4, 3.8), "gum", tb))
    prims.append(Ell(chest_local(J, (-4.9, 0, 0.8)), (1.3, 1.9, 2.4), "flesh", tb))
    for side in (1, -1):
        prims.append(Box(chest_local(J, (-4.0, side * 4.6, 1.0)), (1.2, 1.4, 3.6), "ice", tb))
    auto_tag(prims, J)
    return prims

CHARACTERS = {
    # 近戰：刀 slash → slash_back → stab；空手 jab → cross → hook（_l／_r 兩套）；重武器 slash_axe、slash_crowbar
    # 每把槍：aim_（1 格）、shoot_（3 格，後座力）、aimwalk_（6 格，舉槍移動：上半身瞄準、腳走路）
    "player": (player_model, dict({"idle": 4, "walk": 8, "sneak": 8, "slash": 8, "slash_back": 8, "stab": 7,
                                   "slash_axe": 8, "slash_crowbar": 9, "punch": 7, "hook": 8, "kick": 9,
                                   "jab_l": 6, "jab_r": 6, "cross_l": 7, "cross_r": 7, "hook_l": 8, "hook_r": 8, "choke": 4,
                                   "hurt": 3, "dodge": 5, "dodge_back": 5},
                                  **{"aim_" + w: 1 for w in GUNS},
                                  **{"shoot_" + w: 3 for w in GUNS},
                                  **{"aimwalk_" + w: 6 for w in GUNS})),
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
# 畫布大小由 `python3 tools/gen_pixel_art.py measure` 量出來（所有格子都放得下、不會被切）
CANVAS = {"player": (66, 56), "watcher": (50, 46), "listener": (52, 54), "guard": (46, 46), "hound": (40, 36),
          "crawler": (46, 36), "husk": (48, 46), "chorister": (46, 46), "bear": (64, 64),
          "runner": (48, 46), "spitter": (42, 42), "brute": (52, 54)}


# 角色放大倍率（模型單位 → 像素）：整個角色等比例放大，手腳才有足夠的像素分開畫。腳印（碰撞大小）在別的檔案，不受影響
CHAR_SCALE = {}
DEFAULT_SCALE = 1.15


def char_prims(name, prims, yaw):
    k = CHAR_SCALE.get(name, DEFAULT_SCALE)
    out = finish(prims, yaw)
    return scale_prims(out, k, (0, 0, 0)) if abs(k - 1.0) > 1e-6 else out


# 腳底離圖的下緣幾個像素（character_sprite.gd 的 FOOT_PAD 要一樣）：往鏡頭方向踢、撲的時候腳會畫到腳底線下面，留空間才不會被切掉
FOOT_PAD = 9
# 四隻腳、趴著的角色身體很長，面向鏡頭時前腳和頭會畫到腳底線下面很多，要留更多（character_sprite.gd 的 FOOT_PADS 要一樣）
FOOT_PADS = {"bear": 15, "crawler": 13}

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


def check_clip(name, fn, img, w, h):
    """圖碰到畫布邊緣 = 可能被切掉，印出來提醒（要加大 CANVAS）"""
    for x in range(w):
        if img[x][3] or img[(h - 1) * w + x][3]:
            print("  !! %s %s 上下被切" % (name, fn))
            return
    for y in range(h):
        if img[y * w][3] or img[y * w + w - 1][3]:
            print("  !! %s %s 左右被切" % (name, fn))
            return


def measure(names):
    """量每個角色所有格子的範圍 → 印出需要的畫布大小和腳底留白（調 CANVAS、FOOT_PAD 用）：
    python3 tools/gen_pixel_art.py measure [角色…]"""
    W = 220
    for name in names:
        sets = [None]
        if name == "player":
            sets += ["player_eod", "player_head_wool_hat", "player_head_eod_helmet", "player_feet_eod_boots"]
        model, anims = CHARACTERS[name]
        ext = [0, 0, 0, 0]  # 左、右、上、下（相對腳底中心）
        worst = ["", "", "", ""]
        for st in sets:
            OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
            if st:
                OUTFIT.update(OUTFIT_SETS[st])
            for anim, n in anims.items():
                for d, yaw in DIRS.items():
                    for f in range(n):
                        m = hurt_of(model, HURT_BASE[name]) if anim == "hurt" and name in HURT_BASE else model
                        img = render(char_prims(name, m(anim, f, n), yaw), W, W, anchor=(W / 2.0, W - 60.0))
                        for y in range(W):
                            for x in range(W):
                                if img[y * W + x][3]:
                                    v = (W // 2 - x, x + 1 - W // 2, W - 60 - y, y + 1 - (W - 60))
                                    for i in range(4):
                                        if v[i] > ext[i]:
                                            ext[i] = v[i]
                                            worst[i] = "%s_%s_%d" % (anim, d, f)
        OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
        half = max(ext[0], ext[1]) + 1
        print("%s: canvas (%d, %d) pad %d   %s %s" % (name, half * 2, ext[2] + ext[3] + 2, ext[3] + 1, ext, worst))


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
                prims = char_prims("player", player_model(anim, f, n), yaw)
                img = render(prims, w, h, anchor=(w / 2.0, h - FOOT_PAD), layer_only=layer)
                check_clip(name, "%s_%s_%d" % (anim, d, f), img, w, h)
                write_png(os.path.join(folder, "%s_%s_%d.png" % (anim, d, f)), w, h, img)
                count += 1
    OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
    print("%s: %d 張" % (name, count))


def gen_character(name):
    if name == "player":
        OUTFIT.update({"body": "parka", "head": "", "feet": "", "layer": ""})
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
                prims = char_prims(name, m(anim, f, n), yaw)
                img = render(prims, w, h, anchor=(w / 2.0, h - FOOT_PADS.get(name, FOOT_PAD)))
                check_clip(name, "%s_%s_%d" % (anim, d, f), img, w, h)
                write_png(os.path.join(folder, "%s_%s_%d.png" % (anim, d, f)), w, h, img)
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
    # 手槍：制式半自動（方正的滑套、扳機護弓、往後斜的握把、滑套上的防滑紋）
    GR = basis_along((1, 0, -0.3))
    save("pistol", [Box((0.8, 0, 2.0), (5.6, 0.7, 1.15), "cabinet", X),            # 滑套
                    Box((1.4, 0, 0.55), (4.4, 0.65, 0.5), "gunmetal", X),          # 槍身
                    Box((-3.4, 0, -1.9), (1.45, 0.65, 2.6), "black", GR),          # 握把
                    Box((0.2, 0, -0.9), (1.5, 0.3, 0.3), "gunmetal", X),           # 扳機護弓
                    Box((1.6, 0, -0.3), (0.3, 0.3, 0.7), "gunmetal", X),
                    Box((-3.6, 0.0, 2.0), (0.9, 0.75, 0.8), "gunmetal", X),        # 滑套後段的防滑紋
                    Box((6.3, 0, 2.2), (0.3, 0.5, 0.55), "black", X)], 18, 14)
    save("shotgun", [Box((2.5, 0, 0.9), (8.0, 0.6, 0.6), "gunmetal", X), Box((4.0, 0, -0.3), (3.0, 0.7, 0.6), "wood", X),
                     Box((-7.2, 0, -0.4), (3.2, 0.7, 1.2), "wood", basis_along((1, 0, 0.2))),
                     Box((-3.2, 0, 0.2), (1.4, 0.7, 1.0), "gunmetal", X)], 26, 10)
    # 求生刀：深色握把、護手、單刃的刀身（刀尖往上收）、刀背一段鋸齒
    save("knife", [Box((-5.0, 0, -0.2), (2.6, 0.7, 1.0), "black", X), Box((-7.4, 0, -0.2), (0.5, 0.75, 1.2), "gunmetal", X),
                   Box((-2.2, 0, -0.2), (0.45, 0.8, 1.9), "steel", X),
                   Box((1.6, 0, 0.0), (3.6, 0.3, 1.25), "blade", X),
                   Box((6.0, 0, 0.45), (1.2, 0.3, 0.8), "blade", basis_along((1, 0, 0.35))),
                   Box((0.4, 0, 1.2), (1.6, 0.32, 0.3), "steel", X)], 20, 10)
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
    save("flashlight", [Cap((-5.0, 0, 0), (1.5, 0, 0), 1.7, "gunmetal"), Cap((2.0, 0, 0), (4.6, 0, 0), 2.9, "cabinet"),
                        Ell((5.6, 0, 0), (0.7, 2.5, 2.5), "amber"), Box((-1.5, -1.7, 0.4), (1.0, 0.25, 0.6), "orange"),
                        Box((-3.8, 0, 0), (0.35, 1.85, 1.85), "black")], 18, 12)
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
    # ── v0.7 新增：鐵撬、左輪、衝鋒槍、十字弓和彈藥、打火機、柴火、空手、營火 ──
    save("crowbar", [Cap((-8.0, 0, -0.6), (5.5, 0, -0.6), 0.75, "red"), Cap((5.5, 0, -0.6), (7.6, 0, 2.2), 0.8, "steel", 0.55),
                     Cap((-8.0, 0, -0.6), (-9.2, 0, 0.1), 0.7, "steel", 0.5)], 22, 10)
    save("revolver", [Box((3.6, 0, 1.9), (3.6, 0.5, 0.6), "steel", X),               # 槍管
                      Box((3.2, 0, 0.9), (2.6, 0.3, 0.3), "cabinet", X),             # 退殼桿
                      Ell((-1.2, 0, 1.3), (1.9, 1.1, 1.6), "steel"),                 # 彈巢
                      Box((-1.6, 0, 1.4), (2.6, 0.55, 1.5), "cabinet", X),           # 槍框
                      Box((-4.2, 0, -1.7), (1.3, 0.65, 2.3), "wood", basis_along((1, 0, -0.5))),
                      Box((-1.0, 0, -1.0), (1.3, 0.3, 0.3), "cabinet", X),
                      Box((-3.9, 0, 2.9), (0.5, 0.3, 0.5), "gunmetal", X)], 18, 14)
    save("magnum_rounds", [Box((0, 0, -0.6), (3.8, 2.3, 1.7), "wood")] +
         [Cap((-2.4 + i * 1.6, -0.9, 1.0), (-2.4 + i * 1.6, -0.9, 2.6), 0.7, "brass") for i in range(4)] +
         [Ell((-2.4 + i * 1.6, -0.9, 3.0), (0.6, 0.6, 0.6), "steel") for i in range(4)], 14, 12, yaw=0.35)
    save("smg", [Box((0.5, 0, 1.4), (5.0, 0.8, 1.3), "cabinet", X),                  # 機匣
                 Box((6.6, 0, 1.5), (1.5, 0.45, 0.45), "steel", X),                  # 槍管
                 Box((1.4, 0, -2.3), (0.85, 0.6, 2.6), "black", X),                  # 直彈匣
                 Box((-2.6, 0, -1.2), (0.95, 0.6, 1.6), "gunmetal", basis_along((1, 0, -0.3))),  # 握把
                 Box((-6.8, 0, 1.6), (2.0, 0.45, 0.4), "gunmetal", X),               # 伸縮槍托
                 Box((-8.7, 0, 0.6), (0.4, 0.6, 1.5), "gunmetal", X),
                 Box((0.0, 0, 3.1), (1.6, 0.4, 0.35), "black", X)], 22, 14)
    # 十字弓：稍微從上面看（看得到橫著的弓臂）
    cb = [Box((-1.0, 0, 0), (7.0, 0.7, 0.8), "wood", X), Box((-7.0, 0, -0.7), (1.8, 0.7, 1.3), "wood", X),
          Cap((-2.0, 0, 1.0), (7.6, 0, 1.0), 0.35, "blade")]
    for sg in (1, -1):
        cb.append(Cap((6.2, 0, 0.6), (4.0, sg * 5.6, 0.6), 0.7, "gunmetal", 0.5))
        cb.append(Cap((4.0, sg * 5.6, 0.6), (-2.2, 0, 0.9), 0.28, "steel"))
    prims_cb = [q.moved(lambda v, d=False: rot_z(v, 0.25)) for q in cb]
    write_png(os.path.join(folder, "crossbow.png"), 20, 16, render(prims_cb, 20, 16, pitch=math.radians(60), anchor=(10.5, 9.5)))
    bolts = []
    for i in range(3):
        y = -1.6 + i * 1.6
        bolts += [Cap((-5.0, y, i * 0.5), (4.0, y, i * 0.5), 0.45, "wood"), Cap((4.0, y, i * 0.5), (6.0, y, i * 0.5), 0.7, "blade", 0.15),
                  Box((-5.0, y, i * 0.5), (1.0, 0.2, 0.95), "red", X)]
    save("bolts", bolts, 16, 10, yaw=0.3)
    # 打火機（黃銅煤油打火機，蓋子掀開）
    save("lighter", [Box((0, 0, -1.6), (2.4, 1.1, 3.0), "brass"), Box((2.9, 0, 3.0), (0.6, 1.1, 2.2), "brass", basis_along((1, 0, 0.5))),
                     Box((-0.2, 0, 2.2), (1.5, 0.8, 0.9), "steel"), Ell((-1.0, -0.2, 2.6), (0.8, 0.8, 0.8), "gunmetal"),
                     Ell((0.4, 0, 4.4), (0.9, 0.7, 1.5), "fire")], 12, 16)
    # 柴火（一捆劈好的木柴，用繩子綁著）
    kd = []
    for i, (y, z) in enumerate(((-1.6, -1.2), (1.4, -1.2), (-0.1, 1.2))):
        kd += [Cap((-5.0, y, z), (5.0, y, z), 1.6, "wood"), Ell((5.4, y, z), (0.5, 1.4, 1.4), "cloth")]
    kd.append(Box((-1.0, 0, 0), (0.5, 3.4, 3.2), "strap"))
    save("kindling", kd, 18, 12, yaw=0.3)
    # 空手（握拳的手套）：拳面朝右、拇指壓在前面、一截袖口
    save("fists", [Box((0.6, 0, 0.4), (3.2, 2.2, 2.8), "mitt"), Box((3.6, 0, 1.0), (0.7, 2.2, 2.0), "mitt"),
                   Box((1.2, -2.3, -1.2), (2.0, 0.5, 0.9), "mitt"), Box((-3.6, 0, 0.0), (1.6, 2.0, 2.4), "parka"),
                   Box((-2.3, 0, 0.0), (0.4, 2.3, 2.7), "parka_trim")] +
         [Box((3.9, 0, -1.2 + i * 1.5), (0.45, 2.3, 0.12), "strap") for i in range(3)], 16, 12, yaw=0.3)
    # 營火的木柴堆（遊戲的 3/4 視角；火焰由程式畫在上面）：三根交叉的木柴＋底下的炭和石頭
    cf = [Ell((0, 0, 0.4), (6.0, 4.0, 0.8), "black")]
    for ang, tilt in ((0.3, 0.35), (2.2, 0.3), (4.3, 0.4), (5.4, 0.2)):
        d = (math.cos(ang), math.sin(ang), 0)
        cf.append(Cap(add(mul(d, 5.4), (0, 0, 1.0)), add(mul(d, -1.6), (0, 0, 1.0 + 6.0 * tilt)), 1.25, "wood", 1.05))
    for ang in (1.2, 3.3, 5.0, 0.0, 2.4, 4.1):
        cf.append(Ell((math.cos(ang) * 6.2, math.sin(ang) * 4.2, 0.7), (1.3, 1.2, 0.9), "rock"))
    write_png(os.path.join(folder, "campfire.png"), 18, 14, render(cf, 18, 14, anchor=(9.0, 11.0)))
    # ── 裝備圖示（Gear.DATA 的每一件）：身體 = 攤開的上衣、頭 = 頭盔外罩、腳 = 一雙靴子 ──
    def suit(mat, trim, extra=()):
        p = [Box((0, 0, -0.4), (3.6, 1.4, 4.4), mat), Box((0, 0, 4.3), (2.0, 1.5, 0.7), trim),
             Box((0, -1.5, -0.4), (0.3, 0.15, 4.2), trim)]
        for sg in (1, -1):
            p.append(Cap((sg * 3.6, 0, 3.0), (sg * 6.6, 0, -2.4), 1.5, mat, 1.3))
            p.append(Ell((sg * 6.8, 0, -3.2), (1.3, 1.2, 0.9), trim))
        return p + list(extra)
    save("parka", suit("parka", "parka_trim"), 18, 14)
    save("hazmat_suit", suit("hazmat", "black", [Box((0, -1.5, 1.6), (1.6, 0.15, 1.0), "glass")]), 18, 14)
    save("eod_armor", suit("eod", "rig", [Box((0, -1.6, 0.2), (2.8, 0.3, 3.0), "rig"), Box((0, 0, 5.0), (2.9, 1.7, 0.9), "eod")]), 18, 14)
    save("sneaking_suit", suit("sneak", "helm_trim", [Box((0, -1.5, 1.0), (3.4, 0.15, 0.35), "helm_trim")]), 18, 14)
    save("arctic_suit", suit("white", "fur"), 18, 14)

    def helm(prims):
        return [q.moved(lambda v, d=False: rot_z(v, -1.0)) for q in prims]
    dome = lambda mat: [Ell((0, 0, 0.6), (5.2, 5.0, 4.8), mat), Ell((0.8, 0, -2.2), (4.2, 4.0, 2.6), mat)]
    hsave = lambda name, prims: write_png(os.path.join(folder, name + ".png"), 16, 16,
                                          render(helm(prims), 16, 16, pitch=side, anchor=(8.0, 9.0)))
    hsave("wool_hat", [Ell((0, 0, 1.4), (5.3, 5.1, 4.0), "knit"), Ell((0, 0, -1.0), (5.5, 5.3, 1.3), "knit"),
                       Ell((-0.5, 0, 5.8), (1.7, 1.7, 1.7), "white"), Ell((1.0, 0, -2.6), (4.2, 4.0, 2.0), "helm")])
    hsave("gas_mask", dome("hazmat") + [Box((4.6, 0, 0.6), (0.5, 2.9, 1.3), "goggle"), Ell((2.0, 0, -2.6), (3.8, 3.4, 2.0), "black"),
                                        Cap((3.6, 2.2, -2.8), (5.6, 3.0, -3.4), 1.5, "steel"), Cap((3.6, -2.2, -2.8), (5.6, -3.0, -3.4), 1.5, "steel")])
    hsave("eod_helmet", dome("eod") + [Box((4.8, 0, 0.2), (0.6, 3.4, 2.4), "glass"), Ell((0, 0, -3.6), (5.4, 5.4, 1.5), "eod")])
    hsave("balaclava", dome("black") + [Box((4.7, 0, 0.6), (0.4, 2.6, 0.9), "sneak")])
    hsave("snow_goggles", dome("white") + [Box((4.7, 0, 0.6), (0.5, 3.0, 1.2), "orange"), Ell((0, 0, 0.6), (5.3, 5.1, 0.6), "black")])

    def boots(mat, sole="black", extra=None):
        p = []
        for y, x0 in ((2.6, -2.2), (-2.6, 1.2)):   # 後面那隻往左錯開，兩隻都看得到
            p += [Box((x0 - 1.6, y, 1.2), (1.6, 1.5, 3.6), mat), Box((x0 + 0.6, y, -1.5), (3.6, 1.5, 1.5), mat),
                  Box((x0 + 0.5, y, -3.2), (3.9, 1.6, 0.5), sole), Box((x0 - 1.6, y, 4.6), (1.8, 1.7, 0.5), sole)]
            if extra:
                p += extra(y)
        return [q.moved(lambda v, d=False: rot_z(v, 0.3)) for q in p]
    bsave = lambda name, prims: write_png(os.path.join(folder, name + ".png"), 16, 14,
                                          render(prims, 16, 14, pitch=side, anchor=(8.0, 7.5)))
    bsave("snow_boots", boots("white", "strap", lambda y: [Box(((-3.8 if y > 0 else -0.4), y, 3.4), (1.9, 1.8, 0.8), "fur")]))
    bsave("hazmat_boots", boots("hazmat"))
    bsave("eod_boots", boots("eod", "black", lambda y: [Box(((1.2 if y > 0 else 4.4), y, -0.6), (1.6, 1.7, 0.9), "rig")]))
    bsave("soft_soles", boots("sneak", "helm_trim"))
    bsave("crampons", boots("boot", "steel", lambda y: [Box(((-1.7 if y > 0 else 1.7) + dx, y, -4.0), (0.35, 1.2, 0.5), "steel") for dx in (-2.6, 0.0, 2.6)]))
    print("items: ok")


# ── 特效（子彈、槍口火光、彈殼、影子）─────────────────────────

BAYER_FX = [[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]


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
    # 刀光 5 格：一大片新月形的弧光，從主角的右手邊（往右看時是畫面下方）掃到左手邊。
    # 外緣是白色的芯、往內是冷藍色的邊，尾巴越來越細、越來越淡；最後兩格整個淡出。
    SW, SR = 48, 20.0
    A0, A1 = 1.4, -1.4
    spans = [(0.0, 0.42, 1.0), (0.04, 0.8, 1.0), (0.3, 1.0, 1.0), (0.62, 1.0, 0.62), (0.84, 1.0, 0.3)]
    for f, (tail, head, fade) in enumerate(spans):
        px = [_] * (SW * SW)
        for y in range(SW):
            for x in range(SW):
                dx, dy = x + 0.5 - SW / 2, y + 0.5 - SW / 2
                r = math.hypot(dx, dy)
                if r < SR - 8 or r > SR + 0.6:
                    continue
                u = (math.atan2(dy, dx) - A0) / (A1 - A0)   # 0 = 起點、1 = 終點
                if u < tail or u > head:
                    continue
                k = (u - tail) / max(head - tail, 1e-6)      # 0 = 尾巴、1 = 刀尖
                thick = 6.6 * math.sin(math.pi * min(1.0, k * 0.5 + 0.5 * k * k)) ** 0.8 + 0.6
                if k > 0.9:
                    thick *= (1.0 - k) / 0.1 * 0.8 + 0.2
                d = SR - r
                if d < -0.4 or d > thick:
                    continue
                q = d / max(thick, 0.01)
                al = fade * (0.25 + 0.75 * k)
                if q < 0.42:
                    col, a_ = (255, 255, 255), 1.0
                elif q < 0.72:
                    col, a_ = (196, 232, 255), 0.85
                else:
                    col, a_ = (104, 176, 255), 0.55
                # 尾巴用抖色變稀，像素風的淡出
                if k < 0.35 and BAYER_FX[y % 4][x % 4] / 16.0 > k / 0.35 + 0.15:
                    continue
                px[y * SW + x] = col + (int(255 * min(1.0, al * a_)),)
        write_png(os.path.join(folder, "slash_%d.png" % f), SW, SW, px)
    # 直刺 4 格：一道往前衝的細長白光（尖端最亮最粗，尾巴抖色淡出），和橫砍的弧光一眼分得出來
    TW, TH = 30, 9
    for f, (tail, head, fade) in enumerate([(0.0, 0.5, 1.0), (0.12, 1.0, 1.0), (0.5, 1.0, 0.7), (0.78, 1.0, 0.35)]):
        px = [_] * (TW * TH)
        for y in range(TH):
            for x in range(TW):
                u = (x + 0.5) / TW
                if u < tail or u > head:
                    continue
                k = (u - tail) / max(head - tail, 1e-6)
                half = (0.5 + 2.6 * k) if k < 0.82 else 3.1 * (1.0 - k) / 0.18 + 0.3
                d = abs(y + 0.5 - TH / 2)
                if d > half:
                    continue
                if k < 0.4 and BAYER_FX[y % 4][x % 4] / 16.0 > k / 0.4 + 0.1:
                    continue
                col = (255, 255, 255) if d < half * 0.5 else (196, 232, 255) if d < half * 0.8 else (104, 176, 255)
                px[y * TW + x] = col + (int(255 * fade * (0.35 + 0.65 * k)),)
        write_png(os.path.join(folder, "thrust_%d.png" % f), TW, TH, px)
    # 拳、勾拳、踢 3 格：出手那一下在拳頭前面的小衝擊（短短的放射線，越來越散、越來越淡）
    BW = 13
    for f, (r0, r1, al) in enumerate([(0.0, 3.2, 1.0), (2.0, 5.2, 0.85), (4.2, 6.4, 0.45)]):
        px = [_] * (BW * BW)
        for y in range(BW):
            for x in range(BW):
                dx, dy = x - BW // 2, y - BW // 2
                r = math.hypot(dx, dy)
                if r < r0 - 0.3 or r > r1 + 0.3:
                    continue
                on = dx == 0 or dy == 0 or (abs(dx) == abs(dy) and f > 0)
                if not on:
                    continue
                if f == 2 and (x + y) % 2:
                    continue
                col = (255, 255, 255) if r < (r0 + r1) * 0.5 + 0.5 else (255, 226, 150)
                px[y * BW + x] = col + (int(255 * al),)
        write_png(os.path.join(folder, "burst_%d.png" % f), BW, BW, px)
    # 命中：第一格是一個白色的四角星閃光，接著冰晶碎片＋暗紅飛濺往外噴（感染體被打中）4 格
    rnd = random.Random(11)
    shards = [(rnd.uniform(0, 6.28), rnd.uniform(0.55, 1.0), rnd.random() < 0.6) for _ in range(14)]
    for f in range(4):
        w, h = 23, 23
        c = 11
        px = [_] * (w * h)
        r = 2.0 + f * 2.6
        for a, sp, ice in shards:
            x = int(c + 0.5 + math.cos(a) * r * sp)
            y = int(c + 0.5 + math.sin(a) * r * sp)
            col = (200, 245, 255) if ice else (170, 34, 44)
            if 0 <= x < w and 0 <= y < h:
                px[y * w + x] = col + (255 - f * 45,)
                if f < 2 and ice and 0 <= x + 1 < w:
                    px[y * w + x + 1] = (150, 215, 255, 200 - f * 45)
        if f < 2:
            arm = 7 if f == 0 else 4
            for i in range(-arm, arm + 1):
                al = 255 if abs(i) < arm - 2 else 150
                colr = (255, 255, 255, al) if f == 0 else (210, 240, 255, al - 60)
                px[c * w + c + i] = colr
                px[(c + i) * w + c] = colr
                if abs(i) <= arm // 2:
                    px[(c + i) * w + c + i] = colr
                    px[(c - i) * w + c + i] = colr
            if f == 0:
                for dx, dy in ((1, 1), (-1, 1), (1, -1), (-1, -1), (0, 0)):
                    px[(c + dy) * w + c + dx] = (255, 255, 255, 255)
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
    # 十字弓的箭：深色箭桿、亮的箭頭
    write_png(os.path.join(folder, "bolt.png"), 8, 1, [(90, 70, 50, 255)] * 2 + [(60, 48, 40, 255)] * 4 + [(200, 210, 222, 255), (240, 246, 250, 255)])
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
            out.append(_keep(Ell(mul(sub(p.c, origin), k), mul(p.r, k), p.mat, p.b), p))
        elif isinstance(p, Cap):
            out.append(_keep(Cap(mul(sub(p.a, origin), k), mul(sub(p.bp, origin), k), p.r * k, p.mat, p.rb * k), p))
        elif isinstance(p, Box):
            out.append(_keep(Box(mul(sub(p.c, origin), k), mul(p.h, k), p.mat, p.b), p))
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
        """主角的頭像：一律是戴著頭盔的頭，不露臉。狀態用面罩表現：
        fine = 乾淨的面罩、琥珀燈；caution = 面罩起霧＋刮痕；danger = 面罩裂開、紅色警示燈、盔上結霜"""
        mats = {"leg": "pants", "boot": "boot", "hip": "pants", "torso": "parka", "arm": "parka", "hand": "glove",
                "skin": "glove", "head": "helm"}

        def extra(J):
            hb = J["head_basis"]

            def on_visor(y, z, lift=0.12):
                q = max(0.05, 1.0 - (y / 2.95) ** 2 - ((z - 0.15) / 1.65) ** 2)
                return head_local(J, (1.25 + 2.7 * math.sqrt(q) + lift, y, z))

            def stroke(y0, z0, y1, z1, mat, th=0.16):
                ln = math.hypot(y1 - y0, z1 - z0)
                dy, dz = (y1 - y0) / ln, (z1 - z0) / ln
                b = (hb[0], add(mul(hb[1], dy), mul(hb[2], dz)), add(mul(hb[1], -dz), mul(hb[2], dy)))
                return Box(on_visor((y0 + y1) * 0.5, (z0 + z1) * 0.5), (0.3, ln * 0.5, th), mat, b)

            visor = {"fine": "visor", "caution": "visor_fog", "danger": "visor"}[state]
            p = helmet_prims(J, visor, "alarm" if state == "danger" else "amber")
            p.append(Ell(chest_local(J, (-0.4, 0, 3.6)), (3.2, 4.0, 1.4), "parka_trim"))
            p.append(Box(chest_local(J, (3.1, 1.7, 0.3)), (0.5, 1.0, 1.1), "strap"))
            if state == "fine":
                p.append(stroke(-1.7, 0.75, -0.7, 0.95, "helm_trim", 0.1))   # 面罩上的一道反光
            elif state == "caution":
                # 刮痕（斜的兩道）、下緣還沒起霧的一條
                p += [stroke(-1.9, 0.9, -0.5, -0.3, "frost", 0.09), stroke(0.5, 0.8, 1.6, 0.1, "frost", 0.08),
                      stroke(-1.4, -0.75, 1.4, -0.75, "visor", 0.22)]
            else:
                # 裂痕從右邊一個撞擊點放射出去，盔頂結霜，領口旁邊冒出結晶
                cx, cz = -0.9, 0.3
                for ty, tz in ((-2.2, 1.0), (0.4, 1.1), (0.9, -0.2), (-0.3, -0.9), (-2.1, -0.5), (1.9, 0.6)):
                    p.append(stroke(cx, cz, ty, tz, "frost", 0.09))
                p.append(Box(on_visor(cx, cz, 0.2), (0.3, 0.3, 0.3), "white", hb))
                p.append(Ell(head_local(J, (-0.6, -0.6, 3.4)), (2.4, 2.4, 0.7), "frost", hb))
                p += [spike(chest_local(J, (0.8, -3.4, 4.0)), (0.2, -0.5, 1.0), 2.4, 0.6),
                      spike(chest_local(J, (0.2, -3.9, 3.6)), (-0.2, -0.9, 0.7), 1.8, 0.5)]
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

    # 守門派：雪地迷彩頭盔、橘色雪鏡、黑色面罩、戰術背心（跟 guard_model 同一套）
    def gate_extra(J):
        hb = J["head_basis"]
        return [Ell(head_local(J, (-0.3, 0, 1.7)), (3.55, 3.45, 2.35), "camo", hb),
                Ell(head_local(J, (-1.2, 1.4, 2.9)), (1.6, 1.5, 1.0), "camo_d", hb),
                Box(head_local(J, (2.8, 0, 0.3)), (0.55, 2.2, 0.8), "lens", hb),
                Ell(head_local(J, (0.3, 0, -0.9)), (3.0, 3.0, 2.4), "black", hb),
                Ell(add(J["chest"], (0.2, 0, -0.2)), (3.8, 4.6, 3.9), "rig"),
                Ell(add(J["chest"], (-0.5, 3.4, 2.6)), (1.6, 1.4, 1.2), "camo_d")]
    save("gate", portrait_human({"torso_r": (3.5, 4.4, 5.4)}, {"leg": "camo", "boot": "boot", "hip": "camo",
                                 "torso": "camo", "arm": "camo", "hand": "glove", "skin": "black"}, gate_extra))
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
        prims.append(Ell(c, (2.7 * sc, 2.4 * sc, 3.7 * sc), "dead", basis_lean(0.25 * (1 if x > 0 else -1))))
        # 沒有眼睛（眼窩被結晶封住）、張開的嘴；臉的周圍一圈被肉吞進去的深色邊
        prims.append(Box(add(c, (0, -2.2 * sc, 1.1 * sc)), (1.7 * sc, 0.5, 0.45 * sc), "crystal_d" if not dead else "frost"))
        mouth_open = 0.7 + 0.7 * swell + 0.4 * open_
        prims.append(Ell(add(c, (0, -2.1 * sc, -1.5 * sc)), (0.9 * sc, 0.6, mouth_open * sc), "vent"))
        prims.append(Ell(add(c, (0, 1.2, 0.1)), (3.2 * sc, 2.0 * sc, 4.2 * sc), "gum"))
    # 肉塊表面的瘤、往地上爬的根
    for c, r in (((-12, -4, 11), 3.2), ((11, -3, 12), 3.0), ((4, -7, 17), 2.6), ((-5, -6, 18), 2.4), ((15, 4, 8), 3.4), ((-16, 3, 7), 3.2)):
        prims.append(Ell((c[0] * s_, c[1] * s_, c[2] * s_ - sink), (r, r, r * 0.9), "mass"))
    for ang in (0.5, 1.2, 2.0, 2.7, 3.6, 4.4, 5.1, 5.9):
        a = (math.cos(ang) * 15, math.sin(ang) * 10 + 4, 3.0)
        b = (math.cos(ang) * 24, math.sin(ang) * 15 + 4, 0.8)
        prims.append(Cap(a, b, 1.6, "mass", 0.6))
    for (x, y, z), (dx, dz) in (((-14, -2, 5), (-6, 4)), ((14, -1, 6), (6, 5)), ((-4, -9, 4), (-3, 2)), ((5, -9, 4), (4, 3))):
        reach = 1.0 + 0.25 * breathe + 0.3 * swell
        a = (x * s_, y * s_, z - sink)
        b = add(a, (dx * reach, -2.0, dz * reach))
        prims.append(Cap(a, b, 1.2, "dead", 0.8))
        prims.append(Ell(b, (1.1, 1.0, 1.0), "dead"))
        for off in (-0.8, 0.0, 0.8):
            prims.append(Cap(b, add(b, (dx * 0.3 + off * 0.4, -0.6, dz * 0.3 + off)), 0.4, "dead", 0.2))
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
    if want and want[0] == "measure":
        measure(want[1:] or list(CHARACTERS))
        return
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
