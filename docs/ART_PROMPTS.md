# 美術生圖提示詞（ComfyUI 用）— DEEPWAKE／《驚蟄》

> 用途：你用 ComfyUI 大量生圖，我負責挑選、縮小、量化調色盤、去背，再套進遊戲。
> 說明用繁體中文；**提示詞一律用英文**（SD／Flux 類模型對英文最穩定），直接複製程式碼區塊即可。
> 世界觀依據：[GDD.md](GDD.md) 第 10 節、[SERIES_BIBLE.md](SERIES_BIBLE.md)。

---

## 1. 技術規格（全部美術統一遵守）

| 項目 | 規格 |
|---|---|
| 遊戲解析度 | 480×270（整數倍放大到 1280×720 以上） |
| 地圖格 | 16×16 像素 |
| 鏡頭 | 高角度 3/4 俯視（約 60 度），**正交投影、沒有透視**：上下左右的線都是平行的，看得到牆頂和牆面上半部、角色的頭頂和正面 |
| 主角、人形敵人 | 遊戲內身高約 16×24 像素，畫在 **24×32** 的格子裡（腳底對齊格子底部往上 2 像素） |
| 鳴骨者 | 24×32（駝背、比人形略寬） |
| 凍眠體（躺姿） | 32×16 |
| 中期 Boss 北極熊 | 約 64×48 |
| 最終 Boss「深井」 | 大型、拆成多個部件（核心、結晶觸手、井壁結晶），每個部件 32～96 像素 |
| 物品欄圖示 | 16×16（另外生，不是地圖上的道具圖） |
| 對話／文件頭像 | 64×64 |
| 方向 | 8 方向移動，但只需要 **5 個獨特方向**：下、右下、右、右上、上。左側三個方向由程式左右鏡像 |

### 角色需要的動作（之後我會用單張方向圖延伸成動畫）

| 角色 | 動作 |
|---|---|
| 主角 沈若寧 | 待機、走、跑、潛行（蹲低）、舉槍、受傷、倒下、躲進櫃子（開門那一格）、撿東西、投擲 |
| 值班者（巡邏型） | 待機（站著微晃）、走（巡邏）、張望、追擊（快走前傾）、攻擊（抓）、受傷、倒下 |
| 鳴骨者（聽覺型） | 待機（頭部微抖、胸口結晶發光）、慢走、「聆聽」（頭側傾）、尖鳴（張口）、衝刺、攻擊、倒下 |
| 凍眠體（伏擊型） | 躺著（偽裝屍體）、甦醒起身、爬行撲擊、倒下 |
| 北極熊 Boss | 待機、走、聆聽、衝撞、拍擊、受傷、倒下 |
| 深井 最終 Boss | 核心脈動、結晶觸手伸出、共鳴（全身發光）、受損碎裂 |

---

## 2. 統一風格提示詞（每張圖都要加）

### 2.1 正向風格（放在提示詞最前面或最後面都可以，整個專案固定不變）

```text
pixel art, 16-bit era survival horror game asset, high top-down 3/4 view, orthographic camera, no perspective, clean pixel clusters, limited palette, cold desaturated blue-grey tones, subtle rim light, dark atmospheric lighting, crisp silhouette, readable at small size, flat solid background
```

### 2.2 負向提示詞（整個專案固定不變）

```text
mushroom, fungus, fungal growth, spores, cordyceps, mycelium, rotting zombie, decayed flesh, excessive gore, blood splatter, umbrella logo, corporate logo, biohazard symbol, military tactical gear, sneaking suit, bandana, anime, manga, chibi, cute, 3d render, octane, unreal engine, photorealistic, blurry, soft focus, jpeg artifacts, perspective distortion, fisheye, isometric diamond grid, dithering noise, gradient background, text, watermark, signature, multiple characters, cropped, extra limbs
```

> 為什麼排除這些：真菌、孢子、蟲草會太像 *The Last of Us*；殭屍腐爛、雨傘標誌、生化標誌會太像惡靈古堡；潛入裝、頭巾、軍事潛行裝備會太像潛龍諜影。我們的怪物是**骨骼長出結晶**，不是長菇也不是腐爛。

### 2.3 世界觀關鍵詞（依需要加在個別提示詞裡）

```text
arctic research station, year 2031, polar night, concrete and steel interior, fluorescent tube lights, frosted glass, ice core samples, laboratory equipment, mineralized translucent crystal bone growths, cold cyan-white crystal glow
```

