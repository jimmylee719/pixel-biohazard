# pixel-biohazard（資料夾代號；遊戲名稱 AFTERSIGNAL《迴頻》）

像素風、俯視跟隨鏡頭的生存恐怖潛行遊戲。世界觀（v0.4）：冰封四萬年的遠古細菌「霜鳴菌」讓宿主失明、聽覺發達、骨骼結晶共鳴；
菌落在冰層下「唱歌」的頻率 126.05 MHz，1962 年被冷戰監聽站「燈籠」收到，歌裡有 2099 年的城市（菌落擴散到全人類的未來）。
過去 1962／現在 2026（主線）／未來 2099。**不使用霓虹燈元素**（使用者覺得太多，已取消）。過場要有好萊塢電影的節奏（見 cutscenes.gd 開頭的步驟說明）。
設定以 `docs/SERIES_BIBLE.md` 第 1～4 節為準；投資人評估、市場研究、IP 企劃在 `docs/IP_REVIEW.md`。
專案名稱 `config/name` 不要改：改了 user:// 資料夾會變，玩家的存檔和設定會不見（視窗標題由 title.gd 設定）。

## 引擎與語言
- Godot 4.7.2（/Applications/Godot.app），渲染器：Compatibility（gl_compatibility）
- 只用 GDScript，不使用 C#（C# 無法匯出網頁版）
- 命令列：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`

## 常用指令
- 行為測試（改完遊戲邏輯一定要跑，結束代碼 0 才算通過）：`tools/run_tests.sh`
  （內部執行 `Godot --headless --path . res://tools/tests/prototype_test.tscn`，有逾時保護：測試腳本語法錯誤時 Godot 不會自己結束）
- 截圖（會開視窗）：`/Applications/Godot.app/Contents/MacOS/Godot --path . res://tools/tests/capture.tscn -- <輸出資料夾>`
- 重新產生 InputMap 設定：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --script res://tools/setup_project_settings.gd`
- 注意：遊戲腳本用到自動載入（NoiseBus），所以測試要用「場景」執行，不能用 `--script`。

## 程式架構（重點）
- `scripts/world/areas.gd`：所有區域的文字地圖、門、敵人路線、溫度區域、物件名稱。新增區域或改地圖從這裡開始。
- 自動載入：`NoiseBus`（聲音事件）、`WorldState`（跨區域狀態、檢查點）、`Missions`（主線＋支線，資料定義在檔案內）。
- `scripts/main.gd`：載入區域、門的切換、被抓到回檢查點、HUD。
- 敵人只有一支腳本 `scripts/enemy/enemy.gd`，種類用場景上的 @export 參數區分。
- 主角的戰鬥在子節點 Combat（`scripts/player/player_combat.gd`）；物品資料在 `scripts/world/items.gd`，物品欄、生命值、感染值存在 WorldState。
- 遊戲從 `scenes/title.tscn` 開始；存檔只在安全屋的無線電（`WorldState.save_to_disk()`，用 store_var 存 data）。測試會把 `WorldState.save_path` 改成測試用檔名。
- 無線電頻率在 `scripts/world/frequencies.gd`（頻率用整數百分之一 MHz）；地圖上的頻率線索用區域資料的 `learn`，聽了才出現的物品用 `hidden`。頻段和內容要維持原創，不要用 MGS 的 140.xx 頻段或角色。
- 敵人種類：patroller（值班者）、listener（鳴骨者）、sleeper（凍眠體，`dormant` 參數）、guard（武裝人員）、hound（獵犬）、
  crawler（爬行者，看不見、聽覺好）、husk（膨脹者，慢、耐打、高感染）、chorister（詠者，看到你就呼叫大範圍同伴）。
  場景的 `species` = 圖鑑編號、`step_style` = 腳步聲（foot／paw）；敵人走路有腳步聲（躲櫃子時靠聽）。
- 圖鑑：`scripts/world/codex.gd`（敵人第一次被看到、武器第一次撿到時解鎖，`WorldState.codex_*`），手機「檔案」App。
- 過場：`scripts/world/cutscenes.gd`（步驟資料）＋ `scripts/ui/cutscene_player.gd`（黑邊、對白），`main.play_cutscene()`；
  區域資料 `cutscene` = 第一次進入時播放（旗標 `scene:<id>`）。用遊戲畫面演出、遊戲暫停。測試／截圖設 `WorldState.cutscenes = false`。
