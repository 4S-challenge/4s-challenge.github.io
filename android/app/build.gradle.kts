import java.util.Base64

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.ohsang.fourschallenge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어에 한 번 올리면 바꿀 수 없다. iOS 번들 ID와 같게 맞춘다.
        applicationId = "com.ohsang.fourschallenge"
        // You can update the following values to match your application needs.
        // For more information, see: https://flutter.dev/to/review-gradle-config.
        minSdk = flutter.minSdkVersion
        targetSdk = flutter.targetSdkVersion
        // Uses the version code from pubspec.yaml. When using split APKs, 1000 * ABI_VERSION
        // is added automatically by Flutter. (https://developer.android.com/studio/build/configure-apk-splits#configure-APK-versions)
        // You can force using the value of versionCode by specifying the `-P force-version-code-ignoring-abi=true`
        // flag during build.
        versionCode = flutter.versionCode
        versionName = flutter.versionName
    }

    buildTypes {
        release {
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
}

kotlin {
    compilerOptions {
        jvmTarget = org.jetbrains.kotlin.gradle.dsl.JvmTarget.JVM_17
    }
}

flutter {
    source = "../.."
}

// 서버 주소(API_BASE_URL) 없이 릴리스 앱을 만들면 랭킹·대결이 없는 오프라인 앱이 된다.
// flutter build appbundle --dart-define-from-file=config/prod.json 처럼 주소를 넘기지 않으면 빌드를 멈춘다.
gradle.taskGraph.whenReady {
    val releaseBuild = allTasks.any { it.project == project && it.name.contains("Release") }
    if (!releaseBuild) return@whenReady
    val defines = (project.findProperty("dart-defines") as String?)
        ?.split(",")
        ?.filter { it.isNotBlank() }
        ?.map { String(Base64.getDecoder().decode(it)) }
        .orEmpty()
    val url = defines.firstOrNull { it.startsWith("API_BASE_URL=") }?.substringAfter("=")
    if (url.isNullOrBlank()) {
        throw GradleException(
            "API_BASE_URL이 없습니다. --dart-define-from-file=config/prod.json 을 붙여 빌드하세요."
        )
    }
}
