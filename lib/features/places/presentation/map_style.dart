/// Custom Google Maps style (redesign spec §6, Phase 3): retunes the map
/// surface to the app's own `map.water`/`map.land`/`warning.amber` tokens
/// instead of leaving light mode as Google's stock tiles and dark mode as
/// Google's generic "Night" style. This supersedes the 2026-07-23 "stock
/// Google Maps look" decision that used to live in this file's header —
/// the app's visual language now extends onto the map surface itself.
///
/// The hex literals below are copies of `AppColors.light`/`AppColors.dark`
/// (`lib/core/theme/app_colors.dart`) — `GoogleMap.style` needs a plain
/// JSON string built at compile time, so it can't reference `AppColors`
/// directly. If those tokens ever change, these two strings need updating
/// to match (this is the same narrow "copy, don't invent" exception to
/// "no raw hex outside app_colors.dart" that `TripCard`'s cover scrim
/// uses — see phase2a's plan, Task 3).
///
/// Both styles share the same feature/element shape (base geometry, road,
/// road.highway, transit, water, plus label fill/stroke for each), only
/// dropping Google's separate `poi.park` override — this app's token set
/// has no distinct "park" hue, and folding parks into the base geometry
/// color keeps the palette as tight as the redesign spec calls for
/// (§3.2: "tightened down... named brand hues: three").
const kMapStyleLight = '''
[
  {"elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#403f47"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#faf3ec"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#403f47"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#faf3ec"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#efe7d8"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#8d5513"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#dceae6"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#56525d"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#dceae6"}]}
]
''';

const kMapStyleDark = '''
[
  {"elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"elementType":"labels.text.stroke","stylers":[{"color":"#242f3e"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"poi","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"road","elementType":"geometry.stroke","stylers":[{"color":"#12141c"}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"featureType":"road.highway","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#12141c"}]},
  {"featureType":"road.highway","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"transit","elementType":"geometry","stylers":[{"color":"#242f3e"}]},
  {"featureType":"transit.station","elementType":"labels.text.fill","stylers":[{"color":"#f2a93c"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#17263c"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#868ba0"}]},
  {"featureType":"water","elementType":"labels.text.stroke","stylers":[{"color":"#17263c"}]}
]
''';