### 2.4 調色盤（32 色）

我會把所有成品量化到這組調色盤。生圖時不用完全遵守，但色調方向要對：**冷藍灰的混凝土和雪、手電筒的暖黃、結晶的冷青白，警示紅只用一點點**。

| 用途 | HEX |
|---|---|
| 黑暗與混凝土（11） | `#0b0d12` `#151a22` `#1f2630` `#2b3440` `#3a4552` `#4b5866` `#5f6d7b` `#7a8896` `#9aa8b4` `#c0cad2` `#e4ebf0` |
| 雪與冰（4） | `#2a4a66` `#3f6f8f` `#6a9fbf` `#a8d4ea` |
| 霜鳴菌結晶（3） | `#3ec8d0` `#8af0f0` `#d8fffa` |
| 手電筒、暖光（3） | `#ffe9b0` `#f4c46a` `#c98a3c` |
| 膚色（3） | `#f0c8a8` `#d39a7a` `#9a6450` |
| 主角服裝亮橘（2） | `#e0702a` `#a84a1c` |
| 木頭、鏽（2） | `#6b4a32` `#3e2a1e` |
| 警示紅（2，少量） | `#c8323a` `#7a1c24` |
| 感染者皮膚灰紫（2） | `#8c8296` `#5a5262` |

---

## 3. 生圖流程（照這樣做最省力）

1. **用高解析生圖**（例如 1024×1024），加一個 pixel art LoRA。不要直接生 24×32 的小圖，AI 生不出乾淨的像素格。
2. **先生「角色設定圖」**：同一張圖裡畫正面、背面、側面、3/4 視角（turnaround）。這張是用來**鎖定角色長相**的參考，不會直接放進遊戲。
3. **再生「單一方向單張」**：用設定圖當參考（IPAdapter 或 reference only）、固定 seed，一次只生一個方向、一個姿勢。這種圖我會切成遊戲用的精靈。
4. **不要叫 AI 一次生出整張動畫 sprite sheet**：格子對不齊、角色每格長得不一樣，處理起來比重畫還麻煩。動畫我會用單張方向圖延伸（或之後再補生關鍵格）。
5. **背景一律純色**（建議純洋紅 `#ff00ff` 或純綠），方便我去背。
6. 交給我之後，我會用工具做：**最近鄰縮小 → 量化到 32 色調色盤 → 去背 → 修邊**，最後放進 `assets/`。

### 一致性小技巧
- 同一個角色：固定 seed、固定角色描述句（下面每個角色都有一段「角色描述」，每次原封不動貼上）。
- 有 IPAdapter 就拿第 2 步的設定圖當參考圖，權重 0.6～0.8。
- 方向寫法統一用：`facing down toward camera`、`facing down-right`、`facing right, side view`、`facing up-right, back three-quarter view`、`facing up, back view`。

---

## 4. 檔案與資料夾

```
art_raw/                     ← 你生的原始大圖（不進 git，我之後會加進 .gitignore）
  characters/shen_ruoning/
  enemies/watcher/
  enemies/listener/
  enemies/frozen/
  bosses/bear/
  bosses/deepwell/
  tiles/
  props/
  icons/
  portraits/
  key_art/
assets/                      ← 我處理好的成品（會進 git，用 Git LFS）
  sprites/characters/
  sprites/enemies/
  sprites/bosses/
  tiles/
  props/
  ui/icons/
  ui/portraits/
```

**命名規則**：`種類_名稱_動作_方向_編號.png`，全部小寫英文、底線分隔。例如：
- `player_shen_walk_downright_01.png`
- `enemy_listener_idle_down_01.png`
- `tile_concrete_floor_01.png`
- `prop_locker_closed_01.png`
- `icon_antibacterial_01.png`

原始大圖你不用照規則命名，**放進對應的 `art_raw/` 資料夾就好**，可以一個資料夾丟很多張。我會挑選、處理、套用，不合用的我會告訴你原因（例如視角不對、太像某部作品、看不清楚輪廓），你再重生。

---

## 5. 各項提示詞（依優先順序）

### 優先 1：主角 沈若寧

**角色描述（每次原封不動貼上）**

```text
Shen Ruoning, 34-year-old Taiwanese woman, supply helicopter pilot, short black hair tied back, tired determined face, bright orange insulated flight jacket with reflective strips, dark grey cargo trousers, black snow boots, headset hanging around neck, small chest flashlight clipped to jacket, fingerless gloves, slim practical build, not a soldier
```

