import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:dio/dio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import '../config/app_config.dart';

class ApiService {
  final Dio _dio = Dio();

  ApiService() {
    _dio.options.connectTimeout = AppConfig.connectionTimeout;
    _dio.options.receiveTimeout = AppConfig.receiveTimeout;
  }

  // Iniciar descarga
  Future<Map<String, dynamic>> startDownload(String url, String quality) async {
    try {
      final response = await http.post(
        Uri.parse('${AppConfig.serverUrl}${AppConfig.downloadEndpoint}'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'url': url, 'quality': quality}),
      );

      if (response.statusCode == 202) {
        return jsonDecode(response.body);
      } else {
        throw Exception('Error al iniciar descarga: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error de conexión: $e');
    }
  }

  // Stream para recibir actualizaciones de progreso via SSE
  Stream<Map<String, dynamic>> getProgressStream() async* {
    try {
      final client = http.Client();
      final request = http.Request(
        'GET',
        Uri.parse('${AppConfig.serverUrl}${AppConfig.progressEndpoint}'),
      );
      request.headers['Accept'] = 'text/event-stream';
      request.headers['Cache-Control'] = 'no-cache';

      final response = await client.send(request);

      if (response.statusCode == 200) {
        await for (final chunk in response.stream.transform(utf8.decoder)) {
          final lines = chunk.split('\n');
          for (final line in lines) {
            if (line.startsWith('data: ')) {
              final data = line.substring(6);
              if (data.trim().isNotEmpty) {
                try {
                  final jsonData = jsonDecode(data);
                  yield jsonData;
                } catch (e) {
                  debugPrint('Error parsing SSE data: $e');
                }
              }
            }
          }
        }
      }
    } catch (e) {
      debugPrint('Error en stream de progreso: $e');
      throw Exception('Error de conexión SSE: $e');
    }
  }

  // Descargar archivo y guardarlo en el dispositivo
  Future<String> downloadFile(String filename, String format) async {
    try {
      // Solicitar permisos de almacenamiento
      await _requestStoragePermission();

      // Obtener la carpeta de descargas
      final directory = await _getDownloadDirectory(format);
      final filePath = '${directory.path}/$filename';

      // Descargar el archivo
      await _dio.download(
        '${AppConfig.serverUrl}${AppConfig.serveVideoEndpoint}/$filename',
        filePath,
        onReceiveProgress: (received, total) {
          if (total != -1) {
            final progress = (received / total * 100).toStringAsFixed(1);
            debugPrint('Descargando: $progress%');
          }
        },
      );

      return filePath;
    } catch (e) {
      throw Exception('Error al descargar archivo: $e');
    }
  }

  // Obtener directorio de descargas
  Future<Directory> _getDownloadDirectory(String format) async {
    Directory? downloadsDir;

    if (Platform.isAndroid) {
      // En Android, usar la carpeta de descargas públicas
      downloadsDir = Directory('/storage/emulated/0/Download/TubeTap');
    } else if (Platform.isIOS) {
      // En iOS, usar el directorio de documentos de la app
      final appDocDir = await getApplicationDocumentsDirectory();
      downloadsDir = Directory('${appDocDir.path}/TubeTap');
    } else {
      // Para otras plataformas, usar el directorio de descargas del sistema
      downloadsDir = await getDownloadsDirectory();
      if (downloadsDir != null) {
        downloadsDir = Directory('${downloadsDir.path}/TubeTap');
      } else {
        final appDocDir = await getApplicationDocumentsDirectory();
        downloadsDir = Directory('${appDocDir.path}/TubeTap');
      }
    }

    // Crear subcarpeta según el formato
    final formatDir = Directory(
      '${downloadsDir.path}/${format == 'video' ? 'video' : 'audio'}',
    );

    if (!await formatDir.exists()) {
      await formatDir.create(recursive: true);
    }

    return formatDir;
  }

  // Solicitar permisos de almacenamiento
  Future<void> _requestStoragePermission() async {
    if (Platform.isAndroid) {
      // Para Android 10+ (API 29+), usar permisos específicos
      final androidInfo = await _getAndroidVersion();

      if (androidInfo >= 30) {
        // Android 11+ (API 30+) - Usar MANAGE_EXTERNAL_STORAGE si es necesario
        var status = await Permission.manageExternalStorage.status;
        if (!status.isGranted) {
          status = await Permission.manageExternalStorage.request();
          if (!status.isGranted) {
            throw Exception('Permisos de almacenamiento requeridos');
          }
        }
      } else {
        // Android 6-10 - Usar permisos de almacenamiento tradicionales
        var status = await Permission.storage.status;
        if (!status.isGranted) {
          status = await Permission.storage.request();
          if (!status.isGranted) {
            throw Exception('Permisos de almacenamiento requeridos');
          }
        }
      }
    }
  }

  // Obtener versión de Android
  Future<int> _getAndroidVersion() async {
    if (Platform.isAndroid) {
      // Esto es una aproximación, en un proyecto real usarías device_info_plus
      return 30; // Asumimos Android 11+ por defecto
    }
    return 0;
  }
}
