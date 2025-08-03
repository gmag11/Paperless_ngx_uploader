import java.util.Properties

plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    // Apply final namespace/applicationId
    namespace = "net.gmartin.paperlessngx_share"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = "27.0.12077973"

    // Load keystore properties if present
    val keystoreProperties = Properties().apply {
        val keystoreFile = rootProject.file("android/key.properties")
        if (keystoreFile.exists()) {
            keystoreFile.inputStream().use { this.load(it) }
        }
    }

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_1_8
        targetCompatibility = JavaVersion.VERSION_1_8
    }

    kotlinOptions {
        jvmTarget = "1.8"
    }

    tasks.withType<org.jetbrains.kotlin.gradle.tasks.KotlinCompile>().configureEach {
        kotlinOptions {
            jvmTarget = "1.8"
        }
    }

    defaultConfig {
        applicationId = "net.gmartin.paperlessngx_share"
        // Ensure minSdk >= 29 per project spec
        minSdk = maxOf(29, flutter.minSdkVersion)
        targetSdk = flutter.targetSdkVersion
        versionCode = flutter.versionCode
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
            isMinifyEnabled = false
            isShrinkResources = false
            proguardFiles(
                getDefaultProguardFile("proguard-android-optimize.txt"),
                "proguard-rules.pro"
            )
        }
        debug {
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

flutter {
    source = "../.."
}
