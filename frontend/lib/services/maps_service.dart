library;

import 'package:url_launcher/url_launcher.dart';

class MapsService {
  /// Opens Google Maps turn-by-turn navigation to [latitude], [longitude].
  ///
  /// Primary:  `google.navigation:q=lat,lng&mode=d` (Google Maps native)
  /// Fallback: `https://www.google.com/maps/dir/?api=1&destination=lat,lng`
  static Future<void> navigateTo({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    // Native Google Maps intent URL (Android)
    final nativeUri = Uri.parse(
      'google.navigation:q=$latitude,$longitude&mode=d',
    );

    // Web fallback (works in browser on any platform)
    final webUri = Uri.parse(
      'https://www.google.com/maps/dir/?api=1'
      '&destination=$latitude,$longitude'
      '&travelmode=driving',
    );

    if (await canLaunchUrl(nativeUri)) {
      await launchUrl(nativeUri, mode: LaunchMode.externalApplication);
    } else if (await canLaunchUrl(webUri)) {
      await launchUrl(webUri, mode: LaunchMode.externalApplication);
    } else {
      throw const MapsException(
        'Could not launch Google Maps. Ensure Google Maps is installed.',
      );
    }
  }
}

/// Custom exception for maps-related errors.
class MapsException implements Exception {
  final String message;
  const MapsException(this.message);

  @override
  String toString() => 'MapsException: $message';
}
