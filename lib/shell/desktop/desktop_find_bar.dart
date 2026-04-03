import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/notifiers/theme_notifier.dart';
import 'package:mira/pages/browser_chrome_providers.dart';

/// Chrome-style persistent find bar for desktop window layouts.
class DesktopFindBar extends ConsumerStatefulWidget {
  const DesktopFindBar({super.key});

  @override
  ConsumerState<DesktopFindBar> createState() => _DesktopFindBarState();
}

class _DesktopFindBarState extends ConsumerState<DesktopFindBar> {
  static const String _desktopFindScript = r'''
(() => {
  const state = window.__miraFindState || {
    marks: [],
    index: -1,
    styleTagId: '__mira_find_style__'
  };

  const ensureStyles = () => {
    if (document.getElementById(state.styleTagId)) return;
    const style = document.createElement('style');
    style.id = state.styleTagId;
    style.textContent = `
      mark[data-mira-find="1"] {
        background: rgba(255, 235, 59, 0.72);
        color: #000;
        padding: 0;
      }
      mark[data-mira-find-active="1"] {
        background: rgba(76, 175, 80, 0.92);
        color: #000;
      }
    `;
    document.head.appendChild(style);
  };

  const clearSelection = () => {
    const sel = window.getSelection && window.getSelection();
    if (sel) {
      sel.removeAllRanges();
    }
  };

  const clear = () => {
    const marks = Array.from(document.querySelectorAll('mark[data-mira-find="1"]'));
    for (const mark of marks) {
      const parent = mark.parentNode;
      if (!parent) continue;
      const text = document.createTextNode(mark.textContent || '');
      parent.replaceChild(text, mark);
      parent.normalize();
    }
    state.marks = [];
    state.index = -1;
    clearSelection();
    return { count: 0, index: -1 };
  };

  const escapeRegExp = (text) =>
    text.replace(/[.*+?^${}()|[\\]\\\\]/g, '\\\\$&');

  const isSearchableTextNode = (node) => {
    const parent = node.parentElement;
    if (!parent) return false;
    const tag = parent.tagName;
    if (['SCRIPT', 'STYLE', 'NOSCRIPT', 'TEXTAREA', 'INPUT'].includes(tag)) {
      return false;
    }
    return !parent.closest('mark[data-mira-find="1"]');
  };

  const collectTextNodes = () => {
    if (!document.body) return [];
    const nodes = [];
    const walker = document.createTreeWalker(
      document.body,
      NodeFilter.SHOW_TEXT,
      {
        acceptNode(node) {
          if (!node.textContent || !node.textContent.trim()) {
            return NodeFilter.FILTER_REJECT;
          }
          return isSearchableTextNode(node)
            ? NodeFilter.FILTER_ACCEPT
            : NodeFilter.FILTER_REJECT;
        }
      }
    );
    let current;
    while ((current = walker.nextNode())) {
      nodes.push(current);
    }
    return nodes;
  };

  const activate = (index) => {
    if (!state.marks.length) {
      state.index = -1;
      return { count: 0, index: -1 };
    }
    const nextIndex = ((index % state.marks.length) + state.marks.length) % state.marks.length;
    state.marks.forEach((mark) => mark.removeAttribute('data-mira-find-active'));
    const mark = state.marks[nextIndex];
    mark.setAttribute('data-mira-find-active', '1');
    mark.scrollIntoView({ block: 'center', inline: 'nearest' });
    state.index = nextIndex;
    return { count: state.marks.length, index: state.index };
  };

  const search = (query) => {
    clear();
    if (!query) return { count: 0, index: -1 };
    ensureStyles();
    const regex = new RegExp(escapeRegExp(query), 'gi');
    const nodes = collectTextNodes();
    for (const node of nodes) {
      const text = node.textContent || '';
      regex.lastIndex = 0;
      if (!regex.test(text)) continue;
      regex.lastIndex = 0;
      const fragment = document.createDocumentFragment();
      let lastIndex = 0;
      let match;
      while ((match = regex.exec(text)) !== null) {
        const start = match.index;
        const end = start + match[0].length;
        if (start > lastIndex) {
          fragment.appendChild(document.createTextNode(text.slice(lastIndex, start)));
        }
        const mark = document.createElement('mark');
        mark.setAttribute('data-mira-find', '1');
        mark.textContent = text.slice(start, end);
        fragment.appendChild(mark);
        state.marks.push(mark);
        lastIndex = end;
      }
      if (lastIndex < text.length) {
        fragment.appendChild(document.createTextNode(text.slice(lastIndex)));
      }
      if (node.parentNode) {
        node.parentNode.replaceChild(fragment, node);
      }
    }
    if (!state.marks.length) {
      state.index = -1;
      return { count: 0, index: -1 };
    }
    return activate(0);
  };

  const next = (forward) => {
    if (!state.marks.length) {
      return { count: 0, index: -1 };
    }
    return activate(state.index + (forward ? 1 : -1));
  };

  window.__miraFindState = state;
  window.__miraFind = {
    clear,
    search,
    next
  };
  return true;
})();
''';

