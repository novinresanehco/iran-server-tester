# 🇮🇷 Iran Server Tester v4

**ابزار هوشمند تحلیل سرور برای اینترنت ایران**  
تست کیفیت سرور قبل از نصب · شناسایی بهترین پروتکل · کلاینت ویندوزی برای تست از داخل ایران

<div dir="rtl">

---

## 📌 چرا این ابزار؟

در شرایط جنگ اینترنتی ایران (آوریل ۲۰۲۶)، اکثر روش‌های سنتی VPN بلاک شده‌اند. خرید سرور بدون تست قبلی به معنای هدر دادن زمان و پول است.

این ابزار **قبل از نصب هر چیزی** به شما می‌گوید:
- ✅ آیا این سرور از ایران قابل دسترسی است؟
- ✅ بهترین پروتکل برای این سرور کدام است؟
- ✅ کدام پنل را نصب کنید؟
- ✅ چه تنظیماتی استفاده کنید؟

---

## 🗂️ فایل‌های پروژه

| فایل | هدف | محل اجرا |
|------|-----|-----------|
| `iran-server-tester-v4.sh` | تحلیل جامع سرور (۸ فاز) + شنونده probe | سرور خارجی (Linux) |
| `iran-probe-client.bat` | تست اتصال از داخل ایران بدون VPN | ویندوز داخل ایران |

---

## 🚀 راه‌اندازی سریع

### مرحله ۱ — اجرای اسکریپت روی سرور خارجی

بعد از خرید سرور، با SSH وصل شوید و این دستور را بزنید:

```bash
bash <(curl -Ls https://raw.githubusercontent.com/novinresanehco/iran-server-tester/main/iran-server-tester-v4.sh)
```

یا روش استاندارد:

```bash
curl -O https://raw.githubusercontent.com/novinresanehco/iran-server-tester/main/iran-server-tester-v4.sh
chmod +x iran-server-tester-v4.sh
./iran-server-tester-v4.sh
```

### مرحله ۲ — تست از داخل ایران (ویندوز)

فایل `iran-probe-client.bat` را دانلود کرده و روی ویندوز داخل ایران دابل‌کلیک کنید.

> ⚠️ **مهم:** قبل از اجرای فایل bat، تمام VPN‌ها را ببندید تا نتیجه واقعی بگیرید.

---

## 📋 حالت‌های اجرا

### حالت عادی (پیشنهادی)
```bash
./iran-server-tester-v4.sh
```

### حالت سریع (فقط تست‌های ضروری)
```bash
./iran-server-tester-v4.sh --quick
```

### حالت HTML (خروجی گزارش گرافیکی)
```bash
./iran-server-tester-v4.sh --html
```
گزارش در مسیر `/tmp/iran-report-[تاریخ].html` ذخیره می‌شود.

### حالت Probe Server (شنونده برای کلاینت ویندوز)
```bash
./iran-server-tester-v4.sh --probe-server=9999
```
سرور منتظر اتصال از `iran-probe-client.bat` می‌ماند تا تأیید کند اتصال از ایران برقرار می‌شود.

---

## 🔄 گردش کار کامل (برای اطمینان قطعی)

```
┌─────────────────────────────────────────────────────┐
│  1. سرور جدید بگیرید (Hetzner Finland توصیه می‌شود)  │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  2. اجرای iran-server-tester-v4.sh روی سرور          │
│     → امتیاز و توصیه‌های نصب دریافت کنید            │
└────────────────────┬────────────────────────────────┘
                     │ اگر امتیاز > 50
                     ▼
┌─────────────────────────────────────────────────────┐
│  3. اجرای --probe-server=9999 روی سرور               │
└────────────────────┬────────────────────────────────┘
                     │
                     ▼
┌─────────────────────────────────────────────────────┐
│  4. اجرای iran-probe-client.bat روی ویندوز ایران    │
│     (همه VPN‌ها بسته باشند)                         │
│     → تأیید واقعی اتصال از ایران به سرور            │
└────────────────────┬────────────────────────────────┘
                     │ اگر "REACHABLE" ✅
                     ▼
┌─────────────────────────────────────────────────────┐
│  5. نصب پنل و پروتکل بر اساس توصیه‌های اسکریپت     │
└─────────────────────────────────────────────────────┘
```

---

## 📊 فازهای تحلیل (۸ فاز)

### فاز ۱ — هویت سرور و ASN
بررسی دیتاسنتر از نظر سابقه عملکرد در ایران:

| رتبه | دیتاسنتر | عملکرد در ایران |
|------|----------|-----------------|
| Tier 1 ⭐⭐⭐ | Hetzner, Contabo, M247, Hostinger | بهترین |
| Tier 2 ⭐⭐ | DigitalOcean, Vultr, Linode | معمولاً خوب |
| Tier 3 ⭐ | AWS, GCP, Azure | تحت نظر DPI |
| ❌ BAD | OVH France, GCore Labs | اغلب بلاک |
| ⚠️ ریسک | باکو (AZ)، گرجستان (GE)، ترکیه (TR) | غیرقابل پیش‌بینی |

