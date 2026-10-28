# 출시 빌드 코드 축소(R8) 규칙.

# 광고 SDK(google_mobile_ads → play-services-ads)가 쓰는 WorkManager는 Room이 만든
# WorkDatabase_Impl을 리플렉션으로 생성한다. R8이 이 클래스를 지우면 앱 시작 때
# "Failed to create an instance of androidx.work.impl.WorkDatabase"로 바로 죽는다.
-keep class * extends androidx.room.RoomDatabase { <init>(); }
-keep class androidx.work.impl.WorkDatabase_Impl { *; }
