# 05 — الأدوار والصلاحيات

أربعة أدوار رئيسية مع نموذج RBAC هرمي مدعوم بسياسات RLS في قاعدة البيانات. الفرض يحدث على ثلاث طبقات (دفاع في العمق):

1. **قاعدة البيانات** — سياسات Postgres RLS (المرجع الأخير).
2. **الخادم** — middleware + server actions تتحقّق قبل أي استدعاء.
3. **الواجهة** — إخفاء الأزرار والشاشات للحدّ من سوء الاستخدام (ليست حدّاً أمنياً).

## الأدوار

| الدور | الوصف | النطاق |
|---|---|---|
| `super_admin` | مالك المنصة | كل شيء، بلا قيود |
| `section_admin` | موظف عمليات | محصور بـ `admin_sections` المسندة (مثلاً "تكييف" أو "الرياض") |
| `provider` | مزوّد خدمة | بياناته الخاصة + الطلبات الموجَّهة إليه |
| `requester` | طالب خدمة | بياناته الخاصة + طلباته |

الأدوار لا تُتوارَث ضمنياً — `super_admin` يحصل صراحةً على كل صلاحية في الكود.

## مصفوفة الصلاحيات

السطر = الإجراء، العمود = الدور. ✓ = مسموح، ✗ = ممنوع، ◐ = مسموح بشروط (موضّحة).

### الكتالوج

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| إنشاء/تعديل/حذف الفئات | ✓ | ◐ ضمن قسمه | ✗ | ✗ |
| تعديل الخدمات | ✓ | ◐ | ✗ | ✗ |
| عرض الكتالوج | ✓ | ✓ | ✓ | ✓ |

### المستخدمون والمزوّدون

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| عرض جميع المستخدمين | ✓ | ◐ ضمن نطاقه | ✗ | ✗ |
| تعليق/تنشيط مستخدم | ✓ | ◐ ضمن نطاقه | ✗ | ✗ |
| تعديل ملف شخصي | ✓ | ◐ | ◐ ملفه فقط | ◐ ملفه فقط |
| التحقّق من مزوّد | ✓ | ◐ | ✗ | ✗ |
| رفع وثائق المزوّد | ✓ | ✗ | ◐ ملفه فقط | ✗ |

### الطلبات

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| إنشاء طلب | ✗ | ✗ | ✗ | ✓ |
| عرض طلب | ✓ | ◐ ضمن نطاقه | ◐ طلباته المسندة | ◐ طلباته |
| قبول/رفض طلب | ✗ | ✗ | ◐ الموجَّه له | ✗ |
| تغيير الحالة (en_route → in_progress → completed) | ✗ | ✗ | ◐ طلباته | ✗ |
| إلغاء طلب | ✓ بشروط الإدارة | ✓ ضمن نطاقه | ◐ قبل قبوله أو ضمن النوافذ | ◐ قبل قبوله أو ضمن النوافذ |
| تعديل سعر نهائي | ✓ | ✓ ضمن نطاقه | ◐ بموافقة الطالب | ✗ |

### الدردشة

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| إرسال رسالة | ✗ مباشرةً | ✗ | ◐ في محادثات طلباته | ◐ في محادثات طلباته |
| قراءة الأرشيف | ✓ كأدلّة فقط | ◐ كأدلّة لنزاع موكَّل له | ◐ محادثاته | ◐ محادثاته |
| حذف رسالة | ✗ (للأدلّة) | ✗ | ✗ بعد الإرسال | ✗ بعد الإرسال |

### التقييمات والنزاعات

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| إنشاء تقييم | ✗ | ✗ | ◐ على طلباته المكتملة فقط | ◐ على طلباته المكتملة فقط |
| إخفاء تقييم | ✓ | ◐ ضمن نطاقه | ✗ | ✗ |
| فتح نزاع | ✗ | ✗ | ◐ على طلباته | ◐ على طلباته |
| إغلاق/حلّ نزاع | ✓ | ◐ الموكَّل له | ✗ | ✗ |

