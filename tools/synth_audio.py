#!/usr/bin/env python3
"""程式合成的暫代音效／音樂／環境音（只用 Python 標準函式庫）。

輸出到 assets/audio/synth/{sfx,music,ambience}/<id>.wav（有多個版本就是 <id>_1.wav…）。
遊戲先找 assets/audio/{sfx,music,ambience}/ 的正式素材，找不到才用這裡的暫代版，
所以之後放進正式素材就會自動取代，不用刪這些檔案。

執行：python3 tools/synth_audio.py            （全部）
      python3 tools/synth_audio.py pistol_shot  （只做指定的 id）
做完要跑一次 Godot --import。
"""
import math
import os
import random
import struct
import sys
import wave

SR = 22050
ROOT = os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "synth")
TAU = math.pi * 2


# ── 基本工具 ───────────────────────────────────────────

def n(sec):
    return int(sec * SR)


def silence(sec):
    return [0.0] * n(sec)


def noise(sec, rng):
    return [rng.uniform(-1, 1) for _ in range(n(sec))]


def sine(sec, freq, phase=0.0):
    """freq 可以是數字或 f(t) 函式"""
    out = []
    ph = phase
    for i in range(n(sec)):
        f = freq(i / SR) if callable(freq) else freq
        out.append(math.sin(ph))
        ph += TAU * f / SR
    return out


def saw(sec, freq, rng=None, jitter=0.0):
    out = []
    ph = 0.0
    for i in range(n(sec)):
        f = freq(i / SR) if callable(freq) else freq
        if jitter and rng:
            f *= 1 + rng.uniform(-jitter, jitter)
        out.append(2 * (ph - math.floor(ph + 0.5)))
        ph += f / SR
    return out


def square(sec, freq):
    return [1.0 if s >= 0 else -1.0 for s in sine(sec, freq)]


def env(x, attack=0.002, decay=0.1, hold=0.0):
    """attack 線性上升、hold 維持、之後指數衰減（decay = 掉到 1/e 的時間）"""
    out = []
    a, h = n(attack), n(hold)
    for i, s in enumerate(x):
        if i < a:
            g = i / max(a, 1)
        elif i < a + h:
            g = 1.0
        else:
            g = math.exp(-(i - a - h) / (decay * SR))
        out.append(s * g)
    return out


def bell(x, peak=0.5):
    """先升後降的包絡，peak = 最大值在全長的哪個位置"""
    L = len(x)
    out = []
    for i, s in enumerate(x):
        t = i / max(L - 1, 1)
        g = t / peak if t < peak else (1 - t) / (1 - peak)
        out.append(s * math.sin(g * math.pi / 2) ** 2)
    return out


def lp(x, fc):
    out, y = [], 0.0
    for i, s in enumerate(x):
        f = fc(i / SR) if callable(fc) else fc
        a = 1 - math.exp(-TAU * f / SR)
        y += a * (s - y)
        out.append(y)
    return out


def hp(x, fc):
    low = lp(x, fc)
    return [a - b for a, b in zip(x, low)]


def bp(x, freq, q=4.0):
    """biquad 帶通，freq 可以是函式（掃頻）"""
    out = []
    x1 = x2 = y1 = y2 = 0.0
    for i, s in enumerate(x):
        f = freq(i / SR) if callable(freq) else freq
        f = min(max(f, 20), SR * 0.45)
        w = TAU * f / SR
        alpha = math.sin(w) / (2 * q)
        b0, b2 = alpha, -alpha
        a0, a1, a2 = 1 + alpha, -2 * math.cos(w), 1 - alpha
        y = (b0 * s + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, s
        y2, y1 = y1, y
        out.append(y)
    return out


def gain(x, g):
    return [s * g for s in x]


def mix(*parts, length=None):
    """parts: (訊號, 開始秒數, 音量)"""
    L = length or max(n(t) + len(s) for s, t, _ in parts)
    out = [0.0] * L
    for s, t, g in parts:
        o = n(t)
        for i, v in enumerate(s):
            if o + i < L:
                out[o + i] += v * g
    return out


def am(x, rate, depth=1.0, phase=0.0):
    return [s * (1 - depth * 0.5 * (1 + math.sin(TAU * rate * i / SR + phase))) for i, s in enumerate(x)]


def crackle(sec, density, rng, tone=3000.0, decay=0.003):
    """隨機的小脈衝（冰裂、碎石、火的劈啪聲）。density = 每秒幾個"""
    L = n(sec)
    out = [0.0] * L
    count = int(density * sec)
    for _ in range(count):
        o = rng.randrange(L)
        amp = rng.uniform(0.2, 1.0)
        length = n(decay * 6)
        for i in range(length):
            if o + i >= L:
                break
            out[o + i] += amp * math.exp(-i / (decay * SR)) * rng.uniform(-1, 1)
    return hp(out, tone * 0.3)


def tone_partials(sec, partials, decay, rng=None):
    """多個泛音（金屬、玻璃、鐘）：partials = [(頻率, 音量, 衰減倍率)]"""
    out = [0.0] * n(sec)
    for f, a, d in partials:
        s = env(sine(sec, f, rng.uniform(0, TAU) if rng else 0.0), 0.001, decay * d)
        for i, v in enumerate(s):
            out[i] += v * a
    return out


def piano(sec, freq):
    p = [(freq, 1.0, 1.0), (freq * 2, 0.45, 0.6), (freq * 3, 0.2, 0.4), (freq * 4.02, 0.1, 0.3)]
    return env(tone_partials(sec, p, sec * 0.35), 0.004, sec * 0.35)


def normalize(x, peak=0.89):
    m = max((abs(s) for s in x), default=0) or 1.0
    return [s * peak / m for s in x]


def fade(x, fin=0.003, fout=0.02):
    L = len(x)
    a, b = n(fin), n(fout)
    out = list(x)
    for i in range(min(a, L)):
        out[i] *= i / a
    for i in range(min(b, L)):
        out[L - 1 - i] *= i / b
    return out


def make_loop(x, xfade=1.5):
    """把尾巴交叉淡入到開頭，做成無縫循環"""
    k = n(xfade)
    body = x[:-k]
    tail = x[-k:]
    for i in range(k):
        g = i / k
        body[i] = body[i] * g + tail[i] * (1 - g)
    return body


def write(folder, name, x, loop=False):
    path = os.path.join(ROOT, folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    x = normalize(x)
    if not loop:
        x = fade(x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, s)) * 32767)) for s in x))


