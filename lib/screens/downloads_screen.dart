import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_manager.dart';
import 'dart:io';

class DownloadsScreen extends StatelessWidget {
  const DownloadsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          Consumer<DownloadManager>(
            builder: (context, downloadManager, child) {
              final hasCompleted = downloadManager.downloads.any(
                (d) => d.status == DownloadStatus.completed,
              );

              return IconButton(
                icon: const Icon(Icons.delete_sweep),
                onPressed: hasCompleted
                    ? () => downloadManager.clearCompleted()
                    : null,
                tooltip: 'Limpiar completadas',
              );
            },
          ),
        ],
      ),
      body: Consumer<DownloadManager>(
        builder: (context, downloadManager, child) {
          final downloads = downloadManager.downloads;

          if (downloads.isEmpty) {
            return _buildEmptyState(context);
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: downloads.length,
            itemBuilder: (context, index) {
              final download = downloads[index];
              return _DownloadCard(
                download: download,
                onDelete: () => downloadManager.removeDownload(download.id),
                onRetry: () => downloadManager.retryDownload(download.id),
                onCancel: () => downloadManager.cancelDownload(download.id),
              );
            },
          );
        },
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.download_done, size: 80, color: Colors.grey[400]),
          const SizedBox(height: 16),
          Text(
            'No hay descargas',
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tus descargas aparecerán aquí',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: Colors.grey[500]),
          ),
          const SizedBox(height: 32),
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Comenzar descarga'),
          ),
        ],
      ),
    );
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback onDelete;
  final VoidCallback onRetry;
  final VoidCallback onCancel;

  const _DownloadCard({
    required this.download,
    required this.onDelete,
    required this.onRetry,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                _buildStatusIcon(),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        download.title,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(fontWeight: FontWeight.w600),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '${download.format.toUpperCase()} • ${download.quality} • ${_getStatusText()}',
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Colors.grey[600],
                        ),
                      ),
                    ],
                  ),
                ),
                _buildActionButton(context),
              ],
            ),

            if (download.status == DownloadStatus.downloading) ...[
              const SizedBox(height: 12),
              LinearProgressIndicator(
                value: download.progress / 100,
                backgroundColor: Colors.grey[300],
                valueColor: AlwaysStoppedAnimation<Color>(
                  Theme.of(context).primaryColor,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '${download.progress}% completado',
                style: Theme.of(
                  context,
                ).textTheme.bodySmall?.copyWith(color: Colors.grey[600]),
              ),
            ],

            if (download.status == DownloadStatus.failed &&
                download.errorMessage != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.error_outline,
                      size: 16,
                      color: Colors.red.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        download.errorMessage!,
                        style: TextStyle(
                          color: Colors.red.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (download.status == DownloadStatus.completed &&
                download.filePath != null) ...[
              const SizedBox(height: 8),
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.green.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.green.shade200),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.check_circle_outline,
                      size: 16,
                      color: Colors.green.shade700,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Guardado en: ${download.filePath!.split('/').last}',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 12,
                        ),
                      ),
                    ),
                    if (Platform.isAndroid) ...[
                      const SizedBox(width: 8),
                      InkWell(
                        onTap: () => _openFile(download.filePath!),
                        child: Text(
                          'Abrir',
                          style: TextStyle(
                            color: Colors.green.shade700,
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ],

            const SizedBox(height: 8),
            Text(
              download.url,
              style: Theme.of(
                context,
              ).textTheme.bodySmall?.copyWith(color: Colors.grey[500]),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ],
        ),
      ),
    );
  }

  String _getStatusText() {
    switch (download.status) {
      case DownloadStatus.pending:
        return 'Pendiente';
      case DownloadStatus.downloading:
        return 'Descargando';
      case DownloadStatus.completed:
        return 'Completado';
      case DownloadStatus.failed:
        return 'Error';
      case DownloadStatus.cancelled:
        return 'Cancelado';
    }
  }

  Widget _buildStatusIcon() {
    switch (download.status) {
      case DownloadStatus.completed:
        return const Icon(Icons.check_circle, color: Colors.green, size: 24);
      case DownloadStatus.downloading:
        return const SizedBox(
          width: 24,
          height: 24,
          child: CircularProgressIndicator(strokeWidth: 2),
        );
      case DownloadStatus.failed:
        return const Icon(Icons.error, color: Colors.red, size: 24);
      case DownloadStatus.cancelled:
        return const Icon(Icons.cancel, color: Colors.orange, size: 24);
      case DownloadStatus.pending:
        return const Icon(Icons.schedule, color: Colors.blue, size: 24);
    }
  }

  Widget _buildActionButton(BuildContext context) {
    switch (download.status) {
      case DownloadStatus.completed:
        return PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            } else if (value == 'open' && download.filePath != null) {
              _openFile(download.filePath!);
            }
          },
          itemBuilder: (context) => [
            if (download.filePath != null && Platform.isAndroid)
              const PopupMenuItem(
                value: 'open',
                child: Row(
                  children: [
                    Icon(Icons.open_in_new, size: 20),
                    SizedBox(width: 8),
                    Text('Abrir'),
                  ],
                ),
              ),
            const PopupMenuItem(
              value: 'delete',
              child: Row(
                children: [
                  Icon(Icons.delete, size: 20),
                  SizedBox(width: 8),
                  Text('Eliminar'),
                ],
              ),
            ),
          ],
          child: const Icon(Icons.more_vert),
        );
      case DownloadStatus.downloading:
        return IconButton(
          icon: const Icon(Icons.cancel),
          onPressed: onCancel,
          tooltip: 'Cancelar',
        );
      case DownloadStatus.failed:
      case DownloadStatus.cancelled:
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: onRetry,
              tooltip: 'Reintentar',
            ),
            IconButton(
              icon: const Icon(Icons.delete),
              onPressed: onDelete,
              tooltip: 'Eliminar',
            ),
          ],
        );
      case DownloadStatus.pending:
        return IconButton(
          icon: const Icon(Icons.delete),
          onPressed: onDelete,
          tooltip: 'Eliminar',
        );
    }
  }

  void _openFile(String filePath) {
    // En una implementación real, usarías open_file o similar
    // Por ahora solo mostramos la ruta
    debugPrint('Abrir archivo: $filePath');
  }
}
