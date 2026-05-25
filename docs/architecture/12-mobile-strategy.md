# 12 — استراتيجية الموبايل

> **⚠️ مؤجّل بقرار من مالك المنتج.** هذا المستند يُسجّل القرارات المعماريّة فقط. **لا يُبدأ التنفيذ في أي شيء يخص الموبايل (Flutter / iOS / Android / Huawei)** حتى يكتمل الموقع ويُختبَر بالكامل ويُعطي مالك المنتج إشارة صريحة لبدء المرحلة 11.

## القرارات المعماريّة (مُقفَلة)

| الموضوع | القرار | المبرّر |
|---|---|---|
| الإطار | Flutter (Dart 3+) | قاعدة كود واحدة لـ iOS وAndroid وHuawei، دعم RTL ممتاز |
| الـ State Management | Riverpod | بسيط، قابل للاختبار، يدعم async |
| المعمارية | Clean Architecture: presentation / domain / data | يمنع التداخل بين طبقات UI و business logic و data |
| التوجيه | go_router | يدعم deep links وnested routes |
| الـ HTTP | dio + retrofit (مُولَّد من OpenAPI) | مُولَّد، إعادة محاولة مدمجة، interceptors |
| Realtime | supabase_flutter | نفس عقد القنوات في الويب |
| الخرائط | google_maps_flutter (iOS/Android) + huawei_map (HMS) | parity نظيف لكل متجر |
| الإشعارات | firebase_messaging (iOS/Android) + huawei_push (HMS) | أصلي لكل متجر |
| التخزين الآمن | flutter_secure_storage | Keychain / EncryptedSharedPreferences / HMS Vault |
| الترجمة | flutter_localizations + ARB | نفس مفاتيح الويب |
| الـ DI | Riverpod (لا حاجة لـ get_it) | تقليل التبعيات |
| الاختبار | flutter_test + integration_test + golden_toolkit | unit + widget + integration + screenshot |

## بنية المشروع (تُنشأ في المرحلة 11)

```
apps/mobile/
├── lib/
│   ├── app/                   # MaterialApp، routing، theming
│   ├── core/                  # ثوابت، أخطاء، شبكة، تخزين، utilities
│   ├── data/                  # repositories، dtos، عميل API مُولَّد
│   ├── domain/                # كيانات، use cases، failures
│   ├── features/              # وحدات ميزات تطابق الويب
│   │   ├── auth/
│   │   ├── home/
│   │   ├── orders/
│   │   ├── chat/
│   │   ├── tracking/
│   │   ├── ratings/
│   │   └── profile/
│   ├── l10n/                  # ar.arb, ur.arb, en.arb, hi.arb, bn.arb
│   ├── theme/                 # soft_blue.dart, pink.dart, tokens.dart
│   └── main.dart
├── android/
├── ios/
├── huawei/                    # إعدادات HMS + agconnect-services.json
├── test/
├── integration_test/
└── pubspec.yaml
```

## التطبيقات

ثلاثة تطبيقات مستقلّة (build flavors) من نفس قاعدة الكود:

| Flavor | المتجر | بنية إضافية |
|---|---|---|
| `gms` | Google Play (Android) + App Store (iOS) | FCM + Google Maps |
| `hms` | Huawei AppGallery (Android) | HMS Push + Huawei Map |

التبديل عبر:
- `flutter build appbundle --flavor gms`
- `flutter build appbundle --flavor hms`
- `flutter build ipa` (iOS)

## الأذونات

| الإذن | الاستخدام | تبرير في المتجر |
|---|---|---|
| Location (Foreground) | عرض الخريطة، اختيار الموقع، البحث القريب | "لتحديد موقعك وعرض المزوّدين الأقرب" |
| Location (Background) | تتبّع المزوّد أثناء طلب نشط فقط | "لمشاركة موقعك مع طالب الخدمة أثناء التوجّه إليه" — مع تحذير مرئي مستمرّ |
| Notifications | إشعارات الدردشة والطلبات | "ليصلك إشعار عند رسائل جديدة أو تغيير حالة الطلب" |
| Camera | التقاط صور للطلب أو الدردشة | "لإرفاق صور بطلبك أو محادثتك" |
| Photos | اختيار صور موجودة | نفس السبب |
| Microphone | تسجيل رسائل صوتية | "لإرسال رسائل صوتية في الدردشة" |
| Phone (call) | اتصال مباشر بالمزوّد (اختياري) | "لإجراء مكالمة سريعة عند الحاجة" |

## ميزانيات الأداء (مُلزِمة)

| المقياس | الهدف |
|---|---|
| البدء البارد (cold start) | < 2.5 ثانية على Pixel 5 / iPhone 11 |
| البدء الدافئ | < 1 ثانية |
| ذاكرة وقت التشغيل (في الخمول) | < 150 MB |
| FPS أثناء تمرير الدردشة | 60 FPS متواصل |
| حجم APK/AAB | < 30 MB compressed |
| استهلاك بطارية أثناء تتبّع نشط (ساعة) | < 8% |

## الاختبار

- Unit tests للـ use cases و repositories (تغطية ≥ 70%).
- Widget tests لكل screen (تغطية الشاشات الرئيسية).
- Integration tests للسيناريوهات الذهبية (Auth → Browse → Order → Chat → Complete → Rate).
- Golden tests لكل عنصر أساسي في الثيمين × الاتجاهين.
- اختبار يدوي على أجهزة فعلية: iPhone (موديل قديم + جديد)، Pixel، Samsung متوسط، Huawei.

## الإصدارات

- Versioning: SemVer (1.2.3) + buildNumber متزايد.
- Release channel: Internal → Closed Beta → Open Beta → Production.
- Fastlane لأتمتة التقديم.

## ما الذي يجب أن يكون جاهزاً قبل بدء المرحلة 11 (شروط الإشارة)

- [x] الموقع كامل ومُختبَر في كل المراحل من 2 إلى 10.
- [x] عقد API (OpenAPI) مستقرّ.
- [x] اختبار اختراق أمني للموقع منتهٍ بنتائج خضراء.
- [x] حسابات مطوّر معتمدة: Apple Developer Program، Google Play Console، Huawei AppGallery.
- [x] شهادات التوقيع جاهزة.
- [x] سياسة الخصوصية وشروط الاستخدام منشورة بكل اللغات.
- [x] تصميم نسخة الموبايل من المصمم (مرحلة 2 الموسّعة).
- [x] **إشارة صريحة من مالك المنتج لبدء التنفيذ.**

> حتى تتحقّق هذه الشروط، يبقى مجلد `apps/mobile/` غير موجود في المستودع.