def midi(m):
    return 440.0 * 2 ** ((m - 69) / 12)


# ── 音效 ──────────────────────────────────────────────

def thump(rng, f=90, d=0.05, nf=1500, nd=0.03):
    return mix((env(sine(0.3, lambda t: f * (1 + 2 * math.exp(-t * 40))), 0.001, d), 0, 1.0),
               (env(lp(noise(0.2, rng), nf), 0.001, nd), 0, 0.6))


def step_concrete(rng):
    heel = mix((env(lp(noise(0.12, rng), 2200), 0.001, 0.02), 0, 0.8), (env(sine(0.12, 110), 0.001, 0.03), 0, 0.5))
    toe = env(bp(noise(0.1, rng), 1800, 1.2), 0.002, 0.025)
    return mix((heel, 0, 1.0), (toe, rng.uniform(0.05, 0.07), 0.6), length=n(0.3))


def step_snow(rng):
    grit = mix((crackle(0.25, 260, rng, 2500, 0.002), 0, 1.0), (bp(noise(0.25, rng), 900, 0.8), 0, 0.4))
    return bell(lp(grit, 5000), 0.25)


def step_metal(rng):
    ring = tone_partials(0.3, [(rng.uniform(520, 640), 0.5, 1), (1370, 0.3, 0.6), (2410, 0.15, 0.4)], 0.07, rng)
    return mix((thump(rng, 80, 0.04), 0, 1.0), (ring, 0.002, 0.6))


def player_hurt(rng):
    v = saw(0.45, lambda t: 230 - 80 * t, rng, 0.03)
    v = bp(v, 800, 2) + []
    breath = bp(noise(0.45, rng), 1300, 1.5)
    return env(mix((v, 0, 0.8), (breath, 0, 0.5)), 0.01, 0.12)


def player_death(rng):
    v = env(bp(saw(1.0, lambda t: 200 - 90 * t, rng, 0.05), 700, 2), 0.02, 0.35)
    breath = env(bp(noise(1.0, rng), 1100, 1.2), 0.05, 0.4)
    fall = thump(rng, 60, 0.15, 800, 0.1)
    return mix((v, 0, 0.7), (breath, 0, 0.5), (fall, 0.7, 1.0), length=n(1.5))


def shiver_breath(rng):
    b = bell(bp(noise(1.4, rng), lambda t: 900 + 300 * math.sin(t * 4), 1.3), 0.4)
    b = am(b, 11, 0.6)
    chatter = crackle(1.4, 18, rng, 2500, 0.002)
    return mix((b, 0, 1.0), (chatter, 0, 0.25))


def creak(rng, sec, f0, f1):
    s = saw(sec, lambda t: f0 + (f1 - f0) * t / sec + 15 * math.sin(t * 37), rng, 0.08)
    return bell(bp(s, 1100, 3), 0.5)


def locker_open(rng):
    latch = env(hp(noise(0.05, rng), 2000), 0.0005, 0.006)
    return mix((latch, 0, 1.0), (creak(rng, 0.55, 260, 330), 0.06, 0.7))


def locker_close(rng):
    return mix((creak(rng, 0.25, 320, 260), 0, 0.5), (thump(rng, 120, 0.06, 1800, 0.05), 0.25, 1.0),
               (env(hp(noise(0.03, rng), 2500), 0.0005, 0.005), 0.27, 0.6))


def knock(rng):
    k = lambda: bp(thump(rng, 160, 0.04, 1200, 0.03), 350, 1.5)
    return mix((k(), 0, 1.0), (k(), rng.uniform(0.13, 0.16), 0.9), length=n(0.4))


def click(rng, tone=3000, d=0.004):
    return env(bp(noise(0.03, rng), tone, 1.5), 0.0003, d)


def flashlight_click(rng):
    return mix((click(rng, 2500), 0, 1.0), (click(rng, 1800), 0.05, 0.6), length=n(0.15))


def lighter_flick(rng):
    lid = click(rng, 3500, 0.006)
    strike = env(hp(noise(0.08, rng), 3000), 0.001, 0.02)
    flame = bell(lp(noise(0.3, rng), 900), 0.2)
    return mix((lid, 0, 0.8), (strike, 0.12, 1.0), (flame, 0.16, 0.5), length=n(0.5))


