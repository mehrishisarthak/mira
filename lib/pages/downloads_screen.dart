import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:mira/core/entities/download_entity.dart';
import 'package:mira/core/services/download_provider.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';


class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  String _searchQuery = '';
  String _selectedFilter = 'All';

  final List<String> _filters = ['All', 'Images', 'Documents', 'Media', 'Archives', 'Other'];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        ref.read(downloadsProvider.notifier).loadTasks();
      }
    });
  }

  bool _matchesFilter(MiraDownloadTask task) {
    if (_selectedFilter == 'All') return true;
    final ext = task.filename.split('.').last.toLowerCase();
    switch (_selectedFilter) {
      case 'Images':
        return ['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp'].contains(ext);
      case 'Documents':
        return ['pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx'].contains(ext);
      case 'Media':
        return ['mp3', 'mp4', 'wav', 'avi', 'mkv', 'mov'].contains(ext);
      case 'Archives':
        return ['zip', 'rar', 'tar', 'gz', '7z'].contains(ext);
      case 'Other':
      default:
        return !(['jpg', 'jpeg', 'png', 'gif', 'webp', 'bmp', 'pdf', 'doc', 'docx', 'txt', 'rtf', 'xls', 'xlsx', 'mp3', 'mp4', 'wav', 'avi', 'mkv', 'mov', 'zip', 'rar', 'tar', 'gz', '7z'].contains(ext));
    }
  }

  void _showClearDialog(BuildContext context, Color contentColor, MiraTheme appTheme) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: appTheme.surfaceColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Clear Downloads',
                style: TextStyle(
                  color: contentColor,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Choose how you want to clear your downloads.',
                style: TextStyle(
                  color: contentColor.withAlpha(150),
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: contentColor.withAlpha(20),
                  foregroundColor: contentColor,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ref.read(downloadsProvider.notifier).clearHistory(deleteFiles: false);
                  Navigator.pop(ctx);
                },
                child: const Text('Clear History Only', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.red.withAlpha(30),
                  foregroundColor: Colors.red,
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: () {
                  ref.read(downloadsProvider.notifier).clearHistory(deleteFiles: true);
                  Navigator.pop(ctx);
                },
                child: const Text('Delete Files & History', style: TextStyle(fontWeight: FontWeight.w600)),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.pop(ctx),
                style: TextButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  foregroundColor: contentColor.withAlpha(150),
                ),
                child: const Text('Cancel'),
              ),
            ],
          ),
        );
      }
    );
  }

  @override
  Widget build(BuildContext context) {
    final allTasks = ref.watch(downloadsProvider);
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? kMiraInkPrimary : Colors.white;

    final filteredTasks = allTasks.where((task) {
      final matchesSearch = task.filename.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesSearch && _matchesFilter(task);
    }).toList();

    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Downloads", style: TextStyle(color: contentColor, fontSize: 20, fontWeight: FontWeight.w600)),
        backgroundColor: appTheme.surfaceColor,
        elevation: 0,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          if (allTasks.isNotEmpty)
            IconButton(
              icon: Icon(Icons.delete_outline, color: contentColor.withAlpha(200)),
              onPressed: () => _showClearDialog(context, contentColor, appTheme),
            ),
        ],
      ),
      body: Column(
        children: [
          Container(
            color: appTheme.surfaceColor,
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Column(
              children: [
                CupertinoSearchTextField(
                  style: TextStyle(color: contentColor),
                  backgroundColor: contentColor.withAlpha(15),
                  placeholderStyle: TextStyle(color: contentColor.withAlpha(100)),
                  itemColor: contentColor.withAlpha(150),
                  onChanged: (val) => setState(() => _searchQuery = val),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  height: 36,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: _filters.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, index) {
                      final filter = _filters[index];
                      final isSelected = _selectedFilter == filter;
                      return ActionChip(
                        label: Text(filter),
                        labelStyle: TextStyle(
                          color: isSelected ? appTheme.surfaceColor : contentColor,
                          fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                          fontSize: 13,
                        ),
                        backgroundColor: isSelected ? contentColor : contentColor.withAlpha(10),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20), side: BorderSide(color: isSelected ? Colors.transparent : contentColor.withAlpha(20))),
                        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 0),
                        onPressed: () => setState(() => _selectedFilter = filter),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: filteredTasks.isEmpty
                ? Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.download_outlined, size: 52, color: contentColor.withAlpha(40)),
                        const SizedBox(height: 16),
                        Text(
                          allTasks.isEmpty ? 'No downloads yet' : 'No matching downloads',
                          style: TextStyle(color: contentColor.withAlpha(128), fontSize: 15, fontWeight: FontWeight.w500),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    itemCount: filteredTasks.length,
                    separatorBuilder: (_, __) => Divider(height: 1, color: contentColor.withAlpha(15), indent: 72),
                    itemBuilder: (context, index) {
                      return _buildDownloadItem(filteredTasks[index], appTheme, contentColor);
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildThumbnail(MiraDownloadTask task, Color contentColor) {
    final ext = task.filename.split('.').last.toLowerCase();
    final isImage = ['jpg', 'jpeg', 'png', 'gif', 'webp'].contains(ext);
    
    if (isImage && task.status == MiraDownloadStatus.completed && File(task.savePath).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(task.savePath),
          width: 48,
          height: 48,
          fit: BoxFit.cover,
          cacheWidth: 100, // Optimize memory (O-33)
          errorBuilder: (c, e, s) => _buildIcon(ext, contentColor),
        ),
      );
    }
    
    return _buildIcon(ext, contentColor);
  }

  Widget _buildIcon(String ext, Color contentColor) {
    IconData icon;
    Color color;

    if (['pdf'].contains(ext)) {
      icon = Icons.picture_as_pdf;
      color = Colors.red;
    } else if (['doc', 'docx', 'txt'].contains(ext)) {
      icon = Icons.description;
      color = Colors.blue;
    } else if (['mp3', 'wav', 'mp4', 'mkv'].contains(ext)) {
      icon = Icons.play_circle_outline;
      color = Colors.orange;
    } else if (['zip', 'rar'].contains(ext)) {
      icon = Icons.folder_zip;
      color = Colors.purple;
    } else if (['jpg', 'jpeg', 'png'].contains(ext)) {
      icon = Icons.image;
      color = Colors.green;
    } else {
      icon = Icons.insert_drive_file;
      color = contentColor.withAlpha(150);
    }

    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        color: color.withAlpha(20),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(icon, color: color, size: 24),
    );
  }

  Widget _buildDownloadItem(MiraDownloadTask task, MiraTheme appTheme, Color contentColor) {
    return InkWell(
      onTap: task.status == MiraDownloadStatus.completed
          ? () => ref.read(downloadsProvider.notifier).openTask(task)
          : null,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            _buildThumbnail(task, contentColor),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    task.filename,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: contentColor,
                      fontSize: 15,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (task.status == MiraDownloadStatus.running || task.status == MiraDownloadStatus.paused)
                    _buildProgressRow(task, contentColor)
                  else
                    _buildMetadataRow(task, contentColor),
                ],
              ),
            ),
            _buildTrailingAction(task, contentColor),
          ],
        ),
      ),
    );
  }

  Widget _buildMetadataRow(MiraDownloadTask task, Color contentColor) {
    final metaColor = contentColor.withAlpha(128);
    final size = task.fileSizeString ?? 'Unknown Size';
    final date = task.timestamp != null ? DateFormat('MMM d, h:mm a').format(task.timestamp!) : '';
    
    String subText = size;
    if (task.status == MiraDownloadStatus.failed) subText = 'Failed • $size';
    if (task.status == MiraDownloadStatus.canceled) subText = 'Canceled • $size';
    if (date.isNotEmpty && task.status == MiraDownloadStatus.completed) subText += ' • $date';

    return Text(
      subText,
      style: TextStyle(color: metaColor, fontSize: 13),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildProgressRow(MiraDownloadTask task, Color contentColor) {
    return Row(
      children: [
        Expanded(
          child: ClipRRect(
            borderRadius: BorderRadius.circular(2),
            child: LinearProgressIndicator(
              value: task.progress > 0 ? task.progress / 100 : null,
              backgroundColor: contentColor.withAlpha(20),
              valueColor: AlwaysStoppedAnimation(contentColor),
              minHeight: 4,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Text(
          '${task.progress}%',
          style: TextStyle(
            color: contentColor.withAlpha(128),
            fontSize: 12,
            fontWeight: FontWeight.w500,
          ),
        ),
      ],
    );
  }

  Widget _buildTrailingAction(MiraDownloadTask task, Color contentColor) {
    final notifier = ref.read(downloadsProvider.notifier);

    if (task.status == MiraDownloadStatus.running) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.pause, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.pauseTask(task),
          ),
          IconButton(
            icon: Icon(Icons.close, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.cancelTask(task),
          ),
        ],
      );
    } else if (task.status == MiraDownloadStatus.paused) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.play_arrow, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.resumeTask(task),
          ),
          IconButton(
            icon: Icon(Icons.close, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.cancelTask(task),
          ),
        ],
      );
    } else if (task.status == MiraDownloadStatus.failed || task.status == MiraDownloadStatus.canceled) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          IconButton(
            icon: Icon(Icons.refresh, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.retryTask(task),
          ),
          IconButton(
            icon: Icon(Icons.delete_outline, color: contentColor.withAlpha(150)),
            onPressed: () => notifier.deleteTask(task),
          ),
        ],
      );
    }

    // Completed state
    return IconButton(
      icon: Icon(Icons.more_vert, color: contentColor.withAlpha(100)),
      onPressed: () {
        // Simple delete bottom sheet for individual item
        showModalBottomSheet(
          context: context,
          backgroundColor: Colors.transparent,
          builder: (ctx) => Container(
            padding: const EdgeInsets.symmetric(vertical: 16),
            decoration: BoxDecoration(
              color: ref.read(themeProvider).surfaceColor,
              borderRadius: const BorderRadius.vertical(top: Radius.circular(16)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                ListTile(
                  leading: const Icon(Icons.history_toggle_off),
                  title: const Text('Clear from History'),
                  onTap: () {
                    notifier.deleteTask(task, deleteFile: false); 
                    Navigator.pop(ctx);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.delete_outline, color: Colors.red),
                  title: const Text('Delete File & History', style: TextStyle(color: Colors.red)),
                  onTap: () {
                    notifier.deleteTask(task, deleteFile: true); 
                    Navigator.pop(ctx);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
