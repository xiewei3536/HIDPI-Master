# HiDPI 大師（HiDPI Master）

[English](README.md) | **繁體中文** | [简体中文](README.zh-Hans.md)

精緻的 macOS 選單列工具，讓外接螢幕（27″／32″ 2K／4K…）的介面「**又大又清晰**」——一鍵開啟 HiDPI（Retina 2× 渲染）、依螢幕實際規格智慧推薦最佳大小，並以白話文（不是解析度數字）調整。

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Universal](https://img.shields.io/badge/晶片-Intel%20%7C%20Apple%20Silicon-purple) ![Release](https://img.shields.io/github/v/release/xiewei3536/HIDPI-Master)

## 下載

到 [Releases](https://github.com/xiewei3536/HIDPI-Master/releases/latest) 下載最新的 **`HiDPI-Master.dmg`**，打開後把 App 拖進「應用程式」。

> App 未經 Apple 公證。第一次開啟請對 App 按右鍵 →「打開」，或到「系統設定 → 隱私權與安全性」允許；也可執行：`xattr -dr com.apple.quarantine "/Applications/HiDPI Master.app"`

## 為什麼需要它？

外接大螢幕時，macOS 常常只給你兩個爛選項：

- **原生解析度** → 文字太小
- **非 Retina 縮放** → 介面夠大，但字體模糊、鋸齒明顯

HiDPI 大師解鎖 **HiDPI（2× Retina）模式**，介面放大的同時保持銳利。

## 功能特色

| | |
|---|---|
| 🔍 **智慧偵測** | 自動讀取每台螢幕的實體尺寸（吋數）、原生解析度與 PPI |
| ⭐ **智慧推薦** | 以「介面舒適度 × 文字銳利度」為你的螢幕評分每個 HiDPI 檔位，附白話推薦理由；只推薦 HiDPI 且比例貼合的模式 |
| 🗣 **預設白話介面** | 看不到數字：「字大圖示大 ↔ 字小圖示小」滑桿，配「剛剛好／超大」等標籤；進階模式可看完整解析度／PPI 數據 |
| ⚡ **一鍵開啟 HiDPI** | Intel：顯示器覆寫檔（重開機後原生支援、不動 SIP）；Apple Silicon：虛擬螢幕＋鏡像（立即生效、免重啟） |
| 📐 **最大檔位目錄＋比例防呆** | 依面板規格產生最多可能的 HiDPI 尺寸（涵蓋各比例家族）；與螢幕比例不合的檔位標示 ⚠，套用前需確認 |
| 🎞 **幀數（更新率）調整** | 顯示器支援的 Hz 都可選；切換解析度時自動保留你的幀數 |
| 🔁 **自動套用** | 記住每台螢幕的設定，重新接上自動還原；支援登入時啟動 |
| 🔔 **自動更新** | 自動檢查 GitHub Releases，新版推播通知、一鍵下載安裝 |
| 🌐 **多語系** | 繁體中文、简体中文、English，App 內即時切換 |

## 技術原理

| | Intel（預設） | Apple Silicon（預設） |
|---|---|---|
| 方式 | EDID 覆寫檔 + `scale-resolutions` | `CGVirtualDisplay` 虛擬螢幕＋鏡像 |
| 生效 | 重新開機後 | 立即 |
| 需要常駐 App | 否 | 是（建議開啟「登入時啟動」） |
| SIP | 不需變動 | 不需變動 |
| 寫入位置 | `/Library/Displays/Contents/Resources/Overrides` | 無（純執行期） |

Intel Mac 也可以改用免重啟的虛擬螢幕方案。

## 從原始碼建置

需求：macOS 12+、Xcode（或 Command Line Tools，Swift 5.9+）：

```bash
./scripts/build-app.sh          # → dist/HiDPI Master.app（Universal）
./scripts/make-dist.sh          # → dist/HiDPI-Master.dmg + .zip
```

## 還原

「設定 → 還原 → 將所有顯示器還原為預設」：關閉虛擬螢幕並移除覆寫檔（需管理員密碼），重開機後完全恢復。

## 注意事項

- 虛擬螢幕方案使用與 BetterDummy／BetterDisplay 相同的私有 API 技術，屬盡力支援性質。
- 覆寫檔只影響對應「廠商 ID＋產品 ID」的螢幕。
- 以 [MIT 授權](LICENSE) 發布。