def gunshot(rng, body_f=70, length=0.8, tail=0.25, crack_d=0.02):
    crack = env(hp(noise(0.1, rng), 900), 0.0003, crack_d)
    body = env(sine(0.3, lambda t: body_f * (1 + 3 * math.exp(-t * 60))), 0.0005, 0.07)
    mid = env(lp(noise(0.3, rng), 2500), 0.0005, 0.05)
    room = env(lp(noise(length, rng), 1200), 0.01, tail)
    return mix((crack, 0, 1.0), (body, 0, 1.0), (mid, 0, 0.7), (room, 0.01, 0.35), length=n(length))


def pistol_shot(rng):
    return gunshot(rng, 75, 0.8, 0.18)


def shotgun_shot(rng):
    shot = gunshot(rng, 50, 1.0, 0.3, 0.035)
    rack = mix((click(rng, 1500, 0.01), 0, 1), (click(rng, 1100, 0.012), 0.12, 1))
    return mix((shot, 0, 1.0), (rack, 0.62, 0.35), length=n(1.0))


def gun_empty(rng):
    return mix((click(rng, 2200, 0.005), 0, 1), (click(rng, 1400, 0.004), 0.02, 0.5), length=n(0.2))


def reload(rng):
    return mix((click(rng, 1600, 0.01), 0.0, 0.8), (thump(rng, 200, 0.02, 2000, 0.02), 0.45, 0.6),
               (click(rng, 2000, 0.01), 0.5, 1.0), (click(rng, 1300, 0.015), 0.85, 0.9),
               (click(rng, 1900, 0.01), 0.95, 0.9), length=n(1.2))


def whoosh(rng, sec, f0, f1, q=1.5):
    return bell(bp(noise(sec, rng), lambda t: f0 + (f1 - f0) * t / sec, q), 0.45)


def knife_swing(rng):
    return whoosh(rng, 0.28, 700, rng.uniform(2800, 3600), 2.0)


def knife_hit(rng):
    return mix((thump(rng, 130, 0.04, 2000, 0.04), 0, 1.0), (crackle(0.2, 200, rng, 3500, 0.002), 0, 0.6),
               length=n(0.4))


def bullet_hit_flesh(rng):
    return mix((thump(rng, 100, 0.05, 1200, 0.04), 0, 1.0), (crackle(0.25, 150, rng, 4000, 0.002), 0.005, 0.5),
               length=n(0.3))


def throw_whoosh(rng):
    return whoosh(rng, 0.3, 500, 1800)


def stone_land(rng):
    hit = lambda: bp(thump(rng, 220, 0.02, 3000, 0.02), 1400, 1.2)
    return mix((hit(), 0, 1.0), (hit(), 0.14, 0.5), (hit(), 0.24, 0.25), length=n(0.4))


def glass(rng, sec, count=14):
    parts = []
    for _ in range(count):
        f = rng.uniform(2200, 7000)
        parts.append((env(sine(sec, f), 0.0005, rng.uniform(0.02, 0.12)), rng.uniform(0, sec * 0.4), rng.uniform(0.1, 0.4)))
    return mix(*parts, length=n(sec))


def bottle_break(rng):
    return mix((env(hp(noise(0.2, rng), 1500), 0.0005, 0.04), 0, 1.0), (glass(rng, 0.7), 0, 0.8),
               (crackle(0.5, 80, rng, 5000, 0.002), 0.03, 0.4), length=n(0.7))


def flame_tail(rng, sec):
    return mix((lp(noise(sec, rng), 700), 0, 0.6), (crackle(sec, 40, rng, 2000, 0.004), 0, 0.5))


def molotov_ignite(rng):
    whoomp = env(lp(noise(0.6, rng), lambda t: 300 + 1500 * t), 0.08, 0.2)
    return mix((whoomp, 0, 1.0), (env(flame_tail(rng, 1.2), 0.05, 0.6), 0.1, 0.6), length=n(1.2))


def fire_loop(rng):
    base = lp(noise(5.5, rng), 600)
    base = [s * (0.7 + 0.3 * math.sin(i / SR * 1.7) * math.sin(i / SR * 0.9)) for i, s in enumerate(base)]
    x = mix((base, 0, 0.7), (crackle(5.5, 30, rng, 2500, 0.004), 0, 0.6), (crackle(5.5, 6, rng, 1200, 0.01), 0, 0.5))
    return make_loop(x, 1.5)


def extinguisher_spray(rng):
    return env(hp(noise(0.8, rng), 1500), 0.01, 0.25, 0.2)


def metal_hit(rng, sec, base):
    return tone_partials(sec, [(base, 0.6, 1.0), (base * 2.76, 0.4, 0.7), (base * 5.4, 0.25, 0.4), (base * 8.9, 0.1, 0.3)],
                         sec * 0.3, rng)


def extinguisher_clang(rng):
    return mix((thump(rng, 90, 0.05), 0, 0.8), (metal_hit(rng, 0.9, 430), 0, 1.0), (metal_hit(rng, 0.5, 470), 0.3, 0.4),
               length=n(0.9))


