import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AdBlockService {
  // Simple regex rules to kill common ad networks
  static final List<ContentBlocker> adBlockRules = [
    // 1. The Big G
    _createBlocker(r".*googlesyndication\.com.*"),
    _createBlocker(r".*doubleclick\.net.*"),
    _createBlocker(r".*googleadservices\.com.*"),
    _createBlocker(r".*google-analytics\.com.*"),
    _createBlocker(r".*googletagservices\.com.*"),

    // 2. Facebook/Meta
    _createBlocker(r".*facebook\.net.*"),
    _createBlocker(r".*connect\.facebook\.net.*"),
    _createBlocker(r".*fbsbx\.com.*"),

    // 3. Major Ad Networks
    _createBlocker(r".*adnxs\.com.*"),
    _createBlocker(r".*criteo\.com.*"),
    _createBlocker(r".*taboola\.com.*"),
    _createBlocker(r".*outbrain\.com.*"),
    _createBlocker(r".*pubmatic\.com.*"),
    _createBlocker(r".*openx\.net.*"),
    _createBlocker(r".*amazon-adsystem\.com.*"),
    _createBlocker(r".*moatads\.com.*"),
    _createBlocker(r".*adzerk\.net.*"),
    _createBlocker(r".*adsrvr\.org.*"),
    _createBlocker(r".*bidswitch\.net.*"),
    _createBlocker(r".*rubiconproject\.com.*"),
    _createBlocker(r".*smartadserver\.com.*"),
    _createBlocker(r".*yieldmo\.com.*"),

    // 4. Mobile Ad Networks & Trackers
    _createBlocker(r".*appsflyer\.com.*"),
    _createBlocker(r".*adjust\.com.*"),
    _createBlocker(r".*branch\.io.*"),
    _createBlocker(r".*inmobi\.com.*"),
    _createBlocker(r".*adcolony\.com.*"),
    _createBlocker(r".*vungle\.com.*"),
    _createBlocker(r".*applovin\.com.*"),
    _createBlocker(r".*chartboost\.com.*"),
    _createBlocker(r".*unityads\.unity3d\.com.*"),
    
    // 5. General Annoyances & Trackers
    _createBlocker(r".*scorecardresearch\.com.*"),
    _createBlocker(r".*quantserve\.com.*"),
    _createBlocker(r".*comscore\.com.*"),
    _createBlocker(r".*liadm\.com.*"),
    _createBlocker(r".*adroll\.com.*"),
    _createBlocker(r".*hotjar\.com.*"),
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