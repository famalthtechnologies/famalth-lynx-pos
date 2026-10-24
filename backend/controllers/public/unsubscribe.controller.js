function renderUnsubscribePage(req, res) {
    const rawEmail = (req.query.email || '').trim();
    const sanitizedEmail = rawEmail.replace(/[<>"']/g, '');
    const displayEmail = sanitizedEmail || 'your email address';

    console.log(`[Famalth Lynx] Unsubscribe request processed for: "${sanitizedEmail || 'unknown'}"`);

    const html = `<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>Unsubscribed • Famalth Lynx</title>
  <link rel="icon" href="data:image/svg+xml,<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24' fill='%231a73e8'><path d='M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z'/></svg>">
  <style>
    * { box-sizing: border-box; margin: 0; padding: 0; }
    body {
      font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, "Google Sans", Helvetica, Arial, sans-serif;
      background-color: #f8f9fa;
      color: #202124;
      display: flex;
      align-items: center;
      justify-content: center;
      min-height: 100vh;
      padding: 24px;
    }
    .card {
      background: #ffffff;
      border: 1px solid #dadce0;
      border-radius: 12px;
      max-width: 500px;
      width: 100%;
      padding: 44px 36px;
      text-align: center;
      box-shadow: 0 1px 3px 0 rgba(60,64,67,0.15), 0 4px 8px 3px rgba(60,64,67,0.06);
    }
    .brand {
      font-size: 24px;
      font-weight: 700;
      color: #1a73e8;
      letter-spacing: -0.5px;
      margin-bottom: 26px;
    }
    .brand span {
      color: #202124;
    }
    .icon-wrap {
      width: 58px;
      height: 58px;
      background: #e6f4ea;
      border-radius: 50%;
      display: inline-flex;
      align-items: center;
      justify-content: center;
      margin-bottom: 22px;
    }
    .icon-wrap svg {
      width: 34px;
      height: 34px;
      fill: #137333;
    }
    h1 {
      font-size: 22px;
      font-weight: 500;
      color: #202124;
      margin-bottom: 12px;
    }
    .desc {
      font-size: 14.5px;
      color: #5f6368;
      line-height: 1.55;
      margin-bottom: 22px;
    }
    .email-chip {
      display: inline-block;
      background: #e8f0fe;
      color: #1a73e8;
      font-weight: 600;
      padding: 5px 14px;
      border-radius: 16px;
      margin-top: 8px;
      word-break: break-all;
      font-size: 13.5px;
    }
    .notice {
      background: #f8f9fa;
      border: 1px solid #e8eaed;
      border-radius: 8px;
      padding: 14px 18px;
      font-size: 12.5px;
      color: #5f6368;
      line-height: 1.55;
      text-align: left;
      margin-bottom: 28px;
    }
    .notice strong {
      color: #202124;
    }
    .footer {
      font-size: 11.5px;
      color: #80868b;
      line-height: 1.6;
      border-top: 1px solid #f1f3f4;
      padding-top: 22px;
    }
  </style>
</head>
<body>
  <div class="card">
    <div class="brand">Famalth <span>Lynx</span></div>
    <div class="icon-wrap">
      <svg viewBox="0 0 24 24"><path d="M12 2C6.48 2 2 6.48 2 12s4.48 10 10 10 10-4.48 10-10S17.52 2 12 2zm-2 15l-5-5 1.41-1.41L10 14.17l7.59-7.59L19 8l-9 9z"/></svg>
    </div>
    <h1>You have unsubscribed</h1>
    <div class="desc">
      You will no longer receive non-essential email notifications for:
      <div><span class="email-chip">${displayEmail}</span></div>
    </div>
    <div class="notice">
      <strong>Important account security notice:</strong> Even if you unsubscribe from these emails, you'll continue to receive critical security alerts, OTP verifications, password resets, and regulatory invoices for your account protection.
    </div>
    <div class="footer">
      © 2026 Famalth Technologies, Dehradun, Uttarakhand 248001
    </div>
  </div>
</body>
</html>`;

    res.setHeader('Content-Type', 'text/html; charset=utf-8');
    return res.status(200).send(html);
}

module.exports = { renderUnsubscribePage };
