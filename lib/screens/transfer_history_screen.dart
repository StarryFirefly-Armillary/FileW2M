import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:open_file/open_file.dart';
import '../models/file_transfer.dart';
import '../providers/transfer_provider.dart';

class TransferHistoryScreen extends StatelessWidget {
  const TransferHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        final tasks = provider.tasks;

        if (tasks.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.history,
                  size: 64,
                  color: Theme.of(context).colorScheme.onSurfaceVariant.withOpacity(0.5),
                ),
                const SizedBox(height: 16),
                Text(
                  '暂无传输记录',
                  style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                    color: Theme.of(context).colorScheme.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          );
        }

        final grouped = _groupByDate(tasks);

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: grouped.length,
          itemBuilder: (context, index) {
            final entry = grouped.entries.elementAt(index);
            return _buildDateGroup(context, entry.key, entry.value);
          },
        );
      },
    );
  }

  Map<String, List<FileTransferTask>> _groupByDate(List<FileTransferTask> tasks) {
    final Map<String, List<FileTransferTask>> grouped = {};

    for (final task in tasks) {
      final date = task.startTime;
      final now = DateTime.now();
      String key;

      if (date.day == now.day && date.month == now.month && date.year == now.year) {
        key = '今天';
      } else if (date.day == now.day - 1 && date.month == now.month && date.year == now.year) {
        key = '昨天';
      } else {
        key = '${date.month}/${date.day}';
      }

      grouped.putIfAbsent(key, () => []).add(task);
    }

    return grouped;
  }

  Widget _buildDateGroup(BuildContext context, String date, List<FileTransferTask> tasks) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Text(
            date,
            style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.onSurfaceVariant,
            ),
          ),
        ),
        ...tasks.map((task) => _buildTaskCard(context, task)),
      ],
    );
  }

  Widget _buildTaskCard(BuildContext context, FileTransferTask task) {
    final isSend = task.direction == TransferDirection.send;
    final statusIcon = _getStatusIcon(task.status);
    final statusColor = _getStatusColor(context, task.status);
    final canOpen = task.status == TransferStatus.completed && task.filePath != null;

    return GestureDetector(
      onTap: canOpen ? () => _openFile(context, task) : null,
      onSecondaryTap: canOpen ? () => _openFolder(context, task) : null,
      onLongPress: canOpen ? () => _showTaskActions(context, task) : null,
      child: Card(
        margin: const EdgeInsets.only(bottom: 8),
        child: ListTile(
          leading: Icon(
            isSend ? Icons.upload_file : Icons.download,
            color: Theme.of(context).colorScheme.primary,
          ),
          title: Text(
            task.fileName,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: canOpen ? Theme.of(context).colorScheme.primary : null,
            ),
          ),
          subtitle: Row(
            children: [
              Text(isSend ? '→ ${task.peerDeviceName}' : '← ${task.peerDeviceName}'),
              const SizedBox(width: 8),
              Text(task.sizeLabel),
            ],
          ),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(statusIcon, color: statusColor, size: 20),
              const SizedBox(width: 4),
              Text(
                _getStatusLabel(task.status),
                style: TextStyle(color: statusColor, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openFile(BuildContext context, FileTransferTask task) async {
    if (task.filePath == null) return;
    try {
      final file = File(task.filePath!);
      if (!await file.exists()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('文件不存在')),
          );
        }
        return;
      }

      if (Platform.isWindows) {
        await Process.run('cmd', ['/c', 'start', '', task.filePath!]);
      } else if (Platform.isAndroid) {
        final result = await OpenFile.open(task.filePath!);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('打开失败: ${result.message}')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件失败: $e')),
        );
      }
    }
  }

  Future<void> _openFolder(BuildContext context, FileTransferTask task) async {
    if (task.filePath == null) return;
    try {
      final file = File(task.filePath!);
      final dir = file.parent.path;

      if (Platform.isWindows) {
        await Process.run('explorer', ['/select,', task.filePath!]);
      } else if (Platform.isAndroid) {
        // Try to open folder with OpenFile using the directory
        final result = await OpenFile.open(dir);
        if (result.type != ResultType.done && context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('文件夹: $dir')),
          );
        }
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('打开文件夹失败: $e')),
        );
      }
    }
  }

  void _showTaskActions(BuildContext context, FileTransferTask task) {
    showModalBottomSheet(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.open_in_new),
              title: const Text('打开文件'),
              onTap: () {
                Navigator.pop(ctx);
                _openFile(context, task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.folder_open),
              title: const Text('打开所在文件夹'),
              onTap: () {
                Navigator.pop(ctx);
                _openFolder(context, task);
              },
            ),
            ListTile(
              leading: const Icon(Icons.copy),
              title: const Text('复制文件路径'),
              onTap: () {
                Navigator.pop(ctx);
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text(task.filePath ?? '')),
                );
              },
            ),
            if (task.filePath != null)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text('删除原文件', style: TextStyle(color: Colors.red)),
                onTap: () {
                  Navigator.pop(ctx);
                  _confirmDeleteFile(context, task);
                },
              ),
            ListTile(
              leading: const Icon(Icons.delete_sweep_outlined, color: Colors.orange),
              title: const Text('删除传输记录', style: TextStyle(color: Colors.orange)),
              onTap: () {
                Navigator.pop(ctx);
                _confirmDeleteRecord(context, task);
              },
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _confirmDeleteFile(BuildContext context, FileTransferTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除原文件'),
        content: Text('确定要删除文件 "${task.fileName}" 吗？\n\n此操作将同时删除文件和传输记录，不可撤销。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('删除'),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      await _deleteFileAndRecord(context, task);
    }
  }

  Future<void> _deleteFileAndRecord(BuildContext context, FileTransferTask task) async {
    try {
      // Delete file if it exists
      if (task.filePath != null) {
        final file = File(task.filePath!);
        if (await file.exists()) {
          await file.delete();
        }
      }

      // Delete transfer record
      final provider = context.read<TransferProvider>();
      await provider.deleteTaskAndFile(task.id);

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('文件和传输记录已删除')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  Future<void> _confirmDeleteRecord(BuildContext context, FileTransferTask task) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('删除传输记录'),
        content: const Text('确定要删除此传输记录吗？'),
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

    if (confirmed == true && context.mounted) {
      await _deleteRecord(context, task);
    }
  }

  Future<void> _deleteRecord(BuildContext context, FileTransferTask task) async {
    try {
      final provider = context.read<TransferProvider>();
      await provider.deleteTaskAndFile(task.id);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('传输记录已删除')),
        );
      }
    } catch (e) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('删除失败: $e')),
        );
      }
    }
  }

  IconData _getStatusIcon(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Icons.check_circle;
      case TransferStatus.failed:
        return Icons.error;
      case TransferStatus.transferring:
        return Icons.sync;
      case TransferStatus.pending:
        return Icons.schedule;
      case TransferStatus.cancelled:
        return Icons.cancel;
    }
  }

  Color _getStatusColor(BuildContext context, TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return Colors.green;
      case TransferStatus.failed:
        return Colors.red;
      case TransferStatus.transferring:
        return Theme.of(context).colorScheme.primary;
      case TransferStatus.pending:
        return Theme.of(context).colorScheme.onSurfaceVariant;
      case TransferStatus.cancelled:
        return Theme.of(context).colorScheme.onSurfaceVariant;
    }
  }

  String _getStatusLabel(TransferStatus status) {
    switch (status) {
      case TransferStatus.completed:
        return '已完成';
      case TransferStatus.failed:
        return '失败';
      case TransferStatus.transferring:
        return '传输中';
      case TransferStatus.pending:
        return '等待中';
      case TransferStatus.cancelled:
        return '已取消';
    }
  }
}
