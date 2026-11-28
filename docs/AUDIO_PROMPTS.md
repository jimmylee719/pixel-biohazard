# AFTERSIGNAL／《迴頻》：音效與音樂提示詞

給生成影音的 agent 用的清單。**檔名就是表格裡的 id**，遊戲直接用檔名找聲音，名字錯了就不會出聲。
清單和程式裡的 `scripts/audio/sound_list.gd` 一致（測試會檢查）；要新增聲音時兩邊都要加。

## 1. 交付規則（請整段一起給生成 agent）

- **格式**：`.ogg`（最好）、`.mp3` 或 `.wav` 都可以。44.1 kHz。音效用單聲道（mono），音樂和環境音用立體聲。
- **放哪裡**：
  - 音效 → `assets/audio/sfx/<id>.ogg`
  - 音樂 → `assets/audio/music/<id>.ogg`
  - 環境音 → `assets/audio/ambience/<id>.ogg`
- **多個版本**：表格寫「×3」的，請做 3 個略有不同的版本，命名 `<id>_1.ogg`、`<id>_2.ogg`、`<id>_3.ogg`，遊戲會隨機挑，聽起來比較不重複。
- **頭尾**：音效開頭不要有空白（聲音要馬上出來），結尾自然收掉，不要長殘響（除非提示詞有寫）。
- **音量**：峰值大約 -1 dBFS，不要破音。不用自己調整各檔的相對大小，遊戲裡會調。
- **循環**：表格寫「循環」的，頭尾要能無縫接起來（不能有喀一聲或明顯斷點）。
- **原創**：不要模仿任何現有遊戲、電影的旋律、主題曲或招牌音效（例如特定遊戲的警報聲、存檔音樂）。
- **共通風格（音效）**：每一條音效提示詞前面都加上這段：
  > Realistic, dry, close-miked foley for a dark top-down survival horror game set in an Arctic research station. No music. Short, clean start.

- **共通風格（音樂）**：每一條音樂提示詞前面都加上這段：
  > Original dark ambient score for a survival horror game. Setting: an isolated Arctic island research station in 2026, polar night, blizzard, an ancient frozen bacterium whose colony "sings" on a radio frequency (126.05 MHz). Recurring motif: the five-note signal figure D, E, B-flat, rest, A. Palette: low bowed strings, detuned analog synth pads, prepared piano, metallic scrapes, sparse sub-bass pulses, distant processed choir. Cold, sparse, uneasy. No vocals with lyrics. Do not imitate any existing game or film theme.

## 2. 音效（sfx）

### 主角

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `step_concrete` | 0.3 秒 | ×4 | Single footstep of an insulated winter boot on a dusty concrete floor indoors, soft heel then toe. |
| `step_snow` | 0.35 秒 | ×4 | Single footstep crunching into dry, deep, compacted polar snow. |
| `step_metal` | 0.3 秒 | ×4 | Single footstep of a heavy boot on a metal grate catwalk, slight hollow ring. |
| `player_hurt` | 0.6 秒 | ×3 | A young woman's sharp pained grunt when struck, breathy, restrained, not screaming. |
| `player_death` | 1.5 秒 | ×1 | A young woman's final choked gasp and body collapsing onto a hard floor. |
| `shiver_breath` | 1.5 秒 | ×2 | A woman's shaky, shivering breath in extreme cold, teeth chattering lightly. |
| `locker_open` | 0.7 秒 | ×1 | A thin steel locker door creaking open, metal latch click. |
| `locker_close` | 0.6 秒 | ×1 | A thin steel locker door pulled shut from inside, muffled metal clunk. |
| `knock` | 0.4 秒 | ×2 | Two quick knuckle knocks on a metal-and-plaster wall panel. |

### 光

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `flashlight_click` | 0.15 秒 | ×1 | Rubberized flashlight push-button click. |
| `lighter_flick` | 0.5 秒 | ×2 | Metal flip-top lighter: lid opens, flint wheel strike, small flame catching. |

