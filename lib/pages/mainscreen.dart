import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/search_model.dart'; // Keep for search settings
import 'package:mira/model/tab_model.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/tab_screen.dart';
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/settings_screen.dart';

// Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);

class Mainscreen extends ConsumerWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Mainscreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeUrl = ref.watch(activeUrlProvider); 
    final tabsState = ref.watch(tabsProvider);
    final tabCount = tabsState.tabs.length;
    
    final double progress = ref.watch(loadingProgressProvider) / 100;

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final controller = ref.read(webViewControllerProvider);
        if (controller != null) {
          if (await controller.canGoBack()) {
            controller.goBack();
          } else {
            // If root of tab, clear URL
            if (activeUrl.isNotEmpty) {
               ref.read(tabsProvider.notifier).updateUrl('');
            } else {
               // Minimize app (don't pop, or use SystemNavigator.pop())
               // if (context.mounted) Navigator.pop(context); 
            }
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _buildDrawer(context),
        
        appBar: AppBar(
          titleSpacing: 0,
          leading: const Icon(Icons.search, color: Colors.white54),
          title: TextField(
            decoration: InputDecoration(
              hintText: 'Search or enter address',
              border: InputBorder.none,
              hintStyle: const TextStyle(color: Colors.white30),
            ),
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.go,
            
            // Sync with Active Tab URL
            controller: TextEditingController(text: activeUrl)..selection = TextSelection.collapsed(offset: activeUrl.length),
            
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 String finalUrl;
                 if (value.contains('.') && !value.contains(' ')) {
                    finalUrl = "https://$value";
                 } else {
                    finalUrl = ref.read(formattedSearchUrlProvider(value));
                 }
                 
                 // Save to History
                 ref.read(historyProvider.notifier).addToHistory(value);

                 // UPDATE TAB PROVIDER
                 ref.read(tabsProvider.notifier).updateUrl(finalUrl);
                 
                 // Load in WebView
                 ref.read(webViewControllerProvider)?.loadUrl(
                   urlRequest: URLRequest(url: WebUri(finalUrl))
                 );
              }
            },
          ),
          actions: [
            // --- TAB SWITCHER BUTTON ---
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FractionallySizedBox(
                    heightFactor: 0.8, // Take up 80% of screen
                    child: TabsSheet(),
                  ),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: Colors.white24, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  "$tabCount", 
                  style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                ),
              ),
            ),

            // Menu Button
            IconButton(
              icon: const Icon(Icons.more_vert),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: progress < 1.0 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: progress, 
                  backgroundColor: Colors.transparent, 
                  color: Colors.greenAccent
                ),
              ) 
            : null,
        ),

        // 2. BODY DEPENDS ON ACTIVE TAB URL
        body: activeUrl.isEmpty 
            ? const BrandingScreen()
            : InAppWebView(
                // Key ensures WebView rebuilds when switching tabs (Pseudo-tabs strategy)
                key: ValueKey(tabsState.activeTab.id), 
                
                initialUrlRequest: URLRequest(url: WebUri(activeUrl)),
                initialSettings: InAppWebViewSettings(
                  incognito: true,   
                  clearCache: true,
                  useHybridComposition: true,
                ),
                onWebViewCreated: (controller) {
                  ref.read(webViewControllerProvider.notifier).state = controller;
                },
                onProgressChanged: (controller, progress) {
                  ref.read(loadingProgressProvider.notifier).state = progress;
                },
                onLoadStop: (controller, url) {
                   if (url != null) {
                     // Sync Tab Title and URL
                     ref.read(tabsProvider.notifier).updateUrl(url.toString());
                   }
                },
                onTitleChanged: (controller, title) {
                   if (title != null) {
                     ref.read(tabsProvider.notifier).updateTitle(title);
                   }
                },
                onPermissionRequest: (controller, request) async {
                  return PermissionResponse(
                    resources: request.resources,
                    action: PermissionResponseAction.DENY
                  );
                },
              ),
      ),
    );
  }

  Widget _buildDrawer(BuildContext context) {
    return Drawer(
      backgroundColor: const Color(0xFF1E1E1E),
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          const DrawerHeader(
            decoration: BoxDecoration(color: Color(0xFF121212)),
            child: Center(
              child: Text(
                'M I R A',
                style: TextStyle(color: Colors.white, fontSize: 24, letterSpacing: 5, fontWeight: FontWeight.bold),
              ),
            ),
          ),
          
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white70),
            title: const Text('History', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); 
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),

          ListTile(
            leading: const Icon(Icons.settings_outlined, color: Colors.white70),
            title: const Text('Settings', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context);
              showModalBottomSheet(
                context: context,
                backgroundColor: Colors.transparent,
                builder: (context) => const SettingsSheet(),
              );
            },
          ),
        ],
      ),
    );
  }
}