**角色設定圖（鎖定長相用）**

```text
character turnaround sheet, same character shown from front, back, left side and three-quarter view, standing neutral pose, full body, evenly spaced, [角色描述], [正向風格], solid magenta background
```

**5 方向單張（每個方向各生幾張）**

```text
single character sprite, full body, standing idle pose, facing down toward camera, [角色描述], [正向風格], solid magenta background, centered
```
把 `facing down toward camera` 依序換成：`facing down-right` → `facing right, side view` → `facing up-right, back three-quarter view` → `facing up, back view`。

**動作變化**：把 `standing idle pose` 換成：
`walking mid-stride` ／ `running, leaning forward` ／ `crouching low, sneaking` ／ `aiming a handgun forward with both hands` ／ `recoiling in pain` ／ `collapsed on the floor` ／ `throwing a small glass bottle overhand` ／ `bending down to pick something up`

**頭像 64×64**

```text
pixel art character portrait, head and shoulders, [角色描述], cold blue rim light from the side, warm flashlight glow from below, worried expression, dark background, [正向風格]
```
可以多生幾種表情：`worried` ／ `exhausted` ／ `determined` ／ `terrified` ／ `in pain`。

---

### 優先 2：敵人

#### 值班者（巡邏型）— 早期感染的研究站人員

```text
infected arctic research station staff member, wearing a stained white lab coat over a thick grey sweater, ID lanyard, milky clouded eyes, pale grey-violet skin, small translucent cyan crystal growths breaking through the jaw and collarbone, stiff slow posture, arms slightly raised, still recognizably human
```
- 設定圖：同上方主角的「角色設定圖」模板，把角色描述換成這段。
- 5 方向單張：同主角模板。
- 動作：`slow patrol walk` ／ `stopping and turning head, listening` ／ `lunging forward to grab` ／ `staggering hit` ／ `collapsed`
- 可以多生一兩種變體：`maintenance worker in dark blue coveralls`、`cook in white apron` ，讓同一種敵人有不同外觀。

#### 鳴骨者（聽覺型）— 晚期感染者，全盲

```text
late-stage infected human, completely blind with eyes sealed over by smooth crystal, hunched forward posture, jaw and ribcage overgrown with large translucent cyan-white crystal bone formations that faintly glow, torn research station clothing, thin elongated fingers, head tilted as if listening intently, unsettling but not gory
```
- 動作：`idle, head twitching, chest crystals glowing` ／ `slow cautious walk` ／ `head tilted sideways, listening` ／ `mouth wide open, shrieking` ／ `sprinting on all fours` ／ `slashing attack` ／ `shattered and collapsed`

#### 凍眠體（伏擊型）— 看起來像凍僵的屍體

```text
frozen body lying on the floor, covered in frost and thin ice, curled up, wearing an old parka, subtle translucent crystal veins under frozen skin, looks like an ordinary frozen corpse at first glance, top-down view, lying pose
```
- 需要：`lying still, dormant`（這張最重要，要跟一般屍體只差一點點）、`waking up, head lifting`、`crawling forward rapidly`、`lunging`。
- 另外請生 2～3 張**真正的普通凍屍**（同樣提示詞，去掉 `crystal veins`），我要讓兩者混在一起擺放。

---

### 優先 3：研究站室內地圖格

> 地圖格請生「一大張無縫材質」或「一整片俯視地板」，我會切成 16×16。牆面要有 3/4 俯視的**牆頂**（上方一條）和**牆面**（下方垂直面）。

```text
seamless tileable texture, top-down view, [材質], [正向風格], no objects, even lighting
```
把 `[材質]` 依序換成：
- `worn grey concrete floor with hairline cracks`
- `white laboratory floor tiles, slightly dirty grout`
- `metal grating floor panels over dark pipes`
- `frost-covered concrete floor with thin ice patches`（關暖氣後的結霜地板）
- `rubber anti-slip floor mat, dark grey`

**牆面（3/4 俯視）**

```text
pixel art wall tileset, high top-down 3/4 view, concrete wall with visible top edge and vertical front face, painted lower half in pale blue-grey, exposed pipes and cable trays, [正向風格], solid magenta background
```
變化：`laboratory wall with observation window` ／ `steel bulkhead wall with rivets` ／ `wall with frosted window showing snowstorm outside`

