class AppConfig {
  // Configuración del servidor
  static const String serverUrl = 'http://servidordario.ddns.net:5000';
  static const String downloadEndpoint = '/download';
  static const String progressEndpoint = '/progress';
  static const String serveVideoEndpoint = '/serve_video';

  // Configuración de timeouts
  static const Duration connectionTimeout = Duration(seconds: 30);
  static const Duration receiveTimeout = Duration(seconds: 30);

  // Configuración de calidades de video disponibles
  static const List<String> videoQualities = [
    '144',
    '240',
    '360',
    '480',
    '720',
    '1080',
  ];

  // Configuración de calidades de audio disponibles
  static const List<String> audioQualities = ['128', '192', '256', '320'];

  // Configuración de carpetas de descarga
  static const String appFolderName = 'TubeTap';
  static const String videoFolderName = 'video';
  static const String audioFolderName = 'audio';

  // Configuración de la UI
  static const Duration snackBarDuration = Duration(seconds: 3);
  static const Duration errorSnackBarDuration = Duration(seconds: 5);

  // Configuración de SSE
  static const Duration sseReconnectDelay = Duration(seconds: 5);
  static const int sseMaxRetries = 3;
}

// Enums para mejor tipado
enum SupportedPlatform {
  youtube,
  // Futuras plataformas se pueden agregar aquí
}

extension SupportedPlatformExtension on SupportedPlatform {
  String get displayName {
    switch (this) {
      case SupportedPlatform.youtube:
        return 'YouTube';
    }
  }

  bool isValidUrl(String url) {
    switch (this) {
      case SupportedPlatform.youtube:
        return url.contains('youtube.com') || url.contains('youtu.be');
    }
  }
}
