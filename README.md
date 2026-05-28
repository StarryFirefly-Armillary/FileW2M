# FileW2M

A cross-platform LAN file transfer application supporting Windows and Android.

## Features

- **Device Discovery**: Automatic UDP broadcast scanning for nearby devices
- **File Transfer**: Send and receive files over TCP connection
- **Messaging**: Real-time text messaging between connected devices
- **Connection Management**: Request/approve connection system with auto-approve option
- **Transfer History**: View and manage file transfer records
- **Background Service**: Android foreground service to maintain connections
- **System Notifications**: In-app and system notifications for messages
- **Device History**: Save connection history for quick reconnection
- **Manual Connection**: Connect to devices by IP address when auto-discovery fails

## Requirements

- Windows 10+ or Android 8.0+
- Both devices must be on the same local network

## Build

### Windows

```bash
flutter build windows
```

The executable will be at `build/windows/x64/runner/Release/FileW2M.exe`.

### Android

```bash
flutter build apk
```

The APK will be at `build/app/outputs/flutter-apk/app-release.apk`.

## Download

Pre-built binaries are available in the [Releases](https://github.com/StarryFirefly-Armillary/FileW2M/releases) section.

## Tech Stack

- Flutter 3.44.0
- Dart 3.12.0
- Provider for state management
- UDP broadcast for device discovery
- TCP sockets for file transfer and messaging

## License

MIT License - see [LICENSE](LICENSE) for details.

## Author

- **StarryFirefly** - [GitHub](https://github.com/StarryFirefly-Armillary)
