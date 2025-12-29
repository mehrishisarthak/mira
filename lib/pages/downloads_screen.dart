import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/theme_model.dart';

class DownloadsPage extends ConsumerStatefulWidget {
  const DownloadsPage({super.key});

  @override
  ConsumerState<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends ConsumerState<DownloadsPage> {
  
  // Refresh the list whenever the page opens
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
       ref.read(downloadsProvider.notifier).loadTasks();
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
          IconButton(
            icon: Icon(Icons.refresh, color: contentColor.withAlpha(179)),
            onPressed: () {
               ref.read(downloadsProvider.notifier).loadTasks();
            },
          )
        ],
      ),
      body: tasks.isEmpty
          ? Center(child: Text("No downloads yet", style: TextStyle(color: contentColor.withAlpha(128))))
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: contentColor.withAlpha(26)),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildDownloadItem(task, appTheme, contentColor);
              },
            ),
    );
  }

  Widget _buildDownloadItem(DownloadTask task, MiraTheme appTheme, Color contentColor) {
    IconData statusIcon;
    Color statusColor;
    String statusText;

    // Determine Status
    if (task.status == DownloadTaskStatus.complete) {
      statusIcon = Icons.check_circle;
      statusColor = Colors.greenAccent;
      statusText = "Completed";
    } else if (task.status == DownloadTaskStatus.failed) {
      statusIcon = Icons.error;
      statusColor = Colors.redAccent;
      statusText = "Failed";
    } else if (task.status == DownloadTaskStatus.running) {
      statusIcon = Icons.downloading;
      statusColor = appTheme.accentColor;
      statusText = "${task.progress}%";
    } else {
      statusIcon = Icons.hourglass_empty;
      statusColor = contentColor.withAlpha(128);
      statusText = "Pending";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(Icons.insert_drive_file, color: contentColor.withAlpha(77), size: 32),
      
      title: Text(
        task.filename ?? "Unknown File",
        style: TextStyle(color: contentColor, fontWeight: FontWeight.bold),
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      
      subtitle: Padding(
        padding: const EdgeInsets.only(top: 4.0),
        child: Row(
          children: [
            Icon(statusIcon, color: statusColor, size: 14),
            const SizedBox(width: 6),
            Text(statusText, style: TextStyle(color: statusColor, fontSize: 12)),
          ],
        ),
      ),
      
      trailing: IconButton(
        icon: Icon(Icons.delete_outline, color: contentColor.withAlpha(128)),
        onPressed: () {
          ref.read(downloadsProvider.notifier).deleteTask(task);
        },
      ),

      onTap: () {
        if (task.status == DownloadTaskStatus.complete) {
          ref.read(downloadsProvider.notifier).openTask(task);
        } else if (task.status == DownloadTaskStatus.failed) {
          // Retry logic could go here
          ref.read(downloadsProvider.notifier).retryTask(task);
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text("Retrying...")));
        }
      },
    );
  }
}