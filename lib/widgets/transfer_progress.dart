import 'package:flutter/material.dart';
import '../models/file_transfer.dart';

class TransferProgress extends StatelessWidget {
  final FileTransferTask task;

  const TransferProgress({super.key, required this.task});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildHeader(context),
            const SizedBox(height: 12),
            _buildProgressBar(context),
            const SizedBox(height: 8),
            _buildDetails(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Row(
      children: [
        Icon(
          _getFileIcon(task.fileName),
          color: Theme.of(context).colorScheme.primary,
          size: 20,
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            task.fileName,
            style: Theme.of(context).textTheme.titleSmall,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ),
        _buildStatusBadge(context),
      ],
    );
  }

  Widget _buildStatusBadge(BuildContext context) {
    Color color;
    String label;
    IconData icon;

    switch (task.status) {
      case TransferStatus.pending:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        label = '等待中';
        icon = Icons.schedule;
        break;
      case TransferStatus.transferring:
        color = Theme.of(context).colorScheme.primary;
        label = task.progressPercent;
        icon = Icons.sync;
        break;
      case TransferStatus.completed:
        color = Colors.green;
        label = '已完成';
        icon = Icons.check_circle;
        break;
      case TransferStatus.failed:
        color = Colors.red;
        label = '失败';
        icon = Icons.error;
        break;
      case TransferStatus.cancelled:
        color = Theme.of(context).colorScheme.onSurfaceVariant;
        label = '已取消';
        icon = Icons.cancel;
        break;
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(color: color, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar(BuildContext context) {
    final color = task.status == TransferStatus.failed
        ? Colors.red
        : task.status == TransferStatus.completed
            ? Colors.green
            : Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(4),
      child: LinearProgressIndicator(
        value: task.progress,
        minHeight: 8,
        backgroundColor: Theme.of(context).colorScheme.surfaceContainerHighest,
        valueColor: AlwaysStoppedAnimation<Color>(color),
      ),
    );
  }

  Widget _buildDetails(BuildContext context) {
    if (task.status == TransferStatus.pending) {
      return Text(
        '等待传输...',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Theme.of(context).colorScheme.onSurfaceVariant,
        ),
      );
    }

    if (task.status == TransferStatus.completed) {
      return Text(
        '${task.sizeLabel} · SHA-256 校验通过',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.green,
        ),
      );
    }

    if (task.status == TransferStatus.failed) {
      return Text(
        task.errorMessage ?? '传输失败',
        style: Theme.of(context).textTheme.bodySmall?.copyWith(
          color: Colors.red,
        ),
      );
    }

    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          '${task.transferredLabel} / ${task.sizeLabel}',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        Text(
          '${task.speedLabel} · 剩余 ${task.remainingTime}',
          style: Theme.of(context).textTheme.bodySmall?.copyWith(
            color: Theme.of(context).colorScheme.onSurfaceVariant,
          ),
        ),
      ],
    );
  }

  IconData _getFileIcon(String fileName) {
    final ext = fileName.split('.').last.toLowerCase();
    switch (ext) {
      case 'jpg':
      case 'jpeg':
      case 'png':
      case 'gif':
      case 'bmp':
      case 'webp':
        return Icons.image;
      case 'mp4':
      case 'avi':
      case 'mkv':
      case 'mov':
      case 'wmv':
        return Icons.video_file;
      case 'mp3':
      case 'wav':
      case 'flac':
      case 'aac':
      case 'ogg':
        return Icons.audio_file;
      case 'pdf':
        return Icons.picture_as_pdf;
      case 'doc':
      case 'docx':
      case 'txt':
      case 'rtf':
        return Icons.description;
      case 'zip':
      case 'rar':
      case '7z':
      case 'tar':
      case 'gz':
        return Icons.archive;
      default:
        return Icons.insert_drive_file;
    }
  }
}
