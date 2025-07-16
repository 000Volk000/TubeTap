import 'package:flutter/material.dart';

class DownloadsScreen extends StatefulWidget {
  const DownloadsScreen({super.key});

  @override
  State<DownloadsScreen> createState() => _DownloadsScreenState();
}

class _DownloadsScreenState extends State<DownloadsScreen> {
  // Lista simulada de descargas
  final List<DownloadItem> _downloads = [
    DownloadItem(
      title: 'Video de ejemplo 1',
      url: 'https://youtube.com/watch?v=example1',
      format: 'MP4',
      status: DownloadStatus.completed,
      progress: 100,
      size: '25.6 MB',
    ),
    DownloadItem(
      title: 'Audio de ejemplo 2',
      url: 'https://youtube.com/watch?v=example2',
      format: 'MP3',
      status: DownloadStatus.downloading,
      progress: 65,
      size: '4.2 MB',
    ),
    DownloadItem(
      title: 'Video de ejemplo 3',
      url: 'https://youtube.com/watch?v=example3',
      format: 'MP4',
      status: DownloadStatus.failed,
      progress: 0,
      size: '0 MB',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Descargas'),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_sweep),
            onPressed: _clearCompleted,
            tooltip: 'Limpiar completadas',
          ),
        ],
      ),
      body: _downloads.isEmpty
          ? _buildEmptyState()
          : ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: _downloads.length,
              itemBuilder: (context, index) {
                return _DownloadCard(
                  download: _downloads[index],
                  onDelete: () => _deleteDownload(index),
                  onRetry: () => _retryDownload(index),
                );
              },
            ),
    );
  }

  Widget _buildEmptyState() {
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

  void _clearCompleted() {
    setState(() {
      _downloads.removeWhere(
        (download) => download.status == DownloadStatus.completed,
      );
    });
  }

  void _deleteDownload(int index) {
    setState(() {
      _downloads.removeAt(index);
    });
  }

  void _retryDownload(int index) {
    setState(() {
      _downloads[index] = _downloads[index].copyWith(
        status: DownloadStatus.downloading,
        progress: 0,
      );
    });

    // Aquí implementarías la lógica de reintento
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(const SnackBar(content: Text('Reintentando descarga...')));
  }
}

class _DownloadCard extends StatelessWidget {
  final DownloadItem download;
  final VoidCallback onDelete;
  final VoidCallback onRetry;

  const _DownloadCard({
    required this.download,
    required this.onDelete,
    required this.onRetry,
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
                        '${download.format} • ${download.size}',
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
    }
  }

  Widget _buildActionButton(BuildContext context) {
    switch (download.status) {
      case DownloadStatus.completed:
        return PopupMenuButton<String>(
          onSelected: (value) {
            if (value == 'delete') {
              onDelete();
            }
          },
          itemBuilder: (context) => [
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
          onPressed: onDelete,
          tooltip: 'Cancelar',
        );
      case DownloadStatus.failed:
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
    }
  }
}

enum DownloadStatus { downloading, completed, failed }

class DownloadItem {
  final String title;
  final String url;
  final String format;
  final DownloadStatus status;
  final int progress;
  final String size;

  DownloadItem({
    required this.title,
    required this.url,
    required this.format,
    required this.status,
    required this.progress,
    required this.size,
  });

  DownloadItem copyWith({
    String? title,
    String? url,
    String? format,
    DownloadStatus? status,
    int? progress,
    String? size,
  }) {
    return DownloadItem(
      title: title ?? this.title,
      url: url ?? this.url,
      format: format ?? this.format,
      status: status ?? this.status,
      progress: progress ?? this.progress,
      size: size ?? this.size,
    );
  }
}