def wood_break(rng):
    return mix((thump(rng, 100, 0.06, 1500, 0.05), 0, 1.0), (crackle(0.6, 160, rng, 1800, 0.006), 0.0, 0.9),
               (env(bp(noise(0.5, rng), 600, 1), 0.001, 0.1), 0.02, 0.5), length=n(0.8))


def drum_ignite(rng):
    whoomp = env(lp(noise(1.0, rng), lambda t: 200 + 900 * t), 0.1, 0.35)
    return mix((whoomp, 0, 1.0), (env(flame_tail(rng, 1.5), 0.1, 0.8), 0.15, 0.7),
               (env(sine(0.6, 45), 0.05, 0.2), 0, 0.6), length=n(1.5))


def pickup_item(rng):
    z = am(bp(noise(0.3, rng), lambda t: 2000 + 2500 * t, 2), 60, 0.9)
    return mix((env(z, 0.01, 0.12), 0, 0.8), (thump(rng, 180, 0.02, 2000, 0.02), 0, 0.5), length=n(0.4))


def pickup_key(rng):
    j = tone_partials(0.4, [(2600, 0.4, 1), (3900, 0.3, 0.7), (5200, 0.2, 0.5)], 0.08, rng)
    return mix((j, 0, 1.0), (tone_partials(0.3, [(3100, 0.3, 1), (4700, 0.2, 0.6)], 0.06, rng), 0.07, 0.7),
               (click(rng, 1500, 0.01), 0, 0.6), length=n(0.4))


def door_open(rng):
    latch = mix((click(rng, 1400, 0.012), 0, 1.0), (thump(rng, 110, 0.05), 0.02, 0.8))
    wind = bell(lp(noise(0.8, rng), 1200), 0.3)
    return mix((latch, 0, 1.0), (creak(rng, 0.6, 150, 190), 0.1, 0.5), (wind, 0.15, 0.5), length=n(1.0))


def door_locked(rng):
    rattle = mix(*[(click(rng, 1200, 0.008), t, 0.8) for t in (0, 0.06, 0.12)])
    buzz = env(lp(square(0.3, 110), 1500), 0.005, 0.25, 0.15)
    return mix((rattle, 0, 1.0), (buzz, 0.15, 0.35), length=n(0.5))


def stairs(rng):
    return mix(*[(step_metal(rng), i * 0.17, 0.8 - i * 0.08) for i in range(5)], length=n(1.0))


def engine(rng, sec, f):
    s = lp(saw(sec, f, rng, 0.02), 600)
    rumble = am(lp(noise(sec, rng), 300), 14, 0.5)
    return mix((s, 0, 0.8), (rumble, 0, 0.5))


def generator_start(rng):
    sputters = mix(*[(thump(rng, 60, 0.06, 600, 0.06), t, 0.8) for t in (0, 0.35, 0.6, 0.8)])
    run = env(engine(rng, 2.0, lambda t: 45 + 10 * min(t, 0.5)), 0.2, 9, 2.0)
    return mix((sputters, 0, 1.0), (run, 1.0, 0.8), length=n(3.0))


def breaker_switch(rng):
    hum = env(lp(saw(0.5, 60), 400), 0.2, 2, 0.3)
    return mix((thump(rng, 120, 0.05, 2500, 0.03), 0, 1.0), (click(rng, 1600, 0.02), 0.01, 0.8), (hum, 0.05, 0.4),
               length=n(0.6))


def beep(f, sec):
    return env(lp(square(sec, f), 2500), 0.002, sec * 0.8, sec * 0.5)


def terminal_beep(rng):
    return mix((beep(880, 0.08), 0, 1.0), (beep(660, 0.1), 0.13, 1.0), length=n(0.4))


def radio_static(rng):
    st = am(bp(noise(1.5, rng), 1800, 0.8), 7, 0.5)
    garble = bp(am(saw(1.5, lambda t: 140 + 40 * math.sin(t * 9), rng, 0.05), 5, 0.9), 1000, 2)
    return bell(mix((st, 0, 0.8), (garble, 0, 0.3), (crackle(1.5, 50, rng, 3000, 0.002), 0, 0.5)), 0.1)


def radio_tune(rng):
    chirp = env(sine(0.12, lambda t: 1200 + 6000 * t), 0.002, 0.03)
    return mix((click(rng, 2000, 0.005), 0, 1.0), (chirp, 0.02, 0.3), (env(bp(noise(0.15, rng), 2000), 0.005, 0.04), 0.02, 0.3),
               length=n(0.2))


def soft_tone(sec, f, attack=0.03):
    s = mix((sine(sec, f), 0, 1.0), (sine(sec, f * 2.001), 0, 0.25), (sine(sec, f * 3), 0, 0.08))
    return env(s, attack, sec * 0.4)


def save_chime(rng):
    return mix((soft_tone(1.0, midi(57)), 0, 0.8), (soft_tone(0.9, midi(64)), 0.28, 0.7), length=n(1.2))


def snowcat_engine(rng):
    run = env(engine(rng, 3.0, lambda t: 35 + 25 * min(t / 2.0, 1.0)), 0.3, 9, 2.5)
    tracks = am(bp(noise(3.0, rng), 500, 1), 9, 0.8)
    return mix((run, 0, 1.0), (bell(tracks, 0.7), 0, 0.4))