- 武器：`PlayerCombat.WEAPONS`（pistol、shotgun、rifle、nailgun 安靜、flare_gun 落點起火）、`MELEE_WEAPONS`（fire_axe）；地圖符號見 areas.gd。
- 擴張區域：north_harbor（北港，武裝人員＋增援）、ice_caves（冰洞）、station_east_wing（東翼），從氣象小屋北門、二樓東側進入。新種類先試著只用 @export 參數＋新場景做。
- Boss：繼承 Enemy、只覆寫行動邏輯，並覆寫 `is_boss()`／`boss_suffix()`（例：`boss_bear.gd`、最終 Boss `boss_well.gd`）；區域資料 `camera: "fixed"` + `boss` 名稱 = Boss 戰鏡頭與血條；Boss 死亡發出任務事件 `defeat`。
- 門的 `access` 欄位 = 需要的權限卡等級（`WorldState.access_level`）；權限卡、鑰匙類不佔物品欄。
- 推出方式是「本篇＋資料片」（SERIES_BIBLE 第 5 節）：新內容盡量只加資料和參數化場景，不改核心系統，方便之後做資料片。
- 雪地車在區域間來回：區域資料 `snowcat_to` ＋對方的 `entries.snowcat`。樓梯提示依區域的 `floor` 判斷上下樓。
- 天線塔的訊號（結局方向）：`WorldState.signal_choice()`（rescue / quarantine / destroy），選擇介面在 `main.gd` 的 SignalPanel，文字在 `scripts/world/uplink_messages.gd`。
- 結局：`scripts/world/endings.gd`（訊號 × 感染值）；主線最後一個任務 `the_shaft` 完成時 `main.gd` 顯示結局畫面。
- 電力：`WorldState.power_on`；區域的 `powered_area`（燈）、溫度區域的 `powered`（暖氣）。搬運中的東西：`WorldState.carrying`。
- 支線可以設 `radio` 欄位：要在安全屋用無線電聽到才會出現（GDD 第 8.4 節）。
- 瞄準一律是「朝向＋自動鎖定」，不要做需要滑鼠精準瞄準的玩法（觸控版要能玩）。
- 環境互動（P11）：投擲物 `Items.THROWABLES`（物品欄「使用」= 準備丟）、材料 `kind: craft` 的 `recipe`；火 `scripts/fx/fire.gd`（group "fires"）、滅火器白霧 `scripts/fx/smoke_cloud.gd`；
  地圖小寫符號 o 油桶、w 木箱、p 木板、q 滅火器、r 碎石堆（見 areas.gd 開頭）。會擋路的物件用 `Level.add_nav_obstacle()`，拆掉後 `rebake_navigation()`。
- 失溫依區域氣候：`scripts/world/climates.gd`，區域資料 `climate`（預設 `Areas.DEFAULT_CLIMATE`）；`Level.exposure_at()`。
- 美術：角色、道具、物品圖示、子彈／槍口火光、地板貼圖都由 `python3 tools/gen_pixel_art.py [項目]` 產生（純標準函式庫）：
  每個角色用 3D 形狀（橢球、膠囊、方塊）組成，同一台 3/4 攝影機逐像素算圖＋固定調色盤＋描邊，所以每個方向一致、不會破圖。
  新角色＝在檔案裡加一個 `xxx_model(anim, f, n)` 和 `CHARACTERS` 一行；改完跑 `--import`。調色盤在 `MATS`。
  舊的 AI 原圖流程（`art_raw/` → `tools/import_art.gd`）已不用於角色／道具，目前只剩頭像 `portraits/` 是 AI 圖。
  角色動畫 `scripts/fx/character_sprite.gd`（5 方向＋鏡像、腳下影子；動作：idle、walk、sneak、listen、attack、aim、
  aim_pistol、aim_shotgun、slash、punch、kick），讀圖用 `Art.tex()`，沒有圖時退回色塊。物品圖示 `props/<物品 id>`（手機物品 App 也用）。
- 聲音：自動載入 `Sfx`（`scripts/autoload/sfx.gd`）＝玩家聽到的聲音；敵人聽到的是 `NoiseBus`，兩者分開，有聲響的動作兩個都要呼叫。
  清單 `scripts/audio/sound_list.gd`（id = 檔名），提示詞 `docs/AUDIO_PROMPTS.md`（測試會檢查兩邊一致、每個 id 都有檔案）。
  正式素材放 `assets/audio/{sfx,music,ambience}/<id>.ogg`（或 _1、_2 多版本），沒有就用 `assets/audio/synth/` 的合成暫代版（`python3 tools/synth_audio.py` 產生）。
  區域音樂／環境音由 `Level.music_id()`、`ambience_id()` 決定（區域資料可用 `music`、`ambience`、`step` 指定），追逐音樂在 `main.gd` 的 `_update_music`。
