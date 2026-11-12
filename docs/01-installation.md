# فصل ۱ — نصب و راه‌اندازی

## پیش‌نیازها

برای بسته‌های آمادهٔ ویندوز، مک Intel و Apple Silicon و لینوکس، ابتدا [راهنمای نصب هر پلتفرم](19-platform-install.md) را ببینید. جدول زیر نمونهٔ نصب دستی ابزارها با Homebrew در مک است؛ در لینوکس از مدیر بستهٔ توزیع خود استفاده کنید و نصب‌کنندهٔ ویندوز ابزارهای اصلی را همراه دارد.

| ابزار | نقش | نصب |
|---|---|---|
| **Neovim ≥ 0.11** | خود ادیتور | `brew install neovim` |
| **Node.js ≥ 20** | LSPهای TypeScript/Angular | `brew install node` |
| **ripgrep** | جستجوی متن | `brew install ripgrep` |
| **fd** | پیدا کردن فایل | `brew install fd` |
| **lazygit** | UI گیت | `brew install lazygit` |
| **git** | که باشد! | `brew install git` |
| **A Nerd Font** | آیکون‌ها | [jetbrainsmono-nerd-font](https://www.nerdfonts.com/) — مثلاً `brew install --cask font-jetbrains-mono-nerd-font` |

> ⚠️ **فونت مهم است!** بدون Nerd Font، به جای آیکون‌ها مربع‌های خالی می‌بینید. برای فارسی هم فونت fallback مثل **Vazirmatn** نصب کنید (فصل ۱۳).

## نصب movim

به [راهنمای نصب هر پلتفرم](19-platform-install.md) مراجعه کنید. بسته‌های مک و لینوکس از تنظیمات جداگانه استفاده می‌کنند و نسخهٔ قبلی تنظیمات همان بسته را پشتیبان می‌گیرند. اولین بار نصب پلاگین‌ها ممکن است چند دقیقه طول بکشد.

## اولین اجرا چه اتفاقی می‌افتد؟

1. **lazy.nvim** (مدیر پلاگین) همه پلاگین‌ها را دانلود می‌کند.
2. **Mason** سرورهای LSP را نصب می‌کند: `vtsls` (TS/JS)، `angularls`، `tailwindcss`، `html`، `cssls` و…
3. **Treesitter** پارسرهای هایلایت را کامپایل می‌کند.
4. بعد از اتمام، Neovim را ببندید و دوباره باز کنید.

### بررسی سلامت

داخل nvim این را بزنید:

```vim
:checkhealth
```

اگر همه‌چیز سبز یا فقط هشدارِ اختیاری بود، آماده‌اید.

## نصب دستی ابزارهای Mason (در صورت نیاز)

```vim
:Mason
```

باید این‌ها نصب باشند:

- `vtsls` — TypeScript/JavaScript (React, Next, Node, Express, Nest)
- `angularls` — انگولار (شامل قالب‌های HTML)
- `tailwindcss` — تکمیل کلاس‌های CSS
- `html` / `cssls` / `emmet_ls`
- `jsonls` / `yamlls` / `dockerls` / `bashls` / `pyright` / `lua_ls`
- `prettierd` / `eslint_d` / `stylua` — فرمتر و لینتر
- `js-debug-adapter` — دیباگر

## ترمینال پیشنهادی

برای تجربه کامل (مخصوصاً فارسی و Ctrl+Click):

- در ترمینالی که انتخاب می‌کنید، پشتیبانی از فونت فارسی، fallback فونت و رویدادهای ماوس را بررسی کنید. نمایش متن ترکیبی راست‌به‌چپ به محدودیت‌های Neovim و ترمینال بستگی دارد؛ جزئیات در [پشتیبانی فارسی](13-persian.md) آمده است.

## بعد از نصب

- فصل ۲ را بخوانید (مبانی Vim) — حتی اگر عجله دارید، ۲۰ دقیقه‌ای که آینده‌تان را نجات می‌دهد.
- `<Space>` را فشار دهید تا **which-key** منوی امکانات را نشان دهد — هیچ‌وقت لازم نیست کلیدها را حفظ کنید!
