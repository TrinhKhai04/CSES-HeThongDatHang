// ✅ KHỐI BUILD SCRIPT (phải nằm ở đầu file)
buildscript {
    repositories {
        google()
        mavenCentral()
    }
    dependencies {
        classpath("com.android.tools.build:gradle:8.1.1")
        classpath("com.google.gms:google-services:4.4.4")
    }
}

// ✅ Repositories cho toàn bộ project
allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// ✅ Đặt lại đường dẫn build output
val newBuildDir = rootProject.layout.buildDirectory
    .dir("../../build")
    .get()
rootProject.layout.buildDirectory.set(newBuildDir)

subprojects {
    val newSubprojectBuildDir = newBuildDir.dir(project.name)
    project.layout.buildDirectory.set(newSubprojectBuildDir)
}

subprojects {
    project.evaluationDependsOn(":app")
}

// ✅ Task clean
tasks.register<Delete>("clean") {
    delete(rootProject.layout.buildDirectory)
}
