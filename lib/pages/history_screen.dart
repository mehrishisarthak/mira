import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/pages/mainscreen.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: appTheme.backgroundColor, 
      appBar: AppBar(
        title: Text("History", style: TextStyle(color: contentColor)),
        backgroundColor: appTheme.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep, color: Colors.redAccent),
            onPressed: () {
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
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    if (history.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Text("No history yet", style: TextStyle(color: contentColor.withAlpha(128))),
        ),
      );
    }

    return ListView.separated(
      shrinkWrap: true, 
      physics: const NeverScrollableScrollPhysics(), 
      itemCount: history.length,
      separatorBuilder: (context, index) => Divider(height: 1, color: contentColor.withAlpha(26)),
      itemBuilder: (context, index) {
        final item = history[index];
        return ListTile(
          leading: Icon(Icons.history, color: contentColor.withAlpha(77), size: 20),
          title: Text(item.text, style: TextStyle(color: contentColor.withAlpha(179))),
          trailing: IconButton(
            icon: Icon(Icons.close, color: contentColor.withAlpha(51), size: 18),
            onPressed: () {
               ref.read(historyProvider.notifier).removeFromHistory(item);
            },
          ),
          
          onTap: () {
            FocusManager.instance.primaryFocus?.unfocus();
            
            if (Navigator.canPop(context)) {
               Navigator.pop(context);
            }

            String finalUrl;
            if (item.text.contains('.') && !item.text.contains(' ')) {
               finalUrl = "https://${item.text}";
            } else {
               finalUrl = ref.read(formattedSearchUrlProvider(item.text));
            }

            ref.read(tabsProvider.notifier).updateUrl(finalUrl);
            
            ref.read(webViewControllerProvider)?.loadUrl(
               urlRequest: URLRequest(url: WebUri(finalUrl))
            );
          },
        );
      },
    );
  }
}