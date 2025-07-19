import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'downloads_screen.dart';
import '../theme/app_colors.dart';
import '../services/download_manager.dart';
import '../config/app_config.dart';

class FormatSelectionScreen extends StatelessWidget {
  final String url;

  const FormatSelectionScreen({super.key, required this.url});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Seleccionar Formato')),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 40),

            Text(
              'Elige el formato de descarga',
              style: Theme.of(
                context,
              ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 8),

            Text(
              'Selecciona si quieres descargar video o solo audio',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
            ),

            const SizedBox(height: 48),

            // Opción Video
            _FormatOptionCard(
              icon: Icons.videocam,
              title: 'Video (.mp4)',
              subtitle: 'Descarga el video completo con audio',
              color: Colors.red,
              onTap: () => _showVideoQualityDialog(context),
            ),

            const SizedBox(height: 16),

            // Opción Audio
            _FormatOptionCard(
              icon: Icons.audiotrack,
              title: 'Audio (.mp3)',
              subtitle: 'Descarga solo el audio del video',
              color: Colors.orange,
              onTap: () => _showAudioQualityDialog(context),
            ),

            const Spacer(),

            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.grey.shade100,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'URL a descargar:',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Colors.grey[600],
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    url,
                    style: Theme.of(
                      context,
                    ).textTheme.bodySmall?.copyWith(color: Colors.grey[800]),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showVideoQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Center(
            child: Text(
              'Seleccionar Resolución',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Resoluciones disponibles:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...AppConfig.videoQualities.map(
                (resolution) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      _startDownload(context, 'video', resolution);
                      Navigator.of(context).popUntil((route) => route.isFirst);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('${resolution}p'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showAudioQualityDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return AlertDialog(
          backgroundColor: Colors.white,
          title: const Center(
            child: Text(
              'Seleccionar Calidad',
              style: TextStyle(
                color: AppColors.textPrimary,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Calidades disponibles:',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 16),
              ),
              const SizedBox(height: 16),
              ...AppConfig.audioQualities.map(
                (quality) => Container(
                  width: double.infinity,
                  margin: const EdgeInsets.symmetric(vertical: 4),
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pop();
                      _startDownload(context, 'audio', quality);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.textOnPrimary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text('${quality}K'),
                  ),
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Cancelar',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _startDownload(
    BuildContext context,
    String format,
    String quality,
  ) async {
    final downloadManager = Provider.of<DownloadManager>(
      context,
      listen: false,
    );

    // Construir la calidad en el formato esperado por el servidor
    String qualityFormatted;
    if (format == 'video') {
      qualityFormatted = '${quality}p';
    } else {
      qualityFormatted = '${quality}K';
    }

    try {
      // Iniciar descarga usando el DownloadManager
      await downloadManager.startDownload(
        url: url,
        format: format,
        quality: qualityFormatted,
        title: _extractVideoTitle(url),
      );

      // Verificar si el context sigue siendo válido antes de usarlo
      if (!context.mounted) return;

      // Volver a la pantalla principal
      Navigator.of(context).popUntil((route) => route.isFirst);

      // Mostrar mensaje de confirmación
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Descarga iniciada en formato $format ($qualityFormatted)',
          ),
          action: SnackBarAction(
            label: 'Ver descargas',
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (context) => const DownloadsScreen(),
                ),
              );
            },
          ),
          duration: AppConfig.snackBarDuration,
        ),
      );
    } catch (e) {
      // Verificar si el context sigue siendo válido antes de usarlo
      if (!context.mounted) return;

      // Mostrar error si no se puede iniciar la descarga
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error al iniciar descarga: $e'),
          backgroundColor: Colors.red,
          duration: AppConfig.errorSnackBarDuration,
        ),
      );
    }
  }

  // Extraer título básico del URL
  String _extractVideoTitle(String url) {
    if (url.contains('youtube.com') || url.contains('youtu.be')) {
      final uri = Uri.parse(url);
      final videoId =
          uri.queryParameters['v'] ??
          (url.contains('youtu.be') ? uri.pathSegments.last : null);
      return videoId != null ? 'Video $videoId' : 'Video de YouTube';
    }
    return 'Video descargado';
  }
}

class _FormatOptionCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;

  const _FormatOptionCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Row(
            children: [
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(30),
                ),
                child: Icon(icon, size: 32, color: color),
              ),
              const SizedBox(width: 20),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: Theme.of(
                        context,
                      ).textTheme.bodyMedium?.copyWith(color: Colors.grey[600]),
                    ),
                  ],
                ),
              ),
              Icon(Icons.arrow_forward_ios, color: Colors.grey[400], size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
