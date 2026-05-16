/// SMS copy per language — includes Google Maps `?q=lat,lng` link.
class MessageTemplates {
  MessageTemplates._();

  static String emergency({
    required String language,
    required String userName,
    required double lat,
    required double lng,
  }) {
    final mapsLink = 'https://maps.google.com/?q=$lat,$lng';
    switch (language) {
      case 'si':
        return 'අනතුර! $userName උදව් අවශ්‍යයි! ස්ථානය: $mapsLink';
      case 'ta':
        return 'அவசரம்! $userName உதவி தேவை! இடம்: $mapsLink';
      case 'en':
      default:
        return 'EMERGENCY! $userName needs help! Location: $mapsLink';
    }
  }

  static String resolved({
    required String language,
    required String userName,
  }) {
    switch (language) {
      case 'si':
        return 'විසඳුණි: $userName දැන් ආරක්ෂිතයි.';
      case 'ta':
        return 'தீர்வு: $userName இப்போது பாதுகாப்பாக உள்ளார்.';
      case 'en':
      default:
        return 'RESOLVED: $userName is safe now.';
    }
  }
}