def lift_machinery(rng):
    whine = env(sine(3.0, lambda t: 180 + 60 * min(t, 2)), 0.4, 9, 2.4)
    clanks = mix(*[(metal_hit(rng, 0.5, rng.uniform(300, 500)), t, 0.4) for t in (0.1, 0.7, 1.4, 2.0, 2.6)])
    return mix((whine, 0, 0.4), (engine(rng, 3.0, 50), 0, 0.4), (clanks, 0, 0.7), length=n(3.0))


def uplink_transmit(rng):
    rise = env(sine(2.0, lambda t: 300 + 600 * t), 0.2, 9, 1.8)
    chirps = mix(*[(env(square(0.05, rng.choice([1200, 1600, 2100, 2400])), 0.002, 0.03), 0.4 + i * 0.07, 0.25)
                   for i in range(20)])
    return mix((rise, 0, 0.5), (lp(chirps, 3000), 0, 1.0), (beep(1760, 0.25), 2.1, 0.8), length=n(2.5))


def voice(rng, sec, f0, f1, formants=(500, 1100), jitter=0.06, ice=60):
    v = saw(sec, lambda t: f0 + (f1 - f0) * t / sec, rng, jitter)
    v = mix((bp(v, formants[0], 3), 0, 1.0), (bp(v, formants[1], 4), 0, 0.6))
    return mix((v, 0, 1.0), (crackle(sec, ice, rng, 3000, 0.002), 0, 0.5))


def watcher_groan(rng):
    return bell(voice(rng, 1.4, rng.uniform(80, 100), rng.uniform(65, 80), (450, 900)), 0.3)


def watcher_attack(rng):
    return env(voice(rng, 0.6, 180, 140, (700, 1400), 0.1, 120), 0.02, 0.2)


def listener_click(rng):
    clicks = mix(*[(click(rng, rng.uniform(2500, 4000), 0.003), i * rng.uniform(0.03, 0.05), 1.0) for i in range(5)])
    return mix((clicks, 0, 1.0), length=n(0.3))


def listener_shriek(rng):
    s = sine(1.5, lambda t: 1700 + 300 * t + 60 * math.sin(t * 40))
    inharm = sine(1.5, lambda t: 2390 + 400 * t)
    hiss = bp(noise(1.5, rng), 3000, 2)
    return env(mix((s, 0, 0.7), (inharm, 0, 0.4), (hiss, 0, 0.4)), 0.04, 0.5, 0.4)


def sleeper_wake(rng):
    crack = crackle(1.0, 250, rng, 2500, 0.003)
    inhale = bell(bp(noise(0.6, rng), lambda t: 700 + 1200 * t, 2), 0.8)
    return mix((env(crack, 0.001, 0.4), 0, 1.0), (inhale, 0.7, 0.8), length=n(1.5))


def enemy_hurt(rng):
    hiss = env(bp(noise(0.5, rng), 2500, 1.5), 0.01, 0.15)
    return mix((hiss, 0, 0.8), (voice(rng, 0.4, 160, 120, (600, 1300)), 0, 0.5), (crackle(0.3, 200, rng), 0, 0.5))


def enemy_death(rng):
    groan = env(voice(rng, 1.0, 120, 60, (450, 900)), 0.02, 0.4)
    shatter = mix((glass(rng, 0.6, 10), 0, 0.5), (crackle(0.6, 300, rng, 2500, 0.003), 0, 0.8))
    return mix((groan, 0, 0.8), (shatter, 0.6, 0.8), (thump(rng, 70, 0.1), 0.6, 0.7), length=n(1.2))


def enemy_burn(rng):
    hiss = bell(hp(noise(1.0, rng), 2500), 0.2)
    screech = env(voice(rng, 0.9, 300, 380, (1000, 2200), 0.1, 40), 0.05, 0.4)
    return mix((hiss, 0, 0.7), (screech, 0, 0.6))


def bear_roar(rng):
    v = saw(2.0, lambda t: 70 + 25 * math.sin(t * 2.5), rng, 0.1)
    v = am(mix((bp(v, 350, 2), 0, 1.0), (bp(v, 800, 3), 0, 0.5)), 28, 0.5)
    glassy = env(sine(2.0, lambda t: 1500 - 200 * t), 0.3, 0.8)
    return bell(mix((v, 0, 1.0), (glassy, 0, 0.12), (crackle(2.0, 80, rng), 0, 0.4)), 0.3)


def bear_charge(rng):
    steps = mix(*[(thump(rng, 55, 0.08, 500, 0.06), i * 0.16, 1.0) for i in range(9)], length=n(1.5))
    huff = am(bp(noise(1.5, rng), 500, 1), 6, 0.9)
    return mix((steps, 0, 1.0), (huff, 0, 0.3))


def crystal_chord(sec, rng, root=220.0):
    fs = [root, root * 1.5, root * 2.0, root * 2.52, root * 3.0]
    parts = [(sine(sec, f * rng.uniform(0.998, 1.002)), 0, 0.3) for f in fs]
    return mix(*parts)


def well_pulse_charge(rng):
    c = crystal_chord(2.5, rng, 196.0)
    c = [s * (i / n(2.5)) ** 2 for i, s in enumerate(c)]
    return mix((am(c, 6, 0.5), 0, 1.0), (bell(lp(noise(2.5, rng), 400), 0.9), 0, 0.3))


