import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/search_model.dart';
import 'package:mira/pages/mainscreen.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), // Match theme
      appBar: AppBar(
        title: const Text("History", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
               ref.read(historyProvider.notifier).clearAllHistory();
            },
            tooltip: "Clear All History",
          )
        ],
      ),
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.only(top: 10),
          child: HistoryList(),
        ),
      ),
    );
  }
}

class HistoryList extends ConsumerWidget {
  const HistoryList({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. Watch the History Data
    final history = ref.watch(historyProvider);

    if (history.isEmpty) {
      return const Center(
        child: Padding(
          padding: EdgeInsets.all(20.0),
          child: Text("No history yet", style: TextStyle(color: Colors.white54)),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true, // Important if inside another ScrollView
      physics: const NeverScrollableScrollPhysics(), // Let the parent scroll
      itemCount: history.length,
      separatorBuilder: (context, index) => const Divider(height: 1, color: Colors.white10),
      itemBuilder: (context, index) {
        final item = history[index];
        return ListTile(
          leading: const Icon(Icons.history, color: Colors.white30, size: 20),
          title: Text(item.text, style: const TextStyle(color: Colors.white70)),
          trailing: IconButton(
            icon: const Icon(Icons.close, color: Colors.white12, size: 18),
            onPressed: () {
               ref.read(historyProvider.notifier).removeFromHistory(item);
            },
          ),
          
          // 3. CLICK -> GO LOGIC
          onTap: () {
            // A. Close keyboard/sheets if open
            FocusManager.instance.primaryFocus?.unfocus();
            
            // B. If we are on the History Page, we might need to pop back to Main
            // But usually, we just update the provider and the Mainscreen (if active) reacts.
            // If HistoryPage is a full screen route, we should pop it first.
            if (Navigator.canPop(context)) {
               Navigator.pop(context);
            }

            // C. Format the URL
            String finalUrl;
            if (item.text.contains('.') && !item.text.contains(' ')) {
               finalUrl = "https://${item.text}";
            } else {
               finalUrl = ref.read(formattedSearchUrlProvider(item.text));
            }

            // D. Load it!
            ref.read(searchProvider.notifier).updateUrl(finalUrl);
            ref.read(webViewControllerProvider)?.loadUrl(
               urlRequest: URLRequest(url: WebUri(finalUrl))
            );
          },
        );
      },
    );
  }
}