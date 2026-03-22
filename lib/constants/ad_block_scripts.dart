class AdBlockScripts {
  /// Expanded CSS to hide common ad networks, sponsored content, and empty ad slots.
  /// Includes Taboola, Outbrain, Amazon, and generic "Sponsored" labels.
  static const String adHidingCss = """
    /* Core Google & Network Ads */
    [id*="google_ads"], [class*="google_ads"], .adsbygoogle, 
    iframe[src*="googleads"], iframe[src*="doubleclick"],
    
    /* Common Ad Classes/IDs */
    .ad-unit, .ad-container, .ad-wrapper, .ad-slot, .ad-zone, .ad-block,
    [id^="ad-"], [class^="ad-"], [id*="-ad-"], [class*="-ad-"], [id\$="-ad"], [class\$="-ad"],
    [id*="adv-"], [class*="adv-"], .native-ad, .ad-sidebar, .ad-header, .ad-footer,
    
    /* Sponsored & Promoted Content Labels */
    [aria-label*="Advertisement" i], [aria-label*="Sponsored" i],
    [title*="Advertisement" i], [title*="Sponsored" i],
    
    /* Content Recommendation Networks (Taboola, Outbrain, etc.) */
    .trc_related_container, .trc_rbox_container, [id^="taboola-"], [class*="taboola-"],
    .outbrain_widget_container, .ob-widget-items-container, [id^="outbrain-"], [class*="outbrain-"],
    .revcontent-ad, [class*="sponsored-"], [id*="sponsored-"],
    
    /* Amazon & Others */
    [id*="amazon_ad"], [class*="amazon_ad"], [class*="yom-ad"] {
      display: none !important;
      visibility: hidden !important;
      opacity: 0 !important;
      pointer-events: none !important;
      height: 0 !important;
      width: 0 !important;
      max-height: 0 !important;
      margin: 0 !important;
      padding: 0 !important;
    }
  """;

  /// JavaScript for blocking popups, alerts, and mocking ad-variables 
  /// to bypass basic anti-adblocker checks.
  static const String popupBlockerJs = """
    (function() {
      // 1. Mock Ad-Variables (Fool basic Anti-Adblock scripts)
      window.canRunAds = true;
      window.isAdBlocked = false;
      window.google_ad_status = 1;
      window.adsbygoogle = window.adsbygoogle || [];
      window.adsbygoogle.push = function() { return {}; };

      // 2. CSS Injection for Ad-Hiding
      const style = document.createElement('style');
      style.innerHTML = adHidingCssPlaceholder;
      (document.head || document.documentElement).appendChild(style);

      // 3. Popup & Alert Blocking
      const log = (msg) => console.log("MIRA_SHIELD: " + msg);
      
      window.alert = function(m) { log("Blocked Alert: " + m); };
      window.confirm = function(m) { log("Blocked Confirm: " + m); return true; };
      window.prompt = function(m) { log("Blocked Prompt: " + m); return null; };
      
      // 4. Prevent aggressive window.open popups
      const originalOpen = window.open;
      window.open = function(url, name, specs, replace) {
        log("Intercepted window.open: " + url);
        return null; 
      };

      // 5. Cleanup observer to handle dynamically loaded ads
      const observer = new MutationObserver((mutations) => {
        mutations.forEach((mutation) => {
          if (mutation.addedNodes.length > 0) {
             // The CSS handles most cases, but we can add JS logic here if needed
          }
        });
      });
      observer.observe(document.body || document.documentElement, { childList: true, subtree: true });
    })();
  """;

  /// Helper to get the full script with the CSS injected.
  static String getFullShieldScript() {
    return popupBlockerJs.replaceFirst('adHidingCssPlaceholder', '`$adHidingCss`');
  }
}
