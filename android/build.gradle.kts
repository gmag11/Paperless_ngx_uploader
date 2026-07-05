allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

val newBuildDir: Directory =
    rootProject.layout.buildDirectory
        .dir("../../build")
        .get()
rootProject.layout.buildDirectory.value(newBuildDir)

subprojects {
    val newSubprojectBuildDir: Directory = newBuildDir.dir(project.name)
    project.layout.buildDirectory.value(newSubprojectBuildDir)
}
subprojects {
    project.evaluationDependsOn(":app")
}

// Force a consistent JVM target across all Flutter plugin subprojects.
// plugins.withId is lazy and safe to use even after a project is evaluated,
// unlike afterEvaluate which fails when evaluationDependsOn has already run.
subprojects {
    plugins.withId("com.android.library") {
        extensions.configure<com.android.build.gradle.LibraryExtension> {
            compileOptions {
                sourceCompatibility = JavaVersion.VERSION_11
                targetCompatibility = JavaVersion.VERSION_11
            }
        }
    }
    plugins.withId("org.jetbrains.kotlin.android") {
        extensions.configure<org.jetbrains.kotlin.gradle.dsl.KotlinAndroidProjectExtension> {
            compilerOptions {
                jvmTarget.set(org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_11)
            }
        }
    }
}

// --- Reproducible builds for native CMake-based Flutter plugins ---
// Add every Flutter plugin that compiles native .so files via CMake here.
// Run the discovery steps in the fdroid-reproducible-build skill after adding/updating dependencies.
val nativeLibraryModules = setOf(
    "jni"
)
subprojects {
    plugins.withId("com.android.library") {
        if (name in nativeLibraryModules) {
            extensions.configure<com.android.build.gradle.LibraryExtension>("android") {
                defaultConfig {
                    externalNativeBuild {
                        cmake {
                            // Remove build-id so ELF .so files are byte-identical across machines
                            arguments += "-DCMAKE_SHARED_LINKER_FLAGS=-Wl,--build-id=none"
                            // Normalize absolute source paths so embedded debug paths match on any builder
                            cFlags += "-ffile-prefix-map=${project.projectDir.absolutePath}=."
                            cppFlags += "-ffile-prefix-map=${project.projectDir.absolutePath}=."
                        }
                    }
                }
            }
        }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
