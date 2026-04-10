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

  /// JavaScript for blocking ad popups while allowing CAPTCHA / auth flows.
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

      const log = (msg) => console.log("MIRA_SHIELD: " + msg);

      // 3. Allowlisted domains whose popups / dialogs must not be blocked
      //    (CAPTCHA providers, OAuth, payment gateways).
      const _allowedOrigins = [
        'recaptcha', 'google.com/recaptcha', 'gstatic.com/recaptcha',
        'hcaptcha.com', 'newassets.hcaptcha.com',
        'challenges.cloudflare.com', 'turnstile',
        'accounts.google.com', 'appleid.apple.com',
        'login.microsoftonline.com', 'login.live.com',
        'github.com/login', 'id.apple.com',
        'checkout.stripe.com', 'js.stripe.com',
        'paypal.com', 'pay.google.com',
      ];

      function _isAllowedCaller() {
        try {
          const stack = new Error().stack || '';
          for (const origin of _allowedOrigins) {
            if (stack.includes(origin)) return true;
          }
          const active = document.activeElement;
          if (active) {
            const src = (active.src || '') + ' ' + (active.baseURI || '');
            for (const origin of _allowedOrigins) {
              if (src.includes(origin)) return true;
            }
          }
          const frames = document.querySelectorAll('iframe');
          for (const f of frames) {
            const fsrc = f.src || '';
            for (const origin of _allowedOrigins) {
              if (fsrc.includes(origin)) return true;
            }
          }
        } catch (_) {}
        return false;
      }

      // 3b. Keep native references so allowed callers pass through.
      const _nativeAlert   = window.alert.bind(window);
      const _nativeConfirm = window.confirm.bind(window);
      const _nativePrompt  = window.prompt.bind(window);
      const _nativeOpen    = window.open.bind(window);

      window.alert = function(m) {
        if (_isAllowedCaller()) return _nativeAlert(m);
        log("Blocked Alert: " + m);
      };
      window.confirm = function(m) {
        if (_isAllowedCaller()) return _nativeConfirm(m);
        log("Blocked Confirm: " + m);
        return true;
      };
      window.prompt = function(m, d) {
        if (_isAllowedCaller()) return _nativePrompt(m, d);
        log("Blocked Prompt: " + m);
        return null;
      };

      // 4. window.open — allow CAPTCHA / auth, block ad popups.
      function _isAllowedUrl(url) {
        if (!url) return false;
        const s = String(url).toLowerCase();
        for (const origin of _allowedOrigins) {
          if (s.includes(origin)) return true;
        }
        return false;
      }

      window.open = function(url, name, specs, replace) {
        if (_isAllowedUrl(url) || _isAllowedCaller()) {
          log("Allowed window.open: " + url);
          return _nativeOpen(url, name, specs, replace);
        }
        log("Blocked window.open: " + url);
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
