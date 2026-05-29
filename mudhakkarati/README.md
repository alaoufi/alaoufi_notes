# مذكراتي — تطبيق ملاحظات Android يعمل دون إنترنت

تطبيق مذكرات وملاحظات احترافي مبني بـ **Flutter**، يعمل **بالكامل بدون إنترنت**، ويخزّن
كل البيانات داخل الجهاز فقط باستخدام **SQLite**. واجهة عربية **RTL**، بدون تسجيل دخول،
وبدون أي خادم أو تخزين سحابي إجباري.

> هذا مشروع مستقل تمامًا عن مشروع الويب الموجود في جذر المستودع. يقع كامل تطبيق
> الأندرويد داخل مجلد `mudhakkarati/`.

---

## ✨ الميزات

- **الرئيسية:** بطاقات ملوّنة، عرض شبكة/قائمة، بحث سريع، تصنيفات أعلى الصفحة،
  الملاحظات المثبّتة أولاً، زر إضافة ثابت.
- **أنواع الملاحظات:** نصية، قائمة مهام (Checklist)، صورة، صوتية، PDF، ورسم/كتابة يدوية.
- **إجراءات الملاحظة:** حفظ تلقائي أثناء الكتابة، تلوين، تثبيت، نسخ، تكرار، مشاركة،
  أرشفة، قفل، حذف مع **سلة محذوفات** واستعادة.
- **التصنيفات والوسوم:** تصنيفات افتراضية (شخصي/عمل/مهم/مواعيد/أفكار) قابلة للتعديل،
  وسوم (Tags)، وفلترة حسب التصنيف أو الوسم.
- **التذكيرات:** تذكير لأي ملاحظة، تكرار يومي/أسبوعي/شهري/سنوي، إشعارات محلية،
  وصفحة مستقلة للتذكيرات.
- **التقويم:** عرض الملاحظات والتذكيرات حسب التاريخ، ودعم **الميلادي والهجري**.
- **الرسم:** ألوان وأقلام بأحجام مختلفة، تراجع/مسح، وحفظ الرسم مع الملاحظة.
- **الويدجت:** ويدجت يعرض الملاحظة المثبّتة/الأخيرة على الشاشة الرئيسية.
- **الحماية:** قفل التطبيق برقم سري، دعم البصمة، وقفل ملاحظات معيّنة.
- **النسخ الاحتياطي:** تصدير/استيراد نسخة محلية **مشفّرة (AES-256)**.
- **الإعدادات:** وضع ليلي/نهاري، لون السمة، حجم الخط، طريقة العرض، اللغة (عربي/إنجليزي)،
  إدارة التصنيفات وسلة المحذوفات والأرشيف.

---

## 🛠️ المتطلبات

