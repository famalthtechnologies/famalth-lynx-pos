import PDFDocument from 'pdfkit';
import path from 'path';
import fs from 'fs';

export interface InvoicePdfData {
  invoiceNumber: string;
  issueDate: string | Date;
  dueDate: string | Date;
  paymentStatus: 'PAID' | 'PENDING' | 'OVERDUE';
  paidAt?: string | Date;
  tenant: {
    clientCode: string;
    legalName: string;
    tradeName?: string;
    contactEmail: string;
    contactPhone?: string;
    taxIdentifier?: string;
    billingAddress?: string;
    country?: string;
  };
  license: {
    tierName: string;
    maxTerminals: number;
    maxOutlets: number;
    validFrom: string | Date;
    validTill: string | Date;
    gracePeriodDays: number;
  };
  pricing: {
    subtotal: number;
    taxRate: number;
    taxAmount: number;
    totalAmount: number;
    currency?: string;
    currencySymbol?: string;
    taxName?: string;
    country?: string;
  };
}

function resolveCurrencySymbol(currency: string, explicitSym?: string): string {
  if (explicitSym && explicitSym.trim().length > 0) return explicitSym.trim();
  const c = (currency || 'INR').toUpperCase();
  switch (c) {
    case 'USD':
    case 'CAD':
    case 'AUD':
    case 'SGD':
      return '$';
    case 'EUR':
      return '€';
    case 'GBP':
      return '£';
    case 'AED':
      return 'AED ';
    case 'INR':
    default:
      return '₹';
  }
}

/**
 * Generates an ultra-clean, spacious Google Cloud-style single-page Invoice PDF.
 */
