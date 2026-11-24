# pixel-biohazard（暫定代號，正式遊戲名稱未定）

像素風、俯視跟隨鏡頭的生存恐怖遊戲。

## 引擎與語言
- Godot 4.7.2（/Applications/Godot.app），渲染器：Compatibility（gl_compatibility）
- 只用 GDScript，不使用 C#（C# 無法匯出網頁版）
- 命令列：`/Applications/Godot.app/Contents/MacOS/Godot --headless --path . --import`

## 常用指令
- 行為測試（改完遊戲邏輯一定要跑，結束代碼 0 才算通過）：
  `/Applications/Godot.app/Contents/MacOS/Godot --headless --path . res://tools/tests/prototype_test.tscn`
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
- 支線可以設 `radio` 欄位：要在安全屋用無線電聽到才會出現（GDD 第 8.4 節）。
- 瞄準一律是「朝向＋自動鎖定」，不要做需要滑鼠精準瞄準的玩法（觸控版要能玩）。
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
