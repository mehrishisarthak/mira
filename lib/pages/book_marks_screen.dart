import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/pages/mainscreen.dart';

class BookmarksPage extends ConsumerWidget {
  const BookmarksPage({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bookmarks = ref.watch(bookmarksProvider);

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        title: const Text("Bookmarks", style: TextStyle(color: Colors.white)),
        backgroundColor: const Color(0xFF1E1E1E),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.pop(context),
        ),
      ),
      body: bookmarks.isEmpty
          ? const Center(child: Text("No bookmarks yet", style: TextStyle(color: Colors.white54)))
          : ListView.separated(
              itemCount: bookmarks.length,
              separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white10),
              itemBuilder: (context, index) {
                final bookmark = bookmarks[index];
                return ListTile(
                  leading: const Icon(Icons.bookmark, color: Colors.yellowAccent),
                  title: Text(
                    bookmark.title,
                    style: const TextStyle(color: Colors.white),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  subtitle: Text(
                    bookmark.url,
                    style: const TextStyle(color: Colors.white38, fontSize: 12),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  trailing: IconButton(
                    icon: const Icon(Icons.delete_outline, color: Colors.white38),
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