import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_inappwebview/flutter_inappwebview.dart';
import 'package:mira/model/ad_block_model.dart';
import 'package:mira/model/book_mark_model.dart';
import 'package:mira/model/download_model.dart';
import 'package:mira/model/theme_model.dart';
import 'package:mira/pages/browser_sheet.dart';
import 'package:mira/pages/skelleton_loader.dart';
import 'package:url_launcher/url_launcher.dart'; 

// Models & Providers
import 'package:mira/model/ghost_model.dart';
import 'package:mira/model/search_engine.dart';
import 'package:mira/model/security_model.dart'; 
import 'package:mira/model/tab_model.dart';

// UI Pages
import 'package:mira/pages/branding_screen.dart';
import 'package:mira/pages/history_screen.dart';
import 'package:mira/pages/tab_screen.dart'; 
import 'package:mira/pages/downloads_screen.dart'; 
import 'package:mira/pages/book_marks_screen.dart'; 
import 'package:mira/pages/network_error_screen.dart';

// Local Providers
final loadingProgressProvider = StateProvider<int>((ref) => 0);
final webViewControllerProvider = StateProvider<InAppWebViewController?>((ref) => null);
final webErrorProvider = StateProvider<String?>((ref) => null); 

class Mainscreen extends ConsumerWidget {
  final GlobalKey<ScaffoldState> _scaffoldKey = GlobalKey<ScaffoldState>();

  Mainscreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // 1. WATCH STATE
    final isGhost = ref.watch(isGhostModeProvider);
    final activeTab = ref.watch(currentActiveTabProvider);
    final activeUrl = activeTab.url;
    final currentTabsList = ref.watch(currentTabListProvider);
    final tabCount = currentTabsList.length;
    final securityState = ref.watch(securityProvider);
    final double progress = ref.watch(loadingProgressProvider) / 100;
    
    // Watch Error State
    final errorMessage = ref.watch(webErrorProvider);

    // Watch Bookmarks
    final bookmarks = ref.watch(bookmarksProvider);
    final isBookmarked = bookmarks.any((b) => b.url == activeUrl);

    // 2. THEME LOGIC
    final appTheme = ref.watch(themeProvider);
    
    final backgroundColor = isGhost ? Colors.black : appTheme.backgroundColor;
    final appBarColor = isGhost ? const Color(0xFF100000) : appTheme.surfaceColor;
    final primaryAccent = isGhost ? Colors.redAccent : appTheme.primaryColor;
    
    final isLightMode = !isGhost && appTheme.mode == ThemeMode.light;
    final contentColor = isGhost ? Colors.redAccent : (isLightMode ? Colors.black87 : Colors.white);
    final hintColor = isGhost ? Colors.red.withOpacity(0.3) : (isLightMode ? Colors.black38 : Colors.white30);

    // 3. ADDRESS BAR CONTROLLER
    final textController = TextEditingController(text: activeUrl);
    textController.selection = TextSelection.collapsed(offset: activeUrl.length);

    // 4. CALCULATE SECURITY ICON
    IconData securityIcon;
    Color securityColor;

    if (activeUrl.isEmpty) {
      securityIcon = isGhost ? Icons.privacy_tip : Icons.search;
      securityColor = isGhost ? Colors.redAccent : hintColor;
    } else if (activeUrl.startsWith("https://")) {
      securityIcon = Icons.lock;
      securityColor = Colors.greenAccent;
    } else {
      securityIcon = Icons.no_encryption;
      securityColor = Colors.redAccent;
    }

    // 5. LISTENER: THEME CHANGES (FIX FOR STUCK DARK MODE)
    // When the user toggles theme in Drawer, update WebView settings immediately.
    ref.listen(themeProvider, (previous, next) async {
       final controller = ref.read(webViewControllerProvider);
       if (controller != null) {
         // Calculate ForceDark setting based on new theme
         final forceDarkSetting = isGhost 
             ? ForceDark.ON 
             : (next.mode == ThemeMode.light ? ForceDark.OFF : (next.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO));
          
         await controller.setSettings(settings: InAppWebViewSettings(
            forceDark: forceDarkSetting,
            algorithmicDarkeningAllowed: (isGhost || next.mode == ThemeMode.dark),
         ));
       }
    });

