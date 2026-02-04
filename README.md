# Organic Maps Flutter Plugin

Plugin Flutter para integrar Organic Maps en aplicaciones móviles.

## Requisitos

- Flutter SDK (3.10.4+)
- Android NDK 28.2.13676358
- CMake 3.22.1+
- Al menos 20GB de espacio libre
- Librería C++ CoMaps

## Instalación para desarrolladores del plugin

### 1. Clonar el repositorio

```bash
git clone https://codeberg.org/tu-usuario/organic_maps_flutter.git
cd organic_maps_flutter
```

### 2. Ejecutar bootstrap

Este script descargará automáticamente la librería C++ CoMaps con todos sus submódulos:

```bash
chmod +x bootstrap.sh
./bootstrap.sh
```

**Nota:** Descargará ~3-5GB y puede tardar 10-20 minutos.

## Uso en tu aplicación Flutter

### Opción 1: Desde Git (Recomendado)

En tu `pubspec.yaml`:

```yaml
dependencies:
  organic_maps_flutter:
    git:
      url: https://codeberg.org/tu-usuario/organic_maps_flutter.git
      ref: main
```

Luego ejecuta el bootstrap de tu app que descargará este plugin automáticamente.

### Opción 2: Path local (Desarrollo)

```yaml
dependencies:
  organic_maps_flutter:
    path: ../organic_maps_flutter
```

## Estructura del proyecto

```
~/PROYECTOS/
├── organic_maps_flutter/     (este repositorio)
│   ├── android/
│   │   └── build.gradle      (referencia a ../../CMakeLists.txt)
│   ├── ios/
│   ├── lib/
│   └── bootstrap.sh
│
└── comaps/                   (descargado por bootstrap.sh)
    ├── CMakeLists.txt        (usado por el plugin)
    ├── 3party/               (submódulos)
    ├── libs/
    └── configure.sh
```

## Desarrollo

### Compilar para Android

```bash
cd example
flutter build apk --debug
```

### Compilar para iOS

```bash
cd example
flutter build ios --debug
```

### Limpiar build

```bash
flutter clean
cd android
./gradlew clean
```

## Configuración de Android

El plugin compila las librerías C++ nativas de CoMaps. La configuración está en `android/build.gradle`:

```gradle
externalNativeBuild {
    cmake {
        version = '3.22.1+'
        path '../../CMakeLists.txt'  // Apunta a comaps/CMakeLists.txt
    }
}
```

## Troubleshooting

### Error: "CMake Error: add_subdirectory given source which is not an existing directory"

Los submódulos de CoMaps no están inicializados. Ejecuta:

```bash
./bootstrap.sh
```

O manualmente:

```bash
cd ../comaps
git submodule update --init --recursive --depth 1
```

### Error: "ANDROID_HOME not set"

```bash
# Linux
export ANDROID_HOME=$HOME/Android/Sdk

# macOS  
export ANDROID_HOME=$HOME/Library/Android/Sdk
```

### Compilación muy lenta

Opciones para acelerar:

```bash
# Compilar solo para una arquitectura
flutter build apk --target-platform android-arm64

# Usar precompiled headers (en gradle.properties)
pch=true
```

## Arquitectura


El plugin actúa como puente entre Flutter y las librerías C++ de CoMaps:

```
Flutter App (Dart)
    ↓
organic_maps_flutter (Plugin)
    ↓ Platform Channel
Android/iOS Native Code
    ↓ JNI/FFI
CoMaps C++ Libraries
```
### Construir SDK 
# Desde el directorio del plugin
cd plugins/organic_maps_flutter/android

# Construir el SDK
./gradlew :sdk:assembleDebug

# O para release
./gradlew :sdk:assembleRelease


## Más información

- [Documentación de CoMaps](../comaps/docs/INSTALL.md)
- [Guía de Android](../comaps/docs/INSTALL.md#android-app)
- [Guía de iOS](../comaps/docs/INSTALL.md#ios-app)
