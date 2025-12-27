import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/pages/mainscreen.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: const Color(0xFF121212), 
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
               // FIX 1: Method name is clearHistory() in our provider
               ref.read(historyProvider.notifier).clearHistory();
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
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
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
          
          onTap: () {
            // 1. Close keyboard
            FocusManager.instance.primaryFocus?.unfocus();
            
            // 2. Close History Page (Go back to Browser)
            if (Navigator.canPop(context)) {
               Navigator.pop(context);
            }

            // 3. Format URL
            String finalUrl;
            if (item.text.contains('.') && !item.text.contains(' ')) {
               finalUrl = "https://${item.text}";
            } else {
               finalUrl = ref.read(formattedSearchUrlProvider(item.text));
            }

            // FIX 2: Update the TAB provider, not the old search provider
            ref.read(tabsProvider.notifier).updateUrl(finalUrl);
            
            // 4. Load in WebView
            ref.read(webViewControllerProvider)?.loadUrl(
               urlRequest: URLRequest(url: WebUri(finalUrl))
            );
          },
        );
      },
    );
  }
}