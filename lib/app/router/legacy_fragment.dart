/// Where an old `#` URL points, now that the web uses paths (#440): invites
/// sent before were `/#/invite/<code>`. Null for anything else, including
/// the `#access_token=…` or `#error=…` an auth redirect may carry.
String? legacyFragmentTarget(Uri url) {
  final fragment = url.fragment;
  return fragment.startsWith('/') ? fragment : null;
}
