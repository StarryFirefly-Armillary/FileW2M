# FileW2M

跨平台局域网文件传输应用，支持 Windows 和 Android。

## 功能特性

- **设备发现**：通过 UDP 广播自动扫描局域网设备
- **文件传输**：通过 TCP 连接发送和接收文件
- **消息聊天**：已连接设备间实时文字消息
- **连接管理**：请求/审批连接机制，支持自动同意
- **传输历史**：查看和管理文件传输记录
- **后台服务**：Android 前台服务保持连接
- **系统通知**：应用内 + 系统级消息通知
- **设备历史**：保存连接历史，支持快速重连
- **手动连接**：自动发现失败时可通过 IP 地址手动连接

## 系统要求

- Windows 10+ 或 Android 8.0+
- 两台设备需在同一局域网

## 构建

### Windows

```bash
flutter build windows
```

可执行文件位于 `build/windows/x64/runner/Release/FileW2M.exe`。

### Android

```bash
flutter build apk
```

APK 位于 `build/app/outputs/flutter-apk/app-release.apk`。

## 下载

预编译版本请访问 [Releases](https://github.com/StarryFirefly-Armillary/FileW2M/releases) 页面。

## 技术栈

- Flutter 3.44.0
- Dart 3.12.0
- Provider 状态管理
- UDP 广播设备发现
- TCP 套接字文件传输和消息通信

## 许可证

MIT 许可证 - 详见 [LICENSE](LICENSE)。

## 作者

- **StarryFirefly** - [GitHub](https://github.com/StarryFirefly-Armillary)
