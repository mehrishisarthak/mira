import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AdBlockService {
  // Simple regex rules to kill common ad networks
  static final List<ContentBlocker> adBlockRules = [
    // 1. The Big G
    _createBlocker(r".*googlesyndication\.com.*"),
    _createBlocker(r".*doubleclick\.net.*"),
    _createBlocker(r".*googleadservices\.com.*"),
    _createBlocker(r".*google-analytics\.com.*"),
    
    // 2. Facebook/Meta
    _createBlocker(r".*facebook\.net.*"),
    _createBlocker(r".*connect\.facebook\.net.*"),
    
    // 3. Annoying Ad Networks
    _createBlocker(r".*adnxs\.com.*"), 
    _createBlocker(r".*criteo\.com.*"),
    _createBlocker(r".*taboola\.com.*"),
    _createBlocker(r".*outbrain\.com.*"),
    _createBlocker(r".*pubmatic\.com.*"),
    _createBlocker(r".*openx\.net.*"),
    _createBlocker(r".*amazon-adsystem\.com.*"),
    _createBlocker(r".*moatads\.com.*"),
    
    // 4. Mobile Specific Trackers
    _createBlocker(r".*appsflyer\.com.*"),
    _createBlocker(r".*adjust\.com.*"),
    _createBlocker(r".*branch\.io.*"),
  ];

  static ContentBlocker _createBlocker(String urlRegex) {
    return ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: urlRegex,
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK, // The "Talk to the Hand" action
      ),
    );
  }
}