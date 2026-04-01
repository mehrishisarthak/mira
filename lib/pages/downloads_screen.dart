import 'package:flutter/foundation.dart';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
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
  @override
  void initState() {
    super.initState();
    // On mobile, reload from flutter_downloader DB when the screen opens.
    // On desktop, state is already live in the provider.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!kIsWeb && (Platform.isAndroid || Platform.isIOS)) {
        ref.read(downloadsProvider.notifier).loadTasks();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final tasks = ref.watch(downloadsProvider);
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Downloads", style: TextStyle(color: contentColor)),
        backgroundColor: appTheme.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          // Refresh only makes sense on mobile (pulls from flutter_downloader DB).
          if (!kIsWeb && (Platform.isAndroid || Platform.isIOS))
            IconButton(
              icon: Icon(Icons.refresh, color: contentColor.withAlpha(179)),
              onPressed: () =>
                  ref.read(downloadsProvider.notifier).loadTasks(),
            ),
        ],
      ),
      body: tasks.isEmpty
          ? Center(
              child: Text(
                "No downloads yet",
                style: TextStyle(color: contentColor.withAlpha(128)),
              ),
            )
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) =>
                  Divider(height: 1, color: contentColor.withAlpha(26)),
              itemBuilder: (context, index) {
                return _buildDownloadItem(
                    tasks[index], appTheme, contentColor);
              },
            ),
    );
  }

  Widget _buildDownloadItem(
      MiraDownloadTask task, MiraTheme appTheme, Color contentColor) {
    final IconData statusIcon;
    final Color statusColor;
    final String statusText;

    switch (task.status) {
      case MiraDownloadStatus.completed:
        statusIcon = Icons.check_circle;
        statusColor = Colors.greenAccent;
        statusText = "Completed";
      case MiraDownloadStatus.failed:
        statusIcon = Icons.error;
        statusColor = Colors.redAccent;
        statusText = task.error != null ? "Failed" : "Failed";
      case MiraDownloadStatus.running:
        statusIcon = Icons.downloading;
        statusColor = appTheme.accentColor;
        statusText = "${task.progress}%";
      case MiraDownloadStatus.pending:
        statusIcon = Icons.hourglass_empty;
        statusColor = contentColor.withAlpha(128);
        statusText = "Pending";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading:
          Icon(Icons.insert_drive_file, color: contentColor.withAlpha(77), size: 32),
      title: Text(
        task.filename,
        style: TextStyle(color: contentColor, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(statusIcon, color: statusColor, size: 14),
                const SizedBox(width: 6),
                Text(statusText,
                    style: TextStyle(color: statusColor, fontSize: 12)),
                if (task.status == MiraDownloadStatus.failed &&
                    task.error != null) ...[
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      task.error!,
                      style: TextStyle(
                          color: Colors.redAccent.withAlpha(153), fontSize: 11),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ],
            ),
            // Progress bar for in-progress downloads
            if (task.status == MiraDownloadStatus.running) ...[
              const SizedBox(height: 6),
              LinearProgressIndicator(
                value: task.progress > 0 ? task.progress / 100 : null,
                backgroundColor: contentColor.withAlpha(26),
                color: appTheme.accentColor,
                minHeight: 2,
              ),
            ],
          ],
        ),
      ),
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: contentColor.withAlpha(128)),
        onPressed: () => ref.read(downloadsProvider.notifier).deleteTask(task),
      ),
      onTap: () {
        if (task.status == MiraDownloadStatus.completed) {
          ref.read(downloadsProvider.notifier).openTask(task);
        } else if (task.status == MiraDownloadStatus.failed) {
          ref.read(downloadsProvider.notifier).retryTask(task);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text("Retrying...")),
          );
        }
      },
    );
  }
}

