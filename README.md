# Jarvis · 智能工作助手（Flutter 桌面）

一个跨平台（macOS / Linux / Windows）的智能工作助手，采用 Flutter（Material 3）构建。Jarvis 目标是你的工作中枢，汇集多个独立功能入口：文本助手、自动化流程、AI 搜索、知识库等。

## 特性
- 跨平台桌面：Flutter Desktop，单代码库覆盖三大平台
- 科技感首页：极光背景、网格叠层、玻璃拟态卡片、悬浮动效
- 可扩展：卡片即模块入口，后续接入路由/页面/工作流
- 现代主题：Material 3 + 自定义配色与字体（Space Grotesk）

## 开发前置
- 安装 Flutter（建议 3.x+），并通过 `flutter doctor` 确认桌面工具链就绪
- macOS 需安装 Xcode；Windows 需安装 Visual Studio（含桌面 C++ 工具）；Linux 需安装 GTK/clang 等

## 初始化（在项目根目录）
```bash
flutter config --enable-macos-desktop --enable-linux-desktop --enable-windows-desktop
```
```bash
flutter create .
```
```bash
flutter pub add google_fonts
```

## 启动与构建
- 启动（macOS）：  
```bash
flutter run -d macos
```
- 启动（Windows）：  
```bash
flutter run -d windows
```
- 启动（Linux）：  
```bash
flutter run -d linux
```
- 构建安装包（Release）：  
```bash
flutter build macos
```
```bash
flutter build windows
```
```bash
flutter build linux
```

## 结构
