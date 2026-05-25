# 07 — نظام الثيمات

## المبادئ

1. **لا ألوان مُضمَّنة في الكود.** كل لون مرئي ينتج عن متغيّر CSS (`var(--color-...)`).
2. **رموز التصميم (tokens) هي الواجهة الوحيدة بين المصمم والمطوّر.** تعريف الرمز يحدث في مكان واحد.
3. **إضافة ثيم جديد لا تُعدِّل كود العناصر.** فقط ملف CSS جديد + تسجيل في DB.
4. **التبديل وقت التشغيل.** التحوّل لا يتطلّب إعادة تحميل الصفحة.

## الثيمات الافتتاحية

| الثيم | الاستخدام | اللون الأساسي |
|---|---|---|
| `soft-blue` | افتراضي، رسمي | أزرق ناعم احترافي مع رمادي دافئ |
| `pink` | أنيق، اختياري للمستخدم | وردي ناعم مع كريمي |

ألوان مرجعية (تُحسم نهائياً في المرحلة 2 مع المصمم):

| Token | soft-blue | pink |
|---|---|---|
| `--color-bg` | `#F7F9FC` | `#FFF7F8` |
| `--color-surface` | `#FFFFFF` | `#FFFFFF` |
| `--color-surface-muted` | `#EEF2F8` | `#FCEEF1` |
| `--color-primary` | `#1F6FEB` | `#E94E77` |
| `--color-primary-hover` | `#1858C2` | `#C9385F` |
| `--color-primary-contrast` | `#FFFFFF` | `#FFFFFF` |
| `--color-accent` | `#22C55E` | `#F59E0B` |
| `--color-text` | `#0F172A` | `#1B0F14` |
| `--color-text-muted` | `#52607A` | `#7A4D5A` |
| `--color-border` | `#D7DEE9` | `#F3D6DE` |
| `--color-danger` | `#DC2626` | `#DC2626` |
| `--color-warning` | `#F59E0B` | `#F59E0B` |
| `--color-success` | `#16A34A` | `#16A34A` |
| `--color-info` | `#0EA5E9` | `#0EA5E9` |

## مجموعة الرموز (Tokens)

### الألوان (دلالية)
`bg`, `surface`, `surface-muted`, `primary`, `primary-hover`, `primary-contrast`, `accent`, `text`, `text-muted`, `border`, `danger`, `warning`, `success`, `info`, plus state tokens (`focus-ring`, `selection`).

### الطباعة
`--font-sans-ar`, `--font-sans-latin` (يدعم 5 لغات)، `--font-display`، أحجام `--text-xs` → `--text-3xl`، أوزان، ارتفاعات سطر.

الخطوط المختارة (مرشَّحة، تُحسم بالمرحلة 2):
- عربي: IBM Plex Sans Arabic (يدعم الأوردي أيضاً بأوزان متعدّدة)
- لاتيني/هندي/بنغالي: Inter + Noto Sans Devanagari + Noto Sans Bengali (محمَّلة فقط حين تكون اللغة المختارة)

### التباعد
شبكة 4px: `--space-1: 0.25rem` → `--space-16: 4rem`.

### أنصاف الأقطار
`--radius-sm: 6px`, `--radius-md: 10px`, `--radius-lg: 16px`, `--radius-pill: 999px`.

### الظلال
`--shadow-sm`, `--shadow-md`, `--shadow-lg`, `--shadow-focus` (يأخذ لون من ثيم).

### الحركة
`--duration-fast: 120ms`, `--duration-base: 200ms`, `--duration-slow: 320ms`. `--ease-standard: cubic-bezier(0.2, 0, 0, 1)`.

### Z-index
سُلَّم محدّد: `--z-base: 0`, `--z-dropdown: 100`, `--z-sticky: 200`, `--z-modal: 1000`, `--z-toast: 2000`, `--z-popover: 3000`.

## التطبيق في الويب

`apps/web/app/globals.css`:

```css
:root,
[data-theme="soft-blue"] {
  --color-bg: #F7F9FC;
  --color-primary: #1F6FEB;
  /* ... */
}

[data-theme="pink"] {
  --color-bg: #FFF7F8;
  --color-primary: #E94E77;
  /* ... */
}

html { background: var(--color-bg); color: var(--color-text); }
```

Tailwind preset في `packages/ui/tailwind.preset.ts`:

```ts
extend: {
  colors: {
    bg: 'var(--color-bg)',
    surface: 'var(--color-surface)',
    primary: { DEFAULT: 'var(--color-primary)', hover: 'var(--color-primary-hover)' },
    // ...
  },
  borderRadius: { sm: 'var(--radius-sm)', md: 'var(--radius-md)', lg: 'var(--radius-lg)' }
}
```

التبديل:

```ts
function setTheme(theme: "soft-blue" | "pink") {
  document.documentElement.dataset.theme = theme;
  // يُحفظ في cookie + DB (profiles.preferred_theme)
}
```

## التطبيق في الموبايل (Flutter)

- ملف `lib/app/theme/tokens.dart` يحوي الرموز.
- ملفات `lib/app/theme/soft_blue.dart` و `pink.dart` تُصدِّر `ThemeData` كاملاً.
- `MaterialApp.theme` يتبدّل بناءً على `Provider<ThemeMode>` و `Provider<AppTheme>`.

## الوضع الداكن (Dark Mode)

- مؤجَّل لما بعد الإطلاق، لكن نظام الرموز يدعمه: كل لون له نسخة `--color-X-dark` تُملأ في المرحلة 13+.
- بنية الكود لا تحتاج تعديلاً عند الإضافة.

## إضافة ثيم جديد (مستقبلاً)

1. مصمّم يحدّد قيم الرموز.
2. مطوّر يضيف:
   - `packages/ui/src/themes/<new>.css` (ويب)
   - `apps/mobile/lib/app/theme/<new>.dart` (موبايل)
3. مشرف يضيف صف في جدول `themes` (التشغيل، الوصف، slug).
4. لا تعديل في العناصر الأساسية.

## ما هو محظور

- ❌ `color: '#1F6FEB'` في أي مكوّن.
- ❌ `bg-blue-500` (لون Tailwind مباشر) — يُستخدم `bg-primary` بدلاً.
- ❌ ظلال مُكتوبة يدوياً (`box-shadow: 0 2px...`).
- ❌ خطوط محمَّلة خارج النظام.

## التحقق التلقائي

- ESLint rule مخصّص: يرفض ألوان hex/rgb في ملفات `.tsx` و `.css` خارج `themes/`.
- pre-commit hook: يكشف أرقام في خصائص ألوان مباشرة.
- اختبار CI: يُولّد لقطات لكل عنصر في كل ثيم ويُقارن.
