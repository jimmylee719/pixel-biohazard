#!/usr/bin/env python3
"""程式合成的暫代音效／音樂／環境音（只用 Python 標準函式庫）。

輸出到 assets/audio/synth/{sfx,music,ambience}/<id>.wav（有多個版本就是 <id>_1.wav…）。
遊戲先找 assets/audio/{sfx,music,ambience}/ 的正式素材，找不到才用這裡的暫代版，
所以之後放進正式素材就會自動取代，不用刪這些檔案。

格式：音效 44100 Hz（v0.16 起，暫態比較清楚）、音樂和環境音 22050 Hz，16 位元。音效是單聲道（遊戲裡用 2D 定位播放）；音樂和環境音是立體聲。
音樂、環境音都調到同一個響度（RMS 約 -17 dBFS，比音效小聲），遊戲裡的相對音量在 sound_list.gd 調。
音樂全部圍繞同一個「訊號動機」寫（見 MOTIF），循環的檔案頭尾接得起來（見「立體聲引擎」的說明）。

執行：python3 tools/synth_audio.py            （全部，多核心一起算，約半分鐘到一分鐘）
      python3 tools/synth_audio.py pistol_shot title  （只做指定的 id）
      SYNTH_DEBUG=1 python3 tools/synth_audio.py title （印出每個聲部佔多少音量，調混音用）
      SYNTH_AUDIO_OUT=/tmp/x python3 tools/synth_audio.py （輸出到別的資料夾，試聽用）
做完要跑一次 Godot --import。
"""
import array
import math
import os
import random
import struct
import sys
import wave

SR = 22050
ROOT = os.environ.get("SYNTH_AUDIO_OUT") or os.path.join(os.path.dirname(__file__), "..", "assets", "audio", "synth")
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
    """把尾巴交叉淡入到開頭，做成無縫循環（等功率，雜訊類的聲音中間才不會變小聲）"""
    k = n(xfade)
    body = x[:-k]
    tail = x[-k:]
    h = math.pi / 2 / k
    for i in range(k):
        body[i] = body[i] * math.sin(i * h) + tail[i] * math.cos(i * h)
    return body


def _pcm(x):
    a = array.array("h", [int(max(-1.0, min(1.0, s)) * 32767) for s in x])
    if sys.byteorder == "big":
        a.byteswap()
    return a


