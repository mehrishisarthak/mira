import 'package:flutter_inappwebview/flutter_inappwebview.dart';

class AdBlockService {
  // Enhanced regex rules to kill ads, trackers, miners, and session recorders.
  static final List<ContentBlocker> adBlockRules = [
    // 1. The Big G (Google Ecosystem)
    _createBlocker(r".*googlesyndication\.com.*"),
    _createBlocker(r".*doubleclick\.net.*"),
    _createBlocker(r".*googleadservices\.com.*"),
    _createBlocker(r".*google-analytics\.com.*"),
    _createBlocker(r".*googletagservices\.com.*"),
    _createBlocker(r".*adservice\.google\.com.*"),
    _createBlocker(r".*google-analytics\.com/ga\.js.*"),
    _createBlocker(r".*google-analytics\.com/analytics\.js.*"),
    _createBlocker(r".*imasdk\.googleapis\.com.*"), // Video Ads (IMA)

    // 2. Social Media Pixels & Trackers
    _createBlocker(r".*facebook\.net.*"),
    _createBlocker(r".*connect\.facebook\.net.*"),
    _createBlocker(r".*fbsbx\.com.*"),
    _createBlocker(r".*t\.co.*"), // Twitter/X
    _createBlocker(r".*analytics\.twitter\.com.*"),
    _createBlocker(r".*linkedin\.com/px/.*"), // LinkedIn Pixel
    _createBlocker(r".*snapchat\.com/tr.*"), // Snap Pixel
    _createBlocker(r".*tiktok\.com/analytics.*"), // TikTok Pixel
    _createBlocker(r".*pinterest\.com/ct\.html.*"),

    // 3. Session Recorders (The "Creepy" List)
    // These services record videos of user sessions. Blocking them is a huge privacy win.
    _createBlocker(r".*hotjar\.com.*"),
    _createBlocker(r".*crazyegg\.com.*"),
    _createBlocker(r".*fullstory\.com.*"),
    _createBlocker(r".*mouseflow\.com.*"),
    _createBlocker(r".*luckyorange\.com.*"),
    _createBlocker(r".*inspectlet\.com.*"),
    _createBlocker(r".*smartlook\.com.*"),
    _createBlocker(r".*logrocket\.com.*"),

    // 4. Major Ad Networks & Programmatic Advertising
    _createBlocker(r".*adnxs\.com.*"), // AppNexus
    _createBlocker(r".*criteo\.com.*"),
    _createBlocker(r".*taboola\.com.*"),
    _createBlocker(r".*outbrain\.com.*"),
    _createBlocker(r".*pubmatic\.com.*"),
    _createBlocker(r".*openx\.net.*"),
    _createBlocker(r".*amazon-adsystem\.com.*"),
    _createBlocker(r".*moatads\.com.*"),
    _createBlocker(r".*adzerk\.net.*"),
    _createBlocker(r".*adsrvr\.org.*"), // The Trade Desk
    _createBlocker(r".*bidswitch\.net.*"),
    _createBlocker(r".*rubiconproject\.com.*"),
    _createBlocker(r".*smartadserver\.com.*"),
    _createBlocker(r".*yieldmo\.com.*"),
    _createBlocker(r".*teads\.tv.*"),
    _createBlocker(r".*indexexchange\.com.*"),
    _createBlocker(r".*casalemedia\.com.*"),
    _createBlocker(r".*sovrn\.com.*"),
    _createBlocker(r".*lijit\.com.*"),
    _createBlocker(r".*33across\.com.*"),
    _createBlocker(r".*media\.net.*"),
    _createBlocker(r".*triplelift\.com.*"),
    _createBlocker(r".*gumgum\.com.*"),
    _createBlocker(r".*sharethrough\.com.*"),
    _createBlocker(r".*spotxchange\.com.*"),
    _createBlocker(r".*springserve\.com.*"),
    _createBlocker(r".*tremorhub\.com.*"),
    _createBlocker(r".*unruly\.co.*"),

    // 5. Mobile-Specific Ad Networks (Redirects & App Install Ads)
    _createBlocker(r".*appsflyer\.com.*"),
    _createBlocker(r".*adjust\.com.*"),
    _createBlocker(r".*branch\.io.*"),
    _createBlocker(r".*inmobi\.com.*"),
    _createBlocker(r".*adcolony\.com.*"),
    _createBlocker(r".*vungle\.com.*"),
    _createBlocker(r".*applovin\.com.*"),
    _createBlocker(r".*chartboost\.com.*"),
    _createBlocker(r".*unityads\.unity3d\.com.*"),
    _createBlocker(r".*startapp\.com.*"),
    _createBlocker(r".*supersonicads\.com.*"),
    _createBlocker(r".*ironsrc\.com.*"),
    _createBlocker(r".*tapjoy\.com.*"),
    _createBlocker(r".*fyber\.com.*"),
    _createBlocker(r".*mopub\.com.*"),
    _createBlocker(r".*kochava\.com.*"),
    _createBlocker(r".*singular\.net.*"),

    // 6. Analytics & Metrics
    _createBlocker(r".*scorecardresearch\.com.*"), // Comscore
    _createBlocker(r".*quantserve\.com.*"), // Quantcast
    _createBlocker(r".*comscore\.com.*"),
    _createBlocker(r".*liadm\.com.*"),
    _createBlocker(r".*adroll\.com.*"),
    _createBlocker(r".*mixpanel\.com.*"),
    _createBlocker(r".*amplitude\.com.*"),
    _createBlocker(r".*segment\.com.*"),
    _createBlocker(r".*heap\.io.*"),
    _createBlocker(r".*pendo\.io.*"),
    _createBlocker(r".*newrelic\.com.*"),
    _createBlocker(r".*datadoghq\.com.*"),
    _createBlocker(r".*yandex\.ru/metrika.*"),

    // 7. Popups, Popunders & Annoyances
    _createBlocker(r".*popads\.net.*"),
    _createBlocker(r".*popcash\.net.*"),
    _createBlocker(r".*propellerads\.com.*"),
    _createBlocker(r".*ad-maven\.com.*"),
    _createBlocker(r".*revenuehits\.com.*"),
    _createBlocker(r".*infolinks\.com.*"),
    _createBlocker(r".*bidvertiser\.com.*"),
    _createBlocker(r".*chitika\.com.*"),
    _createBlocker(r".*kontera\.com.*"),
    _createBlocker(r".*viglink\.com.*"),
    _createBlocker(r".*skimlinks\.com.*"),

    // 8. Crypto Miners (CPU Hijackers)
    _createBlocker(r".*coinhive\.com.*"),
    _createBlocker(r".*crypto-loot\.com.*"),
    _createBlocker(r".*coin-hive\.com.*"),
    _createBlocker(r".*miner\.js.*"),
    _createBlocker(r".*jsecoin\.com.*"),
  ];

  static ContentBlocker _createBlocker(String urlRegex) {
    return ContentBlocker(
      trigger: ContentBlockerTrigger(
        urlFilter: urlRegex,
      ),
      action: ContentBlockerAction(
        type: ContentBlockerActionType.BLOCK, // "Talk to the Hand"
      ),
    );
  }
}