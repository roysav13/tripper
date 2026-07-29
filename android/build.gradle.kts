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

// Some pub plugins (file_picker 8.x) still pin compileSdk 34, while others
// (flutter_plugin_android_lifecycle) require 36. Force every plugin module
// to compile against 36 — build-time only, device compatibility unchanged.
fun overrideCompileSdk(project: Project) {
    (project.extensions.findByName("android") as? com.android.build.gradle.BaseExtension)
        ?.compileSdkVersion(37)
}

subprojects {
    if (state.executed) {
        overrideCompileSdk(this)
    } else {
        afterEvaluate { overrideCompileSdk(this) }
    }
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
