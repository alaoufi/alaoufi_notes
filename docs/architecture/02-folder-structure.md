# 02 — بنية المجلدات

صيانة تُبنى كـ **monorepo** يُدار بـ pnpm workspaces. الويب والموبايل والأنواع المشتركة والبنية التحتية كلها تحت جذر واحد لكي تبقى العقود متزامنة.

> هذا المستند يحدّد البنية المُخطَّط لها. المجلدات تُنشأ تدريجياً — كل واحد عند بدء مرحلته. المرحلة 1 تُبقي المستودع متعمَّداً على `docs/` بالإضافة لهذه الخطّة فقط.

## التخطيط على المستوى الأعلى

```
syanah/
├── apps/
│   ├── web/                  # Next.js 15 (ويب + إدارة)
│   └── mobile/               # Flutter (iOS / Android / Huawei) — المرحلة 11
│
├── packages/
│   ├── shared/               # أنواع TS مشتركة (أنواع DB، عقود API، enums)
│   ├── ui/                   # مكوّنات React قابلة لإعادة الاستخدام ورموز التصميم (المرحلة 2)
│   ├── i18n/                 # رسائل الترجمة والمساعدات
│   ├── config/               # ESLint، Prettier، tsconfig، Tailwind preset
│   └── sdk/                  # عميل API مُولَّد (المرحلة 4+)
│
├── supabase/
│   ├── migrations/           # ترحيلات SQL مُؤرشفة
│   ├── seed.sql              # بيانات تطوير محلية
│   ├── functions/            # Edge Functions (Deno)
│   └── config.toml           # إعدادات مشروع Supabase
│
├── infra/
│   ├── github-actions/       # سير عمل CI (مرجعة من .github/workflows)
│   └── runbooks/             # كتيّبات تشغيل (حوادث، نشر، rollback)
│
├── docs/
│   ├── PHASES.md
│   ├── PHASE-1-REVIEW.md
│   ├── PHASE-N-REVIEW.md     # يُنشأ عند كل بوابة مرحلة
│   └── architecture/         # المستندات التي تقرؤها
│
├── .github/workflows/
├── .gitignore
├── pnpm-workspace.yaml
├── package.json              # جذر workspace
├── turbo.json                # خط بناء (Turborepo)
└── README.md
```

## `apps/web/` (Next.js 15)

```
apps/web/
├── app/
│   ├── [locale]/             # كل المسارات مقيّدة بـ locale (next-intl)
│   │   ├── (marketing)/      # صفحات تسويقية عامة
│   │   ├── (auth)/           # تسجيل دخول، تسجيل، تحقّق
│   │   ├── (customer)/       # بوابة طالب الخدمة
│   │   ├── (provider)/       # بوابة المزوّد
│   │   ├── (admin)/          # بوابة الإدارة ومشرف القسم
│   │   └── layout.tsx        # layout الجذر الواعي للـ locale (dir=rtl|ltr)
│   ├── api/                  # Route handlers (webhooks وproxies داخلية فقط)
│   └── globals.css           # قاعدة Tailwind + متغيرات CSS للثيم
│
├── components/               # مكوّنات مركّبة خاصة بالتطبيق (مستوى صفحة)
├── features/                 # وحدات ميزات (طلبات، دردشة، تقييمات، ...)
│   └── <feature>/
│       ├── components/
│       ├── hooks/
│       ├── server/           # Server actions ومحمّلات البيانات
│       └── schema.ts         # zod schemas
│
├── lib/
│   ├── supabase/             # عملاء browser + server + service-role
│   ├── auth/                 # مساعدات الجلسة، حُرّاس الصلاحيات
│   ├── i18n/                 # إعداد طلب next-intl
│   ├── theme/                # مساعدات تبديل الثيم
│   └── utils/
│
├── messages/                 # JSON ترجمة لكل locale (ar, ur, en, hi, bn)
├── middleware.ts             # وسيط locale + auth
├── next.config.mjs
├── tailwind.config.ts
├── postcss.config.mjs
└── tsconfig.json
```

### لماذا `features/` بدلاً من تنظيم بالنوع؟

كل ميزة تملك مكوّناتها وhooks وserver actions وschemas الخاصة بها. هذا يُبقي نطاق التأثير صغيراً عند تعديل ميزة، ويجعل من الواضح أين تنظر. العناصر الأساسية بين الميزات تبقى في `packages/ui/` كي تظل قابلة لإعادة الاستخدام.

## `apps/mobile/` (Flutter — المرحلة 11)

```
apps/mobile/
├── lib/
│   ├── app/                  # MaterialApp، التوجيه، الثيم
│   ├── core/                 # ثوابت، أخطاء، شبكة، تخزين
│   ├── data/                 # مستودعات، dtos، عميل API
│   ├── domain/               # كيانات، use cases
│   ├── features/             # وحدات ميزات (تطابق أسماء ميزات الويب)
│   ├── l10n/                 # ملفات ARB لكل locale
│   └── main.dart
├── android/
├── ios/
├── huawei/                   # إعدادات خاصة بـ HMS
├── test/
└── pubspec.yaml
```

## `packages/shared/`

مصدر الحقيقة الواحد للأنواع المشتركة بين الويب والموبايل (عبر OpenAPI codegen) و Edge Functions.

```
packages/shared/
├── src/
│   ├── db.ts                 # مُولَّد من Supabase (`supabase gen types`)
│   ├── api/                  # أشكال طلب/استجابة API
│   ├── enums/                # حالة الطلب، الأدوار، حالات النزاع، ...
│   └── index.ts
└── package.json
```

## `packages/ui/` (المرحلة 2)

```
packages/ui/
├── src/
│   ├── tokens/               # رموز التصميم (TS) → تُصدَّر كـ CSS vars
│   │   ├── colors.ts
│   │   ├── spacing.ts
│   │   ├── typography.ts
│   │   ├── radii.ts
│   │   ├── shadows.ts
│   │   └── motion.ts
│   ├── themes/
│   │   ├── soft-blue.css
│   │   └── pink.css
│   ├── primitives/           # Button, Input, Select, Modal, ...
│   ├── layout/               # AppShell, BottomNav, TopNav, Sidebar
│   ├── icons/
│   └── index.ts
├── tailwind.preset.ts        # يستهلكه apps/web
└── package.json
```

## `supabase/`

```
supabase/
├── migrations/
│   ├── 0001_init_schema.sql
│   ├── 0002_rls_policies.sql
│   └── ...
├── functions/
│   ├── send-otp/
│   ├── verify-nafath/
│   ├── compute-eta/
│   └── monthly-top-providers/
├── seed.sql
└── config.toml
```

## اتفاقيات التسمية

- **المجلدات:** kebab-case (`order-detail/`).
- **مكوّنات React:** أسماء ملفات PascalCase (`OrderCard.tsx`).
- **Hooks:** `useOrderStatus.ts`.
- **Server actions:** `server/createOrder.ts` تُصدِّر `createOrder`.
- **Zod schemas:** `schema.ts` تُصدِّر schemas مُسمّاة (`orderCreateSchema`).
- **جداول DB:** `snake_case` جمع (`orders`, `order_status_history`).
- **أعمدة DB:** `snake_case`.
- **الترحيلات:** تسلسل رقمي مع أصفار + slug قصير (`0007_add_dispute_evidence.sql`).