### فاز ۲ — دسترسی به منابع نصب
بررسی می‌کند GitHub، raw.githubusercontent.com و اسکریپت‌های MasterDNS/VayDNS از سرور قابل دسترس هستند یا نه. اگر این فاز fail شود، نصب هیچ چیزی ممکن نخواهد بود.

### فاز ۳ — پورت‌ها و سرویس‌ها
- وضعیت پورت‌های ۴۴۳، ۸۰، ۵۳
- بررسی تعارض `systemd-resolved` با MasterDNS
- وضعیت BBR و firewall
- نسخه Xray (پشتیبانی از XHTTP نیاز به ۱.۸+ دارد)

### فاز ۴ — کیفیت شبکه و مسیریابی ایران
- تست ping به ISPهای اصلی ایران: MCI، ایرانسل، شاتل، رایتل، TIC
- MTR trace به دروازه بین‌المللی ایران
- شناسایی مسیر از آذربایجان (نقطه خاکستری تحت نظر DPI)
- تست تأخیر به Cloudflare

### فاز ۵ — تست SNI برای Reality
بررسی می‌کند کدام دامنه‌ها از این سرور با TLS 1.3 قابل دسترس هستند:

| دامنه | اولویت |
|-------|--------|
| `www.microsoft.com` | ★★★ بهترین |
| `www.bing.com` | ★★★ بسیار خوب |
| `update.microsoft.com` | ★★★ بسیار خوب |
| `www.apple.com` | ★★★ خوب |
| `www.speedtest.net` | ★☆☆ تحت نظر — از استفاده خودداری کنید |

### فاز ۶ — آمادگی DNS Tunnel
در شرایط بحرانی ایران آوریل ۲۰۲۶، تنها DNS Tunnel با ثبات کار می‌کند:
- تست UDP/TCP پورت ۵۳
- بررسی قابلیت resolver بودن سرور
- آمادگی نصب MasterDnsVPN و VayDNS
- بررسی DoH (DNS over HTTPS)

### فاز ۷ — توصیه پروتکل و پنل

**پروتکل‌ها بر اساس شرایط واقعی ایران:**

| رتبه | پروتکل | پایداری |
|------|--------|---------|
| ★★★★★ | VLESS + DNS Tunnel (MasterDNS/VayDNS) | بهترین در جنگ اینترنتی |
| ★★★★☆ | VLESS + WebSocket + TLS via Cloudflare CDN | پایدار |
| ★★★★☆ | VLESS + XHTTP (SplitHTTP) via CDN | بهتر از WS |
| ★★★☆☆ | VLESS + Reality (IP تمیز) | بلاک می‌شود |
| ✖✖✖✖✖ | WireGuard / OpenVPN | در کمتر از ۱ ثانیه بلاک |

**پنل‌ها:**

