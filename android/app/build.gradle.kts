import java.io.FileInputStream
import java.util.Base64
import java.util.Properties

plugins {
    id("com.android.application")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

// 업로드 키 서명 정보. android/key.properties가 있으면 그 키로 릴리스 빌드에 서명한다 (README 참고).
// 없으면 디버그 키로 서명하는데, 이 빌드는 Play 스토어에 올릴 수 없다.
val keystoreProperties = Properties().apply {
    val file = rootProject.file("key.properties")
    if (file.exists()) FileInputStream(file).use { load(it) }
}

// flutter build ... --dart-define-from-file=config/prod.json 으로 넘긴 값들
val dartDefines: Map<String, String> = (project.findProperty("dart-defines") as String?)
    ?.split(",")
    ?.filter { it.isNotBlank() }
    ?.map { String(Base64.getDecoder().decode(it)) }
    ?.associate { it.substringBefore("=") to it.substringAfter("=", "") }
    .orEmpty()

// AdMob 앱 ID. config/prod.json의 ADMOB_ANDROID_APP_ID, 없으면 Google 테스트 앱 ID.
val admobAndroidAppId = dartDefines["ADMOB_ANDROID_APP_ID"]?.takeIf { it.isNotBlank() }
    ?: "ca-app-pub-3940256099942544~3347511713"

android {
    namespace = "com.ohsang.play.fourschallenge"
    compileSdk = flutter.compileSdkVersion
    ndkVersion = flutter.ndkVersion

    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_17
        targetCompatibility = JavaVersion.VERSION_17
    }

    defaultConfig {
        // 스토어에 한 번 올리면 바꿀 수 없다. iOS 번들 ID와 같게 맞춘다.
        applicationId = "com.ohsang.play.fourschallenge"
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
        manifestPlaceholders["admobAppId"] = admobAndroidAppId
    }

    signingConfigs {
        if (!keystoreProperties.isEmpty) {
            create("release") {
                keyAlias = keystoreProperties.getProperty("keyAlias")
                keyPassword = keystoreProperties.getProperty("keyPassword")
                storeFile = file(keystoreProperties.getProperty("storeFile"))
                storePassword = keystoreProperties.getProperty("storePassword")
            }
        }
    }

    buildTypes {
        release {
            signingConfig = if (keystoreProperties.isEmpty) {
                signingConfigs.getByName("debug")
            } else {
                signingConfigs.getByName("release")
            }
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
    val url = dartDefines["API_BASE_URL"]
    if (url.isNullOrBlank()) {
        throw GradleException(
            "API_BASE_URL이 없습니다. --dart-define-from-file=config/prod.json 을 붙여 빌드하세요."
        )
    }
}
