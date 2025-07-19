# TubeTap - Descargador de Videos

TubeTap es una aplicación Flutter que permite descargar videos y audio de YouTube mediante una conexión a un servidor backend Flask.

## 🚀 Características

- **Descarga de Videos**: Soporte para múltiples resoluciones (144p, 240p, 360p, 480p, 720p, 1080p)
- **Descarga de Audio**: Extracción de audio en diferentes calidades (128K, 192K, 256K, 320K)
- **Almacenamiento Organizado**: Los archivos se guardan en `/storage/emulated/0/Download/TubeTap/video` o `/storage/emulated/0/Download/TubeTap/audio`
- **Progreso en Tiempo Real**: Visualización del progreso de descarga mediante Server-Sent Events (SSE)
- **Interfaz Intuitiva**: Diseño moderno y fácil de usar
- **Gestión de Descargas**: Lista de descargas con estados, reintentos y limpieza

## 🏗️ Arquitectura

### Frontend (Flutter)

- **Provider**: Gestión de estado para las descargas
- **HTTP + SSE**: Comunicación con el servidor backend
- **Permisos**: Manejo de permisos de almacenamiento en Android
- **UI Responsiva**: Diseño adaptable con indicadores de progreso

### Backend (Flask)

- **yt-dlp**: Descarga de videos de YouTube
- **Server-Sent Events**: Transmisión de progreso en tiempo real
- **Gestión de Archivos**: Almacenamiento temporal y entrega de archivos

## 📁 Estructura del Proyecto

```
lib/
├── main.dart                      # Punto de entrada de la aplicación
├── screens/
│   ├── home_screen.dart          # Pantalla principal
│   ├── url_input_screen.dart     # Entrada de URL
│   ├── format_selection_screen.dart # Selección de formato y calidad
│   └── downloads_screen.dart     # Lista de descargas
├── services/
│   ├── api_service.dart          # Comunicación con el servidor
│   └── download_manager.dart     # Gestión de estado de descargas
├── widgets/
│   └── connection_indicator.dart # Indicador de conexión
└── theme/
    ├── app_theme.dart            # Configuración de tema
    └── app_colors.dart           # Paleta de colores
```

## ⚙️ Configuración

### Servidor Backend

El servidor Flask debe estar ejecutándose en `servidordario.ddns.net:5000` con los siguientes endpoints:

- `POST /download`: Iniciar descarga
- `GET /progress`: Stream SSE de progreso
- `GET /serve_video/<filename>`: Descargar archivo

### Permisos de Android

La aplicación requiere los siguientes permisos (ya configurados en `android/app/src/main/AndroidManifest.xml`):

```xml
<uses-permission android:name="android.permission.INTERNET" />
<uses-permission android:name="android.permission.WRITE_EXTERNAL_STORAGE" android:maxSdkVersion="28" />
<uses-permission android:name="android.permission.READ_EXTERNAL_STORAGE" android:maxSdkVersion="32" />
<uses-permission android:name="android.permission.MANAGE_EXTERNAL_STORAGE" />
<uses-permission android:name="android.permission.READ_MEDIA_VIDEO" />
<uses-permission android:name="android.permission.READ_MEDIA_AUDIO" />
```

## 🔧 Instalación y Uso

### 1. Clonar e Instalar Dependencias

```bash
cd /home/dario/projects/TubeTap
flutter pub get
```

### 2. Ejecutar la Aplicación

```bash
flutter run
```

### 3. Uso de la Aplicación

1. **Abrir TubeTap**: La pantalla principal muestra el logo y un botón "Enlace Único"
2. **Introducir URL**: Pegar la URL de YouTube en el campo de texto
3. **Seleccionar Formato**: Elegir entre video (MP4) o audio (MP3)
4. **Seleccionar Calidad**: Elegir la resolución/calidad deseada
5. **Monitorear Progreso**: Ver el progreso en la pantalla de descargas
6. **Acceder a Archivos**: Los archivos se guardan automáticamente en la carpeta de descargas

## 📱 Estructura de Carpetas de Descarga

```
/storage/emulated/0/Download/TubeTap/
├── video/          # Videos descargados (.mp4)
└── audio/          # Audio descargado (.mp3)
```

## 🔄 Flujo de Descarga

1. **Inicio**: Usuario introduce URL y selecciona formato/calidad
2. **Solicitud**: La app envía `POST /download` al servidor
3. **Progreso**: El servidor envía actualizaciones via SSE a `/progress`
4. **Descarga**: Una vez completado, la app descarga el archivo via `/serve_video/<filename>`
5. **Almacenamiento**: El archivo se guarda en la carpeta correspondiente del dispositivo
6. **Limpieza**: El archivo temporal se elimina del servidor

## 🛠️ Dependencias Principales

```yaml
dependencies:
  flutter: sdk
  provider: ^6.1.1 # Gestión de estado
  http: ^1.2.0 # Peticiones HTTP
  dio: ^5.4.0 # Cliente HTTP avanzado
  path_provider: ^2.1.2 # Rutas del sistema
  permission_handler: ^11.3.0 # Permisos de Android
```

## 🐛 Solución de Problemas

### Error de Permisos

- Asegúrate de que los permisos estén correctamente configurados en `AndroidManifest.xml`
- En Android 11+, puede ser necesario habilitar manualmente el permiso "Administrar todos los archivos"

### Error de Conexión

- Verifica que el servidor esté ejecutándose en `servidordario.ddns.net:5000`
- Comprueba la conectividad de red

### Descarga Fallida

- Usa el botón "Reintentar" en la pantalla de descargas
- Verifica que la URL de YouTube sea válida y accesible

## 📝 Notas de Desarrollo

- La aplicación usa Provider para gestión de estado reactiva
- Las descargas se manejan mediante streaming de archivos para evitar problemas de memoria
- El sistema de permisos está optimizado para diferentes versiones de Android
- La UI incluye indicadores de progreso y estados de error descriptivos

## 🔮 Futuras Mejoras

- Soporte para más plataformas de video
- Descarga de listas de reproducción
- Configuración de calidad por defecto
- Modo oscuro/claro manual
- Historial de descargas persistente