- 無縫建築：`Areas.ROOMS` 把房間（安全屋、站長室、床鋪小屋）合併進主區域地圖，共用的門變成室內自動門 `+`（`scripts/level/interior_door.gd`）。
  `level.area_id` 是主地圖；主角所在的房間用 `main.current_area_id()` / `Level.region_at()`；房間的存檔 key 維持「房間 id:房間座標」。
  載入房間：`load_area("station_safe", "radio")` 會載入主地圖並用 `main.entry_key()` 找入口。測試用 `Areas.room_offset()` 換算座標。
  房間黑幕 `RoomFog`：室內門把地板分成房間，只看得到所在的房間。安全屋的門有只擋敵人的牆（圖層 16）。
  圖層：1 牆、2 主角、4 敵人、8 窗戶（擋路不擋視線）、16 安全屋門口（只擋敵人）、32 關著的室內門（擋視線）。`Sight.WALL_MASK = 33`。
- 第一人稱：`scripts/ui/first_person_view.gd`（地圖格子射線投射），躲櫃子、看窗戶（地圖符號 `=`，`WindowPane`）時開啟。
- 警戒：每個 Level 有 `AlertNetwork`（ALERT → EVASION → CAUTION）。怪物發現主角會叫 `call_radius_tiles` 內的同伴；
  人類（`faction = "human"`，`scenes/enemy_guard.tscn`）有無線電：通報中被打中就失敗，成功 = 全區域人類趕來＋區域資料 `reinforcements` 增援。
- 近戰：`PlayerCombat.COMBO`（刀 → 拳 → 踢，踢倒可補刀、撞牆額外傷害）、擒拿（背後按互動抓住；攻擊 = 解決、投擲 = 摔、互動 = 放開）。
- 敵人離開區域時的位置記在 `WorldState.data.enemies`（`Enemy.snapshot()` / `restore_snapshot()`）。
- 畫面的高度感：牆頂往上畫 `Level.WALL_RAISE`、牆面 `scripts/level/wall_faces.gd`（一整格高）、牆腳和家具旁的地板陰影
  （`Level._draw_floor_shadows`）、角色腳下影子。牆畫在角色上面的圖層，角色站在牆／櫃子前面時由 `scripts/level/over_wall.gd`
  用牆格子當遮罩把角色補畫在上面（前後關係才對）。後製 `assets/shaders/film.gdshader`（顆粒、暗角）。
- 手機 UI（`scripts/ui/phone.gd`，main 的 `open_phone()`／`set_phone_app()`）：狀態、物品、任務、訊息、地圖、操作說明都在手機裡，
  遊戲畫面只留互動提示、左上角一行通知（`show_message`，長訊息全文在手機「訊息」= `main.message_log`）、警戒狀態。
  物品、任務 App 沿用 InventoryPanel／MissionPanel（擺進手機螢幕）。狀態列平常隱藏，受傷或狀況不好才出現。
- 操作手感：類比搖桿輕推（< `analog_sneak_tilt`）自動潛行；撞到牆角邊緣會自動滑開（`Player._assist_corner`）。
- 觸控：`scripts/ui/touch_controls.gd`、`touch_stick.gd`（全部轉成 InputMap 動作）。注意 Godot 4.7 內建 `VirtualJoystick` 類別，自己的類別不要取這個名字。
- 多語系：介面與劇情文字一律寫英文原文，顯示時用 `tr()`（資料裡的整句在 `show_message`、面板顯示處翻譯）。
  中文在 `tools/locale/zh_TW.py`，改完跑 `python3 tools/locale/make_po.py` 產生 `locale/zh_TW.po`；測試會檢查劇情、任務、物品文字都有中文。
  字型：俐方體11號（`assets/fonts/`，OFL），只用 12、24 號字才清楚。測試用英文跑（`TranslationServer.set_locale("en")`）。
- 地圖是半開放結構（見 GDD 第 8 節）：用寒冷、電力、工具、權限卡等級等軟性門檻，不要一直做彩色鑰匙。

## 目標平台
1. Steam（Windows）
2. 網頁試玩版（Web）
3. iOS

所有功能都必須能在這三個平台運作；只用 Compatibility 渲染器支援的功能。

