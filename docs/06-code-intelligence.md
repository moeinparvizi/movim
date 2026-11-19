# فصل ۶ — هوشمندی کد (LSP)

LSP یعنی Language Server Protocol — همون موتوری که WebStorm هم (به شکل خودش) استفاده می‌کند. این کانفیگ برای دنیای JS/TS از **vtsls** (قوی‌ترین سرور TypeScript) و **angularls** استفاده می‌کند.

## پشتیبانی زبان‌ها

| زبان/فریمورک | سرور | نکته |
|---|---|---|
| TypeScript / JavaScript / React / Next | vtsls | اتوکامپلیت + هایلایت + ریفکتور |
| **Angular** | angularls | شامل قالب‌های HTML — rename کامپوننت در template ها هم اعمال می‌شود |
| Node / Express / Nest | vtsls | NestJS هم TS است؛ decorator ها پشتیبانی می‌شوند |
| Tailwind CSS | tailwindcss | تکمیل کلاس + رنگ پیش‌نمایش |
| HTML / CSS / SCSS | html, cssls | + emmet |
| JSON / YAML | jsonls, yamlls | با اسکیمای package.json و k8s و… |
| Python | pyright | |
| Lua / Bash / Docker | lua_ls, bashls, dockerls | |

قالب‌های `*.component.html` و فایل‌های HTML داخل پروژه‌ای با `angular.json` با دستور زبان Angular رنگ‌آمیزی می‌شوند؛ از جمله `@if`، bindingها، فراخوانی‌ها و تگ‌های Angular Material. قالب‌های inline در `@Component` نیز از parser مربوط استفاده می‌کنند. رنگ نهایی از تم انتخابی می‌آید. parserهای ویندوز x64، مک Intel/Apple Silicon و لینوکس x64/ARM64 همراه نسخه هستند؛ روی معماری‌های دیگر رنگ‌آمیزی HTML جایگزین می‌شود. تکمیل و تشخیص خطا همچنان به Angular language server و وابستگی‌های پروژه نیاز دارد.

## اتوکامپلیت (blink.cmp)

همین‌طور که تایپ می‌کنید ظاهر می‌شود؛ پنجره مستندات هم کنارش باز است (مثل وب‌استورم).

در ویندوز، Blink از موتور تطبیق Lua استفاده می‌کند تا اجرای هم‌زمان چند Neovim باعث تلاش برای جایگزینی DLL قفل‌شده نشود. ممکن است تطبیق در فهرست‌های بزرگ کندتر باشد؛ موتور Rust امکاناتی مانند frecency و proximity را نیز دارد که در موتور Lua در دسترس نیستند. در macOS تنظیم معمول Blink و موتور Rust ترجیح داده می‌شود.

| کلید | کار |
|---|---|
| `Tab` / `S-Tab` | انتخاب بعدی/قبلی (همراه اسنیپت‌ها) |
| `Enter` | پذیرش |
| `Ctrl+Space` | باز کردن اجباری/رفرش |
| `Ctrl+b/f` | اسکرول مستندات |
| ghost text | پیشنهاد AI-مانند خاکستری؛ `Tab` می‌پذیرید |

اسنیپت‌های friendly-snippets هم فعاله (مثلاً `nfn` در TS).

## هاور و مستندات (Ctrl+Q وب‌استورم)

| کلید | کار |
|---|---|
| `K` | مستندات symbol زیر کرسر (پنجره border دار) |
| `<C-w>d` | تعریف در پنجره جدا |
| `<leader>cd` | نمایش خطای/هشدار همان خط |

## پرش‌ها (WebStorm: Ctrl+B / Ctrl+Alt+B / Alt+Click)

| کلید | کار |
|---|---|
| **Alt+Click** | باز کردن تعریف در یک تب جدید؛ بازگشت به تب قبل با `gT` |
| `gd` | تعریف (لیست fuzzy) |
| `gi` | implementation (پیاده‌سازی interface) |
| `gr` | همه references (کاربردها) |
| `gy` | type definition |
| `gD` | declaration |

