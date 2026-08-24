// Copy to web/config.js (gitignored) and fill in your key, or let
// tool/build_web.ps1 generate it from android/local.properties.
//
// The key must be a *browser* key with the Maps JavaScript API enabled and
// an HTTP-referrer restriction for wherever you host this — a web key is
// public by definition, since it ships in the page.
//
// Leave it empty and the app still runs: maps degrade to the list views.
window.tripperConfig = {
  mapsApiKey: '',
};
