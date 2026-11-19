plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.saludcuidado"

    // Se nombra la plataforma a mano en vez de usar
    // flutter.compileSdkVersion, que pide "android-37".
    //
    // El plugin de notificaciones exige compilar contra la API 37, pero
    // Google no publica ningun paquete llamado "android-37": en su
    // repositorio solo existen "android-37.0" y "android-37.1". Pedir la
    // 37 a secas falla con "Failed to find target with hash string
    // android-37" aunque la plataforma este instalada, porque el paquete
    // declara AndroidVersion.ApiLevel=37.0 y Gradle no lo reconoce como
    // el entero 37.
    //
    // Cuando Flutter y el SDK se pongan de acuerdo en el nombre, esto
    // puede volver a ser flutter.compileSdkVersion.
    compileSdkVersion("android-37.0")
    ndkVersion = flutter.ndkVersion

    compileOptions {
        // Lo exige flutter_local_notifications: los recordatorios usan
        // las clases de fecha y hora de Java 8, que en los Android mas
        // antiguos no existen. El "desugaring" las reescribe para que
        // funcionen tambien ahi, en lugar de subir el minSdk y dejar
        // fuera a los telefonos viejos.
        isCoreLibraryDesugaringEnabled = true
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // TODO: Specify your own unique Application ID (https://developer.android.com/studio/build/application-id.html).
        applicationId = "com.example.saludcuidado"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Libreria que acompana a isCoreLibraryDesugaringEnabled.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.1.5")
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}