def well_pulse_blast(rng):
    boom = env(sine(1.5, lambda t: 40 + 80 * math.exp(-t * 10)), 0.002, 0.4)
    return mix((boom, 0, 1.0), (env(lp(noise(1.0, rng), 1500), 0.002, 0.15), 0, 0.6), (glass(rng, 1.4, 20), 0.05, 0.6),
               length=n(1.5))


def well_crystal_crack(rng):
    return mix((crackle(1.0, 400, rng, 1500, 0.005), 0, 1.0), (thump(rng, 50, 0.2, 400, 0.1), 0, 0.8),
               (glass(rng, 1.0, 12), 0.1, 0.4), length=n(1.0))


def alert_sting(rng):
    stab = mix(*[(lp(saw(1.0, midi(m), rng, 0.004), 3500), 0, 0.3) for m in (69, 70, 76, 81)])
    stab = env(stab, 0.003, 0.25)
    hit = mix((metal_hit(rng, 1.0, 140), 0, 0.6), (thump(rng, 50, 0.15), 0, 1.0))
    return mix((stab, 0, 1.0), (hit, 0, 0.8))


def suspicious_sting(rng):
    s = sine(0.8, lambda t: 420 + 140 * t)
    s2 = sine(0.8, lambda t: 444 + 150 * t)
    return bell(mix((s, 0, 0.6), (s2, 0, 0.4), (bp(noise(0.8, rng), 1500, 6), 0, 0.2)), 0.6)


def ui_move(rng):
    return click(rng, 3200, 0.003)


def ui_confirm(rng):
    return mix((click(rng, 2500, 0.003), 0, 0.6), (env(sine(0.15, 660), 0.002, 0.04), 0.005, 0.7), length=n(0.2))


def ui_cancel(rng):
    return mix((click(rng, 1600, 0.003), 0, 0.6), (env(sine(0.15, 330), 0.002, 0.04), 0.005, 0.7), length=n(0.2))


def mission_complete(rng):
    chord = mix(*[(soft_tone(1.5, midi(m), 0.25), 0, 0.4) for m in (50, 57, 62, 65)])
    return chord


SFX = {
    "step_concrete": (step_concrete, 4), "step_snow": (step_snow, 4), "step_metal": (step_metal, 4),
    "player_hurt": (player_hurt, 3), "player_death": (player_death, 1), "shiver_breath": (shiver_breath, 2),
    "locker_open": (locker_open, 1), "locker_close": (locker_close, 1), "knock": (knock, 2),
    "flashlight_click": (flashlight_click, 1), "lighter_flick": (lighter_flick, 2),
    "pistol_shot": (pistol_shot, 3), "shotgun_shot": (shotgun_shot, 2), "gun_empty": (gun_empty, 1),
    "reload": (reload, 1), "knife_swing": (knife_swing, 2), "knife_hit": (knife_hit, 2),
    "bullet_hit_flesh": (bullet_hit_flesh, 3), "throw_whoosh": (throw_whoosh, 1), "stone_land": (stone_land, 3),
    "bottle_break": (bottle_break, 2), "molotov_ignite": (molotov_ignite, 1), "fire_loop": (fire_loop, 1),
    "extinguisher_spray": (extinguisher_spray, 1), "extinguisher_clang": (extinguisher_clang, 1),
    "wood_break": (wood_break, 2), "drum_ignite": (drum_ignite, 1), "pickup_item": (pickup_item, 2),
    "pickup_key": (pickup_key, 1), "door_open": (door_open, 2), "door_locked": (door_locked, 1),
    "stairs": (stairs, 1), "generator_start": (generator_start, 1), "breaker_switch": (breaker_switch, 1),
    "terminal_beep": (terminal_beep, 1), "radio_static": (radio_static, 2), "radio_tune": (radio_tune, 1),
    "save_chime": (save_chime, 1), "snowcat_engine": (snowcat_engine, 1), "lift_machinery": (lift_machinery, 1),
    "uplink_transmit": (uplink_transmit, 1), "watcher_groan": (watcher_groan, 3), "watcher_attack": (watcher_attack, 2),
    "listener_click": (listener_click, 3), "listener_shriek": (listener_shriek, 1), "sleeper_wake": (sleeper_wake, 2),
    "enemy_hurt": (enemy_hurt, 3), "enemy_death": (enemy_death, 2), "enemy_burn": (enemy_burn, 2),
    "bear_roar": (bear_roar, 2), "bear_charge": (bear_charge, 1), "well_pulse_charge": (well_pulse_charge, 1),
    "well_pulse_blast": (well_pulse_blast, 1), "well_crystal_crack": (well_crystal_crack, 1),
    "alert_sting": (alert_sting, 1), "suspicious_sting": (suspicious_sting, 1), "ui_move": (ui_move, 1),
    "ui_confirm": (ui_confirm, 1), "ui_cancel": (ui_cancel, 1), "mission_complete": (mission_complete, 1),
}
LOOP_SFX = {"fire_loop"}


# ── 環境音 ────────────────────────────────────────────

AMB_LEN = 32.0


