import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Apply final namespace/applicationId
    namespace = "net.gmartin.paperlessngx_uploader"
    compileSdk = 36
    ndkVersion = "27.0.12077973"

    // Load keystore properties if present
    val keystoreProperties = Properties().apply {
        // IMPORTANT: resolve relative to the :app module directory
        val keystoreFile = file("../key.properties")
        if (keystoreFile.exists()) {
            keystoreFile.inputStream().use { this.load(it) }
        }
    }


    compileOptions {
        // Update Java toolchain to 11
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            // Match Kotlin bytecode target with Java 11
            jvmTarget = "11"
        }
    }

    defaultConfig {
        applicationId = "net.gmartin.paperlessngx_uploader"
        // Ensure minSdk >= 29 per project spec
        minSdk = maxOf(29, flutter.minSdkVersion)
        targetSdk = 35
        versionCode = 20
        versionName = flutter.versionName
    }

    signingConfigs {
        create("release") {
            // Prefer environment variables for sensitive data; fallback to key.properties if provided
            val envStorePath = System.getenv("KEYSTORE_PATH")
            val envStorePassword = System.getenv("KEYSTORE_PASSWORD")
            val envKeyAlias = System.getenv("KEY_ALIAS")
            val envKeyPassword = System.getenv("KEY_PASSWORD")

            val resolvedStoreFile = when {
                !envStorePath.isNullOrBlank() -> file(envStorePath)
                !keystoreProperties.getProperty("storeFile").isNullOrBlank() -> file(keystoreProperties.getProperty("storeFile"))
                else -> null
            }
            if (resolvedStoreFile != null) {
                println("Current directory: ${projectDir.absolutePath}")
                println("Keystore path from env: $envStorePath")
                println("Resolved keystore path: ${resolvedStoreFile.absolutePath}")
                storeFile = resolvedStoreFile
            }

            storePassword = when {
                !envStorePassword.isNullOrBlank() -> envStorePassword
                !keystoreProperties.getProperty("storePassword").isNullOrBlank() -> keystoreProperties.getProperty("storePassword")
                else -> null
            }

            keyAlias = when {
                !envKeyAlias.isNullOrBlank() -> envKeyAlias
                !keystoreProperties.getProperty("keyAlias").isNullOrBlank() -> keystoreProperties.getProperty("keyAlias")
                else -> null
            }

            keyPassword = when {
                !envKeyPassword.isNullOrBlank() -> envKeyPassword
                !keystoreProperties.getProperty("keyPassword").isNullOrBlank() -> keystoreProperties.getProperty("keyPassword")
                else -> null
            }
        }
    }

    buildTypes {
        release {
            signingConfig = signingConfigs.getByName("release")
            isMinifyEnabled = true // Activar ofuscación y optimización
            isShrinkResources = true // Activar reducción de recursos
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }

    dependenciesInfo {
        // Disables dependency metadata when building APKs (for IzzyOnDroid/F-Droid)
        includeInApk = false
        // Disables dependency metadata when building Android App Bundles (for Google Play)
        includeInBundle = false
    }
}

flutter {
    source = "../.."
}
