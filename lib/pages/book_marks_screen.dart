import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/pages/mainscreen.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);
    final appTheme = ref.watch(themeProvider);
    final isLightMode = appTheme.mode == ThemeMode.light;
    final contentColor = isLightMode ? Colors.black87 : Colors.white;

    return Scaffold(
      backgroundColor: appTheme.backgroundColor,
      appBar: AppBar(
        title: Text("Bookmarks", style: TextStyle(color: contentColor)),
        backgroundColor: appTheme.surfaceColor,
        leading: IconButton(
          icon: Icon(Icons.arrow_back, color: contentColor),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bookmarks.isEmpty
          ? Center(child: Text("No bookmarks yet", style: TextStyle(color: contentColor.withAlpha(128))))
          : ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => Divider(height: 1, color: contentColor.withAlpha(26)),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  leading: Icon(Icons.bookmark, color: appTheme.accentColor),
                  title: Text(
                    bookmark.title,
                    style: TextStyle(color: contentColor),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    bookmark.url,
                    style: TextStyle(color: contentColor.withAlpha(128), fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: Icon(Icons.delete_outline, color: contentColor.withAlpha(128)),
                    onPressed: () {
                      ref.read(bookmarksProvider.notifier).removeBookmark(bookmark.url);
                    },
                  ),
                  onTap: () {
                    // Load URL and close screen
                    ref.read(tabsProvider.notifier).updateUrl(bookmark.url);
                    ref.read(webViewControllerProvider)?.loadUrl(
                      urlRequest: URLRequest(url: WebUri(bookmark.url))
                    );
                    Navigator.pop(context);
                  },
                );
              },
            ),
    );
  }
}