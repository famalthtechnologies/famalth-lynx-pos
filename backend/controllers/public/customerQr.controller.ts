import { Request, Response } from 'express';

export const renderCustomerQrPage = (req: Request, res: Response) => {
    const { amount, upi_id, payee, note } = req.query as any;
    const upiUri = `upi://pay?pa=${encodeURIComponent(upi_id || '')}&pn=${encodeURIComponent(payee || 'Merchant')}&am=${encodeURIComponent(amount || '0.00')}&cu=INR&tn=${encodeURIComponent(note || 'Payment')}`;
    const qrApiUrl = `https://api.qrserver.com/v1/create-qr-code/?size=300x300&data=${encodeURIComponent(upiUri)}`;

    res.setHeader('Content-Type', 'text/html');
    res.send(`<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="UTF-8">
  <meta name="viewport" content="width=device-width, initial-scale=1.0">
  <title>UPI Scan & Pay</title>
  <style>
    * { margin:0; padding:0; box-sizing: border-box; font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; }
    body { background: #0f172a; color: #fff; min-height: 100vh; display: flex; align-items: center; justify-content: center; padding: 20px; }
    .card { background: #1e293b; border: 1px solid #334155; border-radius: 24px; padding: 32px 24px; max-width: 400px; width: 100%; text-align: center; box-shadow: 0 20px 40px rgba(0,0,0,0.5); }
    .badge { display: inline-block; background: #22c55e20; color: #4ade80; border: 1px solid #22c55e40; padding: 4px 12px; border-radius: 20px; font-size: 12px; font-weight: 600; margin-bottom: 16px; }
    h1 { font-size: 20px; margin-bottom: 6px; }
    .payee { color: #94a3b8; font-size: 14px; margin-bottom: 20px; }
    .amount-box { background: #0f172a; border-radius: 16px; padding: 14px; margin-bottom: 24px; border: 1px dashed #475569; }
    .amount-label { font-size: 12px; color: #94a3b8; }
    .amount { font-size: 32px; font-weight: 800; color: #38bdf8; margin-top: 2px; }
    .qr-container { background: #fff; padding: 16px; border-radius: 20px; display: inline-block; box-shadow: 0 8px 24px rgba(0,0,0,0.3); margin-bottom: 20px; }
    .qr-container img { width: 220px; height: 220px; display: block; border-radius: 8px; }
    .btn { display: block; width: 100%; background: #2563eb; color: #fff; text-decoration: none; padding: 14px; border-radius: 14px; font-weight: 600; font-size: 15px; transition: background 0.2s; margin-top: 10px; }
    .btn:hover { background: #1d4ed8; }
    .footer { margin-top: 20px; font-size: 12px; color: #64748b; }
  </style>
</head>
<body>
  <div class="card">
    <div class="badge">SECURE POS PAYMENT</div>
    <h1>${payee || 'Merchant Store'}</h1>
    <div class="payee">UPI ID: ${upi_id || ''}</div>
    <div class="amount-box">
      <div class="amount-label">AMOUNT TO PAY</div>
      <div class="amount">₹${amount || '0.00'}</div>
    </div>
    <div class="qr-container">
      <img src="${qrApiUrl}" alt="UPI Payment QR Code" />
    </div>
    <a href="${upiUri}" class="btn">⚡ Open UPI App (GPay / PhonePe / Paytm)</a>
    <div class="footer">Scan with any UPI app on your phone. Powered by Famalth LYNX POS.</div>
  </div>
</body>
</html>`);
};

module.exports = { renderCustomerQrPage };
export default { renderCustomerQrPage };
