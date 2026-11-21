/// The Loomia Turnstile widget (Cloudflare → Turnstile, invisible mode). Its
/// hostnames are getloomia.app, app.getloomia.app, the web preview and
/// localhost. Public by design; the secret is `env(TURNSTILE_SECRET_KEY)` in
/// supabase/config.toml.
const turnstileSiteKey = '0x4AAAAAAGLbJD8LJpK6Xhx9';

/// The origin the mobile page is loaded under, one of the widget's hostnames.
/// Proved on an iPhone and an Android phone (spec, Spike result).
const turnstileOrigin = 'https://getloomia.app';

/// The page the mobile web view loads: one invisible challenge, answered
/// through the `Captcha` JavaScript channel as `token:<t>` or `error:<code>`.
/// Turnstile's own retry is off (it loops forever on a failure); `Captcha`
/// retries once.
const captchaPage =
    '''
<!doctype html><html><head>
<meta name="viewport" content="width=device-width,initial-scale=1">
<script src="https://challenges.cloudflare.com/turnstile/v0/api.js?onload=go&render=explicit" async onerror="Captcha.postMessage('error:script')"></script>
<script>
function go() {
  turnstile.render('#c', {
    sitekey: '$turnstileSiteKey',
    retry: 'never',
    'refresh-expired': 'never',
    callback: function (t) { Captcha.postMessage('token:' + t); },
    'error-callback': function (e) { Captcha.postMessage('error:' + e); return true; },
    'timeout-callback': function () { Captcha.postMessage('error:timeout'); },
    'unsupported-callback': function () { Captcha.postMessage('error:unsupported'); },
  });
}
</script></head><body><div id="c"></div></body></html>''';
