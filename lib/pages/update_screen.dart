import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:mira/core/entities/theme_entity.dart';
import 'package:mira/core/services/update_service.dart';
import 'package:url_launcher/url_launcher.dart';

class UpdateScreen extends StatelessWidget {
  final UpdateCheckResult result;
  final Widget? nextScreen;

  const UpdateScreen({
    super.key,
    required this.result,
    this.nextScreen,
  });

  @override
  Widget build(BuildContext context) {
    final bool isForce = result.status == UpdateStatus.forceUpdate;
    final String title = isForce ? 'REQUIRED UPDATE' : 'UPDATE AVAILABLE';
    final String subtitle = isForce
        ? 'Mira version ${result.latestVersion} is required to continue using the browser safely.'
        : 'A new version of Mira (${result.latestVersion}) is available. Update now for the latest security features.';

    return Scaffold(
      backgroundColor: kMiraMatteBlack,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 40),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Icon(
                Icons.security_update_warning_outlined,
                color: Colors.greenAccent,
                size: 48,
              ),
              const SizedBox(height: 32),
              Text(
                title,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 4,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: GoogleFonts.jetBrainsMono(
                  color: Colors.white70,
                  fontSize: 14,
                  height: 1.6,
                ),
              ),
              const Spacer(),
              if (!isForce)
                SizedBox(
                  width: double.infinity,
                  child: TextButton(
                    onPressed: () {
                      if (nextScreen != null) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => nextScreen!,
                          ),
                        );
                      } else {
                        Navigator.pop(context);
                      }
                    },
                    child: Text(
                      'SKIP FOR NOW',
                      style: GoogleFonts.jetBrainsMono(
                        color: Colors.white38,
                        letterSpacing: 2,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: result.storeUrl.isNotEmpty
                      ? () async {
                          final uri = Uri.tryParse(result.storeUrl);
                          if (uri != null && await canLaunchUrl(uri)) {
                            await launchUrl(
                              uri,
                              mode: LaunchMode.externalApplication,
                            );
                          }
                        }
                      : null,
                  style: OutlinedButton.styleFrom(
                    side: const BorderSide(color: Colors.greenAccent),
                    padding: const EdgeInsets.symmetric(vertical: 16),
                  ),
                  child: Text(
                    'UPDATE MIRA',
                    style: GoogleFonts.jetBrainsMono(
                      color: Colors.greenAccent,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 2,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
