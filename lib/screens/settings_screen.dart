import 'dart:io';
import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../providers/settings_provider.dart';
import '../providers/transfer_provider.dart';
import '../services/background_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('设置')),
      body: Consumer<SettingsProvider>(
        builder: (context, settings, _) {
          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              _buildSection(
                context,
                title: '设备信息',
                children: [
                  _buildEditableTile(
                    context,
                    icon: Icons.phone_android,
                    title: '设备名称',
                    value: settings.deviceName,
                    onChanged: (value) => settings.setDeviceName(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: '文件接收',
                children: [
                  _buildPathTile(
                    context,
                    icon: Icons.folder_outlined,
                    title: '保存位置',
                    path: settings.savePath,
                    onTap: () => _pickSavePath(context, settings),
                  ),
                  _buildSwitchTile(
                    context,
                    icon: Icons.download_done,
                    title: '自动接收文件',
                    subtitle: '收到文件请求时自动接收',
                    value: settings.autoAccept,
                    onChanged: (value) => settings.setAutoAccept(value),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: '连接',
                children: [
                  Consumer<TransferProvider>(
                    builder: (context, transferProvider, _) {
                      return _buildSwitchTile(
                        context,
                        icon: Icons.link,
                        title: '自动同意连接请求',
                        subtitle: '收到连接请求时自动同意，无需手动确认',
                        value: transferProvider.autoAcceptConnections,
                        onChanged: (value) => transferProvider.setAutoAcceptConnections(value),
                      );
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: '通知',
                children: [
                  _buildSwitchTile(
                    context,
                    icon: Icons.notifications_outlined,
                    title: '传输完成通知',
                    subtitle: '文件传输完成时显示通知',
                    value: settings.notifyOnComplete,
                    onChanged: (value) => settings.setNotifyOnComplete(value),
                  ),
                ],
              ),
              if (Platform.isAndroid) ...[
                const SizedBox(height: 16),
                _buildSection(
                  context,
                  title: '后台运行',
                  children: [
                    _buildSwitchTile(
                      context,
                      icon: Icons.phone_android,
                      title: '后台保持连接',
                      subtitle: '应用在后台时仍然保持设备连接',
                      value: settings.backgroundService,
                      onChanged: (value) async {
                        await settings.setBackgroundService(value);
                        final backgroundService = BackgroundService();
                        if (value) {
                          await backgroundService.startService();
                        } else {
                          await backgroundService.stopService();
                        }
                      },
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 16),
              _buildSection(
                context,
                title: '关于',
                children: [
                  const ListTile(
                    leading: Icon(Icons.info_outline),
                    title: Text('版本'),
                    subtitle: Text('1.0.0'),
                  ),
                  const ListTile(
                    leading: Icon(Icons.person_outline),
                    title: Text('作者'),
                    subtitle: Text('StarryFirefly'),
                  ),
                  ListTile(
                    leading: const Icon(Icons.code),
                    title: const Text('GitHub'),
                    subtitle: const Text('https://github.com/StarryFirefly-Armillary'),
                    trailing: const Icon(Icons.open_in_new, size: 20),
                    onTap: () => _launchUrl('https://github.com/StarryFirefly-Armillary'),
                  ),
                ],
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildSection(
    BuildContext context, {
    required String title,
    required List<Widget> children,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 16, bottom: 8),
          child: Text(
            title,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
        ),
        Card(
          child: Column(children: children),
        ),
      ],
    );
  }

  Widget _buildEditableTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String value,
    required ValueChanged<String> onChanged,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(value),
      trailing: const Icon(Icons.edit_outlined, size: 20),
      onTap: () => _showEditDialog(context, title, value, onChanged),
    );
  }

  Widget _buildPathTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String path,
    required VoidCallback onTap,
  }) {
    return ListTile(
      leading: Icon(icon),
      title: Text(title),
      subtitle: Text(
        path,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: const Icon(Icons.folder_open, size: 20),
      onTap: onTap,
    );
  }

  Widget _buildSwitchTile(
    BuildContext context, {
    required IconData icon,
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile(
      secondary: Icon(icon),
      title: Text(title),
      subtitle: Text(subtitle),
      value: value,
      onChanged: onChanged,
    );
  }

  void _showEditDialog(
    BuildContext context,
    String title,
    String currentValue,
    ValueChanged<String> onChanged,
  ) {
    final controller = TextEditingController(text: currentValue);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('修改$title'),
        content: TextField(
          controller: controller,
          autofocus: true,
          decoration: InputDecoration(
            labelText: title,
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              onChanged(controller.text.trim());
              Navigator.pop(context);
            },
            child: const Text('确定'),
          ),
        ],
      ),
    );
  }

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _pickSavePath(BuildContext context, SettingsProvider settings) async {
    try {
      // Don't pass initialDirectory if it doesn't exist
      String? initialDir;
      if (settings.savePath.isNotEmpty) {
        final dir = Directory(settings.savePath);
        if (await dir.exists()) {
          initialDir = settings.savePath;
        }
      }

      final result = await FilePicker.platform.getDirectoryPath(
        dialogTitle: '选择文件保存位置',
        initialDirectory: initialDir,
      );
      if (result != null) {
        await settings.setSavePath(result);
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择目录失败: $e')),
        );
      }
    }
  }
}