**門**

```text
pixel art door sprite, high top-down 3/4 view, heavy insulated steel door with small window and keycard reader, [closed / half open / open], [正向風格], solid magenta background
```

---

### 優先 4：道具（地圖上擺的物件）

```text
pixel art game prop, high top-down 3/4 view, [道具], [正向風格], solid magenta background, single object, centered
```
把 `[道具]` 換成：
- `tall steel locker, closed`／`tall steel locker, door open, empty inside`（躲藏用）
- `low metal filing cabinet`
- `laboratory bench with microscope and sample racks`
- `wall-mounted electrical breaker panel with lever and small indicator light`
- `ice core storage rack with frosted cylindrical ice cores`
- `metal bunk bed with crumpled blanket`
- `empty glass bottle lying on floor`
- `cardboard supply boxes stacked`
- `emergency radiator heater`
- `overturned office chair`
- `cryogenic sample freezer, humming`
- `radio communication console with dials`

#### 物品欄圖示（16×16，另外生）

```text
pixel art inventory icon, single item, front view, bold outline, high contrast, [物品], [正向風格], solid black background, centered
```
把 `[物品]` 換成：
- `empty glass bottle`
- `antibacterial injector syringe with cyan liquid`（抗菌藥劑）
- `small first aid kit`（小型回復）
- `large medical pack`（大型回復）
- `handgun ammunition box`
- `shotgun shells`
- `research station keycard with color stripe`（之後要 4 種顏色：`blue`、`yellow`、`red`、`white`）
- `flashlight battery`
- `fire axe`（近戰武器）
- `compact handgun`
- `pump shotgun`
- `handwritten research note`

---

### 優先 5：Boss

#### 中期 Boss：被感染的北極熊（約 64×48）

```text
massive infected polar bear, blind eyes covered by crystal, huge translucent cyan-white crystal formations erupting along the spine and shoulders like a ridge, matted yellowish-white fur, frost on fur, head tilted listening, menacing but grounded in biology, high top-down 3/4 view
```
- 設定圖：`creature turnaround sheet, front, side, back and three-quarter view`＋上面描述。
- 單張：5 方向的 `standing`、`charging forward`、`swiping paw`、`rearing up roaring`、`collapsed`。

#### 最終 Boss：深井（鑽探井底的結晶菌落）

```text
colossal crystal colony at the bottom of a deep drilling shaft, fused remains of several researchers merged into a resonating mass of translucent cyan-white crystal bone, glowing core pulsing inside, crystal tendrils reaching up the concrete shaft walls, maintenance ladder on the wall, view from above looking down the shaft, [正向風格]
```
- 另外請生**拆開的部件**（我要分開做動畫）：`glowing crystal core alone`、`single crystal tendril`、`crystal growth cluster on concrete wall`。
- 再生一張**垂直剖面視角**（最終戰的特殊鏡頭）：把 `view from above looking down the shaft` 換成 `side cross-section view of the vertical shaft`。

---

### 優先 6：頭像、主視覺、背景

**其他角色頭像（64×64）**：同主角頭像模板，換角色描述：
- 站長：`middle-aged station director, grey beard, thick glasses, guilty exhausted expression, wool sweater`
- 艾娜・科瓦契：`female microbiologist in her 40s, Eastern European features, short ash-blond hair, sharp eyes, lab coat over turtleneck`
- 典藏者：`mysterious figure in a dark parka hood, face mostly hidden in shadow, only a radio headset visible`

**標題畫面主視覺**

```text
pixel art key art, lone research station on a dark arctic island cliff during polar night, blizzard, a single warm window light, collapsing permafrost cliff beside the building, faint cyan glow from cracks in the ice below, a small figure in an orange jacket walking toward the station from a damaged helicopter, wide shot, [正向風格]
```

**選單背景**

```text
pixel art background, dim research station corridor, flickering fluorescent tube, frost creeping along the walls, faint cyan crystal glow at the far end, empty and quiet, high top-down 3/4 view, [正向風格]
```

**戶外暴風雪場景（開場直升機降落）**

```text
pixel art scene, high top-down 3/4 view, snowy helipad at an arctic research station at night, damaged supply helicopter, heavy blowing snow, floodlight casting warm cone of light, concrete building entrance with cargo door, [正向風格]
```

---

## 6. 第一批請先生這些（原型馬上用得到）

