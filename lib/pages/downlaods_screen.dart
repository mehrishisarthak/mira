import 'package:flutter/material.dart';
import 'package:flutter_downloader/flutter_downloader.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/download_model.dart';

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

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Downloads", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh, color: Colors.white70),
            onPressed: () {
               ref.read(downloadsProvider.notifier).loadTasks();
            },
          )
        ],
      ),
      body: tasks.isEmpty
          ? const Center(child: Text("No downloads yet", style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              itemCount: tasks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final task = tasks[index];
                return _buildDownloadItem(task);
              },
            ),
    );
  }

  Widget _buildDownloadItem(DownloadTask task) {
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
      statusColor = Colors.blueAccent;
      statusText = "${task.progress}%";
    } else {
      statusIcon = Icons.hourglass_empty;
      statusColor = Colors.white54;
      statusText = "Pending";
    }

    return ListTile(
      contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      leading: Icon(Icons.insert_drive_file, color: Colors.white30, size: 32),
      
      title: Text(
        task.filename ?? "Unknown File",
        style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
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
        icon: const Icon(Icons.delete_outline, color: Colors.white38),
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