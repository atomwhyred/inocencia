import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// Firma de la release: android/key.properties (fuera de git) apunta al keystore propio.
// Se crea con tools/crear_keystore.sh. Sin él, la release se firma con la clave de
// depuración (solo para probar: tools/build_apks.sh se niega a publicar así).
val releaseKey = Properties().apply {
    val f = rootProject.file("key.properties")
    if (f.exists()) f.inputStream().use { load(it) }
}
val hasReleaseKey = listOf("storeFile", "storePassword", "keyAlias", "keyPassword")
    .all { !releaseKey.getProperty(it).isNullOrBlank() }

android {
    namespace = "com.inocencia.app"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
        // flutter_local_notifications usa java.time en Android < 26.
        isCoreLibraryDesugaringEnabled = true
    }

    defaultConfig {
        applicationId = "com.inocencia.app"
        // Android 10 (API 29) es el minimo exigido para inocencIA.
        minSdk = 29
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
        // Las ABI (arm64-v8a y armeabi-v7a; los telefonos de gama baja con
        // Android 10 suelen ser de 32 bits) se eligen al compilar:
        //   flutter build apk --release --split-per-abi --target-platform android-arm,android-arm64
    }

    packaging {
        // llama.cpp elige en tiempo de ejecucion la variante de CPU buscando
        // libggml-cpu-*.so en una carpeta del disco: las .so tienen que estar
        // extraidas en nativeLibraryDir, no mapeadas desde el APK.
        jniLibs.useLegacyPackaging = true
    }

    signingConfigs {
        if (hasReleaseKey) {
            create("release") {
                storeFile = rootProject.file(releaseKey.getProperty("storeFile"))
                storePassword = releaseKey.getProperty("storePassword")
                keyAlias = releaseKey.getProperty("keyAlias")
                keyPassword = releaseKey.getProperty("keyPassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName(if (hasReleaseKey) "release" else "debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

dependencies {
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

flutter {
    source = "../.."
}
