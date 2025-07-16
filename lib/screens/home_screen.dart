import 'package:flutter/material.dart';
import 'url_input_screen.dart';
import 'downloads_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('TubeTap')),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Logo en la parte superior central
                Expanded(
                  flex: 2,
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        // Logo desde assets (ajustado para formato horizontal)
                        Container(
                          width: 140,
                          height: 140,
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(25),
                            child: _buildLogo(),
                          ),
                        ),
                        const SizedBox(height: 24),
                        Text(
                          'TubeTap',
                          style: Theme.of(context).textTheme.headlineMedium
                              ?.copyWith(
                                fontWeight: FontWeight.bold,
                                color: Theme.of(context).primaryColor,
                                letterSpacing: 1.5,
                              ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Descarga videos y audio fácilmente',
                          style: Theme.of(context).textTheme.bodyMedium
                              ?.copyWith(color: Colors.grey[600]),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                ),

                // Botón "Enlace Simple" en el centro
                Expanded(
                  flex: 1,
                  child: Center(
                    child: SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (context) => const UrlInputScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: const Text(
                          'Enlace Único',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 40),
              ],
            ),
          ),

          // Botón de descargas visible en la esquina inferior derecha
          Positioned(
            bottom: 24,
            right: 24,
            child: InkWell(
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => const DownloadsScreen(),
                  ),
                );
              },
              borderRadius: BorderRadius.circular(30),
              child: Container(
                padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                decoration: BoxDecoration(
                  color: Color(0xFFFF3B3F), // Color coral red directo
                  borderRadius: BorderRadius.circular(30),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black26,
                      blurRadius: 8,
                      offset: Offset(0, 2),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.download, color: Colors.white, size: 20),
                    SizedBox(width: 8),
                    Text(
                      'Descargas',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w600,
                        fontSize: 14,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLogo() {
    try {
      return Image.asset(
        'assets/images/logos/tubetapLogo.png',
        width: 140,
        height: 140,
        fit: BoxFit.contain, // Cambiado a contain para mostrar toda la imagen
        errorBuilder: (context, error, stackTrace) {
          print('🔴 Error loading PNG: $error');
          // Fallback a un logo creado con widgets
          return Container(
            width: 140,
            height: 140,
            decoration: BoxDecoration(
              color: Color(0xFFFF3B3F),
              borderRadius: BorderRadius.circular(25),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.video_library, size: 50, color: Colors.white),
                  SizedBox(height: 8),
                  Text(
                    'TubeTap',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1.2,
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      );
    } catch (e) {
      print('🔴 Exception loading logo: $e');
      return Container(
        width: 140,
        height: 140,
        decoration: BoxDecoration(
          color: Color(0xFFFF3B3F),
          borderRadius: BorderRadius.circular(25),
        ),
        child: Center(
          child: Icon(Icons.video_library, size: 50, color: Colors.white),
        ),
      );
    }
  }
}
