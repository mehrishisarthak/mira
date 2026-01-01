import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:lottie/lottie.dart';
import 'package:mira/pages/mainscreen.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mira/model/theme_model.dart';
import 'package:smooth_page_indicator/smooth_page_indicator.dart'; 

class OnboardingScreen extends ConsumerStatefulWidget {
  const OnboardingScreen({super.key});

  @override
  ConsumerState<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends ConsumerState<OnboardingScreen> {
  final PageController _controller = PageController();
  bool isLastPage = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _completeOnboarding() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool('is_first_run', false); 

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Mainscreen()), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // 1. Theme Awareness
    final appTheme = ref.watch(themeProvider);

    // Check system brightness for "Auto" mode support
    final systemBrightness = MediaQuery.of(context).platformBrightness;
    final isDark = appTheme.mode == ThemeMode.dark || 
                   (appTheme.mode == ThemeMode.system && systemBrightness == Brightness.dark);
    
    // --- COLORS CONFIGURATION ---
    // Theme only affects the Background
    final backgroundColor = appTheme.surfaceColor; 
    
    // TEXT & UI COLORS (Shades of Green)
    // We change the *shade* of green based on the background to ensure readability.
    
    // Main Text (Titles, Buttons): Neon Green for Dark Mode, Dark Forest Green for Light Mode
    final mainGreen = isDark ? Colors.lightGreenAccent : const Color(0xFF1B5E20); 
    
    // Sub Text: Slightly transparent version of the main green
    final subGreen = isDark ? Colors.lightGreenAccent.withAlpha(179) : const Color(0xFF2E7D32); 

    return Scaffold(
      backgroundColor: backgroundColor,
      body: Stack(
        children: [
          // 1. THE CAROUSEL
          PageView(
            controller: _controller,
            onPageChanged: (index) {
              setState(() => isLastPage = index == 2);
            },
            children: [
              _buildPage(
                context,
                lottieAsset: 'assets/1.json',
                title: 'Welcome to MIRA',
                subtitle: 'Experience the web in its purest form.\nFast, minimalist, and strictly yours.',
                titleColor: mainGreen, 
                subtitleColor: subGreen,
              ),
              _buildPage(
                context,
                lottieAsset: 'assets/2.json',
                title: 'Ghost Protocol',
                subtitle: 'Leave no trace behind.\nAdvanced tracker blocking and instant history wiping.',
                titleColor: mainGreen,
                subtitleColor: subGreen,
              ),
              _buildPage(
                context,
                lottieAsset: 'assets/3.json',
                title: 'Your Rules',
                subtitle: 'Desktop class browsing, custom themes,\nand powerful developer tools.',
                titleColor: mainGreen,
                subtitleColor: subGreen,
              ),
            ],
          ),

          // 2. SKIP BUTTON (Top Right)
          if (!isLastPage)
            Positioned(
              top: 50,
              right: 20,
              child: TextButton(
                onPressed: () => _controller.jumpToPage(2),
                child: Text(
                  'SKIP',
                  style: TextStyle(
                    color: mainGreen, 
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2
                  ),
                ),
              ),
            ),

          // 3. BOTTOM CONTROLS
          Container(
            alignment: const Alignment(0, 0.85),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                
                // Back Button (Left)
                TextButton(
                  onPressed: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
                  child: Text(
                    'BACK',
                    style: TextStyle(
                      // Using mainGreen ensures it is visible against the background
                      // Hide logic: If on first page or last page, make it transparent
                      color: isLastPage || (_controller.hasClients && _controller.page == 0)
                          ? Colors.transparent 
                          : mainGreen,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),

                // Smooth Page Indicator (Center)
                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: WormEffect(
                    spacing: 16,
                    // Inactive dots are faded green
                    dotColor: mainGreen.withAlpha(51), 
                    // Active dot is solid green
                    activeDotColor: mainGreen, 
                    dotHeight: 10,
                    dotWidth: 10,
                  ),
                ),

                // Next / Enter Button (Right)
                isLastPage
                    ? ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: mainGreen, // Solid Green Background
                          foregroundColor: isDark ? Colors.black : Colors.white, // Text contrast
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text("ENTER MIRA", style: TextStyle(fontWeight: FontWeight.bold)),
                      )
                    : TextButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        ),
                        child: Text(
                          'NEXT',
                          style: TextStyle(
                            color: mainGreen, 
                            fontWeight: FontWeight.bold
                          ),
                        ),
                      ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // Helper Widget for Pages
  Widget _buildPage(
    BuildContext context, {
    required String lottieAsset,
    required String title,
    required String subtitle,
    required Color titleColor,
    required Color subtitleColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic Height for Animation
          Expanded(
            flex: 5,
            child: Lottie.asset(
              lottieAsset,
              fit: BoxFit.contain,
              width: MediaQuery.of(context).size.width * 0.8,
            ),
          ),
          
          const SizedBox(height: 20),

          Expanded(
            flex: 3,
            child: Column(
              children: [
                Text(
                  title,
                  style: TextStyle(
                    color: titleColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subtitleColor, // Now Green shade
                    fontSize: 16,
                    height: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}