### الاشتراكات والإعلانات والمالية

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| تعديل الباقات/الأسعار | ✓ | ✗ | ✗ | ✗ |
| إدارة الإعلانات | ✓ | ◐ ضمن نطاقه | ✗ | ✗ |
| الاشتراك في باقة | ✗ | ✗ | ◐ لنفسه | ✗ |
| عرض التقارير المالية | ✓ | ◐ تقارير نطاقه | ◐ تقاريره | ◐ فواتيره |

### الإعدادات والترجمات

| الإجراء | super | section | provider | requester |
|---|---|---|---|---|
| تعديل النصوص (CMS) | ✓ | ◐ نصوص قسمه | ✗ | ✗ |
| تعديل قوالب الرسائل | ✓ | ✗ | ✗ | ✗ |
| إدارة مفاتيح API | ✓ فقط | ✗ | ✗ | ✗ |
| إدارة الثيمات | ✓ | ✗ | ✗ | ✗ |

## استراتيجية RLS

كل جدول يبدأ بـ:

```sql
alter table <name> enable row level security;
revoke all on <name> from authenticated, anon;
```

ثم تُمنح سياسات صريحة. أمثلة (يُكتب الكامل عند الترحيلات في كل مرحلة):

```sql
-- المستخدم يقرأ ملفه فقط (إلا الإدارة)
create policy profiles_select_self on profiles
  for select using (
    user_id = auth.uid()
    or exists (select 1 from user_roles where user_id = auth.uid() and role in ('super_admin','section_admin'))
  );

-- المزوّد يرى طلباته فقط
create policy orders_select_provider on orders
  for select to authenticated
  using (
    provider_id = auth.uid()
    or requester_id = auth.uid()
    or exists (select 1 from user_roles where user_id = auth.uid() and role in ('super_admin','section_admin'))
  );

-- المزوّد يستطيع تحديث حالة الطلب الموكَّل له فقط (مع تحقّق آلة الحالات في trigger)
create policy orders_update_provider on orders
  for update to authenticated
  using (provider_id = auth.uid())
  with check (provider_id = auth.uid());

-- الرسائل تُقرأ/تُكتب من طرفي المحادثة فقط
create policy messages_rw_participants on messages
  for all to authenticated
  using (
    exists (
      select 1 from conversations c
      join orders o on o.id = c.order_id
      where c.id = messages.conversation_id
        and (o.requester_id = auth.uid() or o.provider_id = auth.uid())
    )
  );
```

## التحقّقات على الخادم

كل server action و Edge Function تبدأ بـ:

```ts
import { requireUser, requireRole } from "@/lib/auth/guard";

export async function cancelOrder(orderId: string) {
  const user = await requireUser();
  const order = await db.orders.findUnique({ where: { id: orderId } });
  if (!order) throw new ApiError("ORDER_NOT_FOUND", 404);

  const isOwnerOrProvider = order.requesterId === user.id || order.providerId === user.id;
  const isAdmin = await hasRole(user.id, ["super_admin", "section_admin"]);
  if (!isOwnerOrProvider && !isAdmin) throw new ApiError("FORBIDDEN", 403);

  // ... قواعد العمل ثم تغيير الحالة
}
```

## نطاق `section_admin`

- يُربط بصفوف في `section_admin_assignments` تشير إلى `admin_sections` (مثلاً `category:hvac` أو `city:riyadh`).
- كل سياسة RLS لها فرع للتحقّق من النطاق:

```sql
exists (
  select 1
  from section_admin_assignments saa
  join admin_sections s on s.id = saa.admin_section_id
  where saa.section_admin_id = auth.uid()
    and (
      (s.scope_type = 'category' and s.scope_value = orders.category_id::text)
      or (s.scope_type = 'city' and s.scope_value = orders.city_id::text)
    )
)
```

## التدقيق

كل تغيير حسّاس (إنشاء/حذف مستخدم، تعديل صلاحية، تغيير سعر، حلّ نزاع، تعديل سرّ API) يُكتب في `audit_log` بصيغة:

```
audit_log: { actor_id, action, target_table, target_id, before jsonb, after jsonb, ip, user_agent, created_at }
```

`audit_log` للقراءة فقط من خارج Edge Functions، ولا يُحذف منها أبداً.
