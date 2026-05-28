import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'app.dart';
import 'providers/device_provider.dart';
import 'providers/transfer_provider.dart';
import 'providers/message_provider.dart';
import 'providers/settings_provider.dart';
import 'providers/device_history_provider.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final settingsProvider = SettingsProvider();
  await settingsProvider.init();

  final deviceHistoryProvider = DeviceHistoryProvider();
  await deviceHistoryProvider.init();

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => DeviceProvider()),
        ChangeNotifierProvider(create: (_) => TransferProvider()),
        ChangeNotifierProvider(create: (_) => MessageProvider()),
        ChangeNotifierProvider.value(value: settingsProvider),
        ChangeNotifierProvider.value(value: deviceHistoryProvider),
      ],
      child: const FileTransferApp(),
    ),
  );
}
