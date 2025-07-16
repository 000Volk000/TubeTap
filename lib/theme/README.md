# Paleta de Colores TubeTap

## Coral Red Palette

Esta aplicación utiliza una paleta de colores **Coral Red** como tema principal.

### Colores Disponibles

| Nivel   | Hex Code    | Color                                                    | Uso Recomendado        |
| ------- | ----------- | -------------------------------------------------------- | ---------------------- |
| 50      | #FFF1F1     | ![](https://via.placeholder.com/20/FFF1F1/000000?text=+) | Fondos muy suaves      |
| 100     | #FFDFE0     | ![](https://via.placeholder.com/20/FFDFE0/000000?text=+) | Fondos de contenedores |
| 200     | #FFC5C6     | ![](https://via.placeholder.com/20/FFC5C6/000000?text=+) | Bordes y divisores     |
| 300     | #FF9D9F     | ![](https://via.placeholder.com/20/FF9D9F/000000?text=+) | Elementos secundarios  |
| 400     | #FF6467     | ![](https://via.placeholder.com/20/FF6467/000000?text=+) | Acentos y highlights   |
| **500** | **#FF3B3F** | ![](https://via.placeholder.com/20/FF3B3F/000000?text=+) | **Color principal**    |
| 600     | #ED1519     | ![](https://via.placeholder.com/20/ED1519/000000?text=+) | Hover states           |
| 700     | #C80D11     | ![](https://via.placeholder.com/20/C80D11/000000?text=+) | Pressed states         |
| 800     | #A50F12     | ![](https://via.placeholder.com/20/A50F12/000000?text=+) | Texto secundario       |
| 900     | #881416     | ![](https://via.placeholder.com/20/881416/000000?text=+) | Texto enfatizado       |
| 950     | #4B0405     | ![](https://via.placeholder.com/20/4B0405/000000?text=+) | Texto principal        |

## Uso en Flutter

### Importar los colores

```dart
import 'package:tubetap/theme/app_colors.dart';
```

### Usar colores individuales

```dart
Container(
  color: AppColors.primary, // Color principal
  child: Text(
    'TubeTap',
    style: TextStyle(color: AppColors.textOnPrimary),
  ),
)
```

### Usar la paleta completa

```dart
Container(
  color: AppColors.coralRed100, // Fondo suave
  child: Text(
    'Contenido',
    style: TextStyle(color: AppColors.coralRed900),
  ),
)
```

## Aplicación del Tema

El tema se aplica automáticamente en toda la aplicación a través de:

1. **AppTheme.lightTheme** - Para modo claro
2. **AppTheme.darkTheme** - Para modo oscuro

Los colores se aplican a:

- AppBar
- Botones (ElevatedButton, FloatingActionButton)
- Campos de entrada (TextField, TextFormField)
- Cards y contenedores
- Indicadores de progreso
- Texto y tipografía

## Configuración Web (PWA)

Los colores también están configurados en `web/manifest.json`:

- **background_color**: #FF3B3F (coral-red-500)
- **theme_color**: #ED1519 (coral-red-600)

Esto asegura que la aplicación web tenga una apariencia consistente cuando se instale como PWA.
