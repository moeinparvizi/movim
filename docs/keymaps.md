# تطبیق میان‌برهای WebStorm با movim

مرجع مقایسه، [کارت رسمی میان‌برهای پیش‌فرض WebStorm برای ویندوز و لینوکس](https://resources.jetbrains.com/storage/products/webstorm/docs/WebStorm_ReferenceCard_Windows_Linux.pdf) است. در movim، کلید Leader همان **Space** است. ارسال ترکیب کلیدها به قابلیت‌های ترمینال بستگی دارد؛ بعضی ترمینال‌ها Ctrl+Shift، Alt یا Shift همراه کلیدهای F را از ترکیب‌های ساده‌تر تشخیص نمی‌دهند. در این حالت از ستون «جایگزین» استفاده کنید. فشار دوبارهٔ Shift به‌عنوان رویداد جداگانه در ترمینال در دسترس نیست.

## جدول تطبیق

| کار | میان‌بر WebStorm | میان‌بر movim | حالت | جایگزین | پیش‌نیاز یا محدودیت |
|---|---|---|---|---|---|
| جست‌وجوی همه‌جا | دو بار Shift | جست‌وجوگرهای جداگانه | Normal | `Space ff` / `fg` / `sc` / `sS` | نتیجه‌های یکپارچه ندارد |
| پیدا کردن فایل | `Ctrl+Shift+N` | `Ctrl+Shift+N` | Normal، Insert | `Space ff` | ترمینال باید کلید را ارسال کند |
| اطلاعات پارامتر | `Ctrl+P` | `Ctrl+P` | Normal، Insert | `:lua vim.lsp.buf.signature_help()` | نیازمند LSP |
| مستندات نماد | `Ctrl+Q` | `Ctrl+Q` | Normal، Insert | `K` | ممکن است ترمینال Ctrl+Q را دریافت کند |
| پیدا کردن فرمان | `Ctrl+Shift+A` | `Ctrl+Shift+A` | Normal، Insert | `Space sc` | فرمان‌های Telescope؛ نه تمام تنظیمات IDE |
| جست‌وجوی پروژه | `Ctrl+Shift+F` | `Ctrl+Shift+F` | Normal، Insert | `Space fg` | نیازمند ripgrep |
| فایل‌های اخیر | `Ctrl+E` | `Ctrl+E` | Normal، Insert | `Space fr` | رفتار پیش‌فرض اسکرول Vim را جایگزین می‌کند |
| خطای بعدی یا قبلی | `F2` / `Shift+F2` | `]d` / `[d` | Normal | `Shift+F2` برای قبلی | نیازمند diagnostics؛ F2 در movim تغییر نام است |
| اقدام متناسب با کد | `Alt+Enter` | `Alt+Enter` | Normal، Insert | `Space ca` | نیازمند پشتیبانی LSP |
| تغییر نام | `Shift+F6` | `Shift+F6` / `F2` | Normal، Insert | `Space cr` / `:RenameSymbol` | تغییر نام معنایی از طریق سرور زبان |
| پیدا کردن استفاده‌ها | `Alt+F7` | `Alt+F7` | Normal، Insert | `gr` | ارجاع‌های LSP |
| رفتن به تعریف | `Ctrl+B` | `Ctrl+B` | Normal، Insert | `gd` | رفتار page-up در Vim را جایگزین می‌کند |
| پیاده‌سازی / تعریف نوع | `Ctrl+Alt+B` / `Ctrl+Shift+B` | همان ترکیب‌ها | Normal، Insert | `gi` / `gy` | نیازمند پشتیبانی سرور زبان |
| ساختار فایل | `Ctrl+F12` | `Ctrl+F12` | Normal، Insert | `Space ss` | نمادهای LSP |
| ادامهٔ دیباگ | `F9` | `F9` | Normal | `F5` | F9 در Insert ورودی فارسی را تغییر می‌دهد |
| قدم بعدی / ورود به تابع | `F8` / `F7` | `F8` / `F7` | Normal، Insert | `F10` / `F11` | نیازمند آداپتر دیباگ |
| خروج از تابع / نقطهٔ توقف | `Shift+F8` / `Ctrl+F8` | همان ترکیب‌ها | Normal، Insert | `Shift+F11` / `Space db` | وابسته به پشتیبانی ترمینال |
| مرتب‌سازی importها | `Ctrl+Alt+O` | `Space so` | Normal | `Space cA` | نیازمند پشتیبانی سرور |
| اجرای تست نزدیک / فایل / مجموعه | `Ctrl+Shift+F10` یا تنظیم پروژه | `Space tn` / `tf` / `tT` | Normal | `Space rr` برای اسکریپت پروژه | Jest یا Vitest؛ راهنمای تست را بخوانید |

## حالت‌ها و تداخل کلیدها

کلیدهای IDE در حالت Insert ابتدا به Normal برمی‌گردند. با `Esc` به Normal و با `i` به Insert بروید. برای خروج از حالت ترمینال `Ctrl+\` و سپس `Ctrl+N` را بزنید. `j` و `k` روی خط‌های نمایشی حرکت می‌کنند. `n`، `N` و `Ctrl+D/U` نما را دوباره وسط می‌آورند. `Q` غیرفعال است؛ در انتخاب بصری، `J/K` خط‌ها را جابه‌جا می‌کنند و paste رجیستر را حفظ می‌کند.

`Ctrl+H/J/K/L` بین پنجره‌ها حرکت می‌کنند. `Ctrl+B` به اعلان نماد می‌رود و دیگر page-up پیش‌فرض Vim نیست. برای دیدن میان‌برهای فعال، `Space sk` یا `:Telescope keymaps` را اجرا کنید. روی ترمینال‌های قدیمی، Ctrl+Shift ممکن است با Ctrl یکی شود؛ از جایگزین‌های Space استفاده کنید.

برای غیرفعال کردن لایهٔ کلیدهای WebStorm، پیش از بارگذاری `config.keymaps` این تنظیم را قرار دهید:

```lua
vim.g.webstorm_keymaps = false
```

برای جدول روزمرهٔ تمام کلیدها، [چیت‌شیت کامل](14-keymaps-cheatsheet.md) و برای تست و دیباگ، [راهنمای عملی اجرا](run-debug-test.md) را بخوانید.
