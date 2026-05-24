/// A curated, high-fidelity premium pastel map style configuration
/// for a clean, professional, and visually balanced navigation experience.
class MapStyles {
  MapStyles._();

  static const String premiumStyle = '''
[
  {"featureType":"all","elementType":"geometry","stylers":[{"color":"#f0ede8"}]},
  {"featureType":"water","elementType":"geometry","stylers":[{"color":"#b8d8ea"}]},
  {"featureType":"water","elementType":"labels.text.fill","stylers":[{"color":"#7ca8c0"}]},
  {"featureType":"road","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.arterial","elementType":"geometry","stylers":[{"color":"#ffffff"}]},
  {"featureType":"road.highway","elementType":"geometry.fill","stylers":[{"color":"#ffe082"}]},
  {"featureType":"road.highway","elementType":"geometry.stroke","stylers":[{"color":"#f0c040","weight":0.5}]},
  {"featureType":"road","elementType":"labels.text.fill","stylers":[{"color":"#6b6b6b"}]},
  {"featureType":"road","elementType":"labels.icon","stylers":[{"visibility":"off"}]},
  {"featureType":"poi","stylers":[{"visibility":"off"}]},
  {"featureType":"poi.park","elementType":"geometry","stylers":[{"color":"#d4e8c8"}]},
  {"featureType":"transit","stylers":[{"visibility":"off"}]},
  {"featureType":"administrative.locality","elementType":"labels.text.fill","stylers":[{"color":"#444444"}]},
  {"featureType":"administrative.neighborhood","elementType":"labels.text.fill","stylers":[{"color":"#888888"}]},
  {"featureType":"landscape.man_made","elementType":"geometry","stylers":[{"color":"#e8e4de"}]},
  {"featureType":"landscape.natural","elementType":"geometry","stylers":[{"color":"#e4edd8"}]}
]
''';
}
