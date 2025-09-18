import com.android.build.api.dsl.ManagedVirtualDevice
import com.android.build.gradle.BaseExtension
import com.android.build.gradle.internal.dsl.BaseAppModuleExtension
import org.gradle.api.JavaVersion

// Top-level build file where you can add configuration options common to all sub-projects/modules.

plugins {
    id("com.android.application")
    id("org.jetbrains.kotlin.android")
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.book_hub"
    compileSdkVersion(flutter.compileSdkVersion)

    defaultConfig {
        // This is the correct application ID based on your AndroidManifest.xml and pubspec.yaml.
        applicationId = "com.example.book_hub"
        minSdkVersion(flutter.minSdkVersion)
        targetSdkVersion(flutter.targetSdkVersion)
        versionCode = flutter.versionCode.toInt()
        versionName = flutter.versionName
    }

    // This is the important part to fix the desugaring error.
    // It enables support for modern Java language features.
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
        // Enable desugaring for core libraries
        isCoreLibraryDesugaringEnabled = true
    }

    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_1_8.toString()
    }
}

dependencies {
    // This is the dependency for core library desugaring.
    // It's required by flutter_local_notifications.
    // The version has been updated to 1.2.2 to fix the build error.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}

flutter {
    source = "../.."
}