### 武器

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `pistol_shot` | 0.8 秒 | ×3 | A 9mm pistol shot inside a concrete corridor, sharp crack with a short hard room reflection. |
| `shotgun_shot` | 1.0 秒 | ×2 | A pump shotgun blast indoors, deep boom, short room reflection, shell rack at the end. |
| `gun_empty` | 0.2 秒 | ×1 | A pistol dry-fire click on an empty chamber. |
| `reload` | 1.2 秒 | ×1 | Pistol reload: magazine released, new magazine inserted, slide racked. |
| `knife_swing` | 0.3 秒 | ×2 | A short combat knife slashing through cold air, quick whoosh. |
| `knife_hit` | 0.4 秒 | ×2 | A knife stabbing into frozen flesh with a brittle, icy crunch. |
| `bullet_hit_flesh` | 0.3 秒 | ×3 | A bullet hitting a frozen body: dull thud with crackling ice shards. |
| `punch_hit` | 0.3 秒 | ×3 | A hard gloved punch landing on a body, meaty thump with a little ice crackle. |
| `kick_hit` | 0.4 秒 | ×2 | A heavy boot kick to a body, deep thud and a grunt of air knocked out. |
| `body_slam` | 0.7 秒 | ×2 | A body slammed hard onto a concrete floor or into a wall, heavy impact with gear rattling. |
| `grab` | 0.4 秒 | ×1 | Grabbing someone from behind: fabric rustle, a firm grip, a muffled struggle breath. |

### 投擲與環境互動

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `throw_whoosh` | 0.3 秒 | ×1 | A small object thrown overhand, short airy whoosh. |
| `stone_land` | 0.4 秒 | ×3 | A fist-sized stone landing and bouncing twice on a concrete floor. |
| `bottle_break` | 0.7 秒 | ×2 | A glass bottle smashing on concrete, shards scattering. |
| `molotov_ignite` | 1.2 秒 | ×1 | Fuel splashing and bursting into flame with a whoomp, then crackling. |
| `fire_loop` | 4 秒 | 循環 | A small fire of burning fuel and debris, steady crackle and flutter. Seamless loop. |
| `extinguisher_spray` | 0.8 秒 | ×1 | A CO2 fire extinguisher discharging a short hard burst, hissing spray. |
| `extinguisher_clang` | 0.9 秒 | ×1 | A heavy steel fire extinguisher dropped onto concrete, loud metallic clang and roll. |
| `wood_break` | 0.8 秒 | ×2 | A wooden crate or plank barricade smashed apart, splintering wood. |
| `drum_ignite` | 1.5 秒 | ×1 | An oil drum of fuel catching fire, deep whoosh into a roaring flame. |

### 物件

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `pickup_item` | 0.4 秒 | ×2 | Picking up a small item and zipping it into a backpack pocket. |
| `pickup_key` | 0.4 秒 | ×1 | Picking up a plastic keycard on a metal lanyard, small jingle. |
| `door_open` | 1.0 秒 | ×2 | A heavy insulated steel door unlatching and swinging open, cold wind rushing in briefly. |
| `door_locked` | 0.5 秒 | ×1 | A locked steel door handle rattling, plus a short low electronic denial buzz. |
| `stairs` | 1.0 秒 | ×1 | Several quick footsteps on metal stairs. |
| `generator_start` | 3.0 秒 | ×1 | A diesel generator pull-started: sputter, cough, then catching into a steady hum. |
| `breaker_switch` | 0.6 秒 | ×1 | A large industrial breaker lever thrown, heavy clack and an electrical hum rising. |
| `terminal_beep` | 0.4 秒 | ×1 | An old computer terminal acknowledging input: two soft low beeps. |
| `radio_static` | 1.5 秒 | ×2 | Shortwave radio static burst with faint garbled transmission underneath. |
| `radio_tune` | 0.2 秒 | ×1 | A radio tuning dial clicking one notch with a tiny static chirp. |
| `save_chime` | 1.2 秒 | ×1 | A calm, low, two-note electronic chime from an old radio set, reassuring but cold. Original, not a known game save sound. |
| `snowcat_engine` | 3.0 秒 | ×1 | A tracked snowcat vehicle's diesel engine starting and revving, tracks starting to move. |
| `lift_machinery` | 3.0 秒 | ×1 | An industrial mine-shaft lift cage starting to descend: heavy motor whine, chains, clanks. |
| `uplink_transmit` | 2.5 秒 | ×1 | A satellite uplink transmitting: rising electronic tone, modem chirps, a final lock-on beep. |

### 敵人

背景：敵人是被古菌「霜鳴菌」感染、半結冰的人和動物。牠們的聲音要有「冰裂、結晶摩擦、走音的鳴響」，不要做成一般殭屍。

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `watcher_groan` | 1.5 秒 | ×3 | An infected, half-frozen man's low wet groan, with brittle ice crackling in the throat. Unsettling, not a cartoon zombie. |
| `watcher_attack` | 0.6 秒 | ×2 | An infected half-frozen man's sudden rasping snarl as it lunges. |
| `listener_click` | 0.3 秒 | ×3 | Rapid clicking like cracking ice and insect mandibles, used by a blind creature for echolocation. |
| `listener_shriek` | 1.5 秒 | ×1 | A blind infected creature's piercing, glassy shriek that resonates like a wet finger on crystal, alarming. |
| `sleeper_wake` | 1.5 秒 | ×2 | A frozen body cracking free from an ice crust, joints popping, a sudden sharp inhale. |
| `enemy_hurt` | 0.5 秒 | ×3 | An infected creature's pained hiss mixed with ice cracking. |
| `enemy_death` | 1.2 秒 | ×2 | An infected creature collapsing: final rattling breath, body shattering partly like ice on the floor. |
| `enemy_burn` | 1.0 秒 | ×2 | An infected creature screeching while fire hisses against frozen flesh, steam. |
| `bear_roar` | 2.0 秒 | ×2 | A huge infected polar bear's roar, deep and distorted with crackling ice and a glassy overtone. |
| `bear_charge` | 1.5 秒 | ×1 | A massive animal charging across a concrete hangar floor, heavy thundering paws, huffing. |
| `well_pulse_charge` | 2.5 秒 | ×1 | A giant crystal organism charging a pulse: rising choir-like hum of resonating crystals, building pressure. |
| `well_pulse_blast` | 1.5 秒 | ×1 | A shockwave of resonant crystal sound releasing, deep boom with shattering glass tails. |
| `well_crystal_crack` | 1.0 秒 | ×1 | Massive crystal shell cracking open, exposing a wet core, deep fracture sound. |

### 介面與提示

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `alert_sting` | 1.0 秒 | ×1 | A sudden horror stinger when the player is spotted: sharp dissonant string stab plus a low metallic hit. Original, not a known game alert sound. |
| `suspicious_sting` | 0.8 秒 | ×1 | A quiet uneasy cue that an enemy noticed something: soft rising bowed metal tone. |
| `ui_move` | 0.08 秒 | ×1 | A tiny dry tick for moving a menu cursor, like a small mechanical switch. |
| `ui_confirm` | 0.2 秒 | ×1 | A short muted confirmation click with a soft low electronic blip. |
| `ui_cancel` | 0.2 秒 | ×1 | A short muted lower-pitched click for closing a menu. |
| `mission_complete` | 1.5 秒 | ×1 | A restrained, cold, low synth chord swelling briefly to mark an objective completed. Not triumphant. |

### v0.16 追加

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `revolver_shot` | 1.1 秒 | ×2 | A .357 revolver gunshot indoors: heavier and lower than a 9mm pistol, sharp crack, long concrete-corridor tail, faint metallic ring of the cylinder. |
| `rifle_shot` | 1.6 秒 | ×2 | A hunting rifle shot: supersonic crack, deep heavy boom, distant outdoor echoes off ice cliffs. |
| `smg_shot` | 0.4 秒 | ×3 | A single short submachine gun shot, bright and tight, quick decay so automatic fire stays distinct. |
| `suppressed_shot` | 0.4 秒 | ×3 | A suppressed pistol shot: muffled low puff, no crack, a small metallic slide clack. |
| `crossbow_shot` | 0.5 秒 | ×2 | A crossbow firing: taut bowstring thrum, wooden stock clack, short arrow whoosh. |
| `nailgun_shot` | 0.25 秒 | ×2 | A pneumatic nail gun: sharp air hiss, metallic nail thunk, plastic body clack. |
| `flare_shot` | 1.0 秒 | ×1 | A flare gun firing: hollow pop, then a burning hiss flying away. |
| `step_wood` | 0.3 秒 | ×4 | Single boot footstep on old hollow wooden floorboards, low resonant thud, occasional small creak. |
| `step_carpet` | 0.25 秒 | ×4 | Single soft boot footstep on thick carpet, muffled, mostly low thump and faint fabric. |
| `choke_struggle` | 1.2 秒 | ×3 | A man being choked from behind: strained muffled grunts and broken gasps through a compressed throat, clothing rustle. Not graphic. |
| `crystal_resonance` | 1.6 秒 | ×2 | A brittle crystal shattering inside a body, then a dissonant glassy ringing chord that swells, beats slowly and fades. |
| `radio_song` | 2.8 秒 | ×2 | A short-wave radio playing a strange five-note tone melody (D, E, B-flat, rest, A) through heavy static and wobbling tape pitch. |

### v0.17 追加（唱潮）

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `tide_warning` | 3.4 秒 | ×1 | Radio static slowly swelling over a deep falling hum, with a faint five-note tone melody (D, E, B-flat, rest, A) buried in the noise. Ominous warning, not a jump scare. |
| `tide_siren` | 10 秒 | ×1 | A distant Cold War hand-cranked air-raid siren across a frozen island: slow wind-up, long wavering high tone, slow wind-down, huge cold echo off ice cliffs, faint wind. |
| `tide_end` | 6 秒 | ×1 | The same distant air-raid siren winding down to silence, rotor slowing, echo fading into wind. |

## 3. 音樂（music）

全部做成**可以無縫循環**（`ending` 除外）。長度是建議值。

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `title` | 90 秒 | 循環 | Title screen theme. Slow, lonely, a single prepared piano motif over wind-like synth pads and distant low strings; a faint glassy "singing" crystal tone appears and fades. Melancholic and ominous. |
| `explore_station` | 120 秒 | 循環 | Indoor exploration in a dark, half-powered research station. Very sparse: low drones, ventilation-like noise, occasional metallic creaks and soft dissonant piano notes. Tension without rhythm. Must stay in the background. |
| `explore_outdoor` | 120 秒 | 循環 | Outdoor exploration in a polar-night blizzard. Vast and empty: deep sub drones, airy synth swells, faint distant choir, very slow. Mostly texture, no melody. |
| `safe_room` | 90 秒 | 循環 | Safe room theme. Calm, warm but fragile: soft felt piano and a gentle low synth pad, slow tempo, slightly sad. A moment to breathe. Original. |
| `chase` | 60 秒 | 循環 | Being hunted. Urgent pulsing low percussion (around 120 BPM), aggressive short string ostinato, metallic hits, rising dissonance. Can start abruptly. |
| `boss_bear` | 90 秒 | 循環 | Boss fight in a cold aircraft hangar against a giant infected polar bear. Heavy tribal-industrial drums, huge low brass-like synth stabs, distorted roaring textures. Driving and dangerous. |
| `boss_well` | 120 秒 | 循環 | Final boss at the bottom of a drill shaft against a giant singing crystal organism. Eerie choir-like crystal harmonics that swell and pulse, deep sub-bass hits, slow building percussion, tragic and enormous. |
| `ending` | 90 秒 | 不循環 | Ending theme. Slow solo piano with low strings, quiet and bittersweet, a faint return of the crystal "singing" tone, resolving softly at the end. |

## 4. 環境音（ambience）

全部**無縫循環**，沒有旋律。

| id | 長度 | 版本 | 提示詞 |
|---|---|---|---|
| `amb_blizzard` | 60 秒 | 循環 | Polar blizzard outdoors at night: strong howling wind gusts, blowing snow hiss, occasional distant metal rattling. No music. Seamless loop. |
| `amb_station_hum` | 60 秒 | 循環 | Inside a powered research station: low electrical hum, ventilation air flow, faint fluorescent buzz, occasional distant pipe tick. No music. Seamless loop. |
| `amb_station_dark` | 60 秒 | 循環 | Inside an unpowered, freezing research station: muffled wind outside the walls, building creaks, dripping water, faint ice cracking. No music. Seamless loop. |
| `amb_shaft` | 60 秒 | 循環 | Deep inside an icy drill shaft: cavernous low rumble, dripping water echoing, faint resonating crystal tones far below. No music. Seamless loop. |

## 5. 優先順序

如果要分批生，建議照這個順序（玩起來差最多的先做）：

1. `step_*`、`pistol_shot`、`knife_*`、`alert_sting`、`door_open`、`ui_*`
2. 敵人全部（`watcher_*`、`listener_*`、`sleeper_wake`、`enemy_*`）
3. 環境音 4 個、音樂 `explore_station`、`explore_outdoor`、`chase`、`safe_room`
4. 其他音效
5. Boss 相關、`title`、`ending`
