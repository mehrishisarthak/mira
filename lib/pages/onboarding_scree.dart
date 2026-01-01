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
    
    // FIXED: Key must match the one in PreferencesService ('is_first_run')
    // Using the wrong key here would cause the onboarding to loop or fail.
    await prefs.setBool('is_first_run', false); 

    if (mounted) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (context) => const Mainscreen()), 
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    // Theme Awareness
    final appTheme = ref.watch(themeProvider);
    final isDark = appTheme.mode == ThemeMode.dark;
    
    // Colors based on theme
    final backgroundColor = appTheme.backgroundColor;
    final textColor = isDark ? Colors.white : Colors.black87;
    final subTextColor = isDark ? Colors.white70 : Colors.black54;
    final primaryColor = appTheme.primaryColor;

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
                lottieAsset: 'assets/1.json',
                title: 'Welcome to MIRA',
                subtitle: 'Experience the web in its purest form.\nFast, minimalist, and strictly yours.',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              _buildPage(
                lottieAsset: 'assets/2.json',
                title: 'Ghost Protocol',
                subtitle: 'Leave no trace behind.\nAdvanced tracker blocking and instant history wiping.',
                textColor: textColor,
                subTextColor: subTextColor,
              ),
              _buildPage(
                lottieAsset: 'assets/3.json',
                title: 'Your Rules',
                subtitle: 'Desktop class browsing, custom themes,\nand powerful developer tools.',
                textColor: textColor,
                subTextColor: subTextColor,
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
                    color: primaryColor,
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
                
                // Back Button (Hidden on first page)
                TextButton(
                  onPressed: () => _controller.previousPage(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOut,
                  ),
                  child: Text(
                    'BACK',
                    style: TextStyle(
                      color: isLastPage || (_controller.hasClients && _controller.page == 0)
                          ? Colors.transparent 
                          : subTextColor,
                    ),
                  ),
                ),

                // Smooth Page Indicator
                SmoothPageIndicator(
                  controller: _controller,
                  count: 3,
                  effect: WormEffect(
                    spacing: 16,
                    dotColor: subTextColor.withOpacity(0.2),
                    activeDotColor: primaryColor,
                    dotHeight: 10,
                    dotWidth: 10,
                  ),
                ),

                // Next / Enter Button
                isLastPage
                    ? ElevatedButton(
                        onPressed: _completeOnboarding,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: primaryColor,
                          foregroundColor: Colors.white,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                        child: const Text("ENTER MIRA"),
                      )
                    : TextButton(
                        onPressed: () => _controller.nextPage(
                          duration: const Duration(milliseconds: 500),
                          curve: Curves.easeOut,
                        ),
                        child: Text(
                          'NEXT',
                          style: TextStyle(
                            color: textColor, 
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
  Widget _buildPage({
    required String lottieAsset,
    required String title,
    required String subtitle,
    required Color textColor,
    required Color subTextColor,
  }) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Dynamic Height for Animation (Responsive)
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
                    color: textColor,
                    fontSize: 28,
                    fontWeight: FontWeight.w900, // Very Bold for modern look
                    letterSpacing: 1.5,
                  ),
                  textAlign: TextAlign.center,
                ),
                
                const SizedBox(height: 16),
                
                Text(
                  subtitle,
                  style: TextStyle(
                    color: subTextColor,
                    fontSize: 16,
                    height: 1.5, // Better readability
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