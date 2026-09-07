# HiDPI 大师（HiDPI Master）

[English](README.md) | [繁體中文](README.zh-Hant.md) | **简体中文**

精致的 macOS 菜单栏工具，让外接屏幕（27″／32″ 2K／4K…）的界面「**又大又清晰**」——一键开启 HiDPI（Retina 2× 渲染）、按屏幕实际规格智能推荐最佳大小，并用通俗语言（而不是分辨率数字）调整。

![macOS 12+](https://img.shields.io/badge/macOS-12%2B-blue) ![Universal](https://img.shields.io/badge/芯片-Intel%20%7C%20Apple%20Silicon-purple) ![Release](https://img.shields.io/github/v/release/xiewei3536/HIDPI-Master)

## 下载

到 [Releases](https://github.com/xiewei3536/HIDPI-Master/releases/latest) 下载最新的 **`HiDPI-Master.dmg`**，打开后把 App 拖入「应用程序」。

> App 未经 Apple 公证。首次打开请右键 App →「打开」，或到「系统设置 → 隐私与安全性」允许；也可执行：`xattr -dr com.apple.quarantine "/Applications/HiDPI Master.app"`

## 为什么需要它？

外接大屏幕时，macOS 常常只给你两个差选项：

- **原生分辨率** → 文字太小
- **非 Retina 缩放** → 界面够大，但字体模糊、锯齿明显

HiDPI 大师解锁 **HiDPI（2× Retina）模式**，界面放大的同时保持锐利。

## 功能特色

| | |
|---|---|
| 🔍 **智能检测** | 自动读取每台屏幕的物理尺寸（英寸）、原生分辨率与 PPI |
| ⭐ **智能推荐** | 以「界面舒适度 × 文字锐利度」为你的屏幕给每个 HiDPI 档位打分，附通俗推荐理由；只推荐 HiDPI 且比例贴合的模式 |
| 🗣 **默认通俗界面** | 看不到数字：「字大图标大 ↔ 字小图标小」滑块，配「刚刚好／超大」等标签；高级模式可看完整分辨率／PPI 数据 |
| ⚡ **一键开启 HiDPI** | Intel：显示器覆写文件（重启后原生支持、不动 SIP）；Apple Silicon：虚拟屏幕＋镜像（立即生效、免重启） |
| 📐 **最大档位目录＋比例防呆** | 按面板规格生成最多可能的 HiDPI 尺寸（覆盖各比例家族）；与屏幕比例不符的档位标 ⚠，应用前需确认 |
| 🎞 **帧数（刷新率）调整** | 显示器支持的 Hz 都可选；切换分辨率时自动保留你的帧数 |
| 🔁 **自动应用** | 记住每台屏幕的设置，重新接入自动恢复；支持登录时启动 |
| 🔔 **自动更新** | 自动检查 GitHub Releases，新版推送通知、一键下载安装 |
| ✨ **一键最佳化** | 标题栏一个按钮，把推荐大小应用到所有外接屏幕 |
| 🙋 **「我偏好」开关** | 大字／均衡／空间，联动所有推荐与大小标签 |
| 🛟 **安全切换** | 有风险的更改（刷新率、非 HiDPI、比例不同）会弹出「画面正常吗？」倒计时，无响应自动还原 |
| 📏 **尺寸校正** | 屏幕没报告尺寸或报告错误？点一下选英寸即可 |
| 💾 **保存守护** | 检测没有覆写文件支撑的 HiDPI 档位（重启会消失），一键写入系统 |
| 🔁 **重启后自动应用** | 重启前选好大小，开机后自动帮你切换 |
| 🖱 **菜单栏快速切换** | 右键点图标就能切换大小，无需打开面板 |
| 🌐 **多语言** | 简体中文、繁體中文、English，App 内实时切换 |

## 技术原理

| | Intel（默认） | Apple Silicon（默认） |
|---|---|---|
| 方式 | EDID 覆写文件 + `scale-resolutions` | `CGVirtualDisplay` 虚拟屏幕＋镜像 |
| 生效 | 重启后 | 立即 |
| 需要常驻 App | 否 | 是（建议开启「登录时启动」） |
| SIP | 无需改动 | 无需改动 |
| 写入位置 | `/Library/Displays/Contents/Resources/Overrides` | 无（纯运行时） |

Intel Mac 也可以改用免重启的虚拟屏幕方案。

## 从源码构建

需求：macOS 12+、Xcode（或 Command Line Tools，Swift 5.9+）：

```bash
./scripts/build-app.sh          # → dist/HiDPI Master.app（Universal）
./scripts/make-dist.sh          # → dist/HiDPI-Master.dmg + .zip
```

## 还原

「设置 → 还原 → 将所有显示器还原为默认」：关闭虚拟屏幕并移除覆写文件（需管理员密码），重启后完全恢复。

## 注意事项

- 虚拟屏幕方案使用与 BetterDummy／BetterDisplay 相同的私有 API 技术，属尽力支持性质。
- 覆写文件只影响对应「厂商 ID＋产品 ID」的屏幕。
- 以 [MIT 许可证](LICENSE) 发布。
