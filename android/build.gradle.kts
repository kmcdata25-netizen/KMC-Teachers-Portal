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

    fun applyCompileSdk(proj: Project) {
        val androidExt = proj.extensions.findByName("android") ?: return
        try {
            val method = androidExt.javaClass.getMethod("compileSdkVersion", Int::class.javaPrimitiveType)
            method.invoke(androidExt, 36)
        } catch (_: Exception) {
            try {
                val method = androidExt.javaClass.getMethod("setCompileSdkVersion", String::class.java)
                method.invoke(androidExt, "android-36")
            } catch (_: Exception) {}
        }
    }

    if (project.name != "app") {
        if (project.state.executed) {
            applyCompileSdk(project)
        } else {
            afterEvaluate {
                applyCompileSdk(project)
            }
        }
    }
}
subprojects {
    project.evaluationDependsOn(":app")
}

tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