| پنل | امتیاز | توضیح |
|-----|--------|-------|
| [3X-UI (mhsanaei)](https://github.com/MHSanaei/3x-ui) | ★★★★★ | کامل‌ترین پنل، XHTTP/Reality/WS |
| [MasterDnsVPN](https://github.com/masterking32/MasterDnsVPN) | ★★★★★ | بهترین برای جنگ اینترنتی |
| [VayDNS](https://github.com/net2share/vaydns) | ★★★★☆ | جایگزین خوب MasterDNS |
| [Hiddify](https://github.com/hiddify/hiddify-manager) | ★★★☆☆ | ساده، برای توزیع |
| [Marzban](https://github.com/Gozargah/Marzban) | ★★★☆☆ | چند سرور |
| x-ui (alireza0) | ★★☆☆☆ | منسوخ — استفاده نکنید |

### فاز ۸ — منابع سیستم
بررسی OS، RAM، kernel، IPv6 و سازگاری با اسکریپت‌های نصب.

---

## 📱 فایل ویندوز — `iran-probe-client.bat`

این فایل را روی کامپیوتر ویندوزی **داخل ایران** اجرا کنید تا بفهمید سرور خارجی‌تان واقعاً از ایران کار می‌کند یا نه.

### نحوه استفاده:

**۱. دانلود فایل:**
[iran-probe-client.bat](https://raw.githubusercontent.com/novinresanehco/iran-server-tester/main/iran-probe-client.bat)

**۲. قبل از اجرا:**
- تمام VPN‌ها را ببندید (v2rayN، OpenVPN، Clash و هر چیز دیگری)
- فایل را راست‌کلیک کرده و "Run as Administrator" انتخاب کنید

**۳. اطلاعات مورد نیاز:**
- آدرس IP سرور خارجی
- پورت‌هایی که می‌خواهید تست کنید (مثلاً `443 80 53`)

**۴. تست‌هایی که انجام می‌دهد:**
- بررسی اتوماتیک فعال بودن VPN (نتیجه را تحت تأثیر قرار می‌دهد)
- تأیید IP ایرانی شما
- ICMP Ping
- TCP connect به پورت‌های مختلف
- TLS Handshake روی پورت ۴۴۳
- DNS resolver test
- Traceroute و آنالیز مسیر
- Reverse probe (اگر سرور در حالت `--probe-server` باشد)
- ذخیره نتیجه در Desktop

**۵. تفسیر نتیجه:**

| نتیجه | معنی |
|-------|------|
| `SERVER IS REACHABLE FROM IRAN` ✅ | سرور کار می‌کند، نصب را شروع کنید |
| `PARTIAL ACCESS` ⚠️ | بعضی پورت‌ها بلاک است، از DNS Tunnel استفاده کنید |
| `NOT REACHABLE` ❌ | سرور کار نمی‌کند، سرور دیگری بگیرید |

### تست Reverse Probe (دقیق‌ترین روش):

این روش اتصال واقعی از ایران به سرور را تأیید می‌کند:

**روی سرور:**
```bash
./iran-server-tester-v4.sh --probe-server=9999
```

**روی ویندوز ایران:**
فایل bat را اجرا کنید و پورت `9999` را به عنوان probe port وارد کنید.

اگر سرور پیام "CONNECTION RECEIVED FROM IRAN" داد، اتصال صددرصد تأیید شده است.

---

## 🏆 جدول امتیازدهی نهایی

| امتیاز | درجه | توصیه |
|--------|------|--------|
| 80–100 | A | عالی — همین الان نصب کنید |
| 65–79 | B | خوب — با Cloudflare CDN نصب کنید |
| 50–64 | C | قابل قبول — فقط DNS Tunnel |
| 35–49 | D | ریسک — Hetzner Finland را امتحان کنید |
| 0–34 | F | اجتناب کنید — سرور عوض کنید |

---

## ⚙️ پیش‌نیازها

| مورد | جزئیات |
|------|---------|
| سیستم عامل | Ubuntu 22.04 / 24.04 یا Debian 11 / 12 |
| دسترسی | root |
| اتصال اینترنت | از سرور خارجی |
| ابزارها | به‌صورت خودکار نصب می‌شوند |

---

## 💡 نکات مهم April 2026

**درباره MasterDNS:**
- مقدار `max-qname-len` را حتماً روی **۱۰۱** تنظیم کنید (نه ۲۵۳)
- DPI ایران درخواست‌های DNS با طول بیشتر از ۱۱۰ کاراکتر را بلاک می‌کند
- نام دامنه و ساب‌دامین را کوتاه انتخاب کنید (مثلاً `v.ab.ir` نه `subdomain.mysite.example.com`)
- قبل از نصب MasterDNS حتماً `systemd-resolved` را غیرفعال کنید

**درباره Reality:**
- روی IP‌های OVH France و G-Core Labs باکو کار نمی‌کند
- روی مسیرهای عبوری از آذربایجان (az-ix) تحت نظر است
- بهترین SNI: `www.microsoft.com` یا `www.bing.com`
- حتماً `flow=xtls-rprx-vision` و `fp=chrome` تنظیم کنید

**درباره سرور:**
- بهترین انتخاب: **Hetzner Finland** (هلزینکی) — AS24940
- قیمت: از ۳.۷۹ یورو در ماه — [hetzner.com](https://hetzner.com)
- بعد از خرید، BBR را فعال کنید: `x-ui` → گزینه ۲۴

---

## 🛠️ راهنمای نصب سریع (بعد از تأیید سرور)

```bash
# مرحله ۱ — آزاد کردن پورت ۵۳
systemctl stop systemd-resolved
systemctl disable systemd-resolved
echo 'nameserver 8.8.8.8' > /etc/resolv.conf

# مرحله ۲ — باز کردن پورت‌ها
ufw allow 443 && ufw allow 80 && ufw allow 53/udp && ufw reload

# مرحله ۳ — نصب 3X-UI
bash <(curl -Ls https://raw.githubusercontent.com/mhsanaei/3x-ui/master/install.sh)

# مرحله ۴ — فعال کردن BBR
x-ui   # سپس گزینه ۲۴ را انتخاب کنید

# مرحله ۵ — نصب MasterDnsVPN (تونل DNS)
bash <(curl -Ls https://raw.githubusercontent.com/masterking32/MasterDnsVPN/main/server_linux_install.sh)
```

**تنظیمات inbound VLESS Reality در پنل:**
```
Protocol  : VLESS
Port      : 443
Security  : Reality
Flow      : xtls-rprx-vision
uTLS      : chrome
SNI       : www.microsoft.com
Short ID  : [یک مقدار hex 8 کاراکتری تصادفی]
```

---

## ⚠️ محدودیت‌ها

- اسکریپت روی **سرور خارجی** اجرا می‌شود و نتایج را بر اساس الگوهای شناخته‌شده DPI ایران تخمین می‌زند
- برای اطمینان **صددرصد**، از `iran-probe-client.bat` داخل ایران استفاده کنید
- نتایج بسته به ISP (MCI، ایرانسل، شاتل) متفاوت است
- اجرا با root الزامی است
- اگر GitHub در دسترس نباشد، ابتدا DNS را اصلاح کنید

---

## 📜 License

MIT License

---

## ❤️ مشارکت

Pull Request، گزارش باگ و پیشنهاد فیچر از طریق GitHub Issues خوشحال‌کننده است.

---

*اینترنت آزاد حق همه مردم ایران است*

</div>
