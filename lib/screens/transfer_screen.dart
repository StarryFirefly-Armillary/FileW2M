import 'package:flutter/material.dart';
import 'package:file_picker/file_picker.dart';
import 'package:provider/provider.dart';
import '../providers/transfer_provider.dart';
import '../widgets/transfer_progress.dart';

class TransferScreen extends StatefulWidget {
  final String peerIp;
  final String peerId;
  final String peerName;

  const TransferScreen({
    super.key,
    required this.peerIp,
    required this.peerId,
    required this.peerName,
  });

  @override
  State<TransferScreen> createState() => _TransferScreenState();
}

class _TransferScreenState extends State<TransferScreen> {
  final List<PlatformFile> _selectedFiles = [];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('文件传输'),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: Center(
              child: Consumer<TransferProvider>(
                builder: (_, provider, __) {
                  final connected = provider.isConnected(widget.peerIp);
                  return Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        connected ? Icons.link : Icons.link_off,
                        size: 16,
                        color: connected ? Colors.green : Colors.grey,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        widget.peerName,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: Theme.of(context).colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          _buildFilePicker(),
          if (_selectedFiles.isNotEmpty) _buildSelectedFiles(),
          const Divider(height: 1),
          Expanded(child: _buildTransferList()),
          _buildSendButton(),
        ],
      ),
    );
  }

  Widget _buildFilePicker() {
    return InkWell(
      onTap: _pickFiles,
      child: Container(
        margin: const EdgeInsets.all(16),
        padding: const EdgeInsets.all(32),
        decoration: BoxDecoration(
          border: Border.all(
            color: Theme.of(context).colorScheme.outline.withOpacity(0.5),
            width: 2,
            style: BorderStyle.solid,
          ),
          borderRadius: BorderRadius.circular(16),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_upload_outlined,
              size: 48,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(height: 12),
            Text(
              '点击选择文件',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 4),
            Text(
              '支持多选',
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSelectedFiles() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '已选择 ${_selectedFiles.length} 个文件',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: 8),
          ...List.generate(_selectedFiles.length, (index) {
            final file = _selectedFiles[index];
            return ListTile(
              dense: true,
              leading: const Icon(Icons.insert_drive_file_outlined, size: 20),
              title: Text(
                file.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
              subtitle: Text(_formatBytes(file.size)),
              trailing: IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () => setState(() => _selectedFiles.removeAt(index)),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildTransferList() {
    return Consumer<TransferProvider>(
      builder: (context, provider, _) {
        final tasks = provider.getTasksForPeer(widget.peerIp);

        if (tasks.isEmpty) {
          return Center(
            child: Text(
              '暂无传输任务',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: Theme.of(context).colorScheme.onSurfaceVariant,
              ),
            ),
          );
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: tasks.length,
          itemBuilder: (context, index) {
            return TransferProgress(task: tasks[index]);
          },
        );
      },
    );
  }

  Widget _buildSendButton() {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: SizedBox(
          width: double.infinity,
          height: 48,
          child: FilledButton.icon(
            icon: const Icon(Icons.send),
            label: const Text('发送文件'),
            onPressed: _selectedFiles.isEmpty ? null : _sendFiles,
          ),
        ),
      ),
    );
  }

  Future<void> _pickFiles() async {
    try {
      final result = await FilePicker.platform.pickFiles(allowMultiple: true);
      if (result != null) {
        setState(() {
          _selectedFiles.addAll(result.files);
        });
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('选择文件失败: $e')),
        );
      }
    }
  }

  Future<void> _sendFiles() async {
    final provider = context.read<TransferProvider>();

    // Ensure connection exists
    if (!provider.isConnected(widget.peerIp)) {
      final success = await provider.connectToDevice(widget.peerIp, widget.peerName);
      if (!success && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('连接设备失败')),
        );
        return;
      }
    }

    final paths = _selectedFiles.where((f) => f.path != null).map((f) => f.path!).toList();
    if (paths.isEmpty) return;

    await provider.sendFiles(paths, widget.peerIp, widget.peerId, widget.peerName);

    setState(() {
      _selectedFiles.clear();
    });

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('文件已发送')),
      );
    }
  }

  String _formatBytes(int bytes) {
    if (bytes < 1024) return '$bytes B';
    if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(1)} KB';
    if (bytes < 1024 * 1024 * 1024) {
      return '${(bytes / (1024 * 1024)).toStringAsFixed(1)} MB';
    }
    return '${(bytes / (1024 * 1024 * 1024)).toStringAsFixed(1)} GB';
  }
}