1. 主角 沈若寧：角色設定圖（turnaround）
2. 主角：5 方向 待機
3. 主角：5 方向 走路
4. 主角：5 方向 潛行（蹲低）
5. 值班者：角色設定圖
6. 值班者：5 方向 巡邏走路
7. 鳴骨者：角色設定圖
8. 鳴骨者：5 方向 慢走＋「聆聽（頭側傾）」
9. 地板材質：混凝土、實驗室磁磚、結霜混凝土
10. 3/4 俯視牆面（混凝土牆）
11. 道具：置物櫃（關／開）、實驗桌、低櫃
12. 道具：配電箱、地上的空瓶
13. 物品欄圖示：空瓶、抗菌藥劑、小型回復
14. 主角頭像（3 種表情）

每一項可以多生幾張（例如 4～8 張），我會挑最好的那張；不需要每張都完美。

---

## 7. 第二批（2026-11-25）：第一批已經進遊戲，接下來要這些

### 7.1 第一批的經驗（第二批請照這樣生，去背和縮圖會乾淨很多）
- **背景一律用純洋紅色 `#FF00FF`、完全平的、不要漸層、不要地面陰影**。灰藍色背景和角色褲子顏色太接近，去背時容易吃到身體；地面投影會留下雜點。
  在正向提示詞最後加上：`solid flat magenta background #FF00FF, no ground shadow, no cast shadow`
- **背面（up、upright）**：第一批 v1 很多還是正面。v3 的寫法有效，請沿用：`seen from behind, back view, back of head visible, face not visible`。
- 每張只要 **一個角色、置中、全身入鏡、上下留一點空白**。
- 一個方向兩張（_01、_02）就能做成兩格動畫；動作差異要明顯（走路左右腳交替）。
- 檔名規則照舊：`<角色>_<動作>_<方向>_<編號>`，放進 `art_raw/` 對應的資料夾。工具 `tools/import_art.gd` 會自動處理。

### 7.2 主角 沈若寧（補動作，5 個方向：down、downright、right、upright、up，各 2 張）
```text
pixel art game sprite, young East Asian woman helicopter pilot, orange insulated flight jacket with reflective stripes, dark cargo pants, aviation headset around neck, black ponytail, RUNNING pose, leaning forward, long stride, arms swinging, facing {DIRECTION}, full body, single character, centered, solid flat magenta background #FF00FF, no ground shadow
```
```text
pixel art game sprite, same pilot woman, AIMING A PISTOL with both hands, arms extended, steady stance, facing {DIRECTION}, full body, single character, centered, solid flat magenta background #FF00FF, no ground shadow
```
```text
pixel art game sprite, same pilot woman, THROWING motion, one arm raised behind head about to throw a glass bottle, facing {DIRECTION}, full body, single character, centered, solid flat magenta background #FF00FF, no ground shadow
```
- 另外各 1 張（方向用 down 就好）：受傷後仰（`flinching, hit, recoiling backward`）、倒地（`collapsed lying on the ground, top-down view`）、拿著滅火器（`holding a red fire extinguisher with both hands, spraying`）。

### 7.3 敵人（補動作）
- 值班者：待機（`standing still, slight sway, head tilted`）、攻擊（`lunging forward, arms grabbing`），5 方向各 1 張。
- 鳴骨者：第二張走路（現在每方向只有 1 張，動畫會很僵），5 方向各 1 張。
- 凍眠體（新，**躺姿、俯視**，32×16 比例的橫長圖）：
```text
pixel art game sprite, top-down view, frozen human body lying on the floor, lab coat dusted with frost, thin ice crust, small translucent cyan crystal shards growing from the spine, pale skin, arms at sides, horizontal composition, single character, centered, solid flat magenta background #FF00FF, no ground shadow
```
  另外 1 張 `same frozen body pushing itself up from the floor, waking, crystals glowing cyan`（甦醒）。
- 地上的屍體要和凍眠體「幾乎一樣」：用同一張圖，遊戲裡只差偶爾的結晶微光，所以不用另外生。

