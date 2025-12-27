import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mira/model/ghost_model.dart'; // Import Ghost Model
import 'package:mira/model/tab_model.dart';   // Import Normal Model

class TabsSheet extends ConsumerWidget {
  const TabsSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. CHECK THE MODE
    final isGhost = ref.watch(isGhostModeProvider);

    // 2. GET THE CORRECT DATA (Using the Smart Providers we made)
    final tabs = ref.watch(currentTabListProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    
    // Theme colors
    final cardColor = isGhost ? const Color(0xFF330000) : Colors.white10;
    final activeBorder = isGhost ? Colors.redAccent : Colors.greenAccent;
    final textColor = isGhost ? Colors.redAccent : Colors.white;

    return Container(
      decoration: BoxDecoration(
        color: isGhost ? const Color(0xFF100000) : const Color(0xFF1E1E1E),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        border: Border(top: BorderSide(color: isGhost ? Colors.redAccent : Colors.transparent)),
      ),
      child: Column(
        children: [
          const SizedBox(height: 10),
          Container(height: 5, width: 40, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(10))),
          
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                   isGhost ? "Ghost Tabs (RAM Only)" : "Open Tabs", 
                   style: TextStyle(color: textColor, fontWeight: FontWeight.bold, fontSize: 18)
                ),
                IconButton(
                  icon: Icon(Icons.add, color: activeBorder),
                  onPressed: () {
                    // BRANCH LOGIC: Add to the correct list
                    if (isGhost) {
                      ref.read(ghostTabsProvider.notifier).addTab();
                    } else {
                      ref.read(tabsProvider.notifier).addTab();
                    }
                    Navigator.pop(context);
                  },
                ),
              ],
            ),
          ),

          Expanded(
            child: GridView.builder(
              padding: const EdgeInsets.all(16),
              gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 2,
                crossAxisSpacing: 10,
                mainAxisSpacing: 10,
                childAspectRatio: 0.8,
              ),
              itemCount: tabs.length,
              itemBuilder: (context, index) {
                final tab = tabs[index];
                final isActive = tab.id == activeTab.id; // Check ID match

                return GestureDetector(
                  onTap: () {
                    // BRANCH LOGIC: Switch on the correct list
                    if (isGhost) {
                       ref.read(ghostTabsProvider.notifier).switchTab(index);
                    } else {
                       ref.read(tabsProvider.notifier).switchTab(index);
                    }
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
                          tab.title.isEmpty ? "New Tab" : tab.title,
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
                              // BRANCH LOGIC: Close from correct list
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
            ),
          ),
        ],
      ),
    );
  }
}