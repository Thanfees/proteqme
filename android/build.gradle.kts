import com.android.build.gradle.LibraryExtension

allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// telephony 0.2.0 predates AGP 8 namespace requirement (discontinued package)
subprojects {
    afterEvaluate {
        if (name != "telephony") return@afterEvaluate
        extensions.findByType<LibraryExtension>()?.apply {
            if (namespace.isNullOrEmpty()) {
                namespace = "com.shounakmulay.telephony"
            }
            compileSdk = 34
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
