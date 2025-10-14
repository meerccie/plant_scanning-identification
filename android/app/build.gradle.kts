plugins {
    id("com.android.application")
    id("kotlin-android")
    // The Flutter Gradle Plugin must be applied after the Android and Kotlin Gradle plugins.
    id("dev.flutter.flutter-gradle-plugin")
}

android {
    namespace = "com.example.my_plant_v2"
    compileSdk = 36
    ndkVersion = "27.0.12077973"
    
    compileOptions {
        sourceCompatibility = JavaVersion.VERSION_11
        targetCompatibility = JavaVersion.VERSION_11
    }
    
    kotlinOptions {
        jvmTarget = JavaVersion.VERSION_11.toString()
    }
    
    defaultConfig {
        applicationId = "com.example.my_plant_v2"
        
        // Explicit SDK versions for better permission handling
        minSdk = 21  // Minimum for modern features
        targetSdk = 34  // Stable target for permissions
        
        versionCode = 1
        versionName = "1.0.0"
        
        // Enable multidex support (helpful for larger apps)
        multiDexEnabled = true
        
        // Improve performance
        vectorDrawables {
            useSupportLibrary = true
        }
    }
    
    buildTypes {
        getByName("debug") {
            // Enable debugging
            isDebuggable = true
            isMinifyEnabled = false
        }
        
        getByName("release") {
            // Optimize for release
            isMinifyEnabled = true
            isShrinkResources = true
            proguardFiles(getDefaultProguardFile("proguard-android-optimize.txt"), "proguard-rules.pro")
            
            // TODO: Add your own signing config for the release build.
            // Signing with the debug keys for now, so `flutter run --release` works.
            signingConfig = signingConfigs.getByName("debug")
        }
    }
    
    // Packaging options to avoid conflicts
    packagingOptions {
        resources {
            excludes += setOf("/META-INF/{AL2.0,LGPL2.1}")
        }
    }
}

flutter {
    source = "../.."
}

dependencies {
    implementation("androidx.multidex:multidex:2.0.1")
}