  late final TextEditingController _query;
  final FocusNode _focus = FocusNode();

  @override
  void initState() {
    super.initState();
    _query = TextEditingController();
  }

  @override
  void dispose() {
    _query.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<InAppWebViewController?> _activeWebController() async {
    return ref.read(browserChromeProvider).controller;
  }

  Future<void> _runDesktopFindCommand(String expression) async {
    final controller = await _activeWebController();
    if (controller == null) return;
    await controller.evaluateJavascript(source: _desktopFindScript);
    await controller.evaluateJavascript(source: expression);
  }

  Future<void> _clearDesktopMatches() async {
    await _runDesktopFindCommand('window.__miraFind.clear();');
  }

  Future<void> _searchDesktop(String query) async {
    final encoded = jsonEncode(query);
    await _runDesktopFindCommand('window.__miraFind.search($encoded);');
  }

  Future<void> _stepDesktop({required bool forward}) async {
    await _runDesktopFindCommand(
      'window.__miraFind.next(${forward ? 'true' : 'false'});',
    );
  }

  void _close() {
    ref.read(desktopFindBarVisibleProvider.notifier).state = false;
    _query.clear();
    final find = ref.read(activeFindInteractionProvider);
    if (find != null) {
      unawaited(find.clearMatches());
    }
    unawaited(_clearDesktopMatches());
  }

  @override
  Widget build(BuildContext context) {
    final theme = ref.watch(themeProvider);
    final find = ref.watch(activeFindInteractionProvider);
    final web = ref.watch(browserChromeProvider).controller;
    final canSearch = find != null || web != null;
    final isLight = theme.mode == ThemeMode.light;
    final bg = theme.surfaceColor;
    final fg = isLight ? kMiraInkPrimary : Colors.white;
    final muted = isLight ? kMiraInkMuted : Colors.white54;
    final accent = theme.primaryColor;

    return CallbackShortcuts(
      bindings: {
        const SingleActivator(LogicalKeyboardKey.escape): _close,
      },
      child: Material(
        elevation: 6,
        color: bg,
        child: Container(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(color: accent.withValues(alpha: 0.35)),
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          child: Row(
            children: [
              Icon(Icons.search, size: 20, color: muted),
              const SizedBox(width: 8),
              Expanded(
                child: TextField(
                  controller: _query,
                  focusNode: _focus,
                  autofocus: true,
                  style: TextStyle(color: fg, fontSize: 14),
                  cursorColor: accent,
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: canSearch ? 'Find in page...' : 'No page to search',
                    hintStyle: TextStyle(color: muted, fontSize: 14),
                    border: InputBorder.none,
                  ),
                  enabled: canSearch,
                  onChanged: (t) async {
                    if (!canSearch) return;
                    if (t.isEmpty) {
                      if (find != null) {
                        await find.clearMatches();
                      }
                      await _clearDesktopMatches();
                      return;
                    }
                    if (find != null) {
                      await find.findAll(find: t);
                    } else {
                      await _searchDesktop(t);
                    }
                  },
                ),
              ),
              IconButton(
                tooltip: 'Previous',
                onPressed: !canSearch
                    ? null
                    : () async {
                        if (find != null) {
                          await find.findNext(forward: false);
                        } else {
                          await _stepDesktop(forward: false);
                        }
                      },
                icon: Icon(Icons.keyboard_arrow_up, color: fg, size: 22),
              ),
              IconButton(
                tooltip: 'Next',
                onPressed: !canSearch
                    ? null
                    : () async {
                        if (find != null) {
                          await find.findNext(forward: true);
                        } else {
                          await _stepDesktop(forward: true);
                        }
                      },
                icon: Icon(Icons.keyboard_arrow_down, color: fg, size: 22),
              ),
              IconButton(
                tooltip: 'Close',
                onPressed: _close,
                icon: Icon(Icons.close, color: muted, size: 22),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
