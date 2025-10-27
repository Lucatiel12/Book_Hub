import com.android.build.api.dsl.ManagedVirtualDevice
import com.android.build.gradle.BaseExtension
import com.android.build.gradle.internal.dsl.BaseAppModuleExtension
import org.gradle.api.JavaVersion
import java.io.FileInputStream
import java.util.Properties

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

    // --- ✅ ADD: release signing (reads android/key.properties) ---
    signingConfigs {
        create("release") {
            val props = Properties()
            val propsFile = rootProject.file("key.properties")
            if (propsFile.exists()) {
                props.load(FileInputStream(propsFile))
                val storePath = props.getProperty("storeFile") ?: ""
                if (storePath.isNotEmpty()) {
                    storeFile = file(storePath)
                }
                storePassword = props.getProperty("storePassword")
                keyAlias = props.getProperty("keyAlias")
                keyPassword = props.getProperty("keyPassword")
            }
        }
    }

    // --- ✅ ADD: release buildType using that signing config ---
    buildTypes {
        getByName("release") {
            signingConfig = signingConfigs.getByName("release")

            // Start simple; enable these later once stable
            isMinifyEnabled = false
            isShrinkResources = false

            // If you enable minify later, keep proguard files:
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        getByName("debug") {
            // debug config (unchanged)
        }
    }

    // It enables support for modern Java language features.
    // (You already had this; keeping as-is.)
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
    // Core library desugaring required by flutter_local_notifications.
    coreLibraryDesugaring("com.android.tools:desugar_jdk_libs:1.2.2")
}

flutter {
    source = "../.."
}