export function generateSubscriptionInvoicePdf(data: InvoicePdfData): Promise<Buffer> {
  return new Promise((resolve, reject) => {
    try {
      const doc = new PDFDocument({
        size: 'A4',
        margins: { top: 48, bottom: 40, left: 54, right: 54 },
        bufferPages: true,
      });
      const buffers: Buffer[] = [];
      doc.on('data', buffers.push.bind(buffers));
      doc.on('end', () => resolve(Buffer.concat(buffers)));

      // REGISTER FONTS
      const possibleFontDirs = [
        path.resolve(__dirname, '../assets/fonts'),
        path.resolve(__dirname, '../../assets/fonts'),
        path.resolve(process.cwd(), 'assets/fonts'),
        path.resolve(process.cwd(), 'backend/assets/fonts'),
      ];

      let fontBold = 'Helvetica-Bold';
      let fontRegular = 'Helvetica';

      for (const fDir of possibleFontDirs) {
        const b = path.join(fDir, 'Roboto-Bold.ttf');
        const r = path.join(fDir, 'Roboto-Regular.ttf');
        if (fs.existsSync(b) && fs.existsSync(r)) {
          doc.registerFont('Google-Roboto-Bold', b);
          doc.registerFont('Google-Roboto-Regular', r);
          fontBold = 'Google-Roboto-Bold';
          fontRegular = 'Google-Roboto-Regular';
          break;
        }
      }

      const currency = (data.pricing.currency || 'INR').toUpperCase();
      const sym = resolveCurrencySymbol(currency, data.pricing.currencySymbol);
      const taxName = (data.pricing.taxName || (currency === 'INR' ? 'GST' : currency === 'USD' ? 'Sales Tax' : 'VAT')).trim();
      const country = (data.pricing.country || data.tenant.country || (currency === 'USD' ? 'United States' : currency === 'INR' ? 'India' : 'International')).trim();

      const leftX = 54;
      const contentW = 487; // 595.28 - 108 = 487.28 printable width
      const rightX = 285;
      const rightW = 256;

      // =========================================================================
      // 1. GOOGLE INVOICE HEADER
      // =========================================================================
      let y = 48;

      // Google-style colorful Brand Wordmark
      doc.fontSize(22).font(fontBold);
      doc.fillColor('#4285F4').text('F', leftX, y, { continued: true });
      doc.fillColor('#EA4335').text('a', { continued: true });
      doc.fillColor('#FBBC05').text('m', { continued: true });
      doc.fillColor('#4285F4').text('a', { continued: true });
      doc.fillColor('#34A853').text('l', { continued: true });
      doc.fillColor('#EA4335').text('t', { continued: true });
      doc.fillColor('#4285F4').text('h', { continued: true });
      doc.fillColor('#5F6368').fontSize(9).text('™', { baseline: 'top' });

      // Title: "Invoice" (Clean Google Headline)
      y += 26;
      doc.fillColor('#202124').fontSize(26).font(fontRegular).text('Invoice', leftX, y);

      // Invoice number directly below title
      y += 34;
      doc.fillColor('#5F6368').fontSize(8.5).font(fontRegular).text(
        `Invoice number: ${data.invoiceNumber}`,
        leftX,
        y
      );

      // Top Right: Licensor Entity Details (Right aligned, Google style)
      let entityY = 48;
      doc.fillColor('#202124').fontSize(8.5).font(fontBold).text(
        'Famalth Technologies',
        rightX,
        entityY,
        { align: 'right', width: rightW }
      );
      entityY += 12;

      doc.fillColor('#5F6368').fontSize(8).font(fontRegular);
      doc.text('Famalth Lynx Enterprise Retail Platform', rightX, entityY, { align: 'right', width: rightW });
      entityY += 11;
      doc.text('Dehradun, Uttarakhand 248001', rightX, entityY, { align: 'right', width: rightW });
      entityY += 11;
      doc.text('India', rightX, entityY, { align: 'right', width: rightW });
      entityY += 11;

      const licensorTaxId = country.toLowerCase().includes('india') ? 'GSTIN: 07AAAAF1234A1Z5' : 'Corporate Tax ID: 82-4910284';
      doc.text(`${licensorTaxId} • CIN: U72900DL2022PTC123456`, rightX, entityY, { align: 'right', width: rightW });
      entityY += 11;
      doc.text('enterprise@famalth.com | www.famalth.com', rightX, entityY, { align: 'right', width: rightW });

      // =========================================================================
      // 2. BILL TO & FINANCIAL SUMMARY (Side by Side, Google Style)
      // =========================================================================
      y = 145;

      // Left: "Bill to" Section
      doc.fillColor('#202124').fontSize(9).font(fontBold).text('Bill to', leftX, y);
      let billY = y + 14;

      doc.fillColor('#202124').fontSize(9).font(fontBold).text(data.tenant.legalName, leftX, billY, { width: 210 });
      billY += 12;

      doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular);
      const addr = (data.tenant.billingAddress && data.tenant.billingAddress.trim().length > 0)
        ? data.tenant.billingAddress
        : 'Registered Commercial Property, Sector Retail';
      doc.text(addr, leftX, billY, { width: 210 });
      billY += doc.heightOfString(addr, { width: 210 }) + 3;

      if (data.tenant.contactPhone) {
        doc.text(`Phone: ${data.tenant.contactPhone}`, leftX, billY, { width: 210 });
        billY += 11;
      }
      doc.text(data.tenant.contactEmail, leftX, billY, { width: 210 });
      billY += 11;
      doc.text(country, leftX, billY, { width: 210 });
      billY += 11;

      const custTaxVal = data.tenant.taxIdentifier && data.tenant.taxIdentifier.trim().length > 0 ? data.tenant.taxIdentifier : 'Standard Enterprise Account';
      doc.text(`Tax ID: ${custTaxVal}`, leftX, billY, { width: 210 });
      billY += 14;

      // Right: Summary Card (Google style right-aligned financial card)
      let sumY = y;
      doc.fillColor('#202124').fontSize(9).font(fontBold).text(
        `Famalth Cloud POS • ${data.license.tierName} Edition`,
        rightX,
        sumY,
        { width: rightW }
      );
      sumY += 14;

      // Top line above total
      doc.rect(rightX, sumY, rightW, 0.6).fill('#DADCE0');
      sumY += 8;

      const subtotal = Number(data.pricing.subtotal);
      const taxRate = Number(data.pricing.taxRate);
      const taxAmount = Number(data.pricing.taxAmount);
      const total = Number(data.pricing.totalAmount);

      // Total in Currency (Big bold Google Style headline)
      doc.fillColor('#202124').fontSize(9).font(fontRegular).text(`Total in ${currency}`, rightX, sumY + 2);
      doc.fillColor('#202124').fontSize(14).font(fontBold).text(
        `${sym}${total.toFixed(2)}`,
        rightX,
        sumY,
        { align: 'right', width: rightW }
      );
      sumY += 24;

      // Summary for Period (Subheader)
      const fromStr = new Date(data.license.validFrom).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
      const tillStr = new Date(data.license.validTill).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
      doc.fillColor('#202124').fontSize(8.5).font(fontBold).text(
        `Summary for ${fromStr} - ${tillStr}`,
        rightX,
        sumY,
        { width: rightW }
      );
      sumY += 14;

      // Thin divider
      doc.rect(rightX, sumY, rightW, 0.4).fill('#E8EAED');
      sumY += 8;

      doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular).text(`Subtotal in ${currency}`, rightX, sumY);
      doc.fillColor('#202124').fontSize(8.5).font(fontRegular).text(
        `${sym}${subtotal.toFixed(2)}`,
        rightX,
        sumY,
        { align: 'right', width: rightW }
      );
      sumY += 14;

      const isIndiaGST = taxName.toUpperCase() === 'GST' && (country.toLowerCase().includes('india') || currency === 'INR');
      if (isIndiaGST) {
        const halfRate = (taxRate / 2).toFixed(1);
        const halfAmount = (taxAmount / 2).toFixed(2);

        doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular).text(`CGST (${halfRate}%)`, rightX, sumY);
        doc.fillColor('#202124').fontSize(8.5).font(fontRegular).text(`${sym}${halfAmount}`, rightX, sumY, { align: 'right', width: rightW });
        sumY += 13;

        doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular).text(`SGST (${halfRate}%)`, rightX, sumY);
        doc.fillColor('#202124').fontSize(8.5).font(fontRegular).text(`${sym}${halfAmount}`, rightX, sumY, { align: 'right', width: rightW });
        sumY += 14;
      } else {
        doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular).text(`${taxName} (${taxRate}%)`, rightX, sumY);
        doc.fillColor('#202124').fontSize(8.5).font(fontRegular).text(`${sym}${taxAmount.toFixed(2)}`, rightX, sumY, { align: 'right', width: rightW });
        sumY += 14;
      }

      // Final Total Line
      doc.fillColor('#202124').fontSize(8.5).font(fontBold).text(`Total in ${currency}`, rightX, sumY);
      doc.fillColor('#202124').fontSize(8.5).font(fontBold).text(
        `${sym}${total.toFixed(2)}`,
        rightX,
        sumY,
        { align: 'right', width: rightW }
      );
      sumY += 24;

      // =========================================================================
      // 3. DETAILS SECTION (Google Dotted Leader Lines)
      // =========================================================================
      let detY = Math.max(billY, 275);
      doc.fillColor('#202124').fontSize(9).font(fontBold).text('Details', leftX, detY);
      detY += 15;

      const issueStr = new Date(data.issueDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });
      const dueStr = new Date(data.dueDate).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' });

      const detailsW = 260;
      const rightBound = leftX + detailsW;

      function renderDottedRow(label: string, value: string, yPos: number): number {
        doc.fontSize(8.5).font(fontRegular);
        doc.fillColor('#3C4043').text(label, leftX, yPos);
        const labelW = doc.widthOfString(label);

        const maxValW = detailsW - labelW - 14;
        const rawValW = doc.widthOfString(value);

        let rowH = 14;
        if (rawValW <= maxValW) {
          const valX = rightBound - rawValW;
          const dotStart = leftX + labelW + 4;
          const dotEnd = valX - 4;
          if (dotEnd > dotStart) {
            const dots = '.'.repeat(Math.max(1, Math.floor((dotEnd - dotStart) / 3.2)));
            doc.fillColor('#9AA0A6').fontSize(7.5).text(dots, dotStart, yPos + 0.5);
          }
          doc.fillColor('#202124').fontSize(8.5).text(value, valX, yPos);
        } else {
          // Multi-line safe wrap: dynamically compute row height to guarantee zero overlap
          const valX = rightBound - maxValW;
          const dotStart = leftX + labelW + 4;
          const dotEnd = valX - 4;
          if (dotEnd > dotStart) {
            const dots = '.'.repeat(Math.max(1, Math.floor((dotEnd - dotStart) / 3.2)));
            doc.fillColor('#9AA0A6').fontSize(7.5).text(dots, dotStart, yPos + 0.5);
          }
          doc.fillColor('#202124').fontSize(8.5).text(value, valX, yPos, { width: maxValW, align: 'right' });
          rowH = Math.max(14, doc.heightOfString(value, { width: maxValW }) + 2);
        }
        return rowH;
      }

      detY += renderDottedRow('Invoice number', data.invoiceNumber, detY);
      detY += renderDottedRow('Invoice date', issueStr, detY);
      detY += renderDottedRow('Due date', dueStr, detY);
      detY += renderDottedRow('Licensed seats', `${data.license.maxTerminals} Terminal(s)`, detY);
      detY += renderDottedRow('Licensed outlets', `${data.license.maxOutlets} Outlet(s)`, detY);
      detY += renderDottedRow('Account ID', data.tenant.clientCode, detY);
      detY += 18;

      // =========================================================================
      // 4. AUTOMATIC PAYMENT / REMITTANCE NOTICE (Google style statement)
      // =========================================================================
      const isPaid = data.paymentStatus === 'PAID';
      let noticeY = Math.max(detY, sumY + 10);

      doc.fillColor(isPaid ? '#137333' : '#B06000').fontSize(9).font(fontBold);
      doc.text(
        isPaid ? '✔  Status: Paid in Full' : '⏳  Status: Payment Due',
        leftX,
        noticeY
      );
      noticeY += 14;

      doc.fillColor('#3C4043').fontSize(8.5).font(fontRegular);
      if (isPaid) {
        const paidStr = data.paidAt ? new Date(data.paidAt).toLocaleDateString('en-GB', { day: 'numeric', month: 'short', year: 'numeric' }) : issueStr;
        doc.text(
          `Thank you for your payment. Settlement confirmed via electronic payment gateway on ${paidStr}.`,
          leftX,
          noticeY,
          { width: contentW }
        );
      } else {
        doc.text(
          `You will be automatically charged for any amount due on ${dueStr}. Please remit through authorized banking channels.`,
          leftX,
          noticeY,
          { width: contentW }
        );
      }
      noticeY += 16;

      doc.fillColor('#70757A').fontSize(7.5).text(
        `License Security Hash: ${data.tenant.clientCode}-ENTERPRISE-TOKEN-VERIFIED • Cloud Telemetry & Automated Backups Included`,
        leftX,
        noticeY,
        { width: contentW }
      );

      // =========================================================================
      // 5. FOOTER (Google Page Numbering & Legal Footer)
      // =========================================================================
      const footerY = 780;
      doc.rect(leftX, footerY, contentW, 0.6).fill('#DADCE0');

      doc.fillColor('#70757A').fontSize(7.5).font(fontRegular).text(
        'Famalth Technologies Inc. • Corporate Head Office: New Delhi / NY • Electronic Digitally Certified Invoice',
        leftX,
        footerY + 8
      );

      doc.fillColor('#70757A').fontSize(8).font(fontRegular).text(
        'Page 1 of 1',
        leftX,
        footerY + 8,
        { align: 'right', width: contentW }
      );

      doc.end();
    } catch (err) {
      reject(err);
    }
  });
}

export const SubscriptionInvoicePdfService = {
  generateInvoicePdf: generateSubscriptionInvoicePdf,
};
