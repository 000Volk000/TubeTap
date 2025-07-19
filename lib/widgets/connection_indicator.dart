import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/download_manager.dart';

class ConnectionIndicator extends StatelessWidget {
  const ConnectionIndicator({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<DownloadManager>(
      builder: (context, downloadManager, child) {
        // Por simplicidad, asumimos que hay conexión si hay descargas activas
        final hasActiveDownloads = downloadManager.downloads.any(
          (d) => d.status == DownloadStatus.downloading,
        );

        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: hasActiveDownloads
                ? Colors.green.shade100
                : Colors.grey.shade100,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: hasActiveDownloads
                  ? Colors.green.shade300
                  : Colors.grey.shade300,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                hasActiveDownloads ? Icons.cloud_done : Icons.cloud_off,
                size: 16,
                color: hasActiveDownloads
                    ? Colors.green.shade700
                    : Colors.grey.shade600,
              ),
              const SizedBox(width: 6),
              Text(
                hasActiveDownloads ? 'Conectado' : 'Servidor',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  color: hasActiveDownloads
                      ? Colors.green.shade700
                      : Colors.grey.shade600,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