- [Flutter SDK](https://docs.flutter.dev/get-started/install) إصدار **3.22 أو أحدث**.
- Android SDK (يأتي مع Android Studio).
- جهاز/محاكي **Android 8.0 (API 26)** فما فوق.

---

## 🚀 بناء التطبيق وإنشاء APK

### الطريقة (أ) — البناء المباشر (الأسرع)

من داخل مجلد `mudhakkarati/`:

```bash
flutter pub get
flutter run                       # للتجربة على جهاز موصول
flutter build apk --release        # إنشاء APK جاهز للتثبيت
```

سيظهر ملف الـ APK في:
```
mudhakkarati/build/app/outputs/flutter-apk/app-release.apk
```
انسخه إلى جوالك وثبّته (فعّل «تثبيت من مصادر غير معروفة»).

لإنشاء نسخ أصغر لكل معمارية: `flutter build apk --release --split-per-abi`

### الطريقة (ب) — الأكثر متانة (إن واجهت أخطاء Gradle/AGP بسبب اختلاف إصدار Flutter)

مجلد `android/` هنا مُعدّ ومثبّت على إصدارات Gradle/AGP معيّنة. إن كان إصدار Flutter
لديك أحدث وظهرت أخطاء بناء، أنشئ مشروعًا جديدًا (يولّد إعدادات Gradle المتوافقة مع
نسختك) وانسخ إليه كود التطبيق:

```bash
# 1) أنشئ مشروعًا جديدًا
flutter create -e --org com.mudhakkarati mudhakkarati_app
cd mudhakkarati_app

# 2) انسخ كود التطبيق والإعدادات من هذا المجلد فوق المشروع الجديد
cp -r ../mudhakkarati/lib .            # كل كود Dart
cp ../mudhakkarati/pubspec.yaml .      # الحزم

# 3) انسخ تخصيصات أندرويد (الأذونات، الويدجت، الأيقونة، MainActivity)
cp ../mudhakkarati/android/app/src/main/AndroidManifest.xml android/app/src/main/
cp -r ../mudhakkarati/android/app/src/main/res/* android/app/src/main/res/
cp ../mudhakkarati/android/app/src/main/kotlin/com/mudhakkarati/app/*.kt \
   android/app/src/main/kotlin/com/mudhakkarati/app/

# 4) في android/app/build.gradle فعّل تكسير الحلوى (desugaring):
#    compileOptions { coreLibraryDesugaringEnabled true }
#    minSdk = 26
#    dependencies { coreLibraryDesugaring "com.android.tools:desugar_jdk_libs:2.0.4" }

# 5) ابنِ
flutter pub get
flutter build apk --release
```

### فتح المشروع في Android Studio
افتح مجلد `mudhakkarati/` مباشرةً؛ يُنشأ `local.properties` تلقائيًا. ثم
**Run** أو **Build > Build APK(s)**.

---

## 🎨 تغيير الاسم والشعار والألوان

### 1) اسم التطبيق (الظاهر تحت الأيقونة)
- العربية/الافتراضي: `android/app/src/main/res/values/strings.xml` → القيمة `app_name`.
- أو مباشرةً في `android/app/src/main/AndroidManifest.xml` → السمة `android:label`.
- الاسم داخل الواجهة: `lib/core/l10n/app_strings.dart` → المفتاح `app_name`.

### 2) الشعار / الأيقونة
الأيقونة الحالية أيقونة متجهية (Adaptive Icon) لا تحتاج صورًا:
- لون الخلفية: `android/app/src/main/res/drawable/ic_launcher_background.xml`.
- الرسم الأمامي: `android/app/src/main/res/drawable/ic_launcher_foreground.xml`.

لاستخدام صورة PNG خاصة بك بدلاً منها، أسهل طريقة هي حزمة
[`flutter_launcher_icons`](https://pub.dev/packages/flutter_launcher_icons):
```bash
flutter pub add dev:flutter_launcher_icons
# ثم أضف إعداداتها وأشر إلى صورتك، ونفّذ:
flutter pub run flutter_launcher_icons
```

### 3) الألوان والهوية
- **ألوان السمة** (المتاحة في الإعدادات) واللون الافتراضي:
  `lib/core/theme/app_colors.dart` → `themeSeeds` و `defaultSeed`.
- **ألوان بطاقات الملاحظات** (نهاري/ليلي): نفس الملف → `noteColorsLight` و `noteColorsDark`.
- **شكل عام للثيم** (الزوايا، الحقول، إلخ): `lib/core/theme/app_theme.dart`.

### 4) معرّف الحزمة (Application ID)
موجود في `android/app/build.gradle` (`applicationId`) و namespace، وفي مسار مجلد Kotlin
`android/app/src/main/kotlin/com/mudhakkarati/app/`. غيّره إن رغبت بمعرّف خاص.

---

## 💾 النسخ الاحتياطي والاستعادة

كل شيء **محلي ومشفّر** — لا يُرفع أي شيء للإنترنت.

**تصدير نسخة:**
1. الإعدادات ← النسخ الاحتياطي ← «تصدير نسخة احتياطية».
2. أدخل كلمة مرور (تُستخدم للتشفير — **احتفظ بها**، لا يمكن الاستعادة بدونها).
3. اختر مكان حفظ الملف (بامتداد `.mdkbak`) في ملفات جهازك.

**استعادة نسخة:**
1. الإعدادات ← النسخ الاحتياطي ← «استيراد نسخة احتياطية».
2. أكّد التحذير (سيتم استبدال البيانات الحالية).
3. اختر ملف `.mdkbak` وأدخل نفس كلمة المرور.

**النسخ إلى Google Drive (اختياري):** بعد التصدير، انسخ ملف `.mdkbak` يدويًا إلى Drive
أو أي مكان. التطبيق لا يحتاجها ويعمل تمامًا بدونها.

تفاصيل تقنية: النسخة عبارة عن أرشيف ZIP (قاعدة بيانات SQLite + كل المرفقات) مشفّر بـ
**AES-256-CBC** بمفتاح مُشتق من كلمة المرور (PBKDF2/SHA-256). انظر
`lib/services/backup_service.dart` و `lib/services/encryption_service.dart`.

---

## 📴 التأكد من العمل بدون إنترنت

التطبيق لا يحتوي على أي استدعاء شبكة:
- **لا** يوجد أي طلب HTTP، ولا حزمة شبكة في `pubspec.yaml`.
- التخزين كله محلي: SQLite (`lib/data/database`) + ملفات داخل تخزين التطبيق الخاص.
- الإشعارات **محلية** عبر `flutter_local_notifications`.
- الأذونات في `AndroidManifest.xml` لا تتضمن `INTERNET`.

**للتأكد بنفسك:** فعّل وضع الطيران ثم استخدم كل الميزات — ستعمل جميعها (الإنشاء،
البحث، التذكيرات، النسخ الاحتياطي، إلخ).

---

## 🗂️ بنية المشروع

```
mudhakkarati/
├── android/                 إعدادات أندرويد (Manifest، Gradle، الويدجت، الأيقونة)
└── lib/
    ├── main.dart            نقطة الدخول والتهيئة
    ├── app.dart             MaterialApp + RTL + الثيم + الترجمة
    ├── core/
    │   ├── theme/           الألوان والثيم
    │   └── l10n/            الترجمة (عربي/إنجليزي)
    ├── data/
    │   ├── models/          النماذج (Note، Category، Reminder، ...)
    │   ├── database/        إعداد SQLite والمخطط
    │   └── repositories/    عمليات قاعدة البيانات
    ├── services/            الإشعارات، التشفير، النسخ، الملفات، الحماية، الويدجت
    ├── features/            الشاشات (home، editor، reminders، calendar، ...)
    └── widgets/             مكوّنات مشتركة (بطاقة الملاحظة، منتقي الألوان، ...)
```

---

## 🔤 خط عربي أجمل (اختياري)

التطبيق يعمل بخط النظام افتراضيًا. لخط عربي أوضح:
1. نزّل خط [Cairo](https://fonts.google.com/specimen/Cairo) وضع الملفات في
   `assets/fonts/`.
2. ألغِ التعليق عن قسم `fonts:` في `pubspec.yaml`.
3. نفّذ `flutter pub get`.

---

## ⚠️ ملاحظات

- ملف الـ APK **موقّع بمفتاح debug** ليكون التثبيت فوريًا للاستخدام الشخصي. للنشر على
  Google Play لاحقًا، أنشئ keystore خاصًا وحدّث `signingConfig` في `android/app/build.gradle`.
- ويدجت الشاشة الرئيسية يعرض الملاحظة المثبّتة/الأخيرة؛ الضغط عليه يفتح التطبيق.