## 像素解析度
- 內部 viewport：480x270，預設視窗 1280x720
- stretch mode = viewport、aspect = expand、scale mode = integer
- 預設貼圖過濾：Nearest（不要模糊像素）
- 美術素材以 480x270 為基準設計，保持像素對齊

## 觸控操作
- 觸控操作從一開始就要設計，不能事後補上
- 每個操作都要同時支援鍵盤/手把與觸控（iOS、手機網頁）
- 已開啟滑鼠模擬觸控（emulate_touch_from_mouse），方便在桌面測試
- 手機方向：sensor landscape（只用橫向）

## 素材與版本控制
- png、wav、ogg、mp3 用 Git LFS 追蹤
- `.godot/` 不進版本控制
- 生存模式「長夜」：`scripts/modes/survival_mode.gd`（波次、分數、空投、撤離；多人預留 `players()`）、資料 `survival_data.gd`、
  撤離點 `survival_extraction.gd`、選單 `scenes/survival_menu.tscn`、結算 `scripts/ui/survival_results.gd`。設計與市場分析 `docs/SURVIVAL_MODE.md`。
  `WorldState.mode`（story／survival）、`start_survival()`；跨存檔的玩家檔案（殘響點數、解鎖、最高紀錄）`WorldState.profile`
  存在 `user://profile.cfg`（測試改 `profile_path`）。解鎖的「主線補給箱」在主線新遊戲時放進儲物箱（`SurvivalData.STORY_CACHES`）。
- 動作流暢化：產生器用關鍵影格內插 `kf()`（緩入緩出）、循環動作 `bf()`；走路 8 格、近戰 6 格、撲擊 5 格、`shoot_<武器>` 後座力、`hurt` 受傷。
  開槍／近戰特效在 `debug_overlay.gd` 的 `_draw_shot`、`_draw_melee`（fx/ 圖：muzzle_big、smoke、hit、impact、slash_0~4）。
  互動物件用 `Interactable.draw_art("名稱")` 畫 props/ 圖；最終 Boss 深井用自己的 AnimatedSprite（well/：idle、charge 依蓄力進度選格、exposed、dead）；過場對白頭像 `main._speaker_portrait()`（portraits/）。
- 操作（少按鍵，MGS1 式）：道具鍵 F／Y、武器鍵 Q／LB「按一下 = 用道具／換武器，按住＋方向 = 選」（`QuickMenu`、main 的 `_process_quick_menu`）；
  光源、投擲都併進道具鍵。閃躲 Space／B（`Player.dodge()`，瞄準中後退 = 後跳，跳的時候無敵）。瞄準會自動鎖定背後的敵人（`find_targets`）。
  操作說明在暫停選單。改按鍵：`tools/setup_project_settings.gd` 再執行一次。
- 裝備（紙娃娃）：`scripts/world/gear.gd`（頭／身／腳、套裝、能力倍率 `Gear.stat()`）；外型 = 本體圖組＋圖層（`Gear.sprite_sets()`，
  `CharacterSprite.set_outfit()`；產生器 `OUTFIT_SETS`、`render(layer_only=True)`）。地圖符號 t＋區域資料 gear。手機「裝備」App。
  特殊區域：區域資料 `hazards`（孢子：沒穿防護裝備一直感染）、`climate: "blizzard"`（沒穿保暖裝備失溫很快）。
- 地圖（惡靈古堡式）：`WorldState.data.explored`（去過的格子）、旗標 `map:<主地圖>`（撿到地圖 l）、主線方向 `main.objective_target()`／
  `objective_doors()`、藍色星號 = 區域資料 hidden 的旗標已解鎖但還沒拿（保險箱 s，區域資料 safes）。
- 室內主題：區域資料 `theme`（lab、office、dorm、industrial、military、hut、cave）→ `Level.THEME_*` 家具、地板痕跡、`WallFaces.WALL_DECOR`。
- 無縫地圖（暗黑破壞神式）：`Areas.ROOMS` 把相鄰的區域合成一張地圖，整張一次載入，`RoomFog` 讓沒走進去的房間看不到。
  目前三大片：南岸＋研究站一樓（正門、貨物門兩扇共用門 `also`）＋安全屋＋燃料庫；二樓＋站長室＋東翼；
  北港＋冰洞＋守門一號（廣場、基地、安全屋）。換地圖（有讀取）只剩：樓梯／不同樓層、機庫（Boss 戰）、雪地車、氣象小屋邊界。
  - 房間可以在主地圖任何方向（左／上時主地圖整張往右下移）、可以巢狀、可以有敵人（巡邏點換成 `cells`）。
  - 座標：區域自己的格子 + `Areas.area_offset(id)` = 合併後的格子。測試用 `_enter()`／`_use()`／`_tile()` 自動換算。
  - 每個區域記成一個範圍（`regions`＋逐格的 `region_cells`）：標題、安全屋、主題、氣候、音樂、電燈、室內／戶外、
    敵人編號起點（過場 `pan_enemy` 從該區域自己的第一隻算）。`Level.region_data()`、`theme_at()`、`climate_at()`、`is_indoor_at()`。
  - 存檔相容：物品 `item_keys`、敵人 `key`、溫度區域旗標都用「原本的區域 id:原本的座標／編號」。
  - 走過共用的門進入另一個區域 = 存檢查點（`region_doors`、main 的 `_checkpoint_at_region_door`）。
