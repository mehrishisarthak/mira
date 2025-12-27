import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/tab_model.dart';

class TabsSheet extends ConsumerWidget {
  const TabsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. WATCH ALL DATA
    final isGhostModeActive = ref.watch(isGhostModeProvider);
    
    // Normal Tabs
    final normalTabsState = ref.watch(tabsProvider);
    final normalTabs = normalTabsState.tabs;
    final activeNormalTab = normalTabsState.activeTab;

    // Ghost Tabs
    final ghostTabsState = ref.watch(ghostTabsProvider);
    final ghostTabs = ghostTabsState.tabs;
    final activeGhostTab = ghostTabsState.activeTab;

    // --- THEME ---
    final overallBgColor = isGhostModeActive ? const Color(0xFF100000) : const Color(0xFF1E1E1E);

    return Container(
      decoration: BoxDecoration(
        color: overallBgColor,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: isGhostModeActive ? Colors.redAccent : Colors.transparent)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(height: 5, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
          
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // --- NORMAL TABS SECTION ---
                  _buildSectionHeader(
                    context,
                    ref,
                    title: "Open Tabs",
                    isGhost: false,
                    onAdd: () => ref.read(tabsProvider.notifier).addTab(),
                  ),
                  _buildTabGrid(
                    context,
                    ref,
                    tabs: normalTabs,
                    activeTabId: isGhostModeActive ? '' : activeNormalTab.id, // Only active if not in ghost mode
                    isGhost: false,
                  ),

                  const Divider(color: Colors.white24, height: 30),

                  // --- GHOST TABS SECTION ---
                  _buildSectionHeader(
                    context,
                    ref,
                    title: "Ghost Tabs (RAM Only)",
                    isGhost: true,
                    onAdd: () => ref.read(ghostTabsProvider.notifier).addTab(),
                  ),
                  _buildTabGrid(
                    context,
                    ref,
                    tabs: ghostTabs,
                    activeTabId: isGhostModeActive ? activeGhostTab.id : '', // Only active if in ghost mode
                    isGhost: true,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, WidgetRef ref, {required String title, required bool isGhost, required VoidCallback onAdd}) {
    final color = isGhost ? Colors.redAccent : Colors.white;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(title, style: TextStyle(color: color, fontWeight: FontWeight.bold, fontSize: 18)),
          IconButton(
            icon: Icon(Icons.add, color: color),
            onPressed: () {
              onAdd();
              // If we add a tab, we should switch to that mode
              ref.read(isGhostModeProvider.notifier).state = isGhost;
              Navigator.pop(context);
            },
          ),
        ],
      ),
    );
  }

  Widget _buildTabGrid(BuildContext context, WidgetRef ref, {required List<BrowserTab> tabs, required String activeTabId, required bool isGhost}) {
    if (tabs.isEmpty) {
      return const Center(child: Text("No tabs in this mode.", style: TextStyle(color: Colors.white54)));
    }

    final activeBorder = isGhost ? Colors.redAccent : Colors.greenAccent;
    final cardColor = isGhost ? const Color(0xFF330000) : Colors.white10;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 0.8,
      ),
      itemCount: tabs.length,
      itemBuilder: (context, index) {
        final tab = tabs[index];
        final isActive = tab.id == activeTabId;

        return GestureDetector(
          onTap: () {
            // 1. Set the mode
            ref.read(isGhostModeProvider.notifier).state = isGhost;
            
            // 2. Switch to the correct tab index
            if (isGhost) {
              ref.read(ghostTabsProvider.notifier).switchTab(index);
            } else {
              ref.read(tabsProvider.notifier).switchTab(index);
            }
            
            // 3. Close the sheet
            Navigator.pop(context);
          },
          child: Container(
            decoration: BoxDecoration(
              color: isActive ? activeBorder.withOpacity(0.1) : cardColor,
              border: isActive ? Border.all(color: activeBorder, width: 2) : null,
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  tab.title.isEmpty ? (isGhost ? "Ghost Tab" : "New Tab") : tab.title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: isActive ? activeBorder : Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  tab.url.isEmpty ? "Start Page" : tab.url,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: Colors.white54, fontSize: 12),
                ),
                const Spacer(),
                Align(
                  alignment: Alignment.bottomRight,
                  child: IconButton(
                    icon: const Icon(Icons.close, color: Colors.white30, size: 20),
                    onPressed: () {
                      if (isGhost) {
                        ref.read(ghostTabsProvider.notifier).closeTab(tab.id);
                      } else {
                        ref.read(tabsProvider.notifier).closeTab(tab.id);
                      }
                    },
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
