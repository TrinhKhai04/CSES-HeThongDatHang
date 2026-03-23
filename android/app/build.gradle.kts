plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    // ⚠️ Flutter plugin phải đặt SAU Android & Kotlin
    id("dev.flutter.flutter-gradle-plugin")
    // ✅ Firebase plugin
    id("com.google.gms.google-services")
}

android {
    namespace = "com.example.cses"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.cses"
        minSdk = maxOf(23, flutter.minSdkVersion)
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // ✅ Debug signing cho release (tạm thời)
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