- 時代與記憶：區域資料 `era`（"1962" 泛黃老底片、"2099" 霓虹幻象）由 `main.set_era()` 設定後製 `film.gdshader` 的 era；
  過場步驟 `{"era": ...}` 可以暫時換時代。盤式錄音機 `&`（`scripts/interact/memory_reel.gd`，區域資料 `reels`）= 走進／走出一段記憶，
  目前有 B1 → `lantern_1962`（1962 年的燈籠監聽站，`lit: true` 一直有燈）→ 回 B1，旗標 `memory:lantern`、支線 `lantern_1962`。
- 選項：`WorldState.options`（settings.cfg 的 options 區段）：音樂、音效、聲音提示 `scripts/ui/sound_cues.gd`、輔助模式 `assist_mult()`、
  觸控透明度、左手模式（`TouchControls.apply_layout`）、省電模式（30 FPS）。介面 `scripts/ui/options_panel.gd`（標題、暫停選單）。
  標題畫面 `scripts/ui/title_backdrop.gd`（潛龍諜影式：衛星定位開場字 → 暴風雪夜景＋大標題＋PRESS ANY BUTTON → 槍聲後選單出現）。
- 過場的電影語言：`CutscenePlayer` 的 fade_out／fade_in（硬切）、title_card（片名卡）、name_card（人物名牌）、credit（片頭字幕）、flash；
  main 的 `_shake_camera`、`_zoom_camera`。寬銀幕黑邊（上 32、下 44）。
- 敵人新增：runner（狂奔者，快、脆）、spitter（噴孢者，`ranged_style = "spit"` 吐孢子團 `scripts/fx/spore_glob.gd`、`ranged_infection`）、
  brute（冰甲巨人，`front_armor` 正面減傷）。
- 潛龍諜影式的視角（2.5D，參考但原創）：`FollowCamera` 的 `zoom_target`（推近）、`frame_point`（固定機位）、`wall_offset`（貼牆視角）；
  後製 `film.gdshader` 的 `tilt`（斜角：上面遠、下面近的梯形）。區域資料 `camera_zones`（rect＋zoom／tilt／frame）、整區預設 `tilt`。
  main 的 `_update_camera_view()` 每幀依主角位置套用。貼牆：`Player.wall_press`（往牆推 0.35 秒）。
- 戰術 HUD：`scripts/ui/tactical_hud.gd`（左上 LIFE／TEMP、左下道具框、右下武器框；觸控版移到右上）。
- 無線電：原創的野戰無線電外觀 `scripts/ui/radio_dial.gd`（刻度盤、強度表、示波器）。不要做成兩個頭像中間一個頻率的樣子。
- Boss 演出：`Enemy.boss_event(kind, data)`（phase 大字＋震動、blackout 熄燈、summon 叫手下、icicle 落冰 `scripts/fx/icicle.gd`、flare 照明彈），
  main 的 `_on_boss_event`；重來時 `reset_attempt` 還原。苔原之母 3 階段（狂暴、熄燈）、深井 3 階段（合唱叫狂奔者、崩塌落冰）。
  郵輪 Boss「典獄長」`scripts/enemy/boss_warden.gd`（狙擊：雷射鎖定、拉槍機、換制高點、聲音誘導、第二階段照明彈）。
- 郵輪「北極星號」：北港頂端的棧橋 `gangway` → `cruise_deck`（＋`cruise_interior` 無縫）、樓梯往下 `cruise_hold`、往上 `cruise_sundeck`（Boss）。支線 `boreal_star`。
- 子彈穿牆：`PlayerCombat.PIERCE`（手槍穿 1 格、獵槍 2 格，每穿一道傷害打折）、`trace_shot()`；沒鎖定時直線開槍會打到路上的敵人。