    // 6. LISTENER: SECURITY CHANGES
    ref.listen(securityProvider, (previous, next) async {
      if (activeUrl.isEmpty) return; 
      final controller = ref.read(webViewControllerProvider);
      if (controller == null) return;

      if (previous?.isDesktopMode != next.isDesktopMode || 
          previous?.isAdBlockEnabled != next.isAdBlockEnabled) {
        try {
          await controller.setSettings(
            settings: InAppWebViewSettings(
              preferredContentMode: next.isDesktopMode 
                  ? UserPreferredContentMode.DESKTOP 
                  : UserPreferredContentMode.MOBILE,
              userAgent: next.isDesktopMode 
                  ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                  : "",
              contentBlockers: next.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
            ),
          );
          controller.reload();
        } catch (e) {
          debugPrint("Safe fail: Controller detached. $e");
        }
      }
    });

    return PopScope(
      canPop: false,
      onPopInvoked: (didPop) async {
        if (didPop) return;
        final controller = ref.read(webViewControllerProvider);
        
        if (errorMessage != null) {
           if (await controller?.canGoBack() ?? false) {
             ref.read(webErrorProvider.notifier).state = null; 
             controller?.goBack();
             return;
           }
        }

        if (controller != null) {
          try {
            if (await controller.canGoBack()) {
              controller.goBack();
            } else {
              if (activeUrl.isNotEmpty) {
                 if (isGhost) {
                   ref.read(ghostTabsProvider.notifier).updateUrl('');
                 } else {
                   ref.read(tabsProvider.notifier).updateUrl('');
                 }
                 ref.read(webErrorProvider.notifier).state = null;
              }
            }
          } catch (e) {
             if (isGhost) {
               ref.read(ghostTabsProvider.notifier).updateUrl('');
             } else {
               ref.read(tabsProvider.notifier).updateUrl('');
             }
          }
        }
      },
      child: Scaffold(
        key: _scaffoldKey,
        backgroundColor: backgroundColor,
        endDrawer: _buildDrawer(context, ref, securityState, isGhost, appTheme, contentColor),
        
        appBar: AppBar(
          backgroundColor: appBarColor,
          titleSpacing: 0,
          leading: IconButton(
            icon: Icon(securityIcon, color: securityColor),
            onPressed: () {
              if (activeUrl.isNotEmpty) {
                showDialog(
                  context: context, 
                  builder: (ctx) => AlertDialog(
                    backgroundColor: appTheme.surfaceColor,
                    title: Text(
                      activeUrl.startsWith("https://") ? "Connection Secure" : "Connection Not Secure",
                      style: TextStyle(color: securityColor),
                    ),
                    content: Text(
                      activeUrl.startsWith("https://") 
                        ? "MIRA verified this site uses a valid SSL certificate."
                        : "This site uses HTTP. Your data is not encrypted.",
                      style: TextStyle(color: contentColor.withOpacity(0.7)),
                    ),
                    actions: [TextButton(onPressed: ()=>Navigator.pop(ctx), child: const Text("Got it"))],
                  )
                );
              }
            },
          ),

          title: TextField(
            controller: textController,
            style: TextStyle(color: contentColor), 
            cursorColor: primaryAccent,
            decoration: InputDecoration(
              hintText: isGhost ? 'Ghost Mode Active' : 'Search or enter address',
              border: InputBorder.none,
              hintStyle: TextStyle(color: hintColor),
              suffixIcon: activeUrl.isNotEmpty && !isGhost
                  ? IconButton(
                      icon: Icon(
                        isBookmarked ? Icons.star : Icons.star_border,
                        color: isBookmarked ? Colors.yellowAccent : hintColor,
                        size: 20,
                      ),
                      onPressed: () {
                         ref.read(bookmarksProvider.notifier).toggleBookmark(activeUrl, activeTab.title);
                      },
                    )
                  : null,
            ),
            textInputAction: TextInputAction.go,
            onTap: () {
              textController.selection = TextSelection(baseOffset: 0, extentOffset: textController.text.length);
            },
            onSubmitted: (value) {
              if (value.isNotEmpty) {
                 ref.read(webErrorProvider.notifier).state = null;

                 String finalUrl;
                 if (value.contains('.') && !value.contains(' ')) {
                    finalUrl = "https://$value";
                 } else {
                    finalUrl = ref.read(formattedSearchUrlProvider(value));
                 }
                 
                 if (isGhost) {
                    ref.read(ghostTabsProvider.notifier).updateUrl(finalUrl);
                 } else {
                    ref.read(historyProvider.notifier).addToHistory(value);
                    ref.read(tabsProvider.notifier).updateUrl(finalUrl);
                 }

                 ref.read(webViewControllerProvider)?.loadUrl(
                   urlRequest: URLRequest(url: WebUri(finalUrl))
                 );
              }
            },
          ),
          actions: [
            InkWell(
              onTap: () {
                showModalBottomSheet(
                  context: context,
                  isScrollControlled: true,
                  backgroundColor: Colors.transparent,
                  builder: (context) => const FractionallySizedBox(heightFactor: 0.8, child: TabsSheet()),
                );
              },
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 8),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  border: Border.all(color: isGhost ? Colors.redAccent.withOpacity(0.5) : hintColor, width: 1.5),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text("$tabCount", style: TextStyle(color: contentColor, fontWeight: FontWeight.bold)),
              ),
            ),
            IconButton(
              icon: Icon(Icons.more_vert, color: contentColor),
              onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
            ),
          ],
          bottom: progress < 1.0 
            ? PreferredSize(
                preferredSize: const Size.fromHeight(2),
                child: LinearProgressIndicator(
                  value: progress, 
                  backgroundColor: Colors.transparent, 
                  color: primaryAccent
                ),
              ) 
            : null,
        ),
        body: _buildBody(activeUrl, errorMessage, ref, securityState, isGhost, activeTab.id, primaryAccent, appTheme),
      ),
    );
  }

  Widget _buildBody(String activeUrl, String? errorMessage, WidgetRef ref, SecurityState securityState, bool isGhost, String tabId, Color accent, MiraTheme theme) {
    if (activeUrl.isEmpty) {
      return const BrandingScreen();
    }

    if (errorMessage != null) {
      return ErrorScreen(
        error: errorMessage,
        url: activeUrl,
        onRetry: () {
          ref.read(webErrorProvider.notifier).state = null;
          ref.read(webViewControllerProvider)?.reload();    
        },
      );
    }

    // Watch progress for the animation logic
    final progress = ref.watch(loadingProgressProvider);
    final bool isLoading = progress < 100;
    
    // 7. FIX: CALCULATE CORRECT FORCE DARK SETTING
    final forceDarkSetting = isGhost 
        ? ForceDark.ON 
        : (theme.mode == ThemeMode.light ? ForceDark.OFF : (theme.mode == ThemeMode.dark ? ForceDark.ON : ForceDark.AUTO));

    return Stack(
      children: [
        InAppWebView(
          key: ValueKey("${isGhost ? 'G' : 'N'}_$tabId"),
          initialUrlRequest: URLRequest(url: WebUri(activeUrl)),
          initialSettings: InAppWebViewSettings(
            incognito: isGhost || securityState.isIncognito, 
            clearCache: isGhost || securityState.isIncognito,
            useHybridComposition: true,
            
            // --- THEME FIX IS HERE ---
            forceDark: forceDarkSetting,
            algorithmicDarkeningAllowed: (isGhost || theme.mode == ThemeMode.dark),
            // ------------------------

            userAgent: securityState.isDesktopMode 
                ? "Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36" 
                : "",
            preferredContentMode: securityState.isDesktopMode 
                ? UserPreferredContentMode.DESKTOP 
                : UserPreferredContentMode.MOBILE,
            contentBlockers: securityState.isAdBlockEnabled ? AdBlockService.adBlockRules : [],
            transparentBackground: true, 
          ),
          onWebViewCreated: (controller) {
            ref.read(webViewControllerProvider.notifier).state = controller;
          },
          onProgressChanged: (controller, progress) {
            ref.read(loadingProgressProvider.notifier).state = progress;
          },
          onLoadStop: (controller, url) {
              if (url != null) {
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).updateUrl(url.toString());
                } else {
                  ref.read(tabsProvider.notifier).updateUrl(url.toString());
                }
              }
          },
          onReceivedError: (controller, request, error) {
            if (request.isForMainFrame ?? true) {
               ref.read(webErrorProvider.notifier).state = error.description;
            }
          },
          onReceivedHttpError: (controller, request, response) {
            if (request.isForMainFrame ?? true) {
               if (response.statusCode! >= 400) {
                 ref.read(webErrorProvider.notifier).state = "HTTP Error: ${response.statusCode}";
               }
            }
          },
          onTitleChanged: (controller, title) {
              if (title != null) {
                if (isGhost) {
                  ref.read(ghostTabsProvider.notifier).updateTitle(title);
                } else {
                  ref.read(tabsProvider.notifier).updateTitle(title);
                }
              }
          },
          shouldOverrideUrlLoading: (controller, navigationAction) async {
            final uri = navigationAction.request.url;
            if (uri == null) return NavigationActionPolicy.ALLOW;

            if (uri.scheme == 'http' || uri.scheme == 'https') {
              return NavigationActionPolicy.ALLOW;
            }
            if (['mailto', 'tel', 'sms'].contains(uri.scheme)) {
              if (await canLaunchUrl(uri)) {
                await launchUrl(uri);
                return NavigationActionPolicy.CANCEL;
              }
            }
            try {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              return NavigationActionPolicy.CANCEL;
            } catch (e) {
              return NavigationActionPolicy.CANCEL; 
            }
          },
          onDownloadStartRequest: (controller, downloadRequest) async {
              await DownloadManager.download(
                  downloadRequest.url.toString(),
                  filename: downloadRequest.suggestedFilename
              );
          },
          onPermissionRequest: (controller, request) async {
            final resources = request.resources;
            if (securityState.isLocationBlocked && resources.contains(PermissionResourceType.DEVICE_ORIENTATION_AND_MOTION)) {
                return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
            }
            if (securityState.isCameraBlocked) {
              if (resources.contains(PermissionResourceType.CAMERA) || 
                  resources.contains(PermissionResourceType.MICROPHONE)) {
                return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
              }
            }
            return PermissionResponse(resources: resources, action: PermissionResponseAction.DENY);
          },
          onGeolocationPermissionsShowPrompt: (controller, origin) async {
              if (securityState.isLocationBlocked) {
                return GeolocationPermissionShowPromptResponse(origin: origin, allow: false, retain: false);
              }
              return GeolocationPermissionShowPromptResponse(origin: origin, allow: true, retain: false);
          },
        ),

        // LAYER B: Skeleton Overlay
        IgnorePointer(
          ignoring: !isLoading, 
          child: AnimatedOpacity(
            opacity: isLoading ? 1.0 : 0.0, 
            duration: const Duration(milliseconds: 500), 
            curve: Curves.easeInOut, 
            child: const WebSkeletonLoader(),
          ),
        ),
      ],
    );
  }

  // UPDATED DRAWER with safe area spacing
  Widget _buildDrawer(BuildContext context, WidgetRef ref, SecurityState securityState, bool isGhost, MiraTheme theme, Color textColor) {
    return Drawer(
      backgroundColor: isGhost ? const Color(0xFF1E1E1E) : theme.surfaceColor,
      child: Column(
        children: [
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 200, 
                    width: double.infinity,
                    decoration: BoxDecoration(color: isGhost ? const Color(0xFF100000) : theme.backgroundColor),
                    child: Center(
                      child: Text(
                        'M I R A',
                        style: TextStyle(
                          color: isGhost ? Colors.redAccent : theme.primaryColor, 
                          fontSize: 24, 
                          letterSpacing: 5, 
                          fontWeight: FontWeight.bold
                        ),
                      ),
                    ),
                  ),
                  
                  ListTile(
                    leading: Icon(Icons.history, color: textColor.withOpacity(0.7)),
                    title: Text('History', style: TextStyle(color: textColor)),
                    enabled: !isGhost,
                    onTap: isGhost ? null : () {
                      Navigator.pop(context); 
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const HistoryPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.bookmark_border, color: textColor.withOpacity(0.7)),
                    title: Text('Bookmarks', style: TextStyle(color: textColor)),
                    enabled: !isGhost,
                    onTap: isGhost ? null : () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const BookmarksPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.download, color: textColor.withOpacity(0.7)),
                    title: Text('Downloads', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.pop(context);
                      Navigator.push(context, MaterialPageRoute(builder: (context) => const DownloadsPage()));
                    },
                  ),

                  ListTile(
                    leading: Icon(Icons.settings, color: textColor.withOpacity(0.7)),
                    title: Text('Settings', style: TextStyle(color: textColor)),
                    onTap: () {
                      Navigator.pop(context);
                      showModalBottomSheet(
                        context: context,
                        backgroundColor: Colors.transparent,
                        builder: (context) => const BrowserSheet(),
                      );
                    },
                  ),

                  Divider(color: textColor.withOpacity(0.2)),

                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
                    child: Text("SECURITY PROTOCOLS", style: TextStyle(color: isGhost ? Colors.redAccent : Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  ListTile(
                    title: Text("New Ghost Tab", style: TextStyle(color: textColor)),
                    subtitle: Text("Start a private session", style: TextStyle(color: textColor.withOpacity(0.5), fontSize: 12)),
                    leading: Icon(Icons.privacy_tip_outlined, color: textColor.withOpacity(0.7)),
                    onTap: () {
                       ref.read(isGhostModeProvider.notifier).state = true;
                       ref.read(ghostTabsProvider.notifier).addTab();
                       Navigator.pop(context);
                    },
                  ),

                  ListTile(
                    title: const Text("Nuke Data", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold)),
                    leading: const Icon(Icons.delete_forever, color: Colors.redAccent),
                    onTap: () async {
                      final confirm = await showDialog<bool>(
                        context: context,
                        builder: (ctx) => AlertDialog(
                          backgroundColor: theme.surfaceColor,
                          title: Text("Nuke Everything?", style: TextStyle(color: textColor)),
                          content: Text("This will wipe all history, cookies, cache, and close all tabs. This cannot be undone.", style: TextStyle(color: textColor.withOpacity(0.7))),
                          actions: [
                            TextButton(onPressed: () => Navigator.pop(ctx, false), child: Text("Cancel", style: TextStyle(color: textColor.withOpacity(0.5)))),
                            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text("NUKE IT", style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold))),
                          ],
                        ),
                      );

                      if (confirm == true) {
                        await InAppWebViewController.clearAllCache();
                        final cookieManager = CookieManager.instance();
                        await cookieManager.deleteAllCookies();
                        ref.read(historyProvider.notifier).clearHistory();
                        ref.read(tabsProvider.notifier).nuke();
                        ref.read(ghostTabsProvider.notifier).nuke();
                        ref.read(webErrorProvider.notifier).state = null; 

                        if (context.mounted) {
                           Navigator.pop(context); 
                           ScaffoldMessenger.of(context).showSnackBar(
                             const SnackBar(content: Text("System Purged."), backgroundColor: Colors.redAccent),
                           );
                        }
                      }
                    },
                  ),

                  SwitchListTile(
                    title: Text("Location Lock", style: TextStyle(color: textColor)),
                    secondary: Icon(Icons.location_off, color: securityState.isLocationBlocked ? Colors.greenAccent : textColor.withOpacity(0.5)),
                    value: securityState.isLocationBlocked,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => ref.read(securityProvider.notifier).toggleLocation(val),
                  ),

                  SwitchListTile(
                    title: Text("Sensor Lock", style: TextStyle(color: textColor)),
                    secondary: Icon(Icons.mic_off, color: securityState.isCameraBlocked ? Colors.greenAccent : textColor.withOpacity(0.5)),
                    value: securityState.isCameraBlocked,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) => ref.read(securityProvider.notifier).toggleCamera(val),
                  ),
                  
                  SwitchListTile(
                    title: Text("The Shield", style: TextStyle(color: textColor)),
                    secondary: Icon(Icons.shield, color: securityState.isAdBlockEnabled ? Colors.greenAccent : textColor.withOpacity(0.5)),
                    value: securityState.isAdBlockEnabled,
                    activeColor: Colors.greenAccent,
                    onChanged: (val) {
                       ref.read(securityProvider.notifier).toggleAdBlock(val);
                    },
                  ),

                  Divider(color: textColor.withOpacity(0.2)),

                  Padding(
                    padding: const EdgeInsets.only(left: 16, top: 10, bottom: 5),
                    child: Text("CUSTOMIZATION", style: TextStyle(color: theme.primaryColor, fontSize: 12, fontWeight: FontWeight.bold)),
                  ),

                  SwitchListTile(
                    title: Text("Desktop Mode", style: TextStyle(color: textColor)),
                    secondary: Icon(Icons.desktop_windows, color: securityState.isDesktopMode ? Colors.blueAccent : textColor.withOpacity(0.5)),
                    value: securityState.isDesktopMode,
                    activeColor: Colors.blueAccent,
                    onChanged: (val) {
                       ref.read(securityProvider.notifier).toggleDesktop(val);
                    },
                  ),

                  if (!isGhost) 
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                      child: _buildDrawerThemeSelector(context, ref, theme, textColor),
                    ),
                  
                  if (isGhost)
                    Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Center(child: Text("Customization disabled in Ghost Mode", style: TextStyle(color: Colors.redAccent.withOpacity(0.5), fontSize: 12))),
                    ),

                  const SizedBox(height: 100), 
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDrawerThemeSelector(BuildContext context, WidgetRef ref, MiraTheme themeData, Color textColor) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final double buttonWidth = (constraints.maxWidth - 4) / 3;
        final primary = themeData.primaryColor;

        return FittedBox(
          fit: BoxFit.scaleDown,
          child: ToggleButtons(
            borderRadius: BorderRadius.circular(12.0),
            borderWidth: 1.5,
            borderColor: textColor.withOpacity(0.1),
            selectedBorderColor: primary,
            fillColor: primary.withOpacity(0.2),
            selectedColor: primary, 
            color: textColor.withOpacity(0.6), 
            constraints: BoxConstraints(
              minHeight: 45.0,
              minWidth: buttonWidth, 
            ),
            isSelected: [
              themeData.mode == ThemeMode.light,
              themeData.mode == ThemeMode.dark,
              themeData.mode == ThemeMode.system,
            ],
            onPressed: (index) {
              const List<ThemeMode> modes = [ThemeMode.light, ThemeMode.dark, ThemeMode.system];
              ref.read(themeProvider.notifier).setMode(modes[index]);
            },
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.light_mode_outlined, size: 16), Text("Light", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.dark_mode_outlined, size: 16), Text("Dark", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8.0),
                child: Wrap(spacing: 6, children: const [Icon(Icons.brightness_auto_outlined, size: 16), Text("Auto", style: TextStyle(fontWeight: FontWeight.w600, fontSize: 12))]),
              ),
            ],
          ),
        );
      },
    );
  }
}