### 7.4 Boss
```text
pixel art game sprite, huge infected polar bear, blind milky eyes, translucent cyan crystal growths bursting from its back and shoulders, matted dirty white fur, walking on all fours, facing {DIRECTION}, single creature, centered, solid flat magenta background #FF00FF, no ground shadow
```
- 北極熊：走路 5 方向各 2 張、衝撞（`charging, head lowered, front legs extended`）5 方向各 1 張、暈眩（`dazed, sitting, stars of ice around head`）1 張。
```text
pixel art game asset, top-down view, a massive mound of fused translucent cyan crystal and frozen human figures, several pale faces half-embedded in the crystal, dark cracks, faint inner glow, symmetrical, centered, solid flat magenta background #FF00FF, no ground shadow
```
- 深井：本體 1～2 張；`same crystal mound split open, glowing orange-red pulsing core exposed in the center`（核心露出）1 張。

### 7.5 戶外與研究站地圖格（俯視、無縫、平鋪）
```text
pixel art seamless tileable top-down texture, {SURFACE}, 16-bit survival horror, cold blue-grey palette, no perspective, flat lighting, square, fills the whole image
```
- `{SURFACE}` 依序換成：`wind-packed snow with faint footprints`、`fresh powder snow`、`blue sea ice with cracks`、`frozen gravel and rocks`、`metal grating floor`、`wooden plank floor of a weather hut`。
- 研究站外牆（俯視、看得到牆頂）：`top-down view of a concrete research station exterior wall top, snow piled on top edge, seamless horizontal`。

### 7.6 道具（地圖上，3/4 俯視，單一物件置中，純洋紅背景）
| 物件 | 提示詞（加在統一風格後面） |
|---|---|
| 油桶 | `rusty oil drum, steel barrel, dented` ＋ 另一張 `same oil drum burning, flames rising from the top` |
| 木箱 | `wooden supply crate, stenciled markings, frost on edges` |
| 木板封住的門 | `doorway boarded up with nailed wooden planks, front view` |
| 滅火器 | `red fire extinguisher mounted on a wall bracket` |
| 碎石堆 | `small pile of grey rocks and stones on snow` |
| 無線電 | `old shortwave radio console on a desk, glowing dials` |
| 儲物箱 | `large metal storage trunk, padlock` |
| 發電機 | `industrial diesel generator, pipes, warning stripes` |
| 燃料桶 | `red metal jerry can` |
| 雪地車 | `orange tracked snowcat vehicle, top-down 3/4 view` |
| 上行終端機 | `satellite uplink terminal with a small screen and keyboard, antenna cable` |
| 升降機 | `industrial cage elevator platform, yellow safety rails, top-down` |

### 7.7 物品欄圖示（16×16，純洋紅背景，物件置中，粗外框）
`pistol`、`pump shotgun`、`box of 9mm ammunition`、`shotgun shells`、`grey stone`、`glass bottle with burning rag (firebomb)`、`brown glass bottle of lab ethanol`、`chemical heat pack`、`plastic keycard with chip`、`fire extinguisher`。
```text
pixel art inventory icon, {ITEM}, single object, centered, thick dark outline, 16-bit survival horror, solid flat magenta background #FF00FF
```

### 7.8 標題畫面主視覺（480×270 的比例，16:9）
```text
pixel art title screen key art, polar night, a lone research station on a black arctic island under heavy blizzard, a small orange-clad figure with a flashlight walking toward it, a tall radio antenna tower with a red light, faint cyan glow from beneath the snow, 16:9 wide composition, empty dark sky at the top for the title text, cold blue palette with a single orange accent
```

### 7.9 第二批的優先順序
1. 凍眠體躺姿（目前借用值班者的圖躺平）
2. 戶外雪地格（目前戶外還是色塊）
3. 主角跑步、舉槍
4. 北極熊、深井
5. 道具、物品欄圖示、標題畫面

## 8. 第三批（2026-11-25）：新怪物、人類敵人、室內門與窗（惡靈古堡 1～3 代、潛龍諜影 1 代的感覺）

規則同 7.1（純洋紅背景、一隻角色置中、全身、5 個方向：down、downright、right、upright、up）。
風格方向：**早期 PS1 生存恐怖的預渲染感**，但做成像素圖：顏色偏暗、偏綠灰和土黃、高對比的光影、細節靠陰影不靠線條。
在每條角色提示詞前面加上：
```text
pixel art game sprite, 32x48, 3/4 top-down view, late-90s survival horror style, dark muted palette, strong rim light, gritty, original creature design,
```
怪物全部要原創：不要模仿任何現有遊戲的怪物外型（例如特定遊戲的殭屍犬、舔食者、暴君）。共通設定：被古菌「霜鳴菌」感染，身上有半透明青色結晶、結霜、裂開的皮膚。