def gusts(sec, rng, base=500, depth=900):
    lfo = [(math.sin(TAU * i / SR / 9.0) + math.sin(TAU * i / SR / 4.3 + 1) * 0.5) for i in range(n(sec))]
    w = bp(noise(sec, rng), lambda t: base + depth * (0.5 + 0.35 * math.sin(TAU * t / 9.0)), 0.7)
    return [s * (0.55 + 0.3 * l) for s, l in zip(w, lfo)]


def drips(sec, rng, count, f0=900, f1=1800):
    return mix(*[(env(sine(0.2, lambda t, f=rng.uniform(f0, f1): f * (1 + 0.5 * math.exp(-t * 60))), 0.001, 0.03),
                  rng.uniform(0, sec - 0.3), rng.uniform(0.3, 1.0)) for _ in range(count)], length=n(sec))


def amb_blizzard(rng):
    x = mix((gusts(AMB_LEN + 2, rng), 0, 1.0), (hp(noise(AMB_LEN + 2, rng), 3000), 0, 0.12),
            (lp(noise(AMB_LEN + 2, rng), 150), 0, 0.5))
    return make_loop(x, 2.0)


def amb_station_hum(rng):
    L = AMB_LEN + 2
    hum = mix((sine(L, 60), 0, 0.5), (sine(L, 120), 0, 0.3), (sine(L, 180), 0, 0.1))
    vent = lp(noise(L, rng), 500)
    buzz = gain(bp(saw(L, 120), 2400, 6), 0.05)
    ticks = mix(*[(click(rng, 1500, 0.01), rng.uniform(0, L - 1), 0.15) for _ in range(6)], length=n(L))
    return make_loop(mix((hum, 0, 0.6), (vent, 0, 0.5), (buzz, 0, 1.0), (ticks, 0, 1.0)), 2.0)


def amb_station_dark(rng):
    L = AMB_LEN + 2
    wind = lp(gusts(L, rng, 250, 300), 700)
    creaks = mix(*[(creak(rng, 1.2, rng.uniform(90, 140), rng.uniform(100, 160)), rng.uniform(0, L - 2), 0.15)
                   for _ in range(4)], length=n(L))
    ice = crackle(L, 1.5, rng, 2000, 0.003)
    return make_loop(mix((wind, 0, 1.0), (creaks, 0, 1.0), (drips(L, rng, 10), 0, 0.15), (ice, 0, 0.2)), 2.0)


def amb_shaft(rng):
    L = AMB_LEN + 2
    rumble = lp(noise(L, rng), 90)
    tones = mix(*[(bell(sine(4.0, rng.choice([392, 466, 587, 698])), 0.5), rng.uniform(0, L - 4), 0.05)
                  for _ in range(5)], length=n(L))
    return make_loop(mix((rumble, 0, 1.0), (drips(L, rng, 14, 600, 1300), 0, 0.2), (tones, 0, 1.0)), 2.0)


AMBIENCE = {"amb_blizzard": amb_blizzard, "amb_station_hum": amb_station_hum,
            "amb_station_dark": amb_station_dark, "amb_shaft": amb_shaft}


# ── 音樂 ──────────────────────────────────────────────
# 暫代用：低音長音＋慢慢起伏的和聲墊＋零星的鋼琴音，追逐和 Boss 加上節奏。

def pad(sec, notes, rng, cutoff=900, detune=0.004):
    parts = []
    for m in notes:
        f = midi(m)
        for d in (-detune, detune):
            parts.append((saw(sec, f * (1 + d)), 0, 0.18))
    x = lp(mix(*parts, length=n(sec)), cutoff)
    return [s * (0.65 + 0.35 * math.sin(TAU * i / SR / 11.0)) for i, s in enumerate(x)]


def drone(sec, m, rng):
    f = midi(m)
    return mix((sine(sec, f), 0, 0.6), (sine(sec, f * 1.003), 0, 0.4), (lp(saw(sec, f / 2), 200), 0, 0.3))


def sparse_piano(sec, rng, notes, count, vol=0.3):
    return mix(*[(piano(3.0, midi(rng.choice(notes))), rng.uniform(0, sec - 3.5), vol) for _ in range(count)],
               length=n(sec))


def kick(rng):
    return env(sine(0.4, lambda t: 50 + 90 * math.exp(-t * 35)), 0.001, 0.12)


def music_title(rng):
    L = 50.0
    x = mix((drone(L, 38, rng), 0, 0.5), (pad(L, [50, 57, 62], rng, 700), 0, 0.6),
            (lp(gusts(L, rng, 400, 500), 1500), 0, 0.15),
            (sparse_piano(L, rng, [62, 65, 69, 70, 74], 10, 0.35), 0, 1.0),
            (bell(sine(8, 1568), 0.5), 20, 0.03))
    return make_loop(x, 3.0)


def music_explore_station(rng):
    L = 50.0
    x = mix((drone(L, 33, rng), 0, 0.6), (lp(noise(L, rng), 300), 0, 0.15),
            (sparse_piano(L, rng, [57, 58, 63, 64], 5, 0.2), 0, 1.0),
            (mix(*[(creak(rng, 1.5, 100, 130), rng.uniform(0, L - 2), 0.12) for _ in range(3)], length=n(L)), 0, 1.0))
    return make_loop(x, 3.0)


def music_explore_outdoor(rng):
    L = 50.0
    x = mix((drone(L, 26, rng), 0, 0.7), (pad(L, [45, 52, 59], rng, 500), 0, 0.4),
            (bell(bp(noise(L, rng), 1200, 3), 0.5), 0, 0.15))
    return make_loop(x, 3.0)