## Rename — Shift+F6 وب‌استورم

| کلید | کار |
|---|---|
| `<S-F6>` / `F2` / `<leader>cr` / `:RenameSymbol` | rename هوشمند symbol |

اگر ترمینال کلید `Shift+F6` را دریافت نمی‌کند، از `F2` یا `Space c r` استفاده کنید. برای بررسی اتصال سرور زبان، `:LspInfo` را اجرا کنید. کلید `]d` به خطای بعدی می‌رود.

چرا LSP rename بهتر از مولتی‌کرسر است؟ چون **کاربردها را از import ها، قالب‌های انگولار و رفرنس‌های دیگر فایل‌ها هم پیدا می‌کند**. import ها هم خودکار آپدیت می‌شوند (`updateImportsOnFileMove` فعاله — جابجایی فایل = آپدیت مسیر import).

برای Angular، مکان‌نما را روی متغیر در فایل TypeScript یا قالب HTML بگذارید،
`Space c r` را بزنید و نام جدید را وارد کنید. تغییرات فایل‌های مرتبط در
بافرها اعمال می‌شوند؛ فایل‌های تغییرکرده را ذخیره کنید. برای این قابلیت باید
وابستگی‌های پروژه نصب و سرور Angular به پروژه متصل باشد (`:LspInfo`).

## Code Actions — Alt+Enter وب‌استورم

| کلید | کار |
|---|---|
| `<leader>ca` | quick-fix های همان نقطه (اضافه کردن import، ساخت متد، ...) |
| `<leader>cA` | source actions: organize imports، fix-all و... |
| `<leader>cR` | ریفکتورها (extract function/variable/constant و...) |

همین کار در وب‌استورم Alt+Enter بود. منوی code action هم با `Ctrl+j/k` حرکت کنید.

## ریفکتور

- **Extract**: `<leader>cR` → انتخاب refactor های سرور (Extract to function/constant، Convert to async و...)
- **Rename**: `<S-F6>`
- **Move/آپدیت import**: جابجایی فایل در neo-tree با `a` (rename) — مسیرها خودکار اصلاح می‌شوند
- **Surround/align/…**: فصل ۴

## فرمت خودکار و ESLint

- ذخیره = فرمت با prettierd (اگر پروژه .prettierrc دارد از همان پیروی می‌کند)
- organize imports هم خودکار موقع ذخیره (vtsls)
- eslint_d خروجی‌اش در gutter و پنل Problems می‌آید

## Problems panel (وب‌استورم: Alt+6)

| کلید | کار |
|---|---|
| `<leader>xX` | پنل خطاهای کل پروژه |
| `<leader>xx` | فقط فایل جاری |
| `]d` / `[d` | خطای بعدی/قبلی |
| `<leader>ui` | نمایش/مخفی inlay hints (نوع‌ها و نام پارامترها داخل کد) |
| `<leader>uI` | نمایش متن کامل راهنمای نوع در خط فعلی |

در TypeScript، TSX، JavaScript و Vue، راهنمای **نوع** کم‌رنگ کنار کد به `: …` خلاصه می‌شود. روی همین علامت کلیک کنید تا متن کامل نوعی که سرور زبان فرستاده در پنجرهٔ شناور نمایش داده شود؛ `Space uI` راهنمای نوعِ خط فعلی را بدون ماوس نشان می‌دهد. نام پارامترها کوتاه نمی‌شوند. این نمایش متن فایل را تغییر نمی‌دهد و به سرور زبان متصل نیاز دارد. `Space ui` همچنان همهٔ راهنماهای درون خط را روشن/خاموش می‌کند. این قابلیت تعریف‌های `type/interface` داخل فایل را خودکار جمع نمی‌کند.

بعدی: [فصل ۷ — گیت کامل](07-git.md)
