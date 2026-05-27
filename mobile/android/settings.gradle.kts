pluginManagement {
    repositories {
        google()
        mavenCentral()
        gradlePluginPortal()
    }

    val flutterSdkPath = providers.gradleProperty("flutter.sdk")
        .orElse(
            providers.provider {
                val properties = java.util.Properties()
                val propertiesFile = file("local.properties")
                if (propertiesFile.exists()) {
                    propertiesFile.inputStream().use { properties.load(it) }
                }
                properties.getProperty("flutter.sdk")
                    ?: throw GradleException("Flutter SDK not found. Define location with flutter.sdk in local.properties.")
            }
        ).get()

    includeBuild("$flutterSdkPath/packages/flutter_tools/gradle")
}

plugins {
    id("com.android.application") version "8.1.0" apply false
    id("org.jetbrains.kotlin.android") version "1.8.22" apply false
    id("dev.flutter.flutter-gradle-plugin") version "1.0.0" apply false
}

include(":app")