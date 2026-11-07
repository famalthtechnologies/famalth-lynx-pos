"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.generateInvoicePdf = generateInvoicePdf;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const pdfkit_1 = __importDefault(require("pdfkit"));
/**
 * Generate a beautifully formatted PDF invoice using pdfkit
 * Supports A4, A5, and 80mm Thermal formats honoring designer template rules
 * @param saleHeader Sales Header record
 * @param saleItems Sales Items list
 * @returns Generated PDF bytes buffer
 */
function generateInvoicePdf(saleHeader, saleItems) {
    return new Promise((resolve, reject) => {
        try {
            const possibleFontDirs = [
                path_1.default.resolve(__dirname, '../assets/fonts'),
                path_1.default.resolve(__dirname, '../../assets/fonts'),
                path_1.default.resolve(__dirname, '../../../backend/assets/fonts'),
                path_1.default.resolve(process.cwd(), 'assets/fonts'),
                path_1.default.resolve(process.cwd(), 'backend/assets/fonts'),
            ];
            let fontBoldPath = null;
            let fontRegularPath = null;
            for (const fDir of possibleFontDirs) {
                const b = path_1.default.join(fDir, 'Roboto-Bold.ttf');
                const r = path_1.default.join(fDir, 'Roboto-Regular.ttf');
                if (fs_1.default.existsSync(b) && fs_1.default.existsSync(r)) {
                    fontBoldPath = b;
                    fontRegularPath = r;
                    break;
                }
            }
            // Determine active print format (A4, A5, or THERMAL_80)
            const rawFormat = (saleHeader.bill_format || saleHeader.billFormat || 'A4').toString().trim().toUpperCase();
            const isThermal = rawFormat.includes('80') || rawFormat.includes('THERMAL') || rawFormat.includes('76') || rawFormat.includes('58');
            const isA5 = !isThermal && rawFormat.includes('A5');
            // Pick applicable template configuration
            const tmplConfig = isThermal
                ? (saleHeader.receipt_template_config || {})
                : (isA5 ? (saleHeader.a5_template_config || {}) : (saleHeader.a4_template_config || {}));
            const showBrand = tmplConfig.show_brand ?? (saleHeader.show_brand ?? (saleHeader.showBrandName ?? true));
            const showHsn = tmplConfig.show_hsn_code ?? (saleHeader.show_hsn_code ?? true);
            const showDiscounts = tmplConfig.show_item_discount ?? tmplConfig.show_item_discounts ?? true;
            const showTaxBreakup = tmplConfig.show_tax_breakup ?? true;
            const docOptions = {};
            if (isThermal) {
                // Standard 80mm thermal roll: 80mm = ~226.77 pt
                const thermalWidth = 226.77;
                const estimatedHeight = Math.max(380, 240 + ((saleItems || []).length * 34));
                docOptions.size = [thermalWidth, estimatedHeight];
                docOptions.margin = 10;
            }
            else if (isA5) {
                // A5 sheet: 419.53 x 595.28 pt
                docOptions.size = 'A5';
                docOptions.margin = 22;
            }
            else {
                // A4 standard: 595.28 x 841.89 pt
                docOptions.size = 'A4';
                docOptions.margin = 36;
            }
            if (fontRegularPath) {
                docOptions.font = fontRegularPath;
            }
            const doc = new pdfkit_1.default(docOptions);
            const buffers = [];
            doc.on('data', buffers.push.bind(buffers));
            doc.on('end', () => {
                const pdfData = Buffer.concat(buffers);
                resolve(pdfData);
            });
            let fontBold = 'Helvetica-Bold';
            let fontRegular = 'Helvetica';
            if (fontBoldPath && fontRegularPath) {
                doc.registerFont('Roboto-Bold', fontBoldPath);
                doc.registerFont('Roboto-Regular', fontRegularPath);
                fontBold = 'Roboto-Bold';
                fontRegular = 'Roboto-Regular';
            }
            const pageWidth = doc.page.width;
            const margin = isThermal ? 10 : (isA5 ? 22 : 36);
            const contentWidth = pageWidth - (margin * 2);
            // =========================================================================
            // THERMAL 80MM LAYOUT
            // =========================================================================
            if (isThermal) {
                const storeTitle = (tmplConfig.header_title || saleHeader.outlet_name || `OUTLET #${saleHeader.outlet_id || '1'}`).toString().toUpperCase();
                const invHeading = (tmplConfig.invoice_title || 'TAX INVOICE').toString().toUpperCase();
                const addressText = tmplConfig.header_subtext || saleHeader.outlet_address || '';
                const taxReg = tmplConfig.tax_reg_no || saleHeader.tax_reg_no || '';
                doc.fillColor('#000000').fontSize(11).font(fontBold).text(storeTitle, margin, doc.y, { width: contentWidth, align: 'center' });
                if (addressText) {
                    doc.fontSize(7.5).font(fontRegular).text(addressText, margin, doc.y, { width: contentWidth, align: 'center' });
                }
                if (taxReg) {
                    doc.fontSize(7.5).font(fontBold).text(taxReg, margin, doc.y, { width: contentWidth, align: 'center' });
                }
                doc.moveDown(0.3);
                doc.fontSize(9).font(fontBold).text(invHeading, margin, doc.y, { width: contentWidth, align: 'center' });
                doc.moveDown(0.3);
                // Dashed separator
                doc.fontSize(8).font(fontRegular).text('-'.repeat(44), margin, doc.y, { width: contentWidth, align: 'center' });
                // Metadata
                doc.fontSize(7.5).font(fontRegular);
                doc.text(`Bill: ${saleHeader.sale_no || 'N/A'}`);
                doc.text(`Date: ${new Date(saleHeader.sale_date || Date.now()).toLocaleDateString()} | Mode: ${saleHeader.payment_mode || 'Cash'}`);
                if (saleHeader.customer_name && saleHeader.customer_name !== 'Walk-in Customer') {
                    doc.text(`Customer: ${saleHeader.customer_name}`);
                }
                doc.text('-'.repeat(44), margin, doc.y, { width: contentWidth, align: 'center' });
                // Items list
                for (const item of (saleItems || [])) {
                    const baseName = (item.item_name || item.itemName || item.item_code || item.itemCode || 'Item').toString().trim();
                    const brand = (item.brand || item.item_brand || '').toString().trim();
                    const displayName = (showBrand && brand && !baseName.toLowerCase().startsWith(brand.toLowerCase()))
                        ? `${brand} - ${baseName}`
                        : baseName;
                    const qty = Number(item.qty || 1).toFixed(2);
                    const rate = Number(item.rate || 0).toFixed(2);
                    const lineTotal = Number(item.line_total || (Number(qty) * Number(rate))).toFixed(2);
                    const lineY = doc.y;
                    doc.font(fontBold).fontSize(8).text(displayName, margin, lineY, { width: contentWidth - 55 });
                    doc.text(lineTotal, margin, lineY, { width: contentWidth, align: 'right' });
                    // Detail line
                    const hsnPart = (showHsn && (item.hsn_code || item.hsnSacCode)) ? `HSN ${item.hsn_code || item.hsnSacCode} | ` : '';
                    doc.font(fontRegular).fontSize(7).fillColor('#4b5563');
                    doc.text(`${hsnPart}${qty} x ${rate}`, margin, doc.y);
                    doc.fillColor('#000000');
                    doc.moveDown(0.2);
                }
                doc.fontSize(8).font(fontRegular).text('-'.repeat(44), margin, doc.y, { width: contentWidth, align: 'center' });
                // Totals
                const netAmount = Number(saleHeader.net_amount || saleHeader.total_amount || 0).toFixed(2);
                const subTotal = Number(saleHeader.sub_total || saleHeader.amount || netAmount).toFixed(2);
                doc.fontSize(8).font(fontRegular);
                const subY = doc.y;
                doc.text('Subtotal:', margin, subY);
                doc.text(subTotal, margin, subY, { width: contentWidth, align: 'right' });
                if (showTaxBreakup && saleHeader.tax_amount) {
                    const taxY = doc.y;
                    doc.text('Tax:', margin, taxY);
                    doc.text(Number(saleHeader.tax_amount).toFixed(2), margin, taxY, { width: contentWidth, align: 'right' });
                }
                doc.fontSize(9.5).font(fontBold);
                const netY = doc.y + 2;
                doc.text('NET TOTAL:', margin, netY);
                doc.text(netAmount, margin, netY, { width: contentWidth, align: 'right' });
                doc.moveDown(0.5);
                const footerText = tmplConfig.footer_note || 'Thank you for shopping with us!';
                doc.fontSize(7.5).font(fontRegular).text(footerText, margin, doc.y, { width: contentWidth, align: 'center' });
                doc.end();
                return;
            }
            // =========================================================================
            // A4 / A5 STANDARD TAX INVOICE LAYOUT
            // =========================================================================
            const themeColor = isA5 ? '#0B5CAD' : '#1e3a8a';
            const titleFontSize = isA5 ? 18 : 22;
            const docTitle = (tmplConfig.invoice_title || 'TAX INVOICE').toString().toUpperCase();
            const storeName = tmplConfig.header_title || saleHeader.outlet_name || 'RETAIL POS STORE';
            const storeAddress = tmplConfig.header_subtext || saleHeader.outlet_address || '';
            const taxReg = tmplConfig.tax_reg_no || '';
            // Header Banner
            doc.fillColor(themeColor).fontSize(titleFontSize).font(fontBold).text(docTitle, margin, margin, { width: contentWidth, align: 'right' });
            doc.fillColor('#64748B').fontSize(isA5 ? 8 : 9).font(fontRegular).text(storeName, margin, doc.y, { width: contentWidth, align: 'right' });
            if (storeAddress) {
                doc.text(storeAddress, margin, doc.y, { width: contentWidth, align: 'right' });
            }
            if (taxReg) {
                doc.font(fontBold).text(taxReg, margin, doc.y, { width: contentWidth, align: 'right' });
            }
            doc.moveDown(1.2);
            // Billed From & Billed To
            const startY = doc.y;
            const colWidth = (contentWidth - 20) / 2;
            doc.fillColor('#1F2937').fontSize(isA5 ? 9.5 : 10.5).font(fontBold).text('Billed From:', margin, startY);
            doc.font(fontRegular).fontSize(isA5 ? 8 : 9).text(`Store / Outlet: ${saleHeader.outlet_id || '1'}`);
            doc.text(`Place of Supply: ${saleHeader.billing_country || 'Commercial'}`);
            doc.font(fontBold).fontSize(isA5 ? 9.5 : 10.5).text('Billed To (Customer):', margin + colWidth + 20, startY);
            doc.font(fontRegular).fontSize(isA5 ? 8 : 9).text(`Name: ${saleHeader.customer_name || 'Walk-in Customer'}`);
            if (saleHeader.customer_phone)
                doc.text(`Phone: ${saleHeader.customer_phone}`);
            if (saleHeader.customer_gstin)
                doc.text(`Tax ID: ${saleHeader.customer_gstin}`);
            doc.moveDown(1.5);
            // Transaction Details Strip
            const transY = doc.y;
            doc.rect(margin, transY, contentWidth, isA5 ? 18 : 22).fill('#F8FAFC');
            doc.fillColor('#334155').font(fontBold).fontSize(isA5 ? 7.5 : 8.5);
            doc.text(`Invoice: ${saleHeader.sale_no || 'N/A'}`, margin + 8, transY + (isA5 ? 4 : 6));
            doc.text(`Date: ${new Date(saleHeader.sale_date || Date.now()).toLocaleDateString()}`, margin + (contentWidth * 0.4), transY + (isA5 ? 4 : 6));
            doc.text(`Mode: ${saleHeader.payment_mode || 'Cash'}`, margin + (contentWidth * 0.75), transY + (isA5 ? 4 : 6));
            doc.y = transY + (isA5 ? 24 : 28);
            // Table Columns layout
            let currentY = doc.y;
            const hsnWidth = showHsn ? (isA5 ? 55 : 70) : 0;
            const qtyWidth = isA5 ? 40 : 50;
            const rateWidth = isA5 ? 60 : 75;
            const totalWidth = isA5 ? 65 : 85;
            const descWidth = contentWidth - hsnWidth - qtyWidth - rateWidth - totalWidth;
            // Table Header
            doc.rect(margin, currentY, contentWidth, isA5 ? 18 : 20).fill(themeColor);
            doc.fillColor('#FFFFFF').font(fontBold).fontSize(isA5 ? 8 : 9);
            let curX = margin + 6;
            doc.text('Item Description', curX, currentY + 5, { width: descWidth });
            curX += descWidth;
            if (showHsn) {
                doc.text('HSN/SAC', curX, currentY + 5, { width: hsnWidth });
                curX += hsnWidth;
            }
            doc.text('Qty', curX, currentY + 5, { width: qtyWidth, align: 'center' });
            curX += qtyWidth;
            doc.text('Rate', curX, currentY + 5, { width: rateWidth, align: 'right' });
            curX += rateWidth;
            doc.text('Amount', curX, currentY + 5, { width: totalWidth - 6, align: 'right' });
            currentY += isA5 ? 18 : 20;
            // Table Data Rows
            doc.fillColor('#374151').font(fontRegular).fontSize(isA5 ? 7.5 : 8.5);
            let index = 0;
            for (const item of (saleItems || [])) {
                const rowHeight = isA5 ? 18 : 20;
                if (index % 2 === 1) {
                    doc.rect(margin, currentY, contentWidth, rowHeight).fill('#F8FAFC');
                    doc.fillColor('#374151');
                }
                const baseName = (item.item_name || item.itemName || item.item_code || item.itemCode || 'Item').toString().trim();
                const brand = (item.brand || item.item_brand || '').toString().trim();
                const displayName = (showBrand && brand && !baseName.toLowerCase().startsWith(brand.toLowerCase()))
                    ? `${brand} - ${baseName}`
                    : baseName;
                const qty = Number(item.qty || 1).toFixed(2);
                const rate = Number(item.rate || 0).toFixed(2);
                const lineTotal = Number(item.line_total || (Number(qty) * Number(rate))).toFixed(2);
                const hsnVal = (item.hsn_code || item.hsnSacCode || '--').toString().trim();
                let rx = margin + 6;
                doc.text(displayName, rx, currentY + 4, { width: descWidth, lineBreak: false });
                rx += descWidth;
                if (showHsn) {
                    doc.text(hsnVal, rx, currentY + 4, { width: hsnWidth });
                    rx += hsnWidth;
                }
                doc.text(qty, rx, currentY + 4, { width: qtyWidth, align: 'center' });
                rx += qtyWidth;
                doc.text(rate, rx, currentY + 4, { width: rateWidth, align: 'right' });
                rx += rateWidth;
                doc.text(lineTotal, rx, currentY + 4, { width: totalWidth - 6, align: 'right' });
                currentY += rowHeight;
                index++;
            }
            doc.y = currentY + 12;
            // Totals Box
            const totalsBoxWidth = isA5 ? 180 : 220;
            const totalsBoxX = margin + contentWidth - totalsBoxWidth;
            const totalsBoxY = doc.y;
            doc.rect(totalsBoxX, totalsBoxY, totalsBoxWidth, isA5 ? 54 : 64).fill('#F8FAFC');
            doc.fillColor('#1E293B').font(fontBold).fontSize(isA5 ? 8 : 9);
            const netAmount = Number(saleHeader.net_amount || saleHeader.total_amount || 0).toFixed(2);
            const subTotal = Number(saleHeader.sub_total || saleHeader.amount || netAmount).toFixed(2);
            doc.text('Subtotal:', totalsBoxX + 10, totalsBoxY + 8);
            doc.text(subTotal, totalsBoxX + 10, totalsBoxY + 8, { width: totalsBoxWidth - 20, align: 'right' });
            if (showTaxBreakup && saleHeader.tax_amount) {
                doc.font(fontRegular).fontSize(isA5 ? 7.5 : 8.5);
                doc.text('Tax:', totalsBoxX + 10, totalsBoxY + (isA5 ? 22 : 26));
                doc.text(Number(saleHeader.tax_amount).toFixed(2), totalsBoxX + 10, totalsBoxY + (isA5 ? 22 : 26), { width: totalsBoxWidth - 20, align: 'right' });
            }
            doc.fontSize(isA5 ? 9.5 : 11).fillColor('#15803D').font(fontBold);
            doc.text('Net Total:', totalsBoxX + 10, totalsBoxY + (isA5 ? 36 : 42));
            doc.text(netAmount, totalsBoxX + 10, totalsBoxY + (isA5 ? 36 : 42), { width: totalsBoxWidth - 20, align: 'right' });
            // Bank settlement & Terms note
            const notesY = totalsBoxY;
            const notesWidth = contentWidth - totalsBoxWidth - 16;
            if (notesWidth > 100) {
                doc.fillColor('#64748B').fontSize(isA5 ? 7 : 8).font(fontRegular);
                const bankInfo = tmplConfig.bank_name ? `Bank: ${tmplConfig.bank_name} | Acc: ${tmplConfig.bank_account_no || '--'}` : '';
                const termsInfo = tmplConfig.terms_and_conditions || 'Goods once sold will not be accepted back without inspection.';
                if (bankInfo) {
                    doc.text(bankInfo, margin, notesY, { width: notesWidth });
                }
                doc.text(termsInfo, margin, notesY + (bankInfo ? 14 : 0), { width: notesWidth });
            }
            // Footer note
            const footerText = tmplConfig.footer_note || 'Thank you for your business! This is a computer generated invoice record.';
            doc.fillColor('#94A3B8').fontSize(isA5 ? 7 : 7.5).font(fontRegular).text(footerText, margin, doc.page.height - (isA5 ? 24 : 34), { align: 'center', width: contentWidth });
            doc.end();
        }
        catch (e) {
            reject(e);
        }
    });
}
exports.default = {
    generateInvoicePdf
};