### 8.1 新怪物（走路 5 方向各 2 張；攻擊 5 方向各 1 張；倒地 1 張）
| id（資料夾名） | 說明 | 提示詞 |
|---|---|---|
| `crawler` 爬行者 | 下半身被凍住斷掉、用雙手在地上爬，速度快、很低，從家具底下鑽出來 | `infected research scientist torso crawling on the floor using both arms, legs missing below the waist encased in ice, torn lab coat dragging, cyan crystals along the spine, facing {DIRECTION}` |
| `husk` 冰殼者 | 全身包著厚冰殼的大個子，子彈打冰殼沒用，要先用火融化 | `hulking infected station worker encased in a thick translucent ice shell, only the face visible through cracked ice, heavy slow stance, crystal spikes on shoulders, facing {DIRECTION}` |
| `hound` 雪橇犬 | 被感染的雪橇犬，成群行動、聽到聲音就衝過來 | `infected sled dog, thin and emaciated, patches of fur missing revealing frosted skin, cyan crystal growths along the ribs, blind white eyes, running on four legs, facing {DIRECTION}` |
| `chorister` 合唱者 | 頭部裂開長出結晶的瘦高個子，會「唱」出聲音把同伴叫來（呼叫範圍很大） | `tall gaunt infected figure in a parka, head split open with a cluster of singing cyan crystals growing out, mouth stretched open, arms hanging long, facing {DIRECTION}` |

- 倒地：`same creature collapsed on the floor, top-down view, defeated`。
- 被踢倒（新動作）：`same creature knocked down on its back, limbs splayed, top-down view`。

### 8.2 人類敵人：清除小組（Cleanup Team）
私人軍事公司派來「清理」北緯站的部隊。有無線電、會開槍、會叫增援。**原創裝備，不要模仿任何現有遊戲或真實部隊的標誌。**
```text
pixel art game sprite, 32x48, 3/4 top-down view, private military contractor in white arctic camouflage, balaclava and tinted ski goggles, plate carrier vest, compact rifle held at low ready, small radio on the shoulder strap, no insignia, facing {DIRECTION}, full body, single character, centered, solid flat magenta background #FF00FF, no ground shadow
```
- 資料夾 `operative`：走路 5 方向各 2 張、舉槍瞄準（`aiming rifle at shoulder`）5 方向各 1 張、用無線電通報（`one hand pressing the shoulder radio, talking, looking around`）down 1 張、被抓住（`being grabbed from behind in a chokehold, struggling`）1 張、倒地 1 張。
- 隊長 `operative_leader`：`same contractor with a red armband and a flashlight mounted on the rifle`，走路 5 方向各 2 張。

### 8.3 主角的近戰與擒拿（新動作）
| 動作 | 提示詞（加在 7.2 主角那段後面） | 數量 |
|---|---|---|
| 揮刀 | `slashing with a combat knife, wide horizontal swing` | 5 方向各 1 |
| 揮拳 | `throwing a straight punch` | 5 方向各 1 |
| 踢 | `front kick, leg extended forward` | 5 方向各 1 |
| 擒拿 | `grabbing an enemy from behind, arm around the neck` | 5 方向各 1 |
| 摔 | `throwing an enemy over the shoulder to the ground` | down 1 |

### 8.4 室內門、窗、牆（地圖用）
| 物件 | 提示詞 |
|---|---|
| 自動門（關） | `pixel art, 16x16 top-down view, sliding metal security door closed, yellow-black hazard stripes on the frame, small status light` |
| 自動門（開） | `same sliding door open, panels retracted into the wall` |
| 安全屋的門 | `pixel art, 16x16 top-down view, heavy pressure door with a green light and a red cross emblem, closed` |
| 觀察窗 | `pixel art, 16x16 top-down view, reinforced observation window glass in a concrete wall, frost in the corners, faint reflection` |
| 牆的正面 | `pixel art seamless horizontal strip, 16x10, front face of a concrete wall in a research station, painted lower half, pipes and a cable tray, grime, cold lighting` |

### 8.5 優先順序
1. 人類敵人 `operative`（警戒、無線電、增援系統已經做好，現在用色塊代替）
2. 主角近戰與擒拿動作
3. `crawler`、`hound`（之後會加進地圖）
4. 門、窗、牆面
5. `husk`、`chorister`
