import 'package:flutter/material.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/search_notifier.dart';
import 'package:mira/core/notifiers/ghost_notifier.dart';
import 'package:mira/core/notifiers/history_notifier.dart';
import 'package:mira/core/notifiers/tab_notifier.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

class HistoryPage extends ConsumerWidget {
  const HistoryPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? kMiraInkPrimary : Colors.white;
    final history = ref.watch(historyProvider);

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
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (ctx) {
                  final appTheme = ref.read(themeProvider);
                  final isLight = appTheme.mode == ThemeMode.light;
                  final dialogText = isLight ? kMiraInkPrimary : Colors.white;
                  return AlertDialog(
                    backgroundColor: appTheme.surfaceColor,
                    title: Text('Clear all history?',
                        style: TextStyle(color: dialogText)),
                    content: Text(
                      'This removes every history entry. This cannot be undone.',
                      style: TextStyle(color: dialogText.withAlpha(179)),
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: Text('Cancel',
                            style: TextStyle(
                                color: dialogText.withAlpha(128))),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Clear',
                            style: TextStyle(color: Colors.redAccent)),
                      ),
                    ],
                  );
                },
              );
              if (ok == true && context.mounted) {
                ref.read(historyProvider.notifier).clearHistory();
              }
            },
            tooltip: "Clear All History",
          )
        ],
      ),
      body: history.isEmpty
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Text("No history yet",
                    style: TextStyle(color: contentColor.withAlpha(128))),
              ),
            )
          : CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.only(top: 10),
                  sliver: SliverList.separated(
                    itemCount: history.length,
                    separatorBuilder: (context, index) => Divider(
                        height: 1, color: contentColor.withAlpha(26)),
                    itemBuilder: (context, index) {
                      final item = history[index];
                      return ListTile(
                        leading: Icon(Icons.history,
                            color: contentColor.withAlpha(77), size: 20),
                        title: Text(item.text,
                            style:
                                TextStyle(color: contentColor.withAlpha(179))),
                        trailing: IconButton(
                          icon: Icon(Icons.close,
                              color: contentColor.withAlpha(51), size: 18),
                          onPressed: () {
                            ref
                                .read(historyProvider.notifier)
                                .removeFromHistory(item);
                          },
                        ),
                        onTap: () {
                          FocusManager.instance.primaryFocus?.unfocus();

                          if (Navigator.canPop(context)) {
                            Navigator.pop(context);
                          }

                          String finalUrl;
                          if (item.text.contains('.') &&
                              !item.text.contains(' ')) {
                            finalUrl = "https://${item.text}";
                          } else {
                            finalUrl = ref
                                .read(formattedSearchUrlProvider(item.text));
                          }

                          final inGhost = ref.read(isGhostModeProvider);
                          if (inGhost) {
                            ref
                                .read(ghostTabsProvider.notifier)
                                .updateUrl(finalUrl);
                          } else {
                            ref.read(tabsProvider.notifier).updateUrl(finalUrl);
                          }

                          ref.read(browserChromeProvider).controller?.loadUrl(
                                urlRequest:
                                    URLRequest(url: WebUri(finalUrl)),
                              );
                        },
                      );
                    },
                  ),
                ),
              ],
            ),
    );
  }
}
