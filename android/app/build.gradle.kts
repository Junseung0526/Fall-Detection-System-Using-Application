import org.gradle.api.JavaVersion

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.iot"
    compileSdk = flutter.compileSdkVersion
    // ndkVersion이 두 번 선언되어 있는데, 하나로 통일하세요
    ndkVersion = "27.0.12077973"

    compileOptions {
        // Kotlin DSL에서는 '=' 꼭 써야 함
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
        isCoreLibraryDesugaringEnabled = true  // camelCase에 is 꼭 붙임
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }

    defaultConfig {
        applicationId = "com.example.iot"
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

dependencies {
    // Kotlin DSL에서는 작은따옴표가 아닌 큰따옴표 사용
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:2.0.3")

    // 여기에 다른 dependencies도 추가하세요
    // 예시: implementation("com.google.firebase:firebase-core:...")

}

flutter {
    source = "../.."
}
