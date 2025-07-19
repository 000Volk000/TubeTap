import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'api_service.dart';

enum DownloadStatus { pending, downloading, completed, failed, cancelled }

class DownloadItem {
  final String id;
  final String title;
  final String url;
  final String format;
  final String quality;
  final DownloadStatus status;
  final int progress;
  final String? filePath;
  final String? errorMessage;
  final DateTime createdAt;

  DownloadItem({
    required this.id,
    required this.title,
    required this.url,
    required this.format,
    required this.quality,
    required this.status,
    this.progress = 0,
    this.filePath,
    this.errorMessage,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  DownloadItem copyWith({
    String? id,
    String? title,
    String? url,
    String? format,
    String? quality,
    DownloadStatus? status,
    int? progress,
    String? filePath,
    String? errorMessage,
    DateTime? createdAt,
  }) {
    return DownloadItem(
      id: id ?? this.id,
      title: title ?? this.title,
      url: url ?? this.url,
      format: format ?? this.format,
      quality: quality ?? this.quality,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      filePath: filePath ?? this.filePath,
      errorMessage: errorMessage ?? this.errorMessage,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get sizeDisplay {
    // Esto se actualizará con información real del servidor
    if (status == DownloadStatus.completed) {
      return 'Completado';
    } else if (status == DownloadStatus.downloading) {
      return '$progress%';
    } else if (status == DownloadStatus.failed) {
      return 'Error';
    }
    return 'Pendiente';
  }
}

class DownloadManager extends ChangeNotifier {
  final ApiService _apiService = ApiService();
  final List<DownloadItem> _downloads = [];
  StreamSubscription? _progressSubscription;

  List<DownloadItem> get downloads => List.unmodifiable(_downloads);

  DownloadManager() {
    _initializeProgressStream();
  }

  // Inicializar el stream de progreso
  void _initializeProgressStream() {
    _progressSubscription = _apiService.getProgressStream().listen(
      (data) {
        _handleProgressUpdate(data);
      },
      onError: (error) {
        debugPrint('Error en stream de progreso: $error');
      },
    );
  }

  // Manejar actualizaciones de progreso del servidor
  void _handleProgressUpdate(Map<String, dynamic> data) {
    final status = data['status'] as String?;

    if (status == null) return;

    // Buscar la descarga activa (la más reciente que esté descargando)
    final downloadingIndex = _downloads.indexWhere(
      (d) => d.status == DownloadStatus.downloading,
    );

    if (downloadingIndex == -1) return;

    final currentDownload = _downloads[downloadingIndex];

    switch (status) {
      case 'downloading':
        final progress = data['progress'] as int? ?? 0;
        _downloads[downloadingIndex] = currentDownload.copyWith(
          progress: progress,
        );
        break;

      case 'download_complete':
        final filename = data['file_path'] as String?;
        if (filename != null) {
          _downloadFile(currentDownload, filename);
        }
        break;

      case 'error':
        final errorMessage = data['message'] as String? ?? 'Error desconocido';
        _downloads[downloadingIndex] = currentDownload.copyWith(
          status: DownloadStatus.failed,
          errorMessage: errorMessage,
        );
        break;
    }

    notifyListeners();
  }

  // Descargar el archivo al dispositivo
  Future<void> _downloadFile(DownloadItem download, String filename) async {
    try {
      final format = download.format == 'video' ? 'video' : 'audio';
      final filePath = await _apiService.downloadFile(filename, format);

      final index = _downloads.indexOf(download);
      if (index != -1) {
        _downloads[index] = download.copyWith(
          status: DownloadStatus.completed,
          progress: 100,
          filePath: filePath,
        );
        notifyListeners();
      }
    } catch (e) {
      final index = _downloads.indexOf(download);
      if (index != -1) {
        _downloads[index] = download.copyWith(
          status: DownloadStatus.failed,
          errorMessage: 'Error al guardar archivo: $e',
        );
        notifyListeners();
      }
    }
  }

  // Iniciar una nueva descarga
  Future<void> startDownload({
    required String url,
    required String format,
    required String quality,
    String? title,
  }) async {
    final id = DateTime.now().millisecondsSinceEpoch.toString();
    final downloadItem = DownloadItem(
      id: id,
      title: title ?? _extractTitleFromUrl(url),
      url: url,
      format: format,
      quality: quality,
      status: DownloadStatus.pending,
    );

    _downloads.insert(0, downloadItem); // Agregar al principio
    notifyListeners();

    try {
      // Iniciar descarga en el servidor
      await _apiService.startDownload(url, quality);

      // Actualizar estado a descargando
      final index = _downloads.indexWhere((d) => d.id == id);
      if (index != -1) {
        _downloads[index] = downloadItem.copyWith(
          status: DownloadStatus.downloading,
        );
        notifyListeners();
      }
    } catch (e) {
      // Manejar error
      final index = _downloads.indexWhere((d) => d.id == id);
      if (index != -1) {
        _downloads[index] = downloadItem.copyWith(
          status: DownloadStatus.failed,
          errorMessage: e.toString(),
        );
        notifyListeners();
      }
    }
  }

  // Extraer título del URL (método simple)
  String _extractTitleFromUrl(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final uri = Uri.parse(url);
      final videoId =
          uri.queryParameters['v'] ??
          (url.contains('youtu.be') ? uri.pathSegments.last : null);
      return videoId != null ? 'Video $videoId' : 'Video de YouTube';
    }
    return 'Video descargado';
  }

  // Reintentar descarga
  Future<void> retryDownload(String downloadId) async {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    final download = _downloads[index];
    await startDownload(
      url: download.url,
      format: download.format,
      quality: download.quality,
      title: download.title,
    );

    // Remover la descarga fallida
    _downloads.removeAt(index);
    notifyListeners();
  }

  // Cancelar descarga
  void cancelDownload(String downloadId) {
    final index = _downloads.indexWhere((d) => d.id == downloadId);
    if (index == -1) return;

    _downloads[index] = _downloads[index].copyWith(
      status: DownloadStatus.cancelled,
    );
    notifyListeners();
  }

  // Eliminar descarga
  void removeDownload(String downloadId) {
    _downloads.removeWhere((d) => d.id == downloadId);
    notifyListeners();
  }

  // Limpiar descargas completadas
  void clearCompleted() {
    _downloads.removeWhere((d) => d.status == DownloadStatus.completed);
    notifyListeners();
  }

  @override
  void dispose() {
    _progressSubscription?.cancel();
    super.dispose();
  }
}
