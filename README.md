# 🇮🇷 Iran Server Tester

ابزار هوشمند تست کیفیت سرور برای استفاده در ایران (مخصوص Xray / Reality / 3X-UI)

---

## 🎯 هدف پروژه

این اسکریپت به شما کمک می‌کند قبل از نصب پنل‌هایی مثل **3X-UI**، کیفیت واقعی سرور را از دید اینترنت ایران بررسی کنید.

با استفاده از این ابزار، می‌توانید از خرید یا استفاده از سرورهای نامناسب جلوگیری کنید.

---

## 🚀 نصب و اجرا

### روش ساده:

```bash
bash <(curl -s https://raw.githubusercontent.com/novinresanehco/iran-server-tester/main/iran-server-tester.sh)
```

### روش استاندارد:

```bash
curl -O https://raw.githubusercontent.com/novinresanehco/iran-server-tester/main/iran-server-tester.sh
chmod +x iran-server-tester.sh
./iran-server-tester.sh
```

---

## ⚙️ پیش‌نیازها

* Ubuntu / Debian
* دسترسی root
* ابزارهای زیر:

  * curl
  * wget
  * jq
  * netcat
  * traceroute

---

## 🔍 مراحل بررسی (۷ فاز هوشمند)

### 🧩 Phase 1 — ASN Check

بررسی می‌کند دیتاسنتر شما در لیست مناسب برای ایران قرار دارد یا نه.

* Hetzner → امتیاز مثبت
* OVH فرانسه → امتیاز منفی

---

### 🛡 Phase 2 — IP Reputation

* بررسی IP در Shodan
* تشخیص بلاک یا مانیتور بودن

---

### 🔌 Phase 3 — Ports & Services

* بررسی نصب بودن 3X-UI
* بررسی فعال بودن BBR
* تست وضعیت فایروال

---

### 🌐 Phase 4 — Network Quality

* تست مسیر به ISPهای ایران:

  * MCI
  * Irancell
* اندازه‌گیری latency به Cloudflare

---

### 🔐 Phase 5 — SNI Detection

تشخیص بهترین دامنه برای Reality:

مثال:

* microsoft.com
* bing.com

---

### 🚀 Phase 6 — Protocol Recommendation

پیشنهاد بهترین پروتکل بر اساس شرایط:

* 🥇 Reality
* 🥈 XHTTP
* 🥉 WS + CDN

---

### 📦 Phase 7 — Installation Check

بررسی دسترسی به GitHub:

❗ اگر این مرحله fail شود:
→ نصب 3X-UI نیز شکست خواهد خورد

---

## 📊 نتیجه نهایی

اسکریپت در پایان یک امتیاز از 0 تا 100 می‌دهد:

| امتیاز    | وضعیت                        |
| --------- | ---------------------------- |
| 🟢 80–100 | عالی (پیشنهاد نصب)           |
| 🟡 60–80  | متوسط                        |
| 🔴 زیر 60 | نامناسب (سرور را تغییر دهید) |

---

## 💡 کاربردها

* انتخاب بهترین دیتاسنتر برای کاربران ایران
* تست قبل از خرید VPS
* بهینه‌سازی Reality / Xray
* کاهش ریسک فیلتر شدن

---

## ⚠️ نکات مهم

* حتماً با دسترسی root اجرا شود
* اگر GitHub در دسترس نباشد، نتیجه قابل اعتماد نیست
* نتایج بسته به ISP ایران ممکن است متفاوت باشد

---

## ❤️ مشارکت

Pull Request و پیشنهادات شما خوشحال‌کننده است.

---

## 📜 License

MIT License
