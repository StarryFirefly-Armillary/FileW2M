import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/device.dart';
import '../models/file_transfer.dart';
import '../providers/device_provider.dart';
import '../providers/transfer_provider.dart';
import '../providers/message_provider.dart';
import '../providers/settings_provider.dart';
import '../providers/device_history_provider.dart';
import '../utils/network_utils.dart';
import '../services/background_service.dart';
import '../widgets/device_card.dart';
import '../widgets/top_notification.dart';
import 'transfer_screen.dart';
import 'chat_screen.dart';
import 'settings_screen.dart';
import 'transfer_history_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _currentIndex = 0;
  String _localIpAddress = '获取中...';

  @override
  void initState() {
    super.initState();
    _initServices();
    _loadIpAddress();
  }

  Future<void> _loadIpAddress() async {
    final ip = await NetworkUtils.getLocalIpAddress();
    if (mounted) {
      setState(() {
        _localIpAddress = ip;
      });
    }
  }

  Future<void> _initServices() async {
    final settings = context.read<SettingsProvider>();
    final deviceProvider = context.read<DeviceProvider>();
    final transferProvider = context.read<TransferProvider>();
    final messageProvider = context.read<MessageProvider>();
    final historyProvider = context.read<DeviceHistoryProvider>();

    // Start background service if enabled
    if (Platform.isAndroid && settings.backgroundService) {
      final backgroundService = BackgroundService();
      await backgroundService.startService();
    }

    await deviceProvider.startDiscovery(settings.deviceId, settings.deviceName);
    await transferProvider.init();
    messageProvider.init(transferProvider.connectionService);

    // Set up device connected callback to save to history
    transferProvider.onDeviceConnected = (deviceId, deviceName, ip, deviceType) {
      historyProvider.addOrUpdateDevice(deviceId, deviceName, ip, deviceType);
    };

    // Set up message notification callback
    messageProvider.onMessageReceived = (deviceName, content) {
      if (mounted) {
        TopNotification.show(
          context,
          title: deviceName,
          message: content,
          onTap: () {
            // Could navigate to chat screen here
          },
        );
      }
    };

    // Sync connection state to DeviceProvider
    transferProvider.connectionService.connectionEstablished.listen((ip) {
      deviceProvider.markConnected(ip);
    });
    transferProvider.connectionService.connectionLost.listen((ip) {
      deviceProvider.markDisconnected(ip);
    });

    // Listen for incoming connection requests and show dialog
    transferProvider.connectionService.connectionRequests.listen((request) {
      final ip = request['_source_ip'] as String;
      final deviceName = request['device_name'] as String? ?? ip;
      final deviceId = request['device_id'] as String?;
      final deviceType = request['device_type'] as String?;

      if (transferProvider.autoAcceptConnections) {
        transferProvider.approveConnection(
          ip,
          deviceId: deviceId,
          deviceName: deviceName,
          deviceType: deviceType,
        );
        deviceProvider.markConnected(ip);
      } else {
        _showConnectionRequestDialog(ip, deviceName, deviceId, deviceType, transferProvider, deviceProvider);
      }
    });

    // Listen for incoming file requests and show dialog
    transferProvider.fileService.incomingRequests.listen((task) {
      if (settings.autoAccept) {
        _autoAcceptFile(task, settings);
      } else {
        _showReceiveDialog(task);
      }
    });
  }

  void _showConnectionRequestDialog(
    String ip,
    String deviceName,
    String? deviceId,
    String? deviceType,
    TransferProvider transferProvider,
    DeviceProvider deviceProvider,
  ) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('连接请求'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('设备名称: $deviceName'),
            const SizedBox(height: 8),
            Text('IP 地址: $ip'),
            const SizedBox(height: 16),
            const Text('是否允许该设备连接?'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              transferProvider.denyConnection(ip);
              TopNotification.show(
                context,
                message: '已拒绝 $deviceName 的连接请求',
              );
            },
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              transferProvider.approveConnection(
                ip,
                deviceId: deviceId,
                deviceName: deviceName,
                deviceType: deviceType,
              );
              deviceProvider.markConnected(ip);
              TopNotification.show(
                context,
                message: '已同意 $deviceName 的连接请求',
              );
            },
            child: const Text('同意'),
          ),
        ],
      ),
    );
  }

  void _autoAcceptFile(FileTransferTask task, SettingsProvider settings) {
    final savePath = settings.savePath.isNotEmpty
        ? settings.savePath
        : '${Directory.current.path}${Platform.pathSeparator}received';
    context.read<TransferProvider>().acceptFile(task.id, savePath);
  }

  void _showReceiveDialog(FileTransferTask task) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: const Text('收到文件传输请求'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('来自: ${task.peerDeviceName}'),
            const SizedBox(height: 8),
            Text('文件: ${task.fileName}'),
            Text('大小: ${task.sizeLabel}'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<TransferProvider>().rejectFile(task.id);
            },
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.pop(ctx);
              final settings = context.read<SettingsProvider>();
              final savePath = settings.savePath.isNotEmpty
                  ? settings.savePath
                  : '${Directory.current.path}${Platform.pathSeparator}received';
              context.read<TransferProvider>().acceptFile(task.id, savePath);
            },
            child: const Text('接收'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('FileW2M'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _navigateToSettings(),
          ),
        ],
      ),
      body: IndexedStack(
        index: _currentIndex,
        children: [
          _buildDeviceList(),
          const TransferHistoryScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.devices_outlined),
            selectedIcon: Icon(Icons.devices),
            label: '设备',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: '传输记录',
          ),
        ],
      ),
    );
  }

  Widget _buildDeviceList() {
    return Consumer4<DeviceProvider, TransferProvider, SettingsProvider, DeviceHistoryProvider>(
      builder: (context, deviceProvider, transferProvider, settings, historyProvider, _) {
        final devices = deviceProvider.deviceList;
        final historyDevices = historyProvider.sortedHistory;

        // Filter out history devices that are already in the online list
        final onlineIps = devices.map((d) => d.ip).toSet();
        final historyOnly = historyDevices.where((h) => !onlineIps.contains(h.ip)).toList();

        return Column(
          children: [
            _buildCurrentDeviceCard(settings),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  Text(
                    '已发现设备 (${devices.length})',
                    style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  const Spacer(),
                  TextButton.icon(
                    icon: const Icon(Icons.refresh, size: 16),
                    label: const Text('刷新'),
                    onPressed: () {
                      deviceProvider.refresh();
                      TopNotification.show(
                        context,
                        message: '正在重新扫描...',
                        duration: const Duration(seconds: 1),
                      );
                    },
                  ),
                ],
              ),
            ),
            Expanded(
              child: devices.isEmpty && historyOnly.isEmpty
                  ? _buildEmptyState()
                  : ListView(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      children: [
                        // Online devices
                        ...devices.map((device) {
                          final connected = transferProvider.isConnected(device.ip);
                          return DeviceCard(
                            device: device,
                            isConnected: connected,
                            onTap: () => _showDeviceActions(device, transferProvider.isConnected(device.ip)),
                            onConnect: () => _toggleConnection(transferProvider, device, transferProvider.isConnected(device.ip)),
                          );
                        }),
                        // History devices (only show if not online)
                        if (historyOnly.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.only(top: 16, bottom: 8),
                            child: Row(
                              children: [
                                Icon(
                                  Icons.history,
                                  size: 16,
                                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                                ),
                                const SizedBox(width: 8),
                                Text(
                                  '历史设备 (${historyOnly.length})',
                                  style: Theme.of(context).textTheme.titleSmall?.copyWith(
                                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          ...historyOnly.map((history) => _buildHistoryDeviceCard(
                            context,
                            history,
                            transferProvider,
                          )),
                        ],
                      ],
                    ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHistoryDeviceCard(
    BuildContext context,
    dynamic history,
    TransferProvider transferProvider,
  ) {
    final isConnected = transferProvider.isConnected(history.ip);

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(
          history.type == 'android' ? Icons.phone_android : Icons.computer,
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
        title: Text(history.name),
        subtitle: Text('${history.ip} · 连接${history.connectionCount}次'),
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: Icon(
                isConnected ? Icons.link_off : Icons.link,
                color: isConnected ? Colors.red : Theme.of(context).colorScheme.primary,
              ),
              onPressed: () => _toggleHistoryConnection(history, transferProvider.isConnected(history.ip)),
            ),
            IconButton(
              icon: const Icon(Icons.delete_outline, size: 20),
              onPressed: () => _removeHistoryDevice(history),
            ),
          ],
        ),
        onTap: () => _showHistoryDeviceActions(history, transferProvider.isConnected(history.ip)),
      ),
    );
  }

  Future<void> _toggleHistoryConnection(dynamic history, bool connected) async {
    final transferProvider = context.read<TransferProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    if (connected) {
      await transferProvider.disconnectFromDevice(history.ip);
      deviceProvider.markDisconnected(history.ip);
      if (mounted) {
        TopNotification.show(
          context,
          message: '已断开 ${history.name}',
        );
      }
    } else {
      await _connectToHistoryDevice(history);
    }
  }

  Future<void> _connectToHistoryDevice(dynamic history) async {
    final transferProvider = context.read<TransferProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    final success = await transferProvider.connectToDevice(history.ip, history.name);
    if (success) {
      deviceProvider.markConnected(history.ip);
      // Update history
      final historyProvider = context.read<DeviceHistoryProvider>();
      await historyProvider.addOrUpdateDevice(
        history.id,
        history.name,
        history.ip,
        history.type,
      );
    }

    if (mounted) {
      TopNotification.show(
        context,
        message: success ? '已连接 ${history.name}' : '连接 ${history.name} 失败',
      );
    }
  }

  Future<void> _removeHistoryDevice(dynamic history) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除历史设备'),
        content: Text('确定要删除 ${history.name} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && mounted) {
      final historyProvider = context.read<DeviceHistoryProvider>();
      await historyProvider.removeDevice(history.id);
    }
  }

  void _showHistoryDeviceActions(dynamic history, bool connected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    history.type == 'android' ? Icons.phone_android : Icons.computer,
                    size: 28,
                  ),
                  const SizedBox(width: 8),
                  Text(history.name, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${history.ip} · 历史设备${connected ? " · 已连接" : ""}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: connected ? Icons.link_off : Icons.link,
                    label: connected ? '断开' : '连接',
                    color: connected ? Colors.red : null,
                    onTap: () {
                      Navigator.pop(context);
                      _connectToHistoryDevice(history);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.folder_outlined,
                    label: '发送文件',
                    onTap: () {
                      Navigator.pop(context);
                      if (!connected) {
                        _connectHistoryThenNavigate(history, 'file');
                      } else {
                        _navigateToSendFile(history.ip, history.id, history.name);
                      }
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.chat_outlined,
                    label: '发消息',
                    onTap: () {
                      Navigator.pop(context);
                      if (!connected) {
                        _connectHistoryThenNavigate(history, 'chat');
                      } else {
                        _navigateToChat(history.ip, history.id, history.name);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectHistoryThenNavigate(dynamic history, String action) async {
    final transferProvider = context.read<TransferProvider>();
    final success = await transferProvider.connectToDevice(history.ip, history.name);

    if (!mounted) return;

    if (success) {
      final historyProvider = context.read<DeviceHistoryProvider>();
      await historyProvider.addOrUpdateDevice(
        history.id,
        history.name,
        history.ip,
        history.type,
      );

      if (action == 'file') {
        _navigateToSendFile(history.ip, history.id, history.name);
      } else {
        _navigateToChat(history.ip, history.id, history.name);
      }
    } else {
      TopNotification.show(
        context,
        message: '连接 ${history.name} 失败',
      );
    }
  }

  Widget _buildCurrentDeviceCard(SettingsProvider settings) {
    return Card(
      margin: const EdgeInsets.all(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            CircleAvatar(
              backgroundColor: Theme.of(context).colorScheme.primaryContainer,
              child: Icon(
                Platform.isAndroid ? Icons.phone_android : Icons.computer,
                color: Theme.of(context).colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    settings.deviceName,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(
                    'IP: $_localIpAddress',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                  Text(
                    '本设备 · ${Platform.isAndroid ? "Android" : "Windows"}',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(context).colorScheme.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                Icons.content_copy,
                size: 20,
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
              onPressed: () {
                // Copy IP to clipboard
                TopNotification.show(
                  context,
                  message: 'IP 地址已复制: $_localIpAddress',
                );
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.devices_other,
            size: 64,
            color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
          ),
          const SizedBox(height: 16),
          Text(
            '正在扫描局域网设备...',
            style: Theme.of(context).textTheme.bodyLarge?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '请确保其他设备已打开此应用',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.7),
            ),
          ),
          const SizedBox(height: 24),
          OutlinedButton.icon(
            onPressed: () => _showManualConnectDialog(),
            icon: const Icon(Icons.add),
            label: const Text('手动连接'),
          ),
        ],
      ),
    );
  }

  void _showManualConnectDialog() {
    final ipController = TextEditingController();
    final nameController = TextEditingController(text: '手动设备');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('手动连接设备'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: ipController,
              decoration: const InputDecoration(
                labelText: 'IP 地址',
                hintText: '例如: 192.168.1.100',
                prefixIcon: Icon(Icons.computer),
              ),
              keyboardType: TextInputType.number,
              autofocus: true,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: nameController,
              decoration: const InputDecoration(
                labelText: '设备名称（可选）',
                prefixIcon: Icon(Icons.phone_android),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final ip = ipController.text.trim();
              final name = nameController.text.trim();
              if (ip.isNotEmpty) {
                Navigator.pop(ctx);
                _connectToDeviceManually(ip, name.isNotEmpty ? name : '设备');
              }
            },
            child: const Text('连接'),
          ),
        ],
      ),
    );
  }

  Future<void> _connectToDeviceManually(String ip, String name) async {
    final transferProvider = context.read<TransferProvider>();
    final deviceProvider = context.read<DeviceProvider>();

    // Show loading indicator
    TopNotification.show(
      context,
      message: '正在连接 $ip...',
    );

    final success = await transferProvider.connectToDevice(ip, name);

    if (success) {
      deviceProvider.markConnected(ip);

      // Save to history
      final historyProvider = context.read<DeviceHistoryProvider>();
      await historyProvider.addOrUpdateDevice(
        ip, // Use IP as ID for manual connections
        name,
        ip,
        'unknown',
      );

      if (mounted) {
        TopNotification.show(
          context,
          message: '已连接 $name ($ip)',
        );
      }
    } else {
      if (mounted) {
        TopNotification.show(
          context,
          message: '连接 $ip 失败，请检查IP地址和网络',
        );
      }
    }
  }

  Future<void> _toggleConnection(TransferProvider provider, Device device, bool connected) async {
    final deviceProvider = context.read<DeviceProvider>();
    if (connected) {
      await provider.disconnectFromDevice(device.ip);
      deviceProvider.markDisconnected(device.ip);
      if (mounted) {
        TopNotification.show(
          context,
          message: '已断开 ${device.name}',
        );
      }
    } else {
      final success = await provider.connectToDevice(device.ip, device.name);
      if (success) {
        deviceProvider.markConnected(device.ip);
        // Save to device history
        final historyProvider = context.read<DeviceHistoryProvider>();
        await historyProvider.addOrUpdateDevice(
          device.id,
          device.name,
          device.ip,
          device.typeLabel.toLowerCase(),
        );
      }
      if (mounted) {
        TopNotification.show(
          context,
          message: success ? '已连接 ${device.name}' : '连接 ${device.name} 失败',
        );
      }
    }
  }

  void _showDeviceActions(Device device, bool connected) {
    showModalBottomSheet(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.4),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(height: 16),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(device.icon, size: 28),
                  const SizedBox(width: 8),
                  Text(device.name, style: Theme.of(context).textTheme.titleLarge),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '${device.ip} · ${device.typeLabel}${connected ? " · 已连接" : ""}',
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: Theme.of(context).colorScheme.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  _buildActionButton(
                    icon: connected ? Icons.link_off : Icons.link,
                    label: connected ? '断开' : '连接',
                    color: connected ? Colors.red : null,
                    onTap: () {
                      Navigator.pop(context);
                      final transferProvider = context.read<TransferProvider>();
                      _toggleConnection(transferProvider, device, connected);
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.folder_outlined,
                    label: '发送文件',
                    onTap: () {
                      Navigator.pop(context);
                      if (!connected) {
                        _connectThenNavigate(device, 'file');
                      } else {
                        _navigateToSendFile(device.ip, device.id, device.name);
                      }
                    },
                  ),
                  _buildActionButton(
                    icon: Icons.chat_outlined,
                    label: '发消息',
                    onTap: () {
                      Navigator.pop(context);
                      if (!connected) {
                        _connectThenNavigate(device, 'chat');
                      } else {
                        _navigateToChat(device.ip, device.id, device.name);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _connectThenNavigate(Device device, String action) async {
    final transferProvider = context.read<TransferProvider>();
    final success = await transferProvider.connectToDevice(device.ip, device.name);

    if (!mounted) return;

    if (success) {
      // Save to device history
      final historyProvider = context.read<DeviceHistoryProvider>();
      await historyProvider.addOrUpdateDevice(
        device.id,
        device.name,
        device.ip,
        device.typeLabel.toLowerCase(),
      );

      if (action == 'file') {
        _navigateToSendFile(device.ip, device.id, device.name);
      } else {
        _navigateToChat(device.ip, device.id, device.name);
      }
    } else {
      TopNotification.show(
        context,
        message: '连接 ${device.name} 失败',
      );
    }
  }

  Widget _buildActionButton({
    required IconData icon,
    required String label,
    required VoidCallback onTap,
    Color? color,
  }) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Icon(icon, size: 32, color: color),
            const SizedBox(height: 8),
            Text(label, style: TextStyle(color: color)),
          ],
        ),
      ),
    );
  }

  void _navigateToSendFile(String peerIp, String peerId, String peerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TransferScreen(
          peerIp: peerIp,
          peerId: peerId,
          peerName: peerName,
        ),
      ),
    );
  }

  void _navigateToChat(String peerIp, String peerId, String peerName) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ChatScreen(
          peerIp: peerIp,
          peerId: peerIp, // Use IP as peer ID for message filtering
          peerName: peerName,
        ),
      ),
    );
  }

  void _navigateToSettings() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SettingsScreen()),
    );
  }
}
