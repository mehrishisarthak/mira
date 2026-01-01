import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/tab_model.dart';
import 'package:mira/model/theme_model.dart';

class TabsSheet extends ConsumerWidget {
  const TabsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isGhostModeActive = ref.watch(isGhostModeProvider);
    
    // Watch Tab States
    final normalTabsState = ref.watch(tabsProvider);
    final normalTabs = normalTabsState.tabs;
    final activeNormalTab = normalTabsState.activeTab;

    final ghostTabsState = ref.watch(ghostTabsProvider);
    final ghostTabs = ghostTabsState.tabs;
    final activeGhostTab = ghostTabsState.activeTab;

    // Theme Logic
    final appTheme = ref.watch(themeProvider);
    final backgroundColor = appTheme.surfaceColor;
    final textColor = appTheme.mode == ThemeMode.light ? Colors.black87 : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(
            color: isGhostModeActive ? Colors.redAccent : appTheme.primaryColor, 
            width: 3
          )
        ),
        boxShadow: [
          BoxShadow(color: Colors.black.withAlpha(51), blurRadius: 20, spreadRadius: 5)
        ],
      ),
      child: Column(
        children: [
          const SizedBox(height: 12),
          Container(
            height: 4, 
            width: 40, 
            decoration: BoxDecoration(
              color: textColor.withAlpha(51), 
              borderRadius: BorderRadius.circular(10)
            )
          ),
          
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.only(top: 20, bottom: 40),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  
                  // --- GHOST SECTION ---
                  if (ghostTabs.isNotEmpty) ...[
                    _buildSectionHeader(
                      context, ref,
                      title: "GHOST PROTOCOL",
                      count: ghostTabs.length,
                      isGhost: true,
                      color: Colors.redAccent,
                      onAdd: () => ref.read(ghostTabsProvider.notifier).addTab(),
                      onClear: () => ref.read(ghostTabsProvider.notifier).nuke(),
                    ),
                    _buildTabGrid(
                      context, ref,
                      tabs: ghostTabs,
                      activeTabId: isGhostModeActive ? activeGhostTab.id : '',
                      isGhost: true,
                      accentColor: Colors.redAccent,
                      textColor: textColor,
                    ),
                    const SizedBox(height: 24),
                    Divider(color: textColor.withAlpha(26), thickness: 1),
                    const SizedBox(height: 16),
                  ],

                  // --- NORMAL SECTION ---
                  _buildSectionHeader(
                    context, ref,
                    title: "ACTIVE SESSIONS",
                    count: normalTabs.length,
                    isGhost: false,
                    color: appTheme.primaryColor,
                    onAdd: () => ref.read(tabsProvider.notifier).addTab(),
                    onClear: () => ref.read(tabsProvider.notifier).nuke(),
                  ),
                  _buildTabGrid(
                    context, ref,
                    tabs: normalTabs,
                    activeTabId: !isGhostModeActive ? activeNormalTab.id : '',
                    isGhost: false,
                    accentColor: appTheme.primaryColor,
                    textColor: textColor,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(
    BuildContext context, 
    WidgetRef ref, 
    {
      required String title, 
      required int count,
      required bool isGhost, 
      required Color color, 
      required VoidCallback onAdd,
      required VoidCallback onClear
    }
  ) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(color: color.withAlpha(26), borderRadius: BorderRadius.circular(8)),
            child: Icon(isGhost ? Icons.privacy_tip_outlined : Icons.public, size: 18, color: color),
          ),
          const SizedBox(width: 12),
          Text(
            title, 
            style: TextStyle(
              color: color, 
              fontWeight: FontWeight.bold, 
              fontSize: 12, 
              letterSpacing: 1.5
            )
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(10)
            ),
            child: Text(
              "$count",
              style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
            ),
          ),
          const Spacer(),
          IconButton(
            icon: Icon(Icons.delete_sweep_outlined, color: color.withAlpha(153), size: 20),
            onPressed: onClear,
            tooltip: "Close All",
          ),
          IconButton(
            icon: Icon(Icons.add_circle_outline, color: color, size: 24),
            onPressed: () {
              onAdd();
              ref.read(isGhostModeProvider.notifier).state = isGhost;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabGrid(
    BuildContext context, 
    WidgetRef ref, 
    {
      required List<BrowserTab> tabs, 
      required String activeTabId, 
      required bool isGhost, 
      required Color accentColor,
      required Color textColor
    }
  ) {
    if (tabs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(32.0),
        child: Center(
          child: Text(
            "No Active Tabs", 
            style: TextStyle(color: textColor.withAlpha(77), fontStyle: FontStyle.italic)
          )
        ),
      );
    }

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 1.3, 
      ),
      itemCount: tabs.length,
      itemBuilder: (context, index) {
        final tab = tabs[index];
        final isActive = tab.id == activeTabId;

        // FIXED: Reverted to standard GestureDetector with no delay/animation
        return GestureDetector(
          onTap: () {
            // Direct logic execution without delays
            if (context.mounted) {
               ref.read(isGhostModeProvider.notifier).state = isGhost;
               if (isGhost) {
                 ref.read(ghostTabsProvider.notifier).switchTab(index);
               } else {
                 ref.read(tabsProvider.notifier).switchTab(index);
               }
               Navigator.pop(context);
            }
          },
          child: Container(
            decoration: BoxDecoration(
              color: isGhost 
                  ? const Color(0xFF2C2C2C) 
                  : accentColor.withAlpha(13),
              border: Border.all(
                color: isActive ? accentColor : Colors.transparent, 
                width: 2
              ),
              borderRadius: BorderRadius.circular(16),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    CircleAvatar(
                      radius: 8,
                      backgroundColor: isActive ? accentColor : textColor.withAlpha(26),
                      child: isActive 
                          ? const SizedBox() 
                          : Icon(Icons.web, size: 10, color: textColor.withAlpha(128)),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        tab.title.isEmpty ? (isGhost ? "Ghost Tab" : "New Tab") : tab.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: isGhost ? Colors.white : textColor,
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                        ),
                      ),
                    ),
                  ],
                ),
                
                const Spacer(),
                
                Text(
                  tab.url.isEmpty ? "Start Page" : tab.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isGhost ? Colors.white54 : textColor.withAlpha(128), 
                    fontSize: 11
                  ),
                ),
                
                const SizedBox(height: 8),
                
                Align(
                  alignment: Alignment.centerRight,
                  child: InkWell(
                    onTap: () {
                      if (isGhost) {
                        ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
                      } else {
                        ref.read(tabsProvider.notifier).closeTab(tab.id);
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.black.withAlpha(26),
                        shape: BoxShape.circle
                      ),
                      child: Icon(Icons.close, size: 14, color: textColor.withAlpha(153)),
                    ),
                  ),
                )
              ],
            ),
          ),
        );
      },
    );
  }
}