def write(folder, name, x, loop=False):
    """單聲道（音效）：去掉直流、峰值調到 0.89、頭尾淡入淡出"""
    path = os.path.join(ROOT, folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    dc = sum(x) / max(len(x), 1)
    x = normalize([s - dc for s in x])
    if not loop:
        x = fade(x)
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(_pcm(x).tobytes())


def write_stereo(folder, name, lr):
    """立體聲（音樂、環境音）：響度和限幅已經在 master() 做好，這裡只寫檔"""
    path = os.path.join(ROOT, folder, name + ".wav")
    os.makedirs(os.path.dirname(path), exist_ok=True)
    l, r = _pcm(lr[0]), _pcm(lr[1])
    frames = array.array("h", bytes(4 * len(l)))
    frames[0::2] = l
    frames[1::2] = r
    with wave.open(path, "wb") as w:
        w.setnchannels(2)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(frames.tobytes())


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


def punch_hit(rng):
    return mix((thump(rng, 120, 0.05, 1600, 0.04), 0, 1.0), (crackle(0.15, 120, rng, 3500, 0.002), 0, 0.3),
               length=n(0.3))


def kick_hit(rng):
    return mix((thump(rng, 80, 0.08, 1200, 0.06), 0, 1.0), (env(bp(noise(0.3, rng), 700, 1.5), 0.01, 0.08), 0.03, 0.5),
               length=n(0.4))


def body_slam(rng):
    rattle = mix(*[(click(rng, rng.uniform(1500, 3000), 0.01), rng.uniform(0.03, 0.2), 0.4) for _ in range(6)])
    return mix((thump(rng, 55, 0.12, 900, 0.1), 0, 1.0), (rattle, 0, 1.0), length=n(0.7))


def grab(rng):
    rustle = bell(bp(noise(0.35, rng), 1500, 0.8), 0.3)
    return mix((rustle, 0, 0.8), (thump(rng, 150, 0.03, 1500, 0.03), 0.05, 0.5),
               (bell(bp(noise(0.3, rng), 600, 2), 0.6), 0.1, 0.4), length=n(0.4))


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


def radio_tune(rng):
    chirp = env(sine(0.12, lambda t: 1200 + 6000 * t), 0.002, 0.03)
    return mix((click(rng, 2000, 0.005), 0, 1.0), (chirp, 0.02, 0.3), (env(bp(noise(0.15, rng), 2000), 0.005, 0.04), 0.02, 0.3),
               length=n(0.2))


def snowcat_engine(rng):
    run = env(engine(rng, 3.0, lambda t: 35 + 25 * min(t / 2.0, 1.0)), 0.3, 9, 2.5)
    tracks = am(bp(noise(3.0, rng), 500, 1), 9, 0.8)
    return mix((run, 0, 1.0), (bell(tracks, 0.7), 0, 0.4))


def lift_machinery(rng):
    whine = env(sine(3.0, lambda t: 180 + 60 * min(t, 2)), 0.4, 9, 2.4)
    clanks = mix(*[(metal_hit(rng, 0.5, rng.uniform(300, 500)), t, 0.4) for t in (0.1, 0.7, 1.4, 2.0, 2.6)])
    return mix((whine, 0, 0.4), (engine(rng, 3.0, 50), 0, 0.4), (clanks, 0, 0.7), length=n(3.0))


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


def ui_move(rng):
    return click(rng, 3200, 0.003)


def ui_confirm(rng):
    return mix((click(rng, 2500, 0.003), 0, 0.6), (env(sine(0.15, 660), 0.002, 0.04), 0.005, 0.7), length=n(0.2))


def ui_cancel(rng):
    return mix((click(rng, 1600, 0.003), 0, 0.6), (env(sine(0.15, 330), 0.002, 0.04), 0.005, 0.7), length=n(0.2))


# ── 立體聲引擎（音樂、環境音用） ─────────────────────────
# 做法：每個音符／鼓點各自算好（短的 list），用 Mixer 疊到左右聲道，另外送一份到殘響和延遲；
# 最後把超過循環長度的尾巴折回開頭（殘響、餘音繞一圈接回去 = 無縫循環），再做響度和柔性限幅。
# 會一直響的底層（長音、風）一律做成「在循環長度內剛好整數個週期」，所以接點不會喀一聲。

TAB = 2048
MASK = TAB - 1
CTRL = 32  # 濾波器截止頻率每幾個樣本更新一次
_TABS = {}
_KS = (1, 2, 3, 4, 6, 8, 12, 16, 24, 32, 48, 64, 96)
_CACHE = {}


def cached(fn):
    """同樣參數的音符只算一次（參數要能當 dict 的 key）"""
    def wrap(*a):
        key = (fn.__name__,) + a
        if key not in _CACHE:
            _CACHE[key] = fn(*a)
        return _CACHE[key]
    wrap.__name__ = fn.__name__
    return wrap


def _amp(shape, h):
    if shape == "saw":
        return 1.0 / h
    if shape == "square":
        return 1.0 / h if h % 2 else 0.0
    if shape == "tri":
        return ((-1) ** (h // 2)) / (h * h) if h % 2 else 0.0
    if shape == "soft":  # 泛音掉得快：柔和的墊底音
        return 1.0 / h ** 1.7
    if shape == "piano":  # 偶數泛音弱一點
        return (0.7 if h % 2 == 0 else 1.0) / h ** 1.15
    if shape == "reed":  # 奇數泛音為主，有一點鼻音
        return (1.0 if h % 2 else 0.35) / h ** 1.3
    raise ValueError(shape)


def table(shape, freq):
    """限頻寬的波表：泛音只加到奈奎斯特頻率以下，所以高音不會有混疊雜音"""
    kmax = max(1, int(SR * 0.45 / freq))
    k = max(v for v in _KS if v <= kmax)
    key = (shape, k)
    t = _TABS.get(key)
    if t is None:
        t = [0.0] * TAB
        for h in range(1, k + 1):
            a = _amp(shape, h)
            if a:
                w = TAU * h / TAB
                t = [v + a * math.sin(w * i) for i, v in enumerate(t)]
        peak = max(abs(v) for v in t)
        t = [v / peak for v in t]
        _TABS[key] = t
    return t


def osc(shape, freq, N, ph=0.0):
    t = table(shape, freq)
    inc = freq * TAB / SR
    p0 = ph * TAB
    return [t[int(p0 + i * inc) & MASK] for i in range(N)]


def osc_vib(shape, freq, N, rate, depth, ph=0.0):
    """有抖音的振盪器。depth = 音高偏移比例（0.004 = ±0.4%）"""
    t = table(shape, freq * (1 + depth))
    inc = freq * TAB / SR
    p0 = ph * TAB
    vd = depth * freq * TAB / (TAU * rate)
    vw = TAU * rate / SR
    sin = math.sin
    return [t[int(p0 + i * inc + vd * sin(i * vw)) & MASK] for i in range(N)]


def sinw(freq, N, ph=0.0):
    w = TAU * freq / SR
    sin = math.sin
    return [sin(w * i + ph) for i in range(N)]


def mul(x, e):
    return [a * b for a, b in zip(x, e)]


def add2(x, y):
    return [a + b for a, b in zip(x, y)]


def qf(freq, sec):
    """把頻率微調成「sec 秒內剛好整數個週期」（循環的底層音用）"""
    return max(1, round(freq * sec)) / sec


def adsr(N, a=0.01, d=0.2, s=0.7, r=0.3):
    """N = 總樣本數（含 release）。a 線性上升、d 指數掉到 s、最後 r 秒平滑收到 0"""
    R = max(1, min(n(r), N - 1))
    G = N - R
    A = max(1, min(n(a), G))
    k = 3.0 / max(1.0, d * SR)
    e = [i / A for i in range(A)]
    e += [s + (1 - s) * math.exp(-k * i) for i in range(G - A)]
    last = e[-1]
    e += [last * (1 - j / R) ** 2 for j in range(R)]
    return e


def swell(N, a, r):
    """緩起緩收的包絡（餘弦曲線），a、r 是秒"""
    A = max(1, min(n(a), N // 2))
    R = max(1, min(n(r), N - A))
    e = [0.5 - 0.5 * math.cos(math.pi * i / A) for i in range(A)]
    e += [1.0] * (N - A - R)
    e += [0.5 + 0.5 * math.cos(math.pi * j / R) for j in range(R)]
    return e


def svf(x, fc, q=0.707, mode="lp"):
    """狀態變數濾波器（有共振、截止頻率可以隨時間變）。fc：數字，或每 CTRL 個樣本一個值的 list"""
    qd = 1.0 / q
    out = []
    ap = out.append
    low = band = 0.0
    lim = SR / 6.5
    for c, s0 in enumerate(range(0, len(x), CTRL)):
        f0 = fc[min(c, len(fc) - 1)] if isinstance(fc, list) else fc
        f = 2 * math.sin(math.pi * min(max(f0, 20.0), lim) / SR)
        if mode == "lp":
            for v in x[s0:s0 + CTRL]:
                low += f * band
                band += f * (v - low - qd * band)
                ap(low)
        elif mode == "bp":
            for v in x[s0:s0 + CTRL]:
                low += f * band
                band += f * (v - low - qd * band)
                ap(band)
        else:
            for v in x[s0:s0 + CTRL]:
                low += f * band
                high = v - low - qd * band
                band += f * high
                ap(high)
    return out


def ctrl_curve(N, fn):
    """給 svf 用的截止頻率曲線：fn(0~1) → Hz"""
    c = max(1, (N + CTRL - 1) // CTRL)
    return [fn(i / c) for i in range(c)]


def biquad(x, kind, f, q=0.707):
    w = TAU * min(f, SR * 0.45) / SR
    cs, al = math.cos(w), math.sin(w) / (2 * q)
    if kind == "lp":
        b0 = b2 = (1 - cs) / 2
        b1 = 1 - cs
    elif kind == "hp":
        b0 = b2 = (1 + cs) / 2
        b1 = -(1 + cs)
    else:  # bp，峰值增益 1
        b0, b1, b2 = al, 0.0, -al
    a0 = 1 + al
    b0, b1, b2, a1, a2 = b0 / a0, b1 / a0, b2 / a0, -2 * cs / a0, (1 - al) / a0
    out = []
    ap = out.append
    x1 = x2 = y1 = y2 = 0.0
    for s in x:
        y = b0 * s + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2
        x2, x1, y2, y1 = x1, s, y1, y
        ap(y)
    return out


def drive(x, g):
    """柔性失真（tanh）"""
    th = math.tanh
    k = 1.0 / th(g)
    return [th(v * g) * k for v in x]


def xfade_loop(x, k):
    """x 比循環長度多 k 個樣本：把多出來的尾巴等功率交叉淡入開頭 → 無縫循環（雜訊類用）"""
    L = len(x) - k
    out = x[:L]
    h = math.pi / 2 / k
    for i in range(k):
        out[i] = x[i] * math.sin(i * h) + x[L + i] * math.cos(i * h)
    return out


def _comb(x, D, fb, damp):
    """回授梳狀濾波器（回授路徑有低通）。一次算一整段（長度 D），比逐樣本快很多"""
    c1, c2 = fb * (1 - damp), fb * damp
    y = [0.0] * (D + 1)
    N = len(x)
    for s in range(0, N, D):
        B = min(D, N - s)
        y.extend([xv + c1 * a + c2 * b for xv, a, b in zip(x[s:s + B], y[s + 1:s + 1 + B], y[s:s + B])])
    return y[D + 1:]


def _allpass(x, D, g=0.5):
    xp = [0.0] * D + x
    y = [0.0] * D
    N = len(x)
    for s in range(0, N, D):
        B = min(D, N - s)
        y.extend([xd - g * xv + g * yd for xv, xd, yd in zip(x[s:s + B], xp[s:s + B], y[s:s + B])])
    return y[D:]


_COMBS = (557, 593, 641, 677, 743, 809)
_APS = (277, 223, 173)


def reverb(x, rt=2.0, damp=0.3, size=1.0, spread=0):
    """Schroeder 殘響：6 個梳狀 + 3 個全通。rt = 衰減 60 dB 的秒數；左右聲道用不同的 spread"""
    acc = None
    for D0 in _COMBS:
        D = int(D0 * size * SR / 22050) + spread
        y = _comb(x, D, 10 ** (-3.0 * D / (SR * rt)), damp)
        acc = y if acc is None else add2(acc, y)
    acc = [v * 0.22 for v in acc]
    for D0 in _APS:
        acc = _allpass(acc, int(D0 * size * SR / 22050) + spread)
    return acc


def room(x, rt=0.35, wet=0.25, tail=0.3):
    """單聲道的小房間回音（音效用）：短殘響＋原音"""
    dry = x + [0.0] * n(tail)
    w = lp(reverb(hp(dry, 250), rt, 0.5, 0.6), 4500)
    return [a + wet * b for a, b in zip(dry, w)]


def tape(x, depth=0.0012, flutter=0.0003, wow_hz=0.5, flutter_hz=6.3):
    """磁帶的音高晃動（wow/flutter）：用會變的延遲讀取。頻率請給「循環長度內整數個週期」的值"""
    A1 = depth * SR / (TAU * wow_hz)
    A2 = flutter * SR / (TAU * flutter_hz)
    base = A1 + A2 + 2
    w1, w2 = TAU * wow_hz / SR, TAU * flutter_hz / SR
    sin = math.sin
    out = []
    ap = out.append
    for i in range(len(x)):
        p = i - base - A1 * sin(w1 * i) - A2 * sin(w2 * i)
        if p < 0:
            ap(0.0)
        else:
            j = int(p)
            fr = p - j
            ap(x[j] * (1 - fr) + x[j + 1] * fr)
    return out


def _acc(buf, o, sig, g):
    e = o + len(sig)
    if e > len(buf):
        e = len(buf)
        sig = sig[:e - o]
    if o < e:
        buf[o:e] = [a + g * b for a, b in zip(buf[o:e], sig)]


def softclip(x, g=1.0, t=0.5, c=0.89):
    """柔性限幅：|x| < t 不動，超過的部分用 tanh 壓到 c 以下（絕對不會破音）"""
    k = c - t
    th = math.tanh
    out = []
    ap = out.append
    for s in x:
        v = s * g
        if v > t:
            v = t + k * th((v - t) / k)
        elif v < -t:
            v = -t - k * th((-v - t) / k)
        ap(v)
    return out


DEBUG = bool(os.environ.get("SYNTH_DEBUG"))


class Mixer:
    """立體聲混音：add() 疊聲音、render() 加延遲與殘響、折回尾巴、調響度"""

    def __init__(self, length, tail=6.0):
        self.L = int(round(length * SR))
        self.N = self.L + n(tail)
        self.l = [0.0] * self.N
        self.r = [0.0] * self.N
        self.sl = [0.0] * self.N  # 送殘響
        self.sr = [0.0] * self.N
        self.d = [0.0] * self.N  # 送延遲
        self.stems = {}

    def add(self, sig, t=0.0, g=1.0, pan=0.0, rev=0.0, dly=0.0, name=""):
        """sig：單聲道 list 或 (左, 右)。pan −1 左 ~ +1 右。rev／dly = 送到殘響／延遲的比例"""
        o = int(round(t * SR))
        if isinstance(sig, tuple):
            L, R = sig
            a = (pan + 1) * math.pi / 4
            gl, gr = g * math.cos(a) * 1.414, g * math.sin(a) * 1.414
        else:
            L = R = sig
            a = (pan + 1) * math.pi / 4
            gl, gr = g * math.cos(a), g * math.sin(a)
        _acc(self.l, o, L, gl)
        _acc(self.r, o, R, gr)
        if rev:
            _acc(self.sl, o, L, gl * rev)
            _acc(self.sr, o, R, gr * rev)
        if dly:
            _acc(self.d, o, L, g * dly)
        if DEBUG and name:
            wl = hp(hp(L, 300), 300)  # 大約是人耳的敏感度（低頻算少一點）
            wr = wl if R is L else hp(hp(R, 300), 300)
            e = sum(v * v for v in wl) * gl * gl + sum(v * v for v in wr) * gr * gr
            self.stems[name] = self.stems.get(name, 0.0) + e

    def render(self, rt=2.5, damp=0.35, size=1.0, wet=1.0, predelay=0.02, dtime=0.0, dfb=0.5, dtaps=5,
               loop=True, level=-19.0, tape_fx=None, fade_out=0.0):
        if DEBUG and self.stems:
            tot = sum(self.stems.values()) or 1.0
            for k, v in sorted(self.stems.items(), key=lambda kv: -kv[1]):
                print("    stem %-12s %6.1f dB" % (k, 10 * math.log10(v / tot + 1e-12)))
        l, r, sl, sr = self.l, self.r, self.sl, self.sr
        if dtime:  # 左右來回的延遲
            d = lp(self.d, 2600)
            D = int(round(dtime * SR))
            for k in range(1, dtaps + 1):
                g = 0.7 * dfb ** (k - 1)
                a, b, sa, sb = (l, r, sl, sr) if k % 2 else (r, l, sr, sl)
                _acc(a, k * D, d, g)
                _acc(b, k * D, d, g * 0.25)
                _acc(sa, k * D, d, g * 0.4)
        if wet:
            pd = n(predelay)
            xl = hp([a + 0.3 * b for a, b in zip(sl, sr)], 180)
            xr = hp([a + 0.3 * b for a, b in zip(sr, sl)], 180)
            _acc(l, pd, reverb(xl, rt, damp, size, 0), wet)
            _acc(r, pd, reverb(xr, rt, damp, size, 13), wet)
        if tape_fx:
            l = tape(l, *tape_fx)
            r = tape(r, *tape_fx)
        if loop:
            k = min(n(0.25), self.N - self.L)  # 緩衝區最後一小段淡出，折回去才不會有斷點
            for buf in (l, r):
                for i in range(k):
                    buf[self.N - 1 - i] *= i / k
                t = buf[self.L:]
                buf[:len(t)] = add2(buf[:len(t)], t)
                del buf[self.L:]
        else:
            l, r = l[:self.L], r[:self.L]
            k = n(fade_out)
            for buf in (l, r):
                for i in range(min(k, len(buf))):
                    buf[len(buf) - 1 - i] *= (i / k) ** 2
        return master(l, r, level)


def master(l, r, level=-19.0):
    """去掉直流、把響度（RMS，dBFS）調到同一個水準、柔性限幅"""
    N = len(l)
    ml, mr = sum(l) / N, sum(r) / N
    l = [v - ml for v in l]
    r = [v - mr for v in r]
    # 量響度時先把很低的頻率算少一點（150 Hz 高通），不然低音長音多的曲子其他聲部會被壓得太小聲
    rms = math.sqrt((sum(v * v for v in hp(l, 150)) + sum(v * v for v in hp(r, 150))) / (2 * N)) or 1.0
    g = 10 ** (level / 20) / rms
    if DEBUG:
        over = sum(1 for v in l if abs(v) * g > 0.5) / N
        print("    gain %.1f dB, %.2f%% of samples in the limiter" % (20 * math.log10(g), over * 100))
    return softclip(l, g), softclip(r, g)


def bar_grid(bpm, beats=4):
    beat = 60.0 / bpm
    return beat, beat * beats, beat / 4


# ── 樂器 ──────────────────────────────────────────────

@cached
def v_piano(m, dur, bright=1.0):
    """毛氈鋼琴：兩條微微走音的弦，亮度和音量各自衰減，開頭一點琴槌的悶聲"""
    f = midi(m)
    N = n(dur)
    x = add2(osc("piano", f * 0.9993, N), osc("piano", f * 1.0012, N, 0.31))
    top = min(3300.0, f * 7 * bright)
    base = min(1200.0, max(260.0, f * 1.3))
    kb = CTRL / (SR * (0.22 + 60.0 / f * 0.25))
    x = svf(x, [base + top * math.exp(-i * kb) for i in range(N // CTRL + 1)], 0.8)
    scale = (220.0 / f) ** 0.35
    k1, k2 = 1 / (0.45 * scale * SR), 1 / (2.6 * scale * SR)
    A = n(0.004)
    R = min(n(0.25), N // 3)
    exp = math.exp
    e = [(0.65 * exp(-i * k1) + 0.35 * exp(-i * k2)) * min(1.0, i / A) for i in range(N)]
    for j in range(R):
        e[N - 1 - j] *= j / R
    x = mul(x, e)
    rng = random.Random(m)
    th = env(lp([rng.uniform(-1, 1) for _ in range(n(0.03))], 900), 0.001, 0.008)
    _acc(x, 0, th, 0.5)
    return [v * 0.5 for v in x]


@cached
def v_ep(m, dur, vel=1.0):
    """FM 電鋼琴：溫暖、圓，敲下去有一點金屬的亮點"""
    f = midi(m)
    N = n(dur)
    w = TAU * f / SR
    I0 = 1.9 * vel * min(1.0, 300.0 / f)
    kI = 1 / (0.5 * SR)
    sin, exp = math.sin, math.exp
    x = [sin(w * i + I0 * exp(-i * kI) * sin(w * i)) for i in range(N)]
    T = min(N, n(0.25))
    kt = 1 / (0.05 * SR)
    tine = [0.18 * vel * sin(w * 5.02 * i) * exp(-i * kt) for i in range(T)]
    _acc(x, 0, tine, 1.0)
    return mul(x, adsr(N, 0.003, 1.4, 0.12, min(0.3, dur * 0.3)))


@cached
def v_glass(m, dur, attack=0.08, sus=0.35):
    """玻璃／水晶的「歌聲」：純音加一點泛音，兩個頻率差一點點所以會慢慢拍動"""
    f = midi(m)
    N = n(dur)
    w = TAU * f / SR
    sin = math.sin
    x = [sin(w * i) + 0.6 * sin(w * 1.003 * i + 1.0) + 0.22 * sin(w * 2.0 * i) + 0.07 * sin(w * 3.01 * i + 2.0)
         for i in range(N)]
    return [v * 0.5 for v in mul(x, adsr(N, attack, dur * 0.5, sus, min(1.5, dur * 0.4)))]


@cached
def v_bass(m, dur, cut=900.0, q=1.4):
    """低音脈衝：鋸齒＋方波＋正弦，濾波器一開就關（咚一下）"""
    f = midi(m)
    N = n(dur)
    x = [a + 0.6 * b + 0.8 * c for a, b, c in zip(osc("saw", f, N), osc("square", f, N, 0.25), sinw(f, N))]
    k = CTRL / (SR * 0.09)
    x = svf(x, [110.0 + cut * math.exp(-i * k) for i in range(N // CTRL + 1)], q)
    return [v * 0.45 for v in mul(x, adsr(N, 0.003, 0.3, 0.35, min(0.06, dur * 0.3)))]


@cached
def v_sub(m, dur):
    """長的低音（正弦＋一點三角波）"""
    f = midi(m)
    N = n(dur)
    x = [a + 0.25 * b for a, b in zip(sinw(f, N), osc("tri", f * 2, N))]
    return mul(x, swell(N, 0.12, min(0.8, dur * 0.3)))


@cached
def v_lead(m, dur):
    """合成器主旋律（追逐用）：兩個走音的鋸齒波，濾波器有共振"""
    f = midi(m)
    N = n(dur)
    x = [a + b + 0.5 * c for a, b, c in zip(osc_vib("saw", f * 0.996, N, 5.5, 0.003), osc("saw", f * 1.005, N, 0.4),
                                             osc("square", f * 0.5, N, 0.1))]
    x = svf(x, ctrl_curve(N, lambda u: 900 + 2300 * math.exp(-u * 3.0)), 2.2)
    return [v * 0.3 for v in mul(x, adsr(N, 0.008, 0.25, 0.65, min(0.12, dur * 0.3)))]


@cached
def v_pluck(m, dur):
    """短促的弦樂頓弓（追逐的八分音符）"""
    f = midi(m)
    N = n(dur)
    x = add2(osc("saw", f * 0.997, N), osc("saw", f * 1.004, N, 0.5))
    k = CTRL / (SR * 0.05)
    x = svf(x, [500.0 + 2800.0 * math.exp(-i * k) for i in range(N // CTRL + 1)], 1.2)
    return [v * 0.4 for v in mul(x, adsr(N, 0.004, 0.12, 0.2, min(0.05, dur * 0.3)))]


@cached
def v_brass(m, dur, bite=1.0):
    """低音銅管般的合成器：濾波器先開後收，再壓一點失真"""
    f = midi(m)
    N = n(dur)
    x = [a + b + 0.7 * c for a, b, c in zip(osc("saw", f * 0.996, N), osc("saw", f * 1.004, N, 0.37),
                                             osc("reed", f * 0.5, N, 0.2))]
    A = max(1, n(0.05) // CTRL)
    cut = [300.0 + 2300.0 * bite * (min(1.0, i / A) * math.exp(-max(0, i - A) * CTRL / (SR * 0.35)) * 0.6
                                    + 0.4 * min(1.0, i / A)) for i in range(N // CTRL + 1)]
    x = drive(svf(x, cut, 1.1), 1.8)
    return [v * 0.5 for v in mul(x, adsr(N, 0.02, 0.4, 0.8, min(0.12, dur * 0.3)))]


@cached
def pad_chord(notes, dur, attack=1.2, release=2.0, cut=(400.0, 1200.0, 500.0), q=0.9, shape="saw", det=0.006):
    """和聲墊：每個音左右各兩個走音的振盪器（左右走音方向相反 = 寬），濾波器慢慢開再關"""
    N = n(dur + release)
    L = [0.0] * N
    R = [0.0] * N
    for j, m in enumerate(notes):
        f = midi(m)
        d1 = det * (1 + 0.37 * j)
        d2 = det * (0.71 + 0.23 * j)
        L = [v + a + 0.6 * b for v, a, b in zip(L, osc(shape, f * (1 - d1), N, 0.13 * j),
                                                osc(shape, f * (1 + d2 * 0.5), N, 0.4 + 0.29 * j))]
        R = [v + a + 0.6 * b for v, a, b in zip(R, osc(shape, f * (1 + d2), N, 0.57 + 0.11 * j),
                                                osc(shape, f * (1 - d1 * 0.6), N, 0.83 - 0.07 * j))]
    c0, c1, c2 = cut
    peak = dur * 0.5 / (dur + release)
    curve = ctrl_curve(N, lambda u: c0 + (c1 - c0) * math.sin(u / peak * math.pi / 2) ** 2 if u < peak
                       else c2 + (c1 - c2) * math.cos((u - peak) / (1 - peak) * math.pi / 2) ** 2)
    e = swell(N, attack, release)
    g = 0.5 / len(notes) ** 0.6
    L = [v * w * g for v, w in zip(svf(L, curve, q), e)]
    R = [v * w * g for v, w in zip(svf(R, curve, q), e)]
    return ([a + 0.25 * b for a, b in zip(L, R)], [b + 0.25 * a for a, b in zip(L, R)])  # 左右互相混一點，單聲道播放也不會空掉


_VOWELS = {
    "oo": ((340, 1.0, 5.0), (780, 0.35, 6.0), (2400, 0.06, 8.0)),
    "ah": ((690, 1.0, 5.0), (1120, 0.5, 6.0), (2650, 0.14, 8.0)),
}


@cached
def choir_chord(notes, dur, attack=1.5, release=2.5, vowel="oo", pulse=0.0, pulse_depth=0.0):
    """合唱般的墊底音：有抖音的鋸齒波過母音共振峰。pulse = 音量脈動的週期（秒）"""
    N = n(dur + release)
    L = [0.0] * N
    R = [0.0] * N
    for j, m in enumerate(notes):
        f = midi(m)
        a = osc_vib("saw", f * 0.997, N, 4.7 + 0.31 * j, 0.004, 0.17 * j)
        b = osc_vib("saw", f * 1.004, N, 5.3 - 0.23 * j, 0.004, 0.61 + 0.13 * j)
        L = [v + p + 0.4 * q_ for v, p, q_ in zip(L, a, b)]
        R = [v + q_ + 0.4 * p for v, p, q_ in zip(R, a, b)]
    e = swell(N, attack, release)
    if pulse:
        w = TAU / (pulse * SR)
        e = [v * (1 - pulse_depth * (0.5 - 0.5 * math.cos(w * i))) for i, v in enumerate(e)]
    g = 0.9 / len(notes) ** 0.6
    out = []
    for ch in (L, R):
        y = [0.0] * N
        for fc, fg, fq in _VOWELS[vowel]:
            y = [v + fg * b for v, b in zip(y, biquad(ch, "bp", fc, fq))]
        out.append([v * w * g for v, w in zip(y, e)])
    return (out[0], out[1])


# ── 鼓與打擊 ──────────────────────────────────────────

def _nz(count, seed):
    r = random.Random(seed)
    return [r.uniform(-1, 1) for _ in range(count)]


@cached
def d_kick(f0=46.0, punch=120.0, dec=0.16, click=0.4):
    N = n(dec * 4 + 0.03)
    out = []
    ph = 0.0
    kd = 1 / (dec * SR)
    for i in range(N):
        t = i / SR
        ph += TAU * (f0 + punch * math.exp(-t * 42)) / SR
        out.append(math.sin(ph) * math.exp(-i * kd))
    _acc(out, 0, env(hp(_nz(n(0.012), 11), 2500), 0.0003, 0.003), click)
    R = n(0.02)
    for j in range(R):
        out[N - 1 - j] *= j / R
    return drive(out, 1.6)


@cached
def d_snare(var=0, dec=0.11, tone=185.0):
    N = n(dec * 5)
    body = env(sine(dec * 2, lambda t: tone * (1 + 0.5 * math.exp(-t * 60))), 0.0005, dec * 0.45)
    nz = env(hp(biquad(_nz(N, 20 + var), "bp", 2100, 0.6), 700), 0.0008, dec)
    out = [v * 0.9 for v in nz]
    _acc(out, 0, body, 0.7)
    return out


@cached
def d_hat(var=0, dec=0.018):
    N = n(dec * 6)
    x = hp(hp(_nz(N, 40 + var), 5200), 5200)
    return [v * 5.0 for v in env(x, 0.0004, dec)]


@cached
def d_tom(f=80.0, dec=0.22, var=0):
    N = n(dec * 4)
    out = []
    ph = 0.0
    kd = 1 / (dec * SR)
    for i in range(N):
        ph += TAU * f * (1 + 0.7 * math.exp(-i / SR * 28)) / SR
        out.append(math.sin(ph) * math.exp(-i * kd))
    _acc(out, 0, env(lp(_nz(n(0.06), 60 + var), 1400), 0.0005, 0.012), 0.5)
    R = n(0.02)
    for j in range(R):
        out[N - 1 - j] *= j / R
    return drive(out, 1.4)


@cached
def d_clang(base=310.0, dur=0.8, var=0):
    """金屬撞擊：不成整數倍的泛音＋一小段雜訊"""
    N = n(dur)
    r = random.Random(70 + var)
    out = [0.0] * N
    for ratio, a, d in ((1, 0.6, 1.0), (1.47, 0.4, 0.8), (2.09, 0.45, 0.6), (2.56, 0.3, 0.5), (3.31, 0.25, 0.4),
                        (4.14, 0.2, 0.3), (5.43, 0.12, 0.25)):
        w = TAU * base * ratio * r.uniform(0.995, 1.005) / SR
        kd = 1 / (dur * 0.28 * d * SR)
        p0 = r.uniform(0, TAU)
        out = [v + a * math.sin(w * i + p0) * math.exp(-i * kd) for i, v in enumerate(out)]
    _acc(out, 0, env(hp(_nz(n(0.05), 80 + var), 1800), 0.0003, 0.008), 0.8)
    A, R = n(0.001), n(0.03)
    for j in range(A):
        out[j] *= j / A
    for j in range(R):
        out[N - 1 - j] *= j / R
    return [v * 0.5 for v in out]


@cached
def d_boom(f=36.0, dur=2.4):
    """很低、很遠的一聲悶響"""
    N = n(dur)
    out = []
    ph = 0.0
    kd = 1 / (dur * 0.28 * SR)
    for i in range(N):
        ph += TAU * (f + 45 * math.exp(-i / SR * 14)) / SR
        out.append(math.sin(ph) * math.exp(-i * kd))
    _acc(out, 0, env(lp(_nz(n(0.6), 90), 260), 0.002, 0.12), 0.7)
    R = n(0.1)
    for j in range(R):
        out[N - 1 - j] *= j / R
    return drive(out, 1.3)


def riser(dur, seed, f0=300.0, f1=3000.0):
    """往上掃的雜訊（段落結尾的上升感）"""
    N = n(dur)
    x = svf(_nz(N, seed), ctrl_curve(N, lambda u: f0 * (f1 / f0) ** u), 2.5, "bp")
    R = max(1, n(0.04))
    return [v * (i / N) ** 2 * min(1.0, (N - i) / R) for i, v in enumerate(x)]


# ── 底層聲音（都做成剛好一個循環長度） ─────────────────

def drone(sec, m, rich=0.3, beat_hz=0.17):
    """低音長音：正弦＋慢慢拍動的第二個正弦＋濾過的鋸齒波。頻率都調成整數個週期"""
    N = int(round(sec * SR))
    f = qf(midi(m), sec)
    f2 = f + max(1, round(beat_hz * sec)) / sec
    x = [a + 0.6 * b for a, b in zip(sinw(f, N), sinw(f2, N, 1.3))]
    if rich:
        x = add2(x, [v * rich for v in primed(lambda s: svf(s, min(420.0, f * 5), 0.8), osc("saw", f, N), 8192)])
    return [v * 0.5 for v in x]


def lfo_sum(sec, cycles, N=None):
    """幾個整數週期的正弦加起來（0~1），循環時接得起來"""
    N = N or int(round(sec * SR))
    ws = [(TAU * c / (sec * SR), 1.7 * j + 0.4) for j, c in enumerate(cycles)]
    k = 1.0 / len(ws)
    sin = math.sin
    return [0.5 + 0.5 * k * sum(sin(w * i + p) for w, p in ws) for i in range(N)]


def wind_bed(sec, seed, lo=300.0, hi=900.0, q=1.6, cycles=(3, 5, 8), xf=2.0, hiss=0.15, phase=0.0):
    """風：雜訊過會移動的帶通（呼嘯聲），音量跟著陣風起伏。回傳剛好 sec 秒、可以循環"""
    N = int(round(sec * SR))
    K = n(xf)
    nz = _nz(N + K, seed)
    g = lfo_sum(sec, cycles, N + K)
    cut = [lo + (hi - lo) * g[min(i * CTRL, N + K - 1)] ** 1.5 for i in range((N + K) // CTRL + 1)]
    x = svf(nz, cut, q, "bp")
    if hiss:
        x = [a + hiss * b for a, b in zip(x, hp(nz, 3500))]
    x = [v * (0.25 + 0.75 * e * e) for v, e in zip(x, g)]
    return xfade_loop(x, K)


def noise_bed(sec, seed, fc=300.0, kind="lp", q=0.7, xf=1.5):
    N = int(round(sec * SR))
    K = n(xf)
    nz = _nz(N + K, seed)
    x = lp(nz, fc) if kind == "lp" else biquad(nz, kind, fc, q)
    return xfade_loop(x, K)


# 訊號動機：126.05 → 音階的第 1、2、6 音，0 = 停一拍，第 5 音。
# D 小調 = D、E、降 B、（停）、A。（拍點, 長度拍數, 離主音幾個半音）
MOTIF = ((0, 1, 0), (1, 1, 2), (2, 2, 8), (5, 3, 7))
ANSWER = ((0, 1, 7), (1, 1, 5), (2, 2, 3), (5, 3, 2))  # 回答句：5、4、3、（停）、2，停在沒解決的地方


def radio_voice(root, beat, seed, phrase=MOTIF, static=0.35):
    """短波電台播出來的訊號動機：純音嗶聲＋靜電＋差頻哨音，頻寬窄、音高像老磁帶一樣晃"""
    total = (phrase[-1][0] + phrase[-1][1]) * beat + 1.0
    N = n(total)
    x = [0.0] * N
    for b, d, semi in phrase:
        f = midi(root + semi)
        L = n(d * beat * 0.9)
        tone = [a + 0.3 * b2 for a, b2 in zip(sinw(f, L), osc("square", f, L))]
        _acc(x, n(0.3 + b * beat), mul(tone, adsr(L, 0.01, 0.2, 0.8, 0.06)), 0.5)
    st = _nz(N, seed)
    x = [a + static * (0.5 + 0.5 * math.sin(i * 0.0021)) * b for i, (a, b) in enumerate(zip(x, st))]
    wh = sine(total, lambda t: 2050 - 160 * t / total + 30 * math.sin(t * 2.3))
    x = [a + 0.05 * b for a, b in zip(x, wh)]
    x = drive(hp(biquad(biquad(x, "bp", 1300, 0.6), "lp", 2500, 0.8), 450), 1.5)
    x = tape(x, 0.006, 0.0015, 0.9, 7.1)
    return mul(x, swell(N, 0.25, 0.6))


def data_burst(dur, seed, rate=14.0):
    """短波上的數據聲：很快的雙音切換"""
    N = n(dur)
    r = random.Random(seed)
    x = []
    step = int(SR / rate)
    ph = 0.0
    while len(x) < N:
        f = r.choice((1180.0, 1180.0, 1420.0, 1760.0))
        on = r.random() < 0.8
        for _ in range(step):
            ph += TAU * f / SR
            x.append(math.sin(ph) if on else 0.0)
    x = biquad(x[:N], "bp", 1400, 0.8)
    return mul(x, swell(N, 0.05, 0.1))


def primed(fn, x, k=6000):
    """對「循環的訊號」做濾波：先用尾巴暖機，濾波器的起始狀態才會和循環接點一致"""
    return fn(x[-k:] + x)[k:]


# ── 用新引擎重做的音效 ─────────────────────────────────

def gunshot(rng, body_f=70, length=0.8, tail=0.16, crack_d=0.02, boom=1.0):
    """槍聲：很短的高頻爆裂＋中頻＋往下掉的低頻，壓過失真變「滿」，再加走廊的幾個反射和短殘響"""
    crack = env(hp(noise(0.1, rng), 2200), 0.0002, crack_d)
    snap = env(biquad(noise(0.15, rng), "bp", 1900, 0.5), 0.0003, crack_d * 1.6)
    hiss = env(hp(noise(0.3, rng), 3000), 0.002, 0.06)
    body = env(sine(0.3, lambda t: body_f * (1 + 3 * math.exp(-t * 55))), 0.0005, 0.06)
    x = drive(mix((crack, 0, 1.6), (snap, 0, 1.3), (hiss, 0, 0.35), (body, 0, 0.5 * boom), length=n(0.35)), 1.6)
    out = x + [0.0] * (n(length) - len(x))
    for dt, g, fc in ((0.023, 0.35, 4500), (0.047, 0.25, 3200), (0.081, 0.18, 2200), (0.127, 0.1, 1500)):
        _acc(out, n(dt * rng.uniform(0.9, 1.1)), lp(x, fc), g)
    wet = lp(reverb(hp(out, 400), tail * 3.5, 0.5, 0.8), 4000)
    return [a + 0.22 * b for a, b in zip(out, wet)]


def pistol_shot(rng):
    return gunshot(rng, 75, 0.8, 0.15)


def shotgun_shot(rng):
    shot = gunshot(rng, 48, 1.0, 0.24, 0.04, 1.4)
    rack = mix((click(rng, 1500, 0.012), 0, 1), (thump(rng, 240, 0.015, 2200, 0.02), 0.01, 0.5),
               (click(rng, 1100, 0.014), 0.12, 1), (thump(rng, 200, 0.02, 1800, 0.02), 0.125, 0.6))
    return mix((shot, 0, 1.0), (rack, 0.62, 0.3), length=n(1.0))


def radio_static(rng):
    N = n(1.5)
    st = am(biquad(noise(1.5, rng), "bp", 1700, 0.6), rng.uniform(5, 9), 0.5)
    garble = [0.0] * N  # 底下聽不清楚的電台：訊號動機的幾個音，斷斷續續
    root = rng.choice((74, 69, 77))
    for i, s in enumerate(rng.sample((0, 2, 8, 7), 3)):
        K = n(0.3)
        _acc(garble, n(0.25 + i * 0.36), mul(am(sinw(midi(root + s), K), 23, 0.9), swell(K, 0.03, 0.05)), 0.5)
    wh = sine(1.5, lambda t, f=rng.uniform(1800, 2600): f - 500 * t + 40 * math.sin(t * 31))
    x = mix((st, 0, 0.8), (garble, 0, 0.3), (wh, 0, 0.06), (crackle(1.5, 50, rng, 3000, 0.002), 0, 0.5), length=N)
    return bell(hp(biquad(x, "lp", 3000, 0.8), 350), 0.1)


def save_chime(rng):
    """存檔：訊號動機（D、E、降 B、停、A）用溫暖的鐘聲很快彈一次"""
    parts = [(v_glass(62 + s, 1.2 if s == 7 else 0.9, 0.006, 0.2), t, g)
             for s, t, g in ((0, 0.0, 0.8), (2, 0.13, 0.75), (8, 0.26, 0.85), (7, 0.56, 0.9))]
    return room(mix(*parts, length=n(1.55)), 0.6, 0.2, 0.1)


def uplink_transmit(rng):
    rise = env(sine(2.0, lambda t: 300 + 600 * t), 0.2, 9, 1.8)
    chirps = mix(*[(env(square(0.05, rng.choice([1200, 1600, 2100, 2400])), 0.002, 0.03), 0.4 + i * 0.07, 0.25)
                   for i in range(20)])
    lock = mix(*[(beep(midi(86 + s), 0.09), i * 0.1, 0.8) for i, s in enumerate((0, 2, 8, 7))])  # 鎖定 = 動機
    return mix((rise, 0, 0.5), (lp(chirps, 3000), 0, 1.0), (lock, 2.0, 1.0), length=n(2.5))


def alert_sting(rng):
    """被發現：不和諧的弦樂和弦（D、降 E、A、D、降 E）猛然一下＋低的金屬撞擊"""
    L, R = pad_chord((62, 63, 69, 74, 75), 0.35, 0.004, 0.6, (3300.0, 3300.0, 700.0), 1.3, "saw", 0.008)
    hit = mix((d_clang(140.0, 1.0, 5), 0, 0.5), (d_boom(40, 1.0), 0, 0.9))
    return room(mix((add2(L, R), 0, 1.0), (hit, 0, 1.0), length=n(1.0)), 0.5, 0.2, 0.15)


def suspicious_sting(rng):
    """起疑：動機的頭兩個音（D → E）往上，底下墊一個很小聲的降 E 讓它不安"""
    air = bell(bp(noise(0.8, rng), 2400, 8), 0.6)
    return mix((v_glass(74, 0.8, 0.12, 0.6), 0, 0.7), (v_glass(76, 0.55, 0.1, 0.6), 0.25, 0.8),
               (v_glass(75, 0.8, 0.2, 0.6), 0, 0.22), (air, 0, 0.25), length=n(0.85))


def mission_complete(rng):
    """任務完成：冷的 D 小調和弦慢慢開，上面是動機最後的降 B → A"""
    L, R = pad_chord((50, 57, 62, 64), 0.9, 0.3, 0.8, (400.0, 1500.0, 500.0), 0.9, "saw", 0.005)
    top = mix((v_glass(70, 0.6, 0.02, 0.3), 0.15, 0.5), (v_glass(69, 1.1, 0.02, 0.3), 0.5, 0.6))
    return mix((add2(L, R), 0, 1.0), (top, 0, 0.35), length=n(1.7))


# ── v0.16：每把槍自己的聲音、更多地面、新機制的聲音 ──────────────

def pluck(rng, f, sec, damp=0.996, bright=0.5):
    """Karplus-Strong 撥弦（弓弦、鋼索）：一段雜訊在延遲線裡來回、越來越暗"""
    D = max(2, int(SR / f))
    buf = [rng.uniform(-1, 1) for _ in range(D)]
    buf = lp(buf, 2000 + 6000 * bright)
    out = []
    i = 0
    for _ in range(n(sec)):
        a = buf[i % D]
        b = buf[(i + 1) % D]
        v = damp * 0.5 * (a + b)
        buf[i % D] = v
        out.append(a)
        i += 1
    return out


def revolver_shot(rng):
    """.357 左輪：比手槍低、更重、尾巴長，帶一點彈巢的金屬餘音"""
    shot = gunshot(rng, 60, 1.1, 0.24, 0.03, 1.3)
    ring = tone_partials(0.6, [(rng.uniform(2900, 3300), 0.3, 1.0), (4700, 0.15, 0.6)], 0.12, rng)
    return mix((shot, 0, 1.0), (ring, 0.01, 0.12), length=n(1.1))


def rifle_shot(rng):
    """獵槍（步槍）：超音速的尖銳爆裂＋很重的低頻，戶外的遠處回聲"""
    crack = env(hp(noise(0.05, rng), 3500), 0.0001, 0.008)
    shot = gunshot(rng, 52, 1.4, 0.3, 0.025, 1.5)
    out = mix((crack, 0, 1.2), (shot, 0, 1.0), length=n(1.6))
    for dt, g in ((0.21, 0.22), (0.43, 0.12)):
        _acc(out, n(dt * rng.uniform(0.92, 1.08)), lp(shot, 1200), g)
    return out


def smg_shot(rng):
    """衝鋒槍：一發一發很短（連發時才不會糊在一起），比手槍亮一點"""
    return gunshot(rng, 95, 0.42, 0.08, 0.014, 0.6)


def suppressed_shot(rng):
    """裝了消音器：悶悶的「噗」＋滑套的金屬聲，沒有爆裂"""
    puff = env(biquad(noise(0.12, rng), "bp", rng.uniform(700, 900), 0.9), 0.0004, 0.025)
    low = env(sine(0.12, lambda t: 140 * (1 + 1.5 * math.exp(-t * 60))), 0.0005, 0.02)
    slide = mix((click(rng, 3200, 0.004), 0, 1.0), (click(rng, 2400, 0.005), 0.035, 0.7))
    return room(mix((puff, 0, 1.0), (low, 0, 0.6), (slide, 0.012, 0.35), length=n(0.25)), 0.25, 0.15, 0.15)


def crossbow_shot(rng):
    """十字弓：弓弦「嗡」一聲（撥弦）＋木頭托架喀一聲＋箭出去的風聲"""
    f = rng.uniform(95, 115)
    string = env(pluck(rng, f, 0.45, 0.994, 0.7), 0.0005, 0.12)
    clack = mix((click(rng, 1800, 0.008), 0, 1.0), (thump(rng, 180, 0.02, 1500, 0.02), 0, 0.6))
    air = whoosh(rng, 0.18, 1500, 4000, 2.5)
    return mix((string, 0, 0.9), (clack, 0, 0.7), (air, 0.01, 0.35), length=n(0.5))


def nailgun_shot(rng):
    """釘槍：氣壓「嗤」＋釘子打出去的金屬「鏘」＋機身喀噠"""
    air = env(hp(noise(0.1, rng), 2500), 0.001, 0.025)
    thunk = env(metal_hit(rng, 0.2, rng.uniform(850, 1000)), 0.0005, 0.04)
    body = thump(rng, 200, 0.015, 2200, 0.015)
    return mix((air, 0, 0.8), (thunk, 0.004, 0.5), (body, 0, 0.6), length=n(0.25))


def flare_shot(rng):
    """信號槍：空心的「砰」＋燃燒的嘶嘶聲飛出去"""
    pop = mix((thump(rng, 170, 0.04, 1200, 0.04), 0, 1.0), (env(biquad(noise(0.2, rng), "bp", 550, 1.2), 0.001, 0.05), 0, 0.7))
    hiss = env(hp(noise(0.9, rng), 2800), 0.02, 0.35, 0.1)
    return mix((pop, 0, 1.0), (hiss, 0.03, 0.35), length=n(1.0))


def step_wood(rng):
    """木地板（小屋、甲板、劇場）：空心的低音共鳴＋偶爾一聲吱嘎"""
    board = env(biquad(noise(0.2, rng), "bp", rng.uniform(170, 240), 5.0), 0.001, 0.06)
    heel = env(lp(noise(0.08, rng), 1100), 0.001, 0.015)
    toe = env(biquad(noise(0.08, rng), "bp", 1100, 1.2), 0.002, 0.02)
    parts = [(board, 0, 1.2), (heel, 0, 0.5), (toe, rng.uniform(0.05, 0.07), 0.25)]
    if rng.random() < 0.35:
        parts.append((creak(rng, 0.18, rng.uniform(380, 460), rng.uniform(300, 360)), 0.04, 0.18))
    return mix(*parts, length=n(0.32))


def step_carpet(rng):
    """地毯（辦公室、客艙、劇場）：很悶、很軟，幾乎只有低頻和布料的摩擦"""
    soft = env(lp(noise(0.12, rng), 650), 0.004, 0.035)
    low = env(sine(0.12, 85), 0.003, 0.03)
    brush = bell(biquad(noise(0.1, rng), "bp", 2200, 0.7), 0.3)
    return mix((soft, 0, 1.0), (low, 0, 0.4), (brush, 0.02, 0.05), length=n(0.25))


def choke_struggle(rng):
    """被勒住的人：喉嚨被壓住的悶哼、抽氣（斷斷續續）＋衣服摩擦"""
    L = 1.2
    gasps = []
    t = 0.0
    while t < L - 0.2:
        d = rng.uniform(0.18, 0.32)
        v = voice(rng, d, rng.uniform(105, 130), rng.uniform(90, 110), (380, 820), 0.12, 0)
        gasps.append((bell(lp(v, 1400), 0.4), t, rng.uniform(0.5, 1.0)))
        t += d + rng.uniform(0.05, 0.15)
    rustle = bell(biquad(noise(L, rng), "bp", 1600, 0.7), 0.5)
    return mix(*gasps, (rustle, 0, 0.25), (thump(rng, 110, 0.03, 900, 0.03), rng.uniform(0.3, 0.7), 0.3), length=n(L))


def crystal_resonance(rng):
    """結晶共鳴：骨頭的結晶碎裂（短的碎裂聲）之後，一組不和諧的玻璃泛音慢慢浮起來、互相拍頻、再淡掉"""
    crack = mix((crackle(0.25, 400, rng, 3500, 0.002), 0, 1.0), (glass(rng, 0.3, 6), 0, 0.5))
    base = rng.uniform(1180, 1320)
    partials = [(base, 0.5, 1.0), (base * 1.503, 0.35, 0.9), (base * 2.12, 0.25, 0.7), (base * 2.99, 0.15, 0.5),
                (base * 1.007, 0.4, 1.0)]  # 最後一個和第一個差一點點 → 會「嗚嗚」地拍頻
    ring = tone_partials(1.6, partials, 0.55, rng)
    swell = [v * min(1.0, i / n(0.12)) for i, v in enumerate(ring)]
    return room(mix((crack, 0, 0.8), (swell, 0.03, 0.7), length=n(1.6)), 0.9, 0.3, 0.6)


def radio_song(rng):
    """頻率誘餌放的「歌」：短波電台裡的訊號動機（D、E、降 B、停、A）"""
    root = rng.choice((74, 62))
    return radio_voice(root, 0.22, rng.randrange(1 << 20), MOTIF, 0.4)


def _siren_curve(t, rise, hold, fall, f0, f1, end):
    """手搖式警報器的轉速：慢慢轉上去、停在高音晃一晃、再慢慢掉下來"""
    if t < rise:
        k = t / rise
        return f0 + (f1 - f0) * (1 - (1 - k) ** 2)
    if t < rise + hold:
        return f1 + 6 * math.sin((t - rise) * 5.3)
    k = min((t - rise - hold) / fall, 1.0)
    return f1 + (end - f1) * k * k


def _siren(rng, sec, rise, hold, fall, f0, f1, end):
    """冷戰時代的防空喇叭：兩個轉子（差一個小三度）＋金屬共鳴，從很遠的地方傳來（低通、長殘響）"""
    a = saw(sec, lambda t: _siren_curve(t, rise, hold, fall, f0, f1, end), rng, 0.002)
    b = saw(sec, lambda t: 1.19 * _siren_curve(t, rise, hold, fall, f0, f1, end), rng, 0.002)
    body = lp(mix((a, 0, 0.6), (b, 0, 0.45)), 1500)
    body = [v * min(1.0, i / n(0.4)) * min(1.0, (n(sec) - i) / n(0.6)) for i, v in enumerate(body)]
    wind = lp(noise(sec, rng), 400)
    return mix((body, 0, 0.8), (wind, 0, 0.08))


def tide_warning(rng):
    """唱潮的預告：無線電雜訊慢慢變大，底下有一段很淡的訊號動機和越來越低的嗡聲"""
    L = 3.4
    hum = [v * (i / n(L)) for i, v in enumerate(sine(L, lambda t: 58 - 4 * t))]
    st = [v * (0.15 + 0.6 * i / n(L)) for i, v in enumerate(biquad(noise(L, rng), "bp", 1500, 0.5))]
    song = radio_voice(62, 0.2, rng.randrange(1 << 20), MOTIF, 0.2)
    return mix((hum, 0, 0.5), (st, 0, 0.45), (song, 0.4, 0.35), length=n(L))


def tide_siren(rng):
    """燈籠站的老防空喇叭響了（唱潮開始）"""
    return room(_siren(rng, 9.0, 2.6, 3.4, 3.0, 130, 455, 150), 2.2, 0.55, 1.6)


def tide_end(rng):
    """唱潮退去：喇叭的轉子慢慢停下來"""
    return room(_siren(rng, 5.0, 0.01, 0.2, 4.79, 440, 440, 55), 2.2, 0.55, 1.6)


SFX = {
    "step_concrete": (step_concrete, 4), "step_snow": (step_snow, 4), "step_metal": (step_metal, 4),
    "player_hurt": (player_hurt, 3), "player_death": (player_death, 1), "shiver_breath": (shiver_breath, 2),
    "locker_open": (locker_open, 1), "locker_close": (locker_close, 1), "knock": (knock, 2),
    "flashlight_click": (flashlight_click, 1), "lighter_flick": (lighter_flick, 2),
    "pistol_shot": (pistol_shot, 3), "shotgun_shot": (shotgun_shot, 2), "gun_empty": (gun_empty, 1),
    "reload": (reload, 1), "knife_swing": (knife_swing, 2), "knife_hit": (knife_hit, 2),
    "bullet_hit_flesh": (bullet_hit_flesh, 3), "punch_hit": (punch_hit, 3), "kick_hit": (kick_hit, 2),
    "body_slam": (body_slam, 2), "grab": (grab, 1), "throw_whoosh": (throw_whoosh, 1), "stone_land": (stone_land, 3),
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
    # v0.16
    "revolver_shot": (revolver_shot, 2), "rifle_shot": (rifle_shot, 2), "smg_shot": (smg_shot, 3),
    "suppressed_shot": (suppressed_shot, 3), "crossbow_shot": (crossbow_shot, 2), "nailgun_shot": (nailgun_shot, 2),
    "flare_shot": (flare_shot, 1), "step_wood": (step_wood, 4), "step_carpet": (step_carpet, 4),
    "choke_struggle": (choke_struggle, 3), "crystal_resonance": (crystal_resonance, 2), "radio_song": (radio_song, 2),
    # v0.17 唱潮
    "tide_warning": (tide_warning, 1), "tide_siren": (tide_siren, 1), "tide_end": (tide_end, 1),
}
LOOP_SFX = {"fire_loop"}


def play_phrase(mx, phrase, root, t0, beat, voice, g=0.4, pan=0.0, rev=0.4, dly=0.0, ring=2.0, name="motif"):
    """把動機（或回答句）用某個樂器放進混音。voice(midi, 秒) → 訊號；ring = 每個音多響幾秒"""
    for b, d, semi in phrase:
        mx.add(voice(root + semi, round(d * beat + ring, 3)), t0 + b * beat, g, pan, rev, dly, name)


# ── 環境音（立體聲、各 30 秒、無縫循環） ─────────────────

AMB_LEN = 30.0


def amb_blizzard(rng):
    L = AMB_LEN
    mx = Mixer(L, 3.0)
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(wind_bed(L, 100 + seed, 260, 950, 1.8, (3, 5, 8), 2.0, 0.22), 0, 0.8, side * 0.75, name="howl")
        mx.add(wind_bed(L, 110 + seed, 700, 2300, 3.5, (2, 7, 11), 2.0, 0.0), 0, 0.22, -side * 0.5, name="whistle")
        mx.add(noise_bed(L, 120 + seed, 140), 0, 0.9, side * 0.4, name="rumble")
    for t, pan, base in ((6.4, -0.6, 380), (6.75, -0.55, 410), (19.3, 0.5, 300), (19.5, 0.55, 345), (20.1, 0.45, 300)):
        mx.add(d_clang(base, 0.6, int(t)), t, 0.035, pan, 0.8, name="rattle")  # 遠處被風吹動的金屬
    return mx.render(rt=1.2, damp=0.5, wet=0.6, level=-17.5)


def amb_station_hum(rng):
    L = AMB_LEN
    N = int(L * SR)
    mx = Mixer(L, 3.0)
    hum = [a * 0.5 + b * 0.3 + c * 0.1 + d * 0.12 for a, b, c, d in
           zip(sinw(60, N), sinw(120, N, 0.7), sinw(180, N, 1.9), sinw(qf(120.2, L), N))]
    mx.add(hum, 0, 0.5, 0.0, name="hum")
    buzz = primed(lambda s: biquad(s, "bp", 2400, 7), osc("saw", 120, N))
    buzz = [v * (0.7 + 0.3 * math.sin(TAU * 7 * i / N)) for i, v in enumerate(buzz)]
    mx.add(buzz, 0, 0.16, 0.35, 0.3, name="buzz")
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(noise_bed(L, 200 + seed, 480), 0, 0.5, side * 0.8, name="vent")
        mx.add(noise_bed(L, 210 + seed, 1500, "bp", 0.8), 0, 0.035, side * 0.6, name="air")
    for t, pan, tone in ((3.7, -0.7, 1500), (9.2, 0.6, 1900), (9.33, 0.6, 1750), (16.8, -0.3, 1300),
                         (23.1, 0.8, 1600), (27.4, -0.6, 2100)):
        mx.add(click(rng, tone, 0.012), t, 0.4, pan, 1.2, name="tick")  # 水管偶爾答一聲
    return mx.render(rt=0.9, damp=0.5, wet=0.5, level=-17.5)


def amb_station_dark(rng):
    L = AMB_LEN
    mx = Mixer(L, 4.0)
    for side, seed in ((-1, 1), (1, 2)):
        w = primed(lambda x: lp(x, 600), wind_bed(L, 300 + seed, 180, 520, 1.3, (2, 3, 7), 2.0, 0.0))
        mx.add(w, 0, 1.0, side * 0.7, name="wind")
        mx.add(noise_bed(L, 310 + seed, 110), 0, 0.5, side * 0.3, name="rumble")
    for t, pan, f0, f1 in ((4.1, -0.5, 95, 120), (11.6, 0.6, 130, 105), (18.9, 0.2, 88, 140), (25.2, -0.7, 110, 150)):
        mx.add(creak(rng, 1.3, f0, f1), t, 0.25, pan, 0.9, name="creak")
    for i in range(11):  # 滴水（有回音）
        f = rng.uniform(900, 1900)
        d = env(sine(0.2, lambda t, f=f: f * (1 + 0.5 * math.exp(-t * 60))), 0.001, 0.03)
        mx.add(d, rng.uniform(0.3, L - 0.3), rng.uniform(0.08, 0.22), rng.uniform(-0.8, 0.8), 1.5, 0.6, name="drip")
    for i in range(6):  # 冰裂
        mx.add(crackle(0.25, rng.uniform(40, 120), rng, 2200, 0.003), rng.uniform(1, L - 1), 0.18,
               rng.uniform(-0.9, 0.9), 0.8, name="ice")
    return mx.render(rt=1.8, damp=0.45, wet=0.7, dtime=0.31, dfb=0.35, dtaps=3, level=-18.5)


def amb_shaft(rng):
    L = AMB_LEN
    mx = Mixer(L, 8.0)
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(noise_bed(L, 400 + seed, 95), 0, 1.0, side * 0.6, name="rumble")
        mx.add(wind_bed(L, 410 + seed, 120, 300, 2.5, (1, 3, 4), 2.5, 0.0), 0, 0.5, side * 0.8, name="draft")
    mx.add(drone(L, 31, 0.15, 0.1), 0, 0.22, 0.0, 0.3, name="drone")
    for i in range(13):
        f = rng.uniform(600, 1300)
        d = env(sine(0.25, lambda t, f=f: f * (1 + 0.5 * math.exp(-t * 50))), 0.001, 0.04)
        mx.add(d, rng.uniform(0.3, L - 0.3), rng.uniform(0.06, 0.15), rng.uniform(-0.8, 0.8), 2.0, 0.8, name="drip")
    # 很遠的井底傳上來的水晶聲（G 小調，和最終 Boss 同一個調）
    for t, m, pan in ((2.0, 67, -0.4), (7.5, 70, 0.5), (12.0, 74, -0.2), (17.5, 69, 0.3), (22.0, 75, -0.5),
                      (23.2, 74, 0.4)):
        mx.add(v_glass(m, 6.0, 2.2, 0.6), t, 0.035, pan, 2.5, 0.5, name="crystal")
    return mx.render(rt=5.0, damp=0.4, size=1.5, wet=0.8, predelay=0.06, dtime=0.47, dfb=0.5, level=-17.5)


AMBIENCE = {"amb_blizzard": amb_blizzard, "amb_station_hum": amb_station_hum,
            "amb_station_dark": amb_station_dark, "amb_shaft": amb_shaft}


# ── 音樂 ──────────────────────────────────────────────
# 全部圍繞同一個「訊號動機」（MOTIF：D、E、降 B、停、A = 126.05 的 1-2-6-0-5）：
# 標題用鋼琴和短波電台、安全屋用鐘琴、追逐用合成器主旋律和低音音型、兩個 Boss 各移一個調、結局轉成大調收掉。
# 每首的長度都是整數個小節，循環時拍子不會亂。

D2, D3, D4, D5 = 38, 50, 62, 74


def music_title(rng):
    """標題：60 BPM、16 小節。風和短波電台 → 鋼琴動機 → 低音脈衝和弦樂進來 → 全體 → 收回風聲"""
    beat, bar, _ = bar_grid(60)
    L = 16 * bar
    mx = Mixer(L, 9.0)
    N = int(L * SR)
    mx.add(drone(L, D2, 0.3), 0, 0.26, 0, 0.1, name="drone")
    mx.add(drone(L, D2 - 12, 0.5, 0.11), 0, 0.15, name="drone")
    swell_env = [0.35 + 0.65 * (0.5 + 0.5 * math.cos(TAU * i / N)) ** 2 for i in range(N)]  # 循環接點附近風最大
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(mul(wind_bed(L, 500 + seed, 300, 900, 1.6, (3, 5, 9)), swell_env), 0, 0.26, side * 0.7, 0.2, name="wind")
    # 短波電台：動機第一次出現是「收到的訊號」
    mx.add(radio_voice(D5, beat, 7), 1 * bar - 0.3, 0.26, -0.45, 0.6, 0.3, name="radio")
    mx.add(data_burst(1.6, 3), 3 * bar + 1.5, 0.035, 0.55, 0.7, name="radio")
    mx.add(d_clang(196, 2.2, 1), 0, 0.14, 0.35, 1.2, name="metal")
    mx.add(d_clang(147, 2.4, 2), 3 * bar + 2, 0.1, -0.5, 1.4, name="metal")
    mx.add(d_boom(36, 2.6), 0, 0.35, 0, 0.3, name="boom")
    # 和聲
    chords = ((4, 2, (50, 57, 64, 65), (300, 750, 480)), (6, 2, (46, 53, 57, 62, 64), (320, 850, 520)),
              (8, 2, (43, 50, 53, 57, 58), (400, 1150, 700)), (10, 1, (45, 52, 55, 62), (450, 1250, 800)),
              (11, 1, (45, 52, 55, 61), (500, 1400, 800)), (12, 2, (38, 50, 57, 62, 65, 69), (550, 1900, 900)),
              (14, 1, (46, 53, 57, 62), (450, 900, 500)), (15, 1, (45, 52, 57, 62), (380, 650, 300)))
    for b, nb, notes, cut in chords:
        mx.add(pad_chord(notes, nb * bar, 1.4, 2.2, cut), b * bar, 0.36, 0, 0.5, name="pad")
    for b, m in ((4, 38), (6, 34), (8, 31), (10, 33), (12, 38), (12, 26), (14, 34), (15, 33)):
        mx.add(v_piano(m, 6.0, 0.8), b * bar, 0.42, -0.15, 0.4, name="piano_lh")
    pno = lambda m, d: v_piano(m, d, 1.0)
    gls = lambda m, d: v_glass(m, d, 0.25, 0.5)
    play_phrase(mx, MOTIF, D4, 4 * bar, beat, pno, 0.55, -0.1, 0.5, 0.3, 3.0)
    play_phrase(mx, ANSWER, D4, 6 * bar, beat, pno, 0.5, 0.1, 0.5, 0.3, 3.0)
    play_phrase(mx, MOTIF, D4, 8 * bar, beat, pno, 0.5, -0.1, 0.5, 0.3, 3.0)
    play_phrase(mx, MOTIF, D5, 8 * bar, beat, pno, 0.3, 0.15, 0.5, 0.3, 3.0)
    play_phrase(mx, MOTIF, D5, 8 * bar, beat, gls, 0.1, 0.3, 0.8, 0.3, 2.0, "glass")
    play_phrase(mx, ANSWER, D4, 10 * bar, beat, pno, 0.5, 0.1, 0.5, 0.3, 3.0)
    play_phrase(mx, ANSWER, D5, 10 * bar, beat, pno, 0.3, -0.15, 0.5, 0.3, 3.0)
    play_phrase(mx, MOTIF, D3, 12 * bar, beat, pno, 0.5, -0.2, 0.5, 0.2, 3.0)
    play_phrase(mx, MOTIF, D4, 12 * bar, beat, pno, 0.55, 0.0, 0.5, 0.3, 3.0)
    play_phrase(mx, MOTIF, D5 + 12, 12 * bar, beat, gls, 0.09, 0.3, 0.9, 0.4, 2.5, "glass")
    play_phrase(mx, ANSWER, D4, 14 * bar, beat, pno, 0.42, 0.1, 0.6, 0.35, 4.0)
    # 低音脈衝（八分音符）和心跳
    acc = (1.0, 0.55, 0.8, 0.55, 0.9, 0.55, 0.8, 0.6)
    for b, m in ((8, 43), (9, 43), (10, 45), (11, 45), (12, 38), (13, 38), (14, 34)):
        for i in range(8):
            mx.add(v_bass(m, beat * 0.5, 520.0 if b < 12 else 800.0), b * bar + i * beat / 2, 0.36 * acc[i],
                   0, 0.1, name="pulse")
    for b in range(8, 14):
        g = 0.3 if b < 12 else 0.45
        mx.add(d_kick(44.0, 70.0, 0.2, 0.1), b * bar, g, 0, 0.15, name="heart")
        mx.add(d_kick(44.0, 70.0, 0.2, 0.1), b * bar + 0.42, g * 0.7, 0, 0.15, name="heart")
    mx.add(d_boom(38, 2.6), 8 * bar, 0.4, 0, 0.4, name="boom")
    mx.add(d_boom(36, 2.8), 12 * bar, 0.55, 0, 0.4, name="boom")
    mx.add(riser(4.0, 5, 250, 2600), 11 * bar, 0.07, 0.2, 0.6, name="riser")
    mx.add(d_clang(220, 2.5, 3), 12 * bar, 0.12, -0.3, 1.3, name="metal")
    # 「歌聲」：很高、很遠的水晶音
    mx.add(v_glass(86, 12.0, 4.0, 0.7), 6 * bar, 0.035, 0.5, 1.5, name="sing")
    mx.add(v_glass(93, 10.0, 3.5, 0.7), 12 * bar, 0.03, -0.5, 1.5, name="sing")
    mx.add(v_glass(91, 9.0, 3.5, 0.7), 14 * bar, 0.022, 0.4, 1.5, name="sing")
    return mx.render(rt=3.4, damp=0.35, size=1.3, dtime=0.75, dfb=0.45, dtaps=4, level=-19.0,
                     tape_fx=(0.0006, 0.00015, qf(0.45, L), qf(6.3, L)))


def music_explore_station(rng):
    """站內探索：沒有拍子感。低音長音＋通風聲，偶爾兩下低音心跳、不和諧的鋼琴音、遠處的金屬聲"""
    bar = 4.8
    beat = bar / 4
    L = 10 * bar
    mx = Mixer(L, 9.0)
    mx.add(drone(L, 33, 0.5, 0.13), 0, 0.13, 0, 0.1, name="drone")
    mx.add(drone(L, 40, 0.3, 0.21), 0, 0.1, 0.2, 0.2, name="drone")
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(noise_bed(L, 600 + seed, 320), 0, 0.14, side * 0.8, name="vent")
        mx.add(wind_bed(L, 610 + seed, 500, 1300, 4.0, (2, 5), 2.0, 0.0), 0, 0.028, -side * 0.5, 0.4, name="air")
    for b in (0, 2, 4, 6, 8):
        mx.add(v_bass(33, 0.5, 380.0), b * bar, 0.32, 0, 0.15, name="heart")
        mx.add(v_bass(33, 0.5, 300.0), b * bar + 0.48, 0.22, 0, 0.15, name="heart")
    for b, bt, notes, pan in ((1, 2, (64, 65), -0.3), (3, 1, (58,), 0.3), (5, 3, (64,), -0.1), (5, 3.5, (63,), -0.1),
                              (7, 0.5, (61,), 0.4), (8, 2, (52, 65), -0.4)):
        for m in notes:
            mx.add(v_piano(m, 5.0, 0.6), b * bar + bt * beat, 0.3, pan, 0.8, 0.4, name="piano")
    for b, pan, base, v in ((2.5, 0.6, 233, 1), (6.25, -0.6, 175, 2), (8.75, 0.3, 262, 3)):
        mx.add(d_clang(base, 2.0, v), b * bar, 0.13, pan, 1.6, 0.3, name="metal")
    # 動機只露出一點（移到 A：A、B、F、停、E），很小聲的玻璃音
    play_phrase(mx, MOTIF, 69, 4 * bar, beat, lambda m, d: v_glass(m, d, 0.4, 0.5), 0.07, 0.35, 1.2, 0.5, 3.0)
    mx.add(pad_chord((88, 89), 2 * bar, 3.5, 3.5, (900, 2200, 900), 0.8, "soft", 0.002), 6 * bar, 0.03, 0, 0.8,
           name="cluster")
    mx.add(mul(data_burst(2.2, 9), swell(n(2.2), 0.6, 0.8)), 9 * bar + 0.4, 0.035, -0.6, 0.8, name="radio")
    mx.add(d_boom(34, 2.6), 5 * bar, 0.14, 0, 0.4, name="boom")
    return mx.render(rt=3.8, damp=0.4, size=1.4, dtime=0.9, dfb=0.4, dtaps=4, level=-20.0)


def music_explore_outdoor(rng):
    """戶外探索：很空、很慢。低音長音、像遠處合唱的墊底音一波一波，動機用很高的玻璃音飄過一次"""
    bar = 6.0
    L = 8 * bar
    mx = Mixer(L, 10.0)
    mx.add(drone(L, D2, 0.25, 0.1), 0, 0.3, 0, 0.1, name="drone")
    mx.add(drone(L, D2 - 12, 0.5, 0.07), 0, 0.2, name="drone")
    chords = ((0, 2, (50, 57, 62, 64)), (2, 2, (46, 53, 57, 62)), (4, 2, (43, 50, 55, 58, 62)), (6, 1, (45, 52, 57, 62)),
              (7, 1, (45, 52, 57, 64)))
    for b, nb, notes in chords:
        mx.add(choir_chord(notes, nb * bar - 1.0, 3.0, 4.0, "oo"), b * bar, 0.55, 0, 0.7, name="choir")
        mx.add(pad_chord(notes[:3], nb * bar - 1.0, 3.5, 4.0, (250, 600, 300), 0.8, "soft"), b * bar, 0.3, 0, 0.4,
               name="pad")
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(wind_bed(L, 700 + seed, 900, 2400, 2.2, (4, 6), 2.0, 0.1), 0, 0.07, side * 0.8, 0.3, name="air")
    play_phrase(mx, MOTIF, D5, 2 * bar, 1.5, lambda m, d: v_glass(m, d, 0.6, 0.6), 0.17, 0.25, 1.2, 0.5, 3.0)
    mx.add(d_boom(36, 2.8), 0, 0.4, 0, 0.5, name="boom")
    mx.add(d_boom(33, 2.8), 4 * bar, 0.3, 0, 0.5, name="boom")
    mx.add(v_glass(93, 10.0, 4.0, 0.7), 5 * bar, 0.02, -0.4, 1.5, name="sing")
    return mx.render(rt=5.0, damp=0.4, size=1.6, predelay=0.05, dtime=1.5, dfb=0.4, dtaps=3, level=-20.0)


def music_safe_room(rng):
    """安全屋：72 BPM、16 小節。電鋼琴分解和弦＋溫暖的墊底音，鐘琴彈訊號動機；整首有一點老磁帶的晃動"""
    beat, bar, _ = bar_grid(72)
    L = 16 * bar
    mx = Mixer(L, 6.0)
    # (低音, 和弦音)
    prog = ((46, (58, 62, 65, 69)), (45, (57, 60, 65, 69)), (43, (58, 62, 65, 67)), (38, (57, 62, 64, 65)),
            (46, (58, 62, 65, 69)), (48, (55, 60, 62, 64)), (38, (57, 60, 62, 65)), (45, (55, 57, 62, 64)),
            (46, (58, 62, 65, 69)), (45, (57, 60, 65, 69)), (43, (58, 62, 65, 67)), (38, (57, 62, 64, 65)),
            (39, (55, 58, 62, 67)), (38, (58, 62, 65, 70)), (48, (55, 60, 65, 67)), (48, (55, 60, 64, 67)))
    arp = (0, 2, 1, 3, 2, 1, 3, 2)
    for b, (bass, ch) in enumerate(prog):
        t = b * bar
        mx.add(pad_chord(ch, bar, 0.6, 1.2, (400, 1150, 500), 0.8, "soft", 0.004), t, 0.24, 0, 0.35, name="pad")
        mx.add(v_sub(bass, bar * 0.95), t, 0.22, 0, 0.05, name="bass")
        for i, k in enumerate(arp):
            vel = 0.9 if i in (0, 4) else 0.6
            mx.add(v_ep(ch[k], 1.6, vel), t + i * beat / 2, 0.3 * vel, (-0.35, 0.35, -0.15, 0.15)[i % 4], 0.3, 0.15,
                   name="ep")
    bell = lambda m, d: v_glass(m, d, 0.006, 0.15)
    P = lambda *semis: tuple((b, d, s) for (b, d, _), s in zip(MOTIF, semis))
    lines = ((0, MOTIF), (2, P(5, 7, 3, 0)), (4, P(3, 5, 12, 10)), (6, ANSWER),
             (8, MOTIF), (10, P(8, 7, 3, 0)), (12, P(5, 8, 12, 10)), (14, P(5, 3, 2, -2)))
    for b, ph in lines:
        play_phrase(mx, ph, D5, b * bar, beat, bell, 0.3, 0.1, 0.5, 0.35, 2.0)
        if b >= 8:
            play_phrase(mx, ph, D4, b * bar, beat, lambda m, d: v_piano(m, d, 0.7), 0.22, -0.2, 0.4, 0.0, 2.5, "piano")
    for side, seed in ((-1, 1), (1, 2)):
        mx.add(noise_bed(L, 800 + seed, 3200, "hp", 0.7), 0, 0.012, side * 0.6, name="hiss")  # 磁帶底噪
    return mx.render(rt=2.2, damp=0.45, dtime=beat * 1.5, dfb=0.4, dtaps=3, level=-19.0,
                     tape_fx=(0.0016, 0.0004, qf(0.5, L), qf(6.1, L)))


def _duck(sig, times, depth=0.5, rel=0.22):
    """每個大鼓的時間點把音量壓一下再放開（抽吸感）"""
    e = [1.0] * len(sig)
    R = n(rel)
    shape = [1 - depth * (1 - j / R) ** 2 for j in range(R)]
    for t in times:
        o = int(round(t * SR))
        seg = e[o:o + R]
        e[o:o + len(seg)] = [min(a, b) for a, b in zip(seg, shape)]
    return mul(sig, e)


def music_chase(rng):
    """追逐：132 BPM、24 小節（A 8、B 8、C 8）。十六分音符低音音型用動機的音，B 段起主旋律就是動機"""
    beat, bar, s16 = bar_grid(132)
    bars = 24
    L = bars * bar
    mx = Mixer(L, 4.0)
    roots = [0, 0, 0, 0, -4, -4, -2, -5, 5, 5, -4, -4, 5, 5, -5, -5, 0, 0, 0, 0, -4, -4, -2, -5]
    P_MIN = (0, 0, 2, 0, 8, 0, 7, 0, 0, 0, 2, 0, 8, 7, 5, 3)
    P_MAJ = (0, 0, 2, 0, 7, 0, 5, 0, 0, 0, 2, 0, 7, 5, 4, 2)
    P_DOM = (0, 0, 1, 0, 8, 0, 7, 0, 0, 0, 1, 0, 8, 7, 4, 1)
    P_DOR = (0, 0, 2, 0, 9, 0, 7, 0, 0, 0, 2, 0, 9, 7, 5, 3)
    acc = (1.0, 0.55, 0.8, 0.55)
    kicks = []
    for b in range(bars):
        t = b * bar
        r = roots[b]
        pat = P_MAJ if r in (-4, -2) else P_DOM if r == -5 else P_DOR if r == 5 else P_MIN
        sec = b // 8
        for i in range(16):
            ti = t + i * s16
            mx.add(v_bass(D2 + r + pat[i], s16 * 1.15, 2000.0), ti, 0.5 * acc[i % 4], 0, 0.05, name="bass")
            if sec >= 1 and i % 2 == 0:
                mx.add(v_pluck(D4 + r + pat[i], s16 * 1.6), ti, 0.42 * acc[i % 4], 0.35 if i % 4 else -0.35, 0.3,
                       name="ostinato")
            hg = 0.26 * acc[i % 4] * (0.6 if sec == 0 and b < 2 else 1.0)
            if sec == 2 and i % 4 == 2:
                mx.add(d_hat(1, 0.07), ti, 0.16, 0.3, 0.1, name="hat")
            else:
                mx.add(d_hat(i % 3, 0.016), ti, hg, -0.3 if i % 2 else 0.3, 0.05, name="hat")
        for i in (0, 4, 8, 12) + ((14,) if b % 2 else ()):
            kicks.append(t + i * s16)
            mx.add(d_kick(48.0, 130.0, 0.15, 0.5), t + i * s16, 0.5 if i != 14 else 0.33, 0, 0.04, name="kick")
        if b >= 4:
            for i in (4, 12):
                mx.add(d_snare(i // 8), t + i * s16, 0.6, 0.05, 0.3, name="snare")
        elif b >= 2:
            mx.add(d_snare(1), t + 12 * s16, 0.3, 0.05, 0.3, name="snare")
        if b % 2 == 0:
            third = 4 if r in (-4, -2) else 3
            ch = (D4 + 12 + r, D4 + 12 + r + third, D4 + 12 + r + 7)
            for i in (0, 6) + ((11,) if sec else ()):
                mx.add(pad_chord(ch, 0.14, 0.006, 0.22, (2400.0, 3000.0, 1200.0), 1.0), t + i * s16, 0.36, 0, 0.35,
                       name="stab")
        if b % 8 == 7:  # 段落結尾：筒鼓過門
            for i, f in ((8, 150), (10, 130), (12, 110), (13, 100), (14, 85), (15, 72)):
                mx.add(d_tom(float(f), 0.16), t + i * s16, 0.5, (i - 11) / 6.0, 0.3, name="tom")
        if b % 8 == 6:  # 往上爬的不和諧音＋上升雜訊
            mx.add(pad_chord((D5, D5 + 1, D5 + 7, D5 + 13), 2 * bar - 0.1, 2 * bar - 0.3, 0.12, (500.0, 3000.0, 3000.0),
                             1.2), t, 0.14, 0, 0.3, name="rise")
            mx.add(riser(2 * bar, b, 300, 3200), t, 0.1, 0, 0.3, name="rise")
        if b % 8 == 0:
            mx.add(d_clang(147.0, 1.6, b), t, 0.22, 0.3 if b % 16 else -0.3, 0.8, name="metal")
            mx.add(d_boom(38, 1.8), t, 0.3, 0, 0.2, name="boom")
    # 主旋律：動機（附點節奏）。拍點單位 = 半拍
    LEAD = ((0, 3, 0), (3, 3, 2), (6, 5, 8), (12, 4, 7))
    LEAD_ANS = ((0, 3, 7), (3, 3, 5), (6, 5, 3), (12, 4, 2))
    for b, ph, top in ((8, LEAD, 0), (12, LEAD_ANS, 0), (16, LEAD, 1), (20, LEAD_ANS, 1)):
        for st, d, semi in ph:
            t = b * bar + st * beat / 2
            mx.add(v_lead(D5 + semi, d * beat / 2 * 0.95), t, 0.5, -0.1, 0.3, 0.35, name="lead")
            if top:
                mx.add(v_lead(D5 + 12 + semi, d * beat / 2 * 0.95), t, 0.22, 0.2, 0.3, 0.35, name="lead")
    N = int(round(L * SR))
    low = _duck(drone(L, D2 - 12, 0.6, 0.2), kicks, 0.7)
    mx.add(low[:N], 0, 0.15, name="drone")
    return mx.render(rt=1.3, damp=0.45, wet=0.9, dtime=beat * 0.75, dfb=0.4, dtaps=3, level=-19.0)


def music_boss_bear(rng):
    """苔原之母：100 BPM、16 小節、A 弗里吉安。3+3+2 的筒鼓、低音銅管動機，動機移到 A 用號角吹"""
    beat, bar, s16 = bar_grid(100)
    bars = 16
    L = bars * bar
    mx = Mixer(L, 5.0)
    A1 = 33
    kicks = []
    riff_a = ((0, 6, 0), (6, 2, 0), (8, 6, 1), (14, 2, -2))
    riff_b = ((0, 8, 0), (8, 4, 3), (12, 4, 1))
    for b in range(bars):
        t = b * bar
        fill = b % 4 == 3
        for i, f, g, pan in ((0, 62, 1.0, -0.25), (3, 82, 0.7, 0.3), (6, 100, 0.6, -0.4), (8, 62, 1.0, 0.25),
                             (11, 82, 0.7, -0.3), (14, 100, 0.6, 0.4)):
            if fill and i >= 8:
                continue
            mx.add(d_tom(float(f), 0.26), t + i * s16, 0.45 * g, pan, 0.35, name="toms")
        if fill:
            for j, i in enumerate(range(8, 16)):
                mx.add(d_tom(132.0 - 9 * j, 0.2), t + i * s16, 0.3 + 0.03 * j, (j - 3.5) / 5.0, 0.35, name="toms")
        for i in (0, 8, 10):
            kicks.append(t + i * s16)
            mx.add(d_kick(42.0, 110.0, 0.2, 0.7), t + i * s16, 0.55 if i != 10 else 0.35, 0, 0.1, name="kick")
        for i in (4, 12):
            mx.add(d_snare(i // 8, 0.14, 160.0), t + i * s16, 0.55, 0, 0.4, name="snare")
            mx.add(d_clang(310.0 if i == 4 else 275.0, 0.4, i), t + i * s16, 0.4, 0.2 if i == 4 else -0.2, 0.5,
                   name="clang")
        for i in range(0, 16, 2):
            mx.add(d_hat(i % 3, 0.03), t + i * s16, 0.11 if i % 4 else 0.16, 0.5 if i % 4 else -0.5, 0.1, name="shaker")
        for i, d, semi in (riff_b if b % 2 else riff_a):
            dur = d * s16 * 0.92
            mx.add(v_brass(A1 + semi, dur), t + i * s16, 0.5, -0.15, 0.25, name="brass")
            mx.add(v_brass(A1 + 12 + semi, dur, 1.2), t + i * s16, 0.45, 0.15, 0.25, name="brass")
            if b >= 8 and d >= 6:
                mx.add(v_brass(A1 + 19 + semi, dur, 1.3), t + i * s16, 0.22, 0.0, 0.3, name="brass")
        if b % 4 == 3:
            mx.add(normalize(bear_roar(random.Random("roar%d" % b))), t + 1.5 * beat, 0.4, 0.3 if b % 8 == 3 else -0.3, 0.6,
                   name="roar")
        if b % 4 == 0:
            mx.add(d_boom(36, 2.0), t, 0.3, 0, 0.3, name="boom")
            mx.add(d_clang(110.0, 1.8, b), t, 0.16, 0, 0.8, name="clang")
    horn = lambda m, d: v_brass(m, d, 1.5)
    play_phrase(mx, MOTIF, 57, 4 * bar, beat, horn, 0.3, 0.2, 0.5, 0.0, 0.0, "horn")
    play_phrase(mx, ANSWER, 57, 6 * bar, beat, horn, 0.3, 0.2, 0.5, 0.0, 0.0, "horn")
    play_phrase(mx, MOTIF, 57, 12 * bar, beat, horn, 0.28, 0.2, 0.5, 0.0, 0.0, "horn")
    play_phrase(mx, MOTIF, 69, 12 * bar, beat, horn, 0.2, -0.2, 0.5, 0.0, 0.0, "horn")
    play_phrase(mx, ANSWER, 57, 14 * bar, beat, horn, 0.28, 0.2, 0.5, 0.0, 0.0, "horn")
    play_phrase(mx, ANSWER, 69, 14 * bar, beat, horn, 0.2, -0.2, 0.5, 0.0, 0.0, "horn")
    N = int(round(L * SR))
    mx.add(_duck(drone(L, A1, 0.6, 0.2), kicks, 0.6)[:N], 0, 0.15, name="drone")
    mx.add(_duck(drone(L, A1 - 12, 0.6, 0.15), kicks, 0.6)[:N], 0, 0.1, name="drone")
    return mx.render(rt=1.9, damp=0.4, size=1.4, wet=0.9, predelay=0.03, level=-19.0)


def music_boss_well(rng):
    """深井：80 BPM、16 小節、G 小調。會脈動的合唱和聲、水晶琶音、很低的重擊，打擊樂越疊越多；動機移到 G"""
    beat, bar, s16 = bar_grid(80)
    bars = 16
    L = bars * bar
    mx = Mixer(L, 9.0)
    G4 = 67
    prog = ((0, 2, 43, (55, 58, 62, 67)), (2, 2, 39, (55, 58, 62, 65)), (4, 2, 36, (55, 58, 62, 63)),
            (6, 1, 38, (55, 57, 62, 67)), (7, 1, 38, (54, 57, 62, 66)),
            (8, 2, 43, (58, 62, 67, 70)), (10, 2, 39, (58, 62, 65, 70)), (12, 2, 36, (60, 63, 67, 69)),
            (14, 1, 38, (57, 62, 67, 69)), (15, 1, 38, (57, 62, 66, 69)))
    for b, nb, bass, ch in prog:
        t = b * bar
        hi = b >= 8
        mx.add(choir_chord(ch, nb * bar - 0.3, 1.2, 1.6, "ah" if hi else "oo", beat / 2, 0.35), t,
               0.62 if hi else 0.5, 0, 0.6, name="choir")
        mx.add(pad_chord(ch[:3], nb * bar - 0.3, 1.5, 1.8, (300.0, 1100.0 if hi else 700.0, 400.0), 0.9), t, 0.3, 0,
               0.4, name="pad")
        mx.add(v_sub(bass, nb * bar), t, 0.25, 0, 0.05, name="sub")
        mx.add(d_boom(34, 2.6), t, 0.5 if hi else 0.35, 0, 0.4, name="boom")
        steps = range(0, nb * 16, 2) if hi else [s for k in range(nb) for s in (k * 16, k * 16 + 6, k * 16 + 12)]
        for j, s in enumerate(steps):
            m = ch[(j * 3 + (j // 4)) % 4] + 12 + (12 if j % 5 == 3 else 0)
            mx.add(v_glass(m, 1.4, 0.004, 0.1), t + s * s16, 0.15, 0.5 if j % 2 else -0.5, 0.6, 0.5, name="crystal")
    for b in range(4, bars):
        t = b * bar
        if b < 8:
            mx.add(d_tom(66.0, 0.3), t, 0.45, -0.2, 0.5, name="perc")
            mx.add(d_tom(66.0, 0.3), t + 8 * s16, 0.3, 0.2, 0.5, name="perc")
        else:
            for i in (0, 8):
                mx.add(d_kick(40.0, 100.0, 0.22, 0.3), t + i * s16, 0.6, 0, 0.2, name="perc")
            for i, f in ((6, 90.0), (14, 74.0)) + (((12, 110.0), (13, 100.0), (15, 66.0)) if b % 2 else ()):
                mx.add(d_tom(f, 0.26), t + i * s16, 0.4, 0.3 if i % 4 else -0.3, 0.5, name="perc")
    for i in range(16):  # 最後一小節的小鼓滾奏，推回開頭
        mx.add(d_snare(i % 2, 0.08, 170.0), 15 * bar + i * s16, 0.05 + 0.02 * i, 0, 0.5, name="roll")
    mx.add(riser(bar, 15, 300, 3000), 15 * bar, 0.1, 0, 0.5, name="roll")
    gls = lambda m, d: v_glass(m, d, 0.12, 0.5)
    voice1 = lambda m, d: choir_chord((m,), d, 0.25, 0.6, "ah")
    play_phrase(mx, MOTIF, G4 + 12, 2 * bar, beat, gls, 0.2, 0.2, 0.8, 0.4, 2.0)
    play_phrase(mx, ANSWER, G4 + 12, 6 * bar, beat, gls, 0.2, -0.2, 0.8, 0.4, 2.0)
    play_phrase(mx, MOTIF, G4 + 12, 10 * bar, beat, gls, 0.22, 0.2, 0.8, 0.4, 2.0)
    play_phrase(mx, MOTIF, G4, 10 * bar, beat, voice1, 0.5, -0.1, 0.6, 0.2, 0.3, "solo")
    play_phrase(mx, ANSWER, G4 + 12, 14 * bar, beat, gls, 0.22, -0.2, 0.8, 0.4, 2.0)
    play_phrase(mx, ANSWER, G4, 14 * bar, beat, voice1, 0.5, 0.1, 0.6, 0.2, 0.3, "solo")
    N = int(round(L * SR))
    sing = [(a + 0.7 * b) * (0.5 + 0.5 * math.sin(TAU * 5 * i / N)) for i, (a, b) in
            enumerate(zip(sinw(qf(1568.0, L), N), sinw(qf(2349.3, L), N, 1.0)))]
    mx.add(sing, 0, 0.012, 0.3, 1.0, name="sing")
    mx.add(drone(L, 31, 0.4, 0.12), 0, 0.3, name="drone")
    return mx.render(rt=4.2, damp=0.35, size=1.5, predelay=0.04, dtime=beat * 0.75, dfb=0.45, dtaps=4, level=-19.0)


def music_ending(rng):
    """結局（不循環）：60 BPM、14 小節。鋼琴獨奏動機，低音弦樂，最後動機的降 B 變成 B（大調）解決在 D"""
    beat, bar, _ = bar_grid(60)
    L = 14 * bar
    mx = Mixer(L, 0.0)
    pno = lambda m, d: v_piano(m, d, 0.9)
    P = lambda *semis: tuple((b, d, s) for (b, d, _), s in zip(MOTIF, semis))
    chords = ((0, 2, 38, (50, 57, 64, 65)), (2, 2, 34, (46, 53, 57, 62)), (4, 2, 31, (43, 50, 53, 58, 57)),
              (6, 1, 33, (45, 52, 55, 62)), (7, 1, 33, (45, 52, 55, 61)), (8, 2, 38, (50, 57, 64, 66)),
              (10, 1, 31, (50, 55, 59, 62)), (11, 1, 38, (50, 57, 62, 66)), (12, 2, 38, (50, 57, 62, 66, 69)))
    for b, nb, bass, ch in chords:
        t = b * bar
        g = 0.2 + 0.025 * min(b, 9)
        mx.add(pad_chord(ch, nb * bar, 1.6, 2.4, (300.0, 700.0 + 60 * b, 420.0)), t, g, 0, 0.5, name="strings")
        mx.add(pad_chord((bass, bass + 12), nb * bar, 1.0, 2.0, (200.0, 420.0, 250.0), 0.8, "reed", 0.003), t, 0.35, 0,
               0.3, name="cello")
        mx.add(v_piano(bass, 6.0, 0.7), t, 0.4, -0.15, 0.4, name="piano_lh")
        if b >= 8:
            mx.add(v_piano(bass + 12, 6.0, 0.7), t + beat, 0.25, -0.1, 0.4, name="piano_lh")
            mx.add(v_piano(ch[1], 6.0, 0.7), t + 2 * beat, 0.25, 0.1, 0.4, name="piano_lh")
    lines = ((0, MOTIF), (2, ANSWER), (4, P(5, 7, 15, 14)), (6, P(14, 12, 9, 13)),
             (8, P(0, 2, 9, 7)), (10, P(7, 4, 2, 0)))
    for b, ph in lines:
        play_phrase(mx, ph, D4, b * bar, beat, pno, 0.6, 0.0, 0.5, 0.25, 3.5)
        if b >= 8:
            play_phrase(mx, ph, D5, b * bar, beat, pno, 0.3, 0.2, 0.5, 0.25, 3.5)
    mx.add(v_piano(D4, 8.0, 0.8), 12 * bar, 0.5, 0, 0.6, name="motif")
    mx.add(v_piano(D3, 8.0, 0.8), 12 * bar, 0.4, -0.1, 0.6, name="motif")
    mx.add(v_piano(D4 + 4, 8.0, 0.8), 12 * bar + 0.08, 0.3, 0.1, 0.6, name="motif")
    mx.add(v_glass(86, 14.0, 4.0, 0.7), 8 * bar, 0.035, 0.4, 1.5, name="sing")
    mx.add(v_glass(93, 12.0, 4.0, 0.7), 10 * bar, 0.028, -0.4, 1.5, name="sing")
    return mx.render(rt=3.2, damp=0.4, size=1.3, dtime=0.75, dfb=0.4, dtaps=3, loop=False, level=-20.0,
                     tape_fx=(0.0008, 0.0002, 0.45, 6.3), fade_out=7.0)


MUSIC = {"title": music_title, "explore_station": music_explore_station, "explore_outdoor": music_explore_outdoor,
         "safe_room": music_safe_room, "chase": music_chase, "boss_bear": music_boss_bear,
         "boss_well": music_boss_well, "ending": music_ending}


# ── 寫檔 ──────────────────────────────────────────────

def _job(job):
    kind, id_, v, count = job
    global SR
    SR = 44100 if kind == "sfx" else 32000  # 音效 44.1k（暫態、玻璃、雪的細節）；音樂、環境音 32k（多一點高頻空氣感，檔案不會太大）
    if kind == "sfx":
        name = id_ if count == 1 else "%s_%d" % (id_, v + 1)
        write("sfx", name, SFX[id_][0](random.Random("%s:%d" % (id_, v))), loop=id_ in LOOP_SFX)
    elif kind == "ambience":
        write_stereo("ambience", id_, AMBIENCE[id_](random.Random(id_)))
    else:
        write_stereo("music", id_, MUSIC[id_](random.Random(id_)))
    return kind, id_, v


def main():
    only = set(a for a in sys.argv[1:] if not a.startswith("-"))
    jobs = [("music", i, 0, 1) for i in MUSIC] + [("ambience", i, 0, 1) for i in AMBIENCE]
    for id_, (_, count) in SFX.items():
        jobs += [("sfx", id_, v, count) for v in range(count)]
    if only:
        jobs = [j for j in jobs if j[1] in only]
    unknown = only - set(j[1] for j in jobs)
    if unknown:
        sys.exit("沒有這個 id：" + ", ".join(sorted(unknown)))
    if len(jobs) > 1 and "--serial" not in sys.argv:
        import multiprocessing
        with multiprocessing.Pool(min(len(jobs), os.cpu_count() or 2)) as pool:  # 一個檔案一個工作，多核心一起算
            for kind, id_, v in pool.imap_unordered(_job, jobs):
                if v == 0:
                    print(kind, id_, flush=True)
    else:
        for job in jobs:
            print(*_job(job)[:2], flush=True)


if __name__ == "__main__":
    main()
