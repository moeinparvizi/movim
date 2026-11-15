# مقایسهٔ قابلیت‌های movim و WebStorm

مبنای میان‌برها، نقشهٔ پیش‌فرض WebStorm برای ویندوز و لینوکس است. این جدول شیوهٔ پیاده‌سازی و تفاوت‌ها را توضیح می‌دهد؛ وجود یک تنظیم به معنی تأیید تمام رفتارهای آن در هر پروژه نیست. جزئیات حالت‌ها و جایگزین‌های کلیدها در [مرجع میان‌برها](keymaps.md) آمده است.

## قابلیت‌ها و تفاوت‌ها

| قابلیت WebStorm | مرجع رسمی | روش movim | میان‌بر | تفاوت یا محدودیت |
|---|---|---|---|---|
| جست‌وجوی همه‌جا | [Search Everywhere](https://www.jetbrains.com/help/webstorm/searching-everywhere.html) | جست‌وجوگرهای جداگانهٔ Telescope | `Space ff/fg/sc/sS` | نتایج یکپارچه و double Shift ندارد |
| درخت پروژه | [Project tool window](https://www.jetbrains.com/help/webstorm/project-tool-window.html) | neo-tree | `Space e` | مدل پروژه با WebStorm متفاوت است |
| ناوبری و استفاده‌ها | [Navigation](https://www.jetbrains.com/help/webstorm/navigating-through-the-source-code.html) | LSP و Telescope | `gd` / `gr` / `gi` | وابسته به سرور زبان |
| تکمیل کد | [Code completion](https://www.jetbrains.com/help/webstorm/auto-completing-code.html) | blink.cmp و LSP | منوی تکمیل | موتور JetBrains نیست |
| بررسی خطاها | [Code inspections](https://www.jetbrains.com/help/webstorm/code-inspection.html) | diagnostics سرور زبان و eslint_d | `Space xx` / `]d` / `[d` | پوشش بررسی‌ها متفاوت است |
| ریفکتور | [Refactoring](https://www.jetbrains.com/help/webstorm/refactoring-source-code.html) | تغییر نام و code actionهای LSP | `Space cr` / `cR` | فقط اقدام‌های معنایی ارائه‌شده توسط سرور |
| قالب‌بندی | [Reformat code](https://www.jetbrains.com/help/webstorm/reformat-and-rearrange-code.html) | conform و Prettier | `Space cf` / `uf` | فرمتر پروژه لازم است؛ قالب‌بندی هنگام ذخیره قابل خاموش کردن است |
| گیت | [Git](https://www.jetbrains.com/help/webstorm/using-git-integration.html) | gitsigns، diffview و lazygit | `Space gg` | lazygit ابزار جداگانه و اختیاری است |
| اجرای اسکریپت | [npm](https://www.jetbrains.com/help/webstorm/using-npm.html) | انتخاب اسکریپت package.json | `Space rr` | مدل Run Configuration در WebStorm را ندارد |
| تست نزدیک، فایل و مجموعه | [Testing](https://www.jetbrains.com/help/webstorm/testing-your-applications.html) | neotest با Jest و Vitest | `Space tn/tf/tT` | وابستگی‌های پروژه و Treesitter لازم‌اند؛ تست نزدیک و مجموعهٔ Vitest و فایل Jest بدون رابط گرافیکی بررسی شده‌اند |
| دیباگ | [Debugging](https://www.jetbrains.com/help/webstorm/debugging-code.html) | nvim-dap و js-debug-adapter | `F9` / `Space db` | breakpoint در Node بدون رابط گرافیکی بررسی شده؛ اجرای Chrome تنظیم شده ولی تعاملی تأیید نشده است |
| فریم‌ورک‌ها | [JavaScript frameworks](https://www.jetbrains.com/help/webstorm/javascript-specific-guidelines.html) | vtsls، vue_ls و svelte | کلیدهای LSP | هر سه سرور در پروژه‌های نمونه متصل شده‌اند؛ سطح هوشمندی متفاوت است |

## مرجع پیاده‌سازی

- [Neovim LSP](https://neovim.io/doc/user/lsp.html) و [nvim-lspconfig](https://github.com/neovim/nvim-lspconfig)
- [lazy.nvim](https://github.com/folke/lazy.nvim) برای مدیریت افزونه‌ها
- [conform.nvim](https://github.com/stevearc/conform.nvim) برای قالب‌بندی
- [nvim-dap](https://github.com/mfussenegger/nvim-dap) برای دیباگ
- [mason-lspconfig](https://github.com/mason-org/mason-lspconfig.nvim) برای ابزارهای زبان

افزونه‌های دیگر هنوز به‌صورت جداگانه با آخرین مستندات خودشان ممیزی نشده‌اند. برای استفادهٔ عملی به [راهنمای اجرا و تست](run-debug-test.md) و [فصل هوشمندی کد](06-code-intelligence.md) مراجعه کنید.
