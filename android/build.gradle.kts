allprojects {
    repositories {
        google()
        mavenCentral()
    }
}

// إضافات قديمة (مثل iris_method_channel لـ Agora) تقرأ compileSdkVersion من هنا وإلا تستخدم 31،
// وAGP 9 يرفض ذلك لأن مكتبات androidx الحالية تتطلب 34 فأعلى. 36 = ما يستخدمه Flutter للتطبيق.
extra["compileSdkVersion"] = 36

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