def music_safe_room(rng):
    L = 48.0
    chords = [[48, 55, 64], [45, 52, 60], [41, 48, 57], [43, 50, 59]]
    seg = L / len(chords)
    x = mix(*[(bell(pad(seg + 2, c, rng, 600, 0.002), 0.3), i * seg, 0.7) for i, c in enumerate(chords)],
            (sparse_piano(L, rng, [64, 67, 69, 72, 76], 12, 0.3), 0, 1.0), length=n(L + 2))
    return make_loop(x, 2.0)


def music_chase(rng):
    bpm = 120.0
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    kicks = mix(*[(kick(rng), i * beat, 1.0) for i in range(bars * 4)], length=n(L))
    hats = mix(*[(env(hp(noise(0.05, rng), 6000), 0.0005, 0.015), i * beat / 2 + beat / 4, 0.25)
                 for i in range(bars * 8)], length=n(L))
    seq = [45, 45, 46, 45, 48, 45, 46, 44]
    osti = mix(*[(env(lp(saw(0.2, midi(seq[i % len(seq)]), rng, 0.003), 1800), 0.003, 0.07), i * beat / 2, 0.35)
                 for i in range(bars * 8)], length=n(L))
    hits = mix(*[(metal_hit(rng, 1.0, 150), b * 4 * beat, 0.3) for b in range(0, bars, 2)], length=n(L))
    riser = [s * (0.3 + 0.7 * ((i / SR) % (8 * beat)) / (8 * beat)) for i, s in enumerate(drone(L, 33, rng))]
    return mix((kicks, 0, 1.0), (hats, 0, 1.0), (osti, 0, 1.0), (hits, 0, 1.0), (riser, 0, 0.4))


def music_boss_bear(rng):
    bpm = 100.0
    beat = 60.0 / bpm
    bars = 16
    L = bars * 4 * beat
    pattern = [0, 1.5, 2, 3, 3.5]
    drums = mix(*[(kick(rng), (b * 4 + p) * beat, 1.0 if p in (0, 2) else 0.6)
                  for b in range(bars) for p in pattern], length=n(L))
    toms = mix(*[(bp(thump(rng, 120, 0.1, 900, 0.08), 200, 1.5), (b * 4 + 2.5) * beat, 0.7) for b in range(bars)],
               length=n(L))
    stabs = mix(*[(env(lp(saw(1.5, midi(m), rng, 0.01), 900), 0.01, 0.4), b * 4 * beat, 0.4)
                  for b, m in zip(range(0, bars, 2), [33, 33, 34, 31, 33, 33, 36, 34])], length=n(L))
    return mix((drums, 0, 1.0), (toms, 0, 1.0), (stabs, 0, 1.0), (drone(L, 28, rng), 0, 0.3))


def music_boss_well(rng):
    beat = 0.75
    bars = 16
    L = bars * 4 * beat
    swell = crystal_chord(L, rng, 196.0)
    swell = [s * (0.4 + 0.6 * (0.5 + 0.5 * math.sin(TAU * i / SR / (8 * beat)))) for i, s in enumerate(swell)]
    hits = mix(*[(well_pulse_blast(rng), b * 4 * beat, 0.35) for b in range(0, bars, 2)], length=n(L))
    perc = mix(*[(kick(rng), (b * 4 + p) * beat, 0.6) for b in range(bars // 2, bars) for p in (0, 1, 2, 3)],
               length=n(L))
    return mix((swell, 0, 0.6), (hits, 0, 1.0), (perc, 0, 1.0), (drone(L, 31, rng), 0, 0.4))


def music_ending(rng):
    L = 50.0
    melody = [62, 65, 69, 67, 65, 62, 60, 62]
    notes = mix(*[(piano(4.0, midi(m)), 2 + i * 4.5, 0.4) for i, m in enumerate(melody)], length=n(L))
    x = mix((pad(L, [50, 57, 65], rng, 600), 0, 0.5), (notes, 0, 1.0), (bell(sine(10, 1568), 0.5), 34, 0.03))
    return [s * min(1.0, (L - i / SR) / 8.0) for i, s in enumerate(x)]


MUSIC = {"title": music_title, "explore_station": music_explore_station, "explore_outdoor": music_explore_outdoor,
         "safe_room": music_safe_room, "chase": music_chase, "boss_bear": music_boss_bear,
         "boss_well": music_boss_well, "ending": music_ending}


def main():
    only = set(sys.argv[1:])
    for id_, (fn, count) in SFX.items():
        if only and id_ not in only:
            continue
        for v in range(count):
            rng = random.Random(f"{id_}:{v}")
            name = id_ if count == 1 else f"{id_}_{v + 1}"
            write("sfx", name, fn(rng), loop=id_ in LOOP_SFX)
        print("sfx", id_)
    for id_, fn in AMBIENCE.items():
        if only and id_ not in only:
            continue
        write("ambience", id_, fn(random.Random(id_)), loop=True)
        print("ambience", id_)
    for id_, fn in MUSIC.items():
        if only and id_ not in only:
            continue
        write("music", id_, fn(random.Random(id_)), loop=id_ != "ending")
        print("music", id_)


if __name__ == "__main__":
    main()
