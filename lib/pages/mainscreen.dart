import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/search_model.dart'; // Ensure this path is correct for your Search Model
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/settings_screen.dart';

// Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);

class Mainscreen extends ConsumerWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Mainscreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final searchState = ref.watch(searchProvider);
    final currentUrl = searchState.url; 
    
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
            if (currentUrl.isNotEmpty) {
               ref.read(searchProvider.notifier).updateUrl('');
            } else {
               if (context.mounted) Navigator.pop(context);
            }
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        endDrawer: _buildDrawer(context),
        
        appBar: AppBar(
          title: TextField(
            decoration: InputDecoration(
              hintText: 'Search or enter address',
              border: InputBorder.none,
              prefixIcon: const Icon(Icons.search),
              filled: true,
              fillColor: Colors.white10,
              contentPadding: const EdgeInsets.symmetric(vertical: 0, horizontal: 16),
              isDense: true,
              enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
              focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(30), borderSide: BorderSide.none),
            ),
            style: const TextStyle(color: Colors.white),
            textInputAction: TextInputAction.go,
            
            controller: TextEditingController(text: currentUrl), 
            
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 String finalUrl;
                 if (value.contains('.') && !value.contains(' ')) {
                    finalUrl = "https://$value";
                 } else {
                    finalUrl = ref.read(formattedSearchUrlProvider(value));
                 }
                 
                 // 1. SAVE TO HISTORY HERE
                 ref.read(historyProvider.notifier).addToHistory(value);

                 ref.read(searchProvider.notifier).updateUrl(finalUrl);
                 ref.read(webViewControllerProvider)?.loadUrl(
                   urlRequest: URLRequest(url: WebUri(finalUrl))
                 );
              }
            },
          ),
          actions: [
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

        body: currentUrl.isEmpty 
            ? const BrandingScreen()
            : InAppWebView(
                initialUrlRequest: URLRequest(url: WebUri(currentUrl)),
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
                     ref.read(searchProvider.notifier).updateUrl(url.toString());
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
          
          // --- History Button ---
          ListTile(
            leading: const Icon(Icons.history, color: Colors.white70),
            title: const Text('History', style: TextStyle(color: Colors.white)),
            onTap: () {
              Navigator.pop(context); // Close Drawer
              // Navigate to History Page
              Navigator.push(
                context,
                MaterialPageRoute(builder: (context) => const HistoryPage()),
              );
            },
          ),

          // --- Settings Button ---
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