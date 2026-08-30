allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// flutter_native_splash pins its own AGP classpath (8.7.0), which drifts
// from the version the app itself builds with. Declaring the app's AGP on
// every subproject's buildscript makes Gradle's conflict resolution pick
// the highest version everywhere, keeping one consistent, already-cached
// toolchain.
subprojects {
    buildscript {
        repositories {
            google()
            mavenCentral()
        }
        dependencies {
            classpath("com.android.tools.build:gradle:8.11.1")
        }
    }
}

// The integration_test module declares androidx.test artifacts with dynamic
// version selectors (e.g. runner:1.2+). Google Maven no longer serves the
// maven-metadata.xml listings those selectors rely on in this environment,
// so resolution fails. Pinning concrete, mutually-compatible versions from
// the AndroidX Test 1.6.2 suite lets Gradle fetch the exact POMs/JARs
// directly instead of consulting the unavailable metadata.
subprojects {
    configurations.all {
        resolutionStrategy {
            force("androidx.test:runner:1.6.2")
            force("androidx.test:rules:1.6.0")
            force("androidx.test:monitor:1.6.0")
            force("androidx.test.espresso:espresso-core:3.6.1")
        }
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

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
