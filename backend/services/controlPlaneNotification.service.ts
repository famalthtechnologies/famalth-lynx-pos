import { sendEmail } from '../modules/emailService';
import { generateSubscriptionInvoicePdf } from './subscriptionInvoicePdf.service';
import initMasterModels from '../models/master';

export class ControlPlaneNotificationService {
  /**
   * Helper to format currency
   */
  private static formatCurrency(amount: number | string, symbol = '₹'): string {
    const num = Number(amount) || 0;
    return `${symbol}${num.toLocaleString('en-IN', { minimumFractionDigits: 2, maximumFractionDigits: 2 })}`;
  }

  /**
   * Helper to safely extract recipient email
   */
  private static getRecipientEmail(tenant: any): string | null {
    const email = tenant?.contact_email || tenant?.billing_email || tenant?.custom_metadata?.contact_email;
    if (email && typeof email === 'string' && email.includes('@') && !email.toLowerCase().includes('example.com')) {
      return email.trim();
    }
    return null;
  }

  // In-memory daily cache to guarantee zero duplicate sends across rapid or concurrent calls
  private static readonly inMemoryDailyCache = new Map<string, number>();

  /**
   * Universal Daily Email Guard:
   * Ensures that alert / automated notification emails are sent at most ONCE PER DAY per tenant.
   * Prevents emails repeating every minute or hour.
   */
  public static canSendDailyNotification(tenant: any, notificationType: string): boolean {
    const tenantId = String(tenant?.id || tenant?.client_code || '');
    if (!tenantId) return true;

    const now = Date.now();
    const todayStr = new Date().toISOString().slice(0, 10); // YYYY-MM-DD
    const memoryKey = `${tenantId}:${notificationType}:${todayStr}`;

    // 1. In-memory check: if sent today or within the last 20 hours
    const lastMemoryTimestamp = this.inMemoryDailyCache.get(memoryKey);
    if (lastMemoryTimestamp && (now - lastMemoryTimestamp) < 20 * 60 * 60 * 1000) {
      console.log(`⏳ [DAILY RATE LIMIT] ${notificationType} blocked for tenant ${tenant?.client_code || tenantId}. Already sent today in memory.`);
      return false;
    }

    // 2. Persistent database metadata check
    const meta = tenant?.custom_metadata || {};
    const dailyTracker = meta.daily_notifications || {};
    const record = dailyTracker[notificationType];

    if (record) {
      const isSameDay = record.date === todayStr;
      const isWithin20Hours = record.timestamp && (now - Number(record.timestamp)) < 20 * 60 * 60 * 1000;
      if (isSameDay || isWithin20Hours) {
        console.log(`⏳ [DAILY RATE LIMIT] ${notificationType} blocked for tenant ${tenant?.client_code || tenantId}. Sent on ${record.date} at ${new Date(record.timestamp).toISOString()}. Only 1 email per day allowed.`);
        return false;
      }
    }

    return true;
  }

  /**
   * Records that a notification was sent today, persisting to memory and database
   */
  public static async recordDailyNotificationSent(
    propertyDb: any,
    tenant: any,
    notificationType: string,
    extraData?: Record<string, any>
  ): Promise<void> {
    const tenantId = String(tenant?.id || '');
    if (!tenantId) return;

    const now = Date.now();
    const todayStr = new Date().toISOString().slice(0, 10);
    const memoryKey = `${tenantId}:${notificationType}:${todayStr}`;

    // Record in memory immediately
    this.inMemoryDailyCache.set(memoryKey, now);

    // Prune entries older than 48 hours to prevent memory leaks
    for (const [k, ts] of this.inMemoryDailyCache.entries()) {
      if (now - ts > 48 * 60 * 60 * 1000) {
        this.inMemoryDailyCache.delete(k);
      }
    }

    // Record in database custom_metadata
    try {
      const meta = tenant.custom_metadata ? JSON.parse(JSON.stringify(tenant.custom_metadata)) : {};
      meta.daily_notifications = meta.daily_notifications || {};
      meta.daily_notifications[notificationType] = {
        date: todayStr,
        timestamp: now,
        iso: new Date().toISOString(),
        ...(extraData || {}),
      };

      tenant.custom_metadata = meta;
      if (typeof tenant.changed === 'function') {
        tenant.changed('custom_metadata', true);
      }
      if (typeof tenant.save === 'function') {
        await tenant.save();
      }

      // Direct SQL update safeguard to ensure PostgreSQL JSONB writes immediately
      if (propertyDb && typeof propertyDb.query === 'function') {
        await propertyDb.query(
          `UPDATE master_tenants SET custom_metadata = :meta WHERE id = :id`,
          {
            replacements: { meta: JSON.stringify(meta), id: tenantId },
            type: (propertyDb.QueryTypes || {}).UPDATE,
          }
        ).catch((e: any) => console.warn('[DAILY TRACKER SQL SAVE WARNING]', e.message));
      }
    } catch (err: any) {
      console.error('[DAILY TRACKER RECORD ERROR]', err.message);
    }
  }

  /**
   * 1. On Assign RM: Send notification email introducing assigned RM
   */
  public static async notifyRelationshipManagerAssigned(tenant: any, rm: any): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) {
        console.warn(`[NOTIFY RM] No valid recipient email found for tenant ${tenant?.legal_name || tenant?.id}. Email bypassed.`);
        return false;
      }

      const clientName = tenant.legal_name || 'Valued Partner';
      const clientCode = tenant.client_code || '';
      const rmName = rm.full_name || rm.name || 'Account Specialist';
      const rmDesignation = rm.designation || 'Dedicated Key Account Manager';
      const rmPhone = rm.phone || '';
      const rmWhatsApp = rm.whatsapp_number || rmPhone;
      const cleanWa = rmWhatsApp.replace(/\+/g, '').replace(/ /g, '').replace(/-/g, '');
      const rmEmail = rm.email || 'care@famalth.com';
      const rmCode = rm.rm_code || '';

      const subject = `Dedicated Relationship Manager Assigned - ${clientName} (${clientCode})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); padding: 28px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">PRIORITY ACCOUNT SUPPORT</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700; letter-spacing: 0.5px;">Dedicated Relationship Manager Assigned</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">Famalth Lynx Account Management & Priority Operations for ${clientName}</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              We are pleased to introduce your dedicated Relationship Manager who will oversee your <strong>Famalth Lynx</strong> enterprise account, POS terminals, billing questions, and priority operational escalations.
            </p>

            <div style="background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 18px; margin: 20px 0;">
              <table style="width: 100%; border-collapse: collapse;">
                <tr>
                  <td style="width: 52px; vertical-align: top;">
                    <div style="width: 44px; height: 44px; border-radius: 50%; background: #e0f2fe; color: #0284c7; font-size: 20px; font-weight: bold; text-align: center; line-height: 44px;">
                      ${rmName.charAt(0).toUpperCase()}
                    </div>
                  </td>
                  <td style="vertical-align: top; padding-left: 12px;">
                    <div style="font-size: 16px; font-weight: 700; color: #0f172a;">${rmName}</div>
                    <div style="font-size: 12.5px; color: #059669; font-weight: 600; margin-top: 2px;">${rmDesignation} ${rmCode ? `• <span style="background: #e2e8f0; color: #334155; padding: 2px 6px; border-radius: 4px; font-size: 11px;">${rmCode}</span>` : ''}</div>
                    <div style="margin-top: 10px; font-size: 13px; color: #475569;">
                      <div>📞 <strong>Phone:</strong> <a href="tel:${rmPhone}" style="color: #0284c7; text-decoration: none;">${rmPhone}</a></div>
                      <div style="margin-top: 3px;">✉️ <strong>Email:</strong> <a href="mailto:${rmEmail}" style="color: #0284c7; text-decoration: none;">${rmEmail}</a></div>
                      ${cleanWa ? `<div style="margin-top: 3px;">💬 <strong>WhatsApp:</strong> <a href="https://wa.me/${cleanWa}" style="color: #10b981; text-decoration: none; font-weight: 600;">Chat on WhatsApp</a></div>` : ''}
                    </div>
                  </td>
                </tr>
              </table>
            </div>

            <div style="text-align: center; margin: 24px 0 10px 0;">
              ${cleanWa ? `
                <a href="https://wa.me/${cleanWa}" style="display: inline-block; background: #10b981; color: #ffffff; padding: 10px 20px; border-radius: 6px; font-weight: 600; font-size: 13px; text-decoration: none; margin-right: 8px;">Direct WhatsApp</a>
              ` : ''}
              <a href="mailto:${rmEmail}" style="display: inline-block; background: #0284c7; color: #ffffff; padding: 10px 20px; border-radius: 6px; font-weight: 600; font-size: 13px; text-decoration: none;">Email RM</a>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 22px; border-top: 1px solid #e2e8f0; padding-top: 14px;">
              Client Code: <strong>${clientCode}</strong> • Registered Business: <strong>${clientName}</strong>
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html);
      console.log(`✅ [NOTIFY RM] Assigned RM notification sent to ${recipient} for ${clientName}.`);
      return true;
    } catch (err: any) {
      console.error('[NOTIFY RM ERROR]', err.message);
      return false;
    }
  }

  /**
   * 2. On Extend Expiry: Send confirmation of license validity extension
   */
  public static async notifyLicenseExpiryExtended(
    tenant: any,
    license: any,
    daysExtended: number,
    targetValidTill: Date | string
  ): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) return false;

      const clientName = tenant.legal_name || 'Valued Client';
      const clientCode = tenant.client_code || '';
      const validTillStr = targetValidTill instanceof Date
        ? targetValidTill.toISOString().split('T')[0]
        : String(targetValidTill).split('T')[0];

      const subject = `Software License Extended by +${daysExtended} Days - ${clientName} (${clientCode})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #10b981 0%, #047857 100%); padding: 26px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">SUBSCRIPTION EXTENDED</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700;">Software Expiry Extended</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">+${daysExtended} Days added to your Famalth Lynx subscription</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              Your <strong>Famalth Lynx</strong> software license validity for <strong>${clientName}</strong> has been successfully extended. Your POS terminals and cloud sync will continue operating without interruption.
            </p>

            <div style="background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 16px; margin: 18px 0;">
              <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Extended Duration:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #047857;">+${daysExtended} Days</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">New Expiry Date:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #0f172a;">${validTillStr}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">License Tier / Seats:</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${license.tier_name || 'ENTERPRISE'} (${license.max_outlets || 1} Outlets, ${license.max_terminals || 3} Terminals)</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Subscription Status:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #10b981;">ACTIVE</td>
                </tr>
              </table>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 18px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              Client Code: <strong>${clientCode}</strong> • Thank you for your continued partnership.
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html);
      console.log(`✅ [NOTIFY EXTENSION] Expiry extension email sent to ${recipient} for ${clientName}.`);
      return true;
    } catch (err: any) {
      console.error('[NOTIFY EXTENSION ERROR]', err.message);
      return false;
    }
  }

  /**
   * 3. On 10 Days Before Expiry: Send renewal Tax Invoice with breakdown and optional PDF attachment
   */
  public static async notifyRenewalInvoice(
    tenant: any,
    license: any,
    invoice: any,
    pdfBuffer?: Buffer
  ): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) return false;

      // Daily Email Guard: Send at most once per day per tenant
      if (!this.canSendDailyNotification(tenant, 'RENEWAL_10D')) {
        return false;
      }

      const clientName = tenant.legal_name || 'Valued Client';
      const clientCode = tenant.client_code || '';
      const invNum = invoice.invoice_number || `INV-${Date.now()}`;
      const subtotal = Number(invoice.subtotal || license.subscription_amount || 4999.00);
      const taxRate = Number(invoice.tax_rate || license.tax_percentage || 18.00);
      const taxAmount = Number(invoice.tax_amount || (subtotal * (taxRate / 100)));
      const totalAmount = Number(invoice.total_amount || (subtotal + taxAmount));
      const dueDate = invoice.due_date || license.next_payment_date || license.valid_till;
      const validTill = license.valid_till;

      const attachments: any[] = [];
      if (pdfBuffer && Buffer.isBuffer(pdfBuffer)) {
        attachments.push({
          filename: `Tax-Invoice-${invNum}.pdf`,
          content: pdfBuffer,
          contentType: 'application/pdf',
        });
      }

      const appBaseUrl = process.env.APP_URL || process.env.PUBLIC_URL || 'http://localhost:5000';
      const downloadUrl = `${appBaseUrl}/api/v1/control-plane/invoices/download/${tenant.id}`;

      const subject = `Upcoming License Renewal & Tax Invoice - ${clientName} (${invNum})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #0284c7 0%, #1e40af 100%); padding: 26px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">RENEWAL NOTICE</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700;">Upcoming Subscription Renewal</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">10 Days remaining until Famalth Lynx license expiry</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              Your <strong>Famalth Lynx</strong> software subscription for <strong>${clientName}</strong> is scheduled for renewal on <strong>${validTill}</strong>. Your official Tax Invoice <strong>${invNum}</strong> has been generated.
            </p>

            <div style="background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 18px; margin: 18px 0;">
              <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Invoice Number:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #0284c7;">${invNum}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Payment Due Date:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #dc2626;">${dueDate}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Plan Subscription Amount:</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${this.formatCurrency(subtotal)}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Tax (${taxRate}% GST):</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${this.formatCurrency(taxAmount)}</td>
                </tr>
                <tr style="border-top: 1.5px dashed #cbd5e1;">
                  <td style="padding: 10px 0 4px 0; font-size: 14.5px; font-weight: 700; color: #0f172a;">Total Payable:</td>
                  <td style="padding: 10px 0 4px 0; font-size: 15px; font-weight: 800; color: #047857;">${this.formatCurrency(totalAmount)}</td>
                </tr>
              </table>
            </div>

            <div style="text-align: center; margin: 24px 0 10px 0;">
              <a href="${downloadUrl}" style="display: inline-block; background: #0284c7; color: #ffffff; padding: 11px 24px; border-radius: 6px; font-weight: 600; font-size: 13.5px; text-decoration: none;">Download Tax Invoice (PDF)</a>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 20px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              Client Code: <strong>${clientCode}</strong> • Please process your payment before the due date to ensure smooth retail billing.
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html, attachments);
      console.log(`✅ [NOTIFY 10D INVOICE] 10-day renewal invoice email sent to ${recipient} for ${clientName}.`);
      await this.recordDailyNotificationSent(undefined, tenant, 'RENEWAL_10D', {
        invoiceNumber: invNum,
        valid_till: validTill,
      });
      return true;
    } catch (err: any) {
      console.error('[NOTIFY 10D INVOICE ERROR]', err.message);
      return false;
    }
  }

  /**
   * 4. On Expired: Send urgent license expiration notice
   */
  public static async notifyLicenseExpired(tenant: any, license: any): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) return false;

      // Daily Email Guard: Send expired alert at most once per day per tenant
      if (!this.canSendDailyNotification(tenant, 'EXPIRED_ALERT')) {
        return false;
      }

      const clientName = tenant.legal_name || 'Valued Client';
      const clientCode = tenant.client_code || '';
      const validTill = license.valid_till || 'Recently';
      const graceDays = license.grace_period_days || 15;
      const subtotal = Number(license.subscription_amount || 4999.00);
      const taxRate = Number(license.tax_percentage || 18.00);
      const totalAmount = Number((subtotal * (1 + taxRate / 100)).toFixed(2));

      const subject = `Software Subscription Expired - ${clientName} (${clientCode})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #fecaca; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #dc2626 0%, #991b1b 100%); padding: 26px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">SUBSCRIPTION ALERT</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700;">Software Subscription Expired</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">Grace Period Active (${graceDays} Days Buffer Remaining)</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              Your <strong>Famalth Lynx</strong> software license for <strong>${clientName}</strong> reached its expiration date on <strong>${validTill}</strong>.
            </p>

            <div style="background: #fef2f2; border: 1.5px solid #f87171; border-radius: 10px; padding: 16px; margin: 18px 0; color: #991b1b;">
              <div style="font-weight: 700; font-size: 14px; margin-bottom: 6px;">⚠️ Grace Period Notice</div>
              <div style="font-size: 12.5px; line-height: 1.5;">
                You are currently operating in a temporary <strong>${graceDays}-day Grace Period Buffer</strong>. Once this grace period expires, local POS terminals will enter lockout mode to prevent unsynchronized data.
              </div>
            </div>

            <div style="background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 16px; margin: 18px 0;">
              <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Expired On:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #dc2626;">${validTill}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Renewal Amount:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #047857;">${this.formatCurrency(totalAmount)}</td>
                </tr>
              </table>
            </div>

            <p style="font-size: 13px; color: #334155;">
              Please contact your assigned Relationship Manager or Central Administrator immediately to process payment and extend your software validity.
            </p>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 20px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              Client Code: <strong>${clientCode}</strong> • Store Management System
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html);
      console.log(`✅ [NOTIFY EXPIRED] Expiry alert email sent to ${recipient} for ${clientName}.`);
      await this.recordDailyNotificationSent(undefined, tenant, 'EXPIRED_ALERT', {
        valid_till: validTill,
      });
      return true;
    } catch (err: any) {
      console.error('[NOTIFY EXPIRED ERROR]', err.message);
      return false;
    }
  }

  /**
   * 5. On Kill Switch: Send notice when remote lock/suspend is activated or deactivated
   */
  public static async notifyKillSwitchToggled(
    tenant: any,
    targetName: string,
    isKillSwitched: boolean,
    reason?: string
  ): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) return false;

      const clientName = tenant.legal_name || targetName;
      const clientCode = tenant.client_code || '';
      const subject = isKillSwitched
        ? `Remote Access Lock Applied to ${targetName} (${clientCode})`
        : `Service Access Reactivated for ${targetName} (${clientCode})`;

      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid ${isKillSwitched ? '#fecaca' : '#bbf7d0'}; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: ${isKillSwitched ? 'linear-gradient(135deg, #b91c1c 0%, #7f1d1d 100%)' : 'linear-gradient(135deg, #10b981 0%, #047857 100%)'}; padding: 26px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">${isKillSwitched ? 'SECURITY NOTICE' : 'SERVICE RESTORED'}</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700;">${isKillSwitched ? 'Remote Lockout Activated' : 'Service Access Restored'}</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">Target: ${targetName}</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              ${isKillSwitched
                ? `An administrative Remote Kill-Switch / Service Lock has been applied to your <strong>Famalth Lynx</strong> outlet <strong>${targetName}</strong>.`
                : `The administrative lock on your <strong>Famalth Lynx</strong> outlet <strong>${targetName}</strong> has been removed. All terminal billing operations and cloud services are fully operational.`
              }
            </p>

            ${isKillSwitched ? `
              <div style="background: #fef2f2; border: 1.5px solid #f87171; border-radius: 10px; padding: 14px 18px; margin: 18px 0; color: #991b1b;">
                <strong>Reason:</strong> ${reason || 'Administrative policy or billing audit update.'}
              </div>
              <p style="font-size: 13px; color: #475569;">
                To resolve this lock and reactivate terminal billing, please contact your Central Administrator or Dedicated Relationship Manager immediately.
              </p>
            ` : ''}

            <p style="font-size: 12.5px; color: #64748b; margin-top: 20px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              Client Code: <strong>${clientCode}</strong> • Enterprise Security Controller
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html);
      console.log(`✅ [NOTIFY KILL-SWITCH] Kill switch notice (${isKillSwitched ? 'LOCKED' : 'UNLOCKED'}) sent to ${recipient} for ${targetName}.`);
      return true;
    } catch (err: any) {
      console.error('[NOTIFY KILL-SWITCH ERROR]', err.message);
      return false;
    }
  }

  /**
   * 6. On New Licenses Pricing / Quota Update: Send email detailing new plan terms
   */
  public static async notifyLicensePricingUpdated(tenant: any, license: any): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) return false;

      // Rate limit pricing notifications to max 1 per day per tenant to avoid spamming on successive edits
      if (!this.canSendDailyNotification(tenant, 'PRICING_UPDATED')) {
        return false;
      }

      const clientName = tenant.legal_name || 'Valued Client';
      const clientCode = tenant.client_code || '';
      const subtotal = Number(license.subscription_amount || 4999.00);
      const taxRate = Number(license.tax_percentage || 18.00);
      const taxAmount = Number((subtotal * (taxRate / 100)).toFixed(2));
      const totalAmount = Number((subtotal + taxAmount).toFixed(2));

      const subject = `Subscription Plan & Quota Updated - ${clientName} (${clientCode})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #0284c7 0%, #0369a1 100%); padding: 26px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 12px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">PLAN UPDATED</div>
            <h1 style="margin: 0; font-size: 20px; font-weight: 700;">Subscription Plan & Quota Updated</h1>
            <p style="margin: 6px 0 0 0; font-size: 13px; opacity: 0.9;">Updated Quota Terms for ${clientName}</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              Your <strong>Famalth Lynx</strong> software license plan and pricing quota for <strong>${clientName}</strong> have been updated by administration.
            </p>

            <div style="background: #f8fafc; border: 1.5px solid #cbd5e1; border-radius: 10px; padding: 18px; margin: 18px 0;">
              <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">License Tier:</td>
                  <td style="padding: 6px 0; font-weight: 700; color: #0284c7;">${license.tier_name || 'ENTERPRISE'}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Max Outlets Permitted:</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${license.max_outlets || 1} Outlets</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Max POS Terminals / Seats:</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${license.max_terminals || 3} Terminals</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Base Subscription Price:</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${this.formatCurrency(subtotal)}</td>
                </tr>
                <tr>
                  <td style="padding: 6px 0; color: #64748b;">Tax (${taxRate}% GST):</td>
                  <td style="padding: 6px 0; font-weight: 600; color: #334155;">${this.formatCurrency(taxAmount)}</td>
                </tr>
                <tr style="border-top: 1.5px dashed #cbd5e1;">
                  <td style="padding: 10px 0 4px 0; font-size: 14px; font-weight: 700; color: #0f172a;">Total Plan Amount:</td>
                  <td style="padding: 10px 0 4px 0; font-size: 15px; font-weight: 800; color: #047857;">${this.formatCurrency(totalAmount)}</td>
                </tr>
              </table>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 18px; border-top: 1px solid #e2e8f0; padding-top: 12px;">
              Client Code: <strong>${clientCode}</strong> • Updated Plan Active
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html);
      console.log(`✅ [NOTIFY PRICING] Pricing update email sent to ${recipient} for ${clientName}.`);
      await this.recordDailyNotificationSent(undefined, tenant, 'PRICING_UPDATED');
      return true;
    } catch (err: any) {
      console.error('[NOTIFY PRICING ERROR]', err.message);
      return false;
    }
  }

  /**
   * 7. On Customer Pay: Send confirmation email stating Payment Done and License increased by -- days
   */
  public static async notifyPaymentReceivedAndLicenseExtended(
    tenant: any,
    license: any,
    amount: number | string,
    extendDays: number | string,
    targetValidTill: Date | string,
    invoice?: any,
    pdfBuffer?: Buffer
  ): Promise<boolean> {
    try {
      const recipient = this.getRecipientEmail(tenant);
      if (!recipient) {
        console.warn(`[NOTIFY PAYMENT] No valid recipient email found for tenant ${tenant?.legal_name || tenant?.id}. Email bypassed.`);
        return false;
      }

      const clientName = tenant.legal_name || 'Valued Client';
      const clientCode = tenant.client_code || '';
      const numDays = Number(extendDays) || 0;
      const meta = tenant.custom_metadata || {};
      const currencySym = meta.currency === 'USD' ? '$' : meta.currency === 'EUR' ? '€' : meta.currency === 'GBP' ? '£' : '₹';
      const formattedAmount = this.formatCurrency(amount, currencySym);
      const newExpiryStr = new Date(targetValidTill).toLocaleDateString('en-GB', {
        day: 'numeric',
        month: 'short',
        year: 'numeric',
      });
      const invNum = invoice?.invoice_number || `INV-PAID-${Date.now().toString().slice(-6)}`;

      // Attempt to generate Tax Invoice PDF with PAID status if buffer not provided
      let attachmentBuffer = pdfBuffer;
      if (!attachmentBuffer) {
        try {
          const subtotal = Number(amount || license.subscription_amount || 4999.00);
          const taxRate = Number(license.tax_percentage || 18.00);
          const taxAmount = Number((subtotal * (taxRate / 100)).toFixed(2));
          const totalAmount = Number((subtotal + taxAmount).toFixed(2));

          attachmentBuffer = await generateSubscriptionInvoicePdf({
            invoiceNumber: invNum,
            issueDate: invoice?.billing_period_start || new Date(),
            dueDate: targetValidTill,
            paymentStatus: 'PAID',
            paidAt: new Date(),
            tenant: {
              clientCode: tenant.client_code,
              legalName: tenant.legal_name,
              contactEmail: recipient,
              contactPhone: tenant.contact_phone,
              taxIdentifier: (tenant as any).tax_identifier,
              billingAddress: (tenant as any).billing_address,
              country: meta.country || 'India',
            },
            license: {
              tierName: license.tier_name || 'ENTERPRISE',
              maxTerminals: license.max_terminals || 3,
              maxOutlets: license.max_outlets || 1,
              validFrom: license.valid_from || new Date(),
              validTill: targetValidTill,
              gracePeriodDays: license.grace_period_days || 15,
            },
            pricing: {
              subtotal,
              taxRate,
              taxAmount,
              totalAmount,
              currency: meta.currency || 'INR',
            },
          });
        } catch (pdfErr: any) {
          console.warn(`[NOTIFY PAYMENT] Could not attach PDF invoice: ${pdfErr.message}`);
        }
      }

      const attachments: any[] = [];
      if (attachmentBuffer && Buffer.isBuffer(attachmentBuffer)) {
        attachments.push({
          filename: `Tax-Invoice-PAID-${invNum}.pdf`,
          content: attachmentBuffer,
          contentType: 'application/pdf',
        });
      }

      const appBaseUrl = process.env.APP_URL || process.env.PUBLIC_URL || 'http://localhost:5000';
      const downloadUrl = `${appBaseUrl}/api/v1/control-plane/invoices/download/${tenant.id}`;

      const subject = `Payment Received — License Increased by +${numDays} Days - ${clientName} (${clientCode})`;
      const html = `
        <div style="font-family: 'Segoe UI', Arial, sans-serif; max-width: 620px; margin: 0 auto; background: #ffffff; border: 1px solid #e2e8f0; border-radius: 12px; overflow: hidden; box-shadow: 0 4px 14px rgba(0,0,0,0.06);">
          <div style="background: linear-gradient(135deg, #059669 0%, #047857 100%); padding: 28px 24px; color: #ffffff; text-align: center;">
            <div style="display: inline-block; background: rgba(255,255,255,0.22); padding: 4px 14px; border-radius: 20px; font-size: 11px; font-weight: 700; letter-spacing: 0.8px; margin-bottom: 8px;">PAYMENT CONFIRMED</div>
            <h1 style="margin: 0; font-size: 21px; font-weight: 700; letter-spacing: 0.3px;">Payment Done — License Increased by +${numDays} Days</h1>
            <p style="margin: 6px 0 0 0; font-size: 13.5px; opacity: 0.95;">Thank you for your payment, ${clientName}</p>
          </div>

          <div style="padding: 26px 24px; color: #334155; line-height: 1.6;">
            <p style="font-size: 14.5px; margin-top: 0;">Dear <strong>${clientName}</strong> Team,</p>
            <p style="font-size: 13.5px; color: #475569;">
              We gratefully acknowledge receipt of your <strong>Famalth Lynx</strong> subscription payment of <strong>${formattedAmount}</strong>. Your software license has been successfully updated and <strong>increased by +${numDays} Days</strong>.
            </p>

            <div style="background: #f0fdf4; border: 1.5px solid #86efac; border-radius: 10px; padding: 20px; margin: 20px 0;">
              <table style="width: 100%; font-size: 13px; border-collapse: collapse;">
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">Payment Status:</td>
                  <td style="padding: 7px 0;">
                    <span style="background: #16a34a; color: #ffffff; padding: 3px 12px; border-radius: 12px; font-size: 11px; font-weight: 700;">PAID & VERIFIED</span>
                  </td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">Amount Received:</td>
                  <td style="padding: 7px 0; font-weight: 800; color: #0f172a; font-size: 14.5px;">${formattedAmount}</td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">License Extension:</td>
                  <td style="padding: 7px 0; font-weight: 800; color: #059669; font-size: 14.5px;">+${numDays} Days Added</td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">New Expiry Date:</td>
                  <td style="padding: 7px 0; font-weight: 700; color: #0f172a; font-size: 13.5px;">${newExpiryStr}</td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">Licensed Terminals:</td>
                  <td style="padding: 7px 0; font-weight: 600; color: #334155;">${license.max_terminals || 3} POS Terminals / Seats</td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">Licensed Outlets:</td>
                  <td style="padding: 7px 0; font-weight: 600; color: #334155;">${license.max_outlets || 1} Outlets</td>
                </tr>
                <tr>
                  <td style="padding: 7px 0; color: #166534; font-weight: 600;">Subscription Tier:</td>
                  <td style="padding: 7px 0; font-weight: 600; color: #334155;">${license.tier_name || 'ENTERPRISE'}</td>
                </tr>
              </table>
            </div>

            <div style="background: #f8fafc; border-left: 4px solid #059669; padding: 12px 14px; margin: 18px 0; border-radius: 4px;">
              <p style="margin: 0; font-size: 12.5px; color: #475569;">
                <strong>⚡ Real-Time POS Sync:</strong> All your active retail outlets and POS checkout machines have been automatically refreshed with this extended validity. No manual license keys or re-installation required.
              </p>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 14px;">
              Your official Tax Invoice marked <strong>PAID</strong> is attached to this email. You may also view or download it anytime:
            </p>

            <div style="text-align: center; margin: 20px 0 12px 0;">
              <a href="${downloadUrl}" style="display: inline-block; background: #059669; color: #ffffff; padding: 11px 26px; border-radius: 6px; font-weight: 600; font-size: 13.5px; text-decoration: none;">Download Paid Tax Invoice (PDF)</a>
            </div>

            <p style="font-size: 12.5px; color: #64748b; margin-top: 22px; border-top: 1px solid #e2e8f0; padding-top: 14px;">
              Client Code: <strong>${clientCode}</strong> • Thank you for your continued partnership!
            </p>
          </div>
        </div>
      `;

      await sendEmail(recipient, subject, html, attachments.length > 0 ? attachments : undefined);
      console.log(`✅ [NOTIFY PAYMENT] Payment received & license extended email sent to ${recipient} (+${numDays} days).`);
      return true;
    } catch (err: any) {
      console.error('[NOTIFY PAYMENT ERROR]', err.message);
      return false;
    }
  }

  /**
   * Background Checker: Inspects all tenants, auto-dispatches 10-day renewal invoices & expiry alerts
   */
  public static async checkAndDispatchExpiryAndRenewalNotices(propertyDb: any): Promise<{ renewalCount: number; expiredCount: number }> {
    let renewalCount = 0;
    let expiredCount = 0;

    try {
      const { MasterTenant, MasterLicense, MasterInvoice } = initMasterModels(propertyDb);
      const tenants = await MasterTenant.findAll({
        include: [
          { model: MasterLicense, as: 'licenses' },
        ],
      });

      for (const t of tenants) {
        const activeLicense = ((t as any).licenses || [])[0];
        if (!activeLicense || !activeLicense.valid_till) continue;

        const diffMs = new Date(activeLicense.valid_till).getTime() - Date.now();
        const daysLeft = Math.ceil(diffMs / (1000 * 60 * 60 * 24));
        const meta = t.custom_metadata || {};

        // 10-DAY RENEWAL INVOICE
        if (daysLeft <= 10 && daysLeft >= 0) {
          const vDate = new Date(activeLicense.valid_till);
          const invoiceNumber = `INV-${t.client_code}-${vDate.getFullYear()}${(vDate.getMonth() + 1).toString().padStart(2, '0')}`;
          
          let invoice = await MasterInvoice.findOne({ where: { invoice_number: invoiceNumber } });
          const subtotal = Number(activeLicense.subscription_amount || 4999.00);
          const taxRate = Number(activeLicense.tax_percentage || 18.00);
          const taxAmount = Number((subtotal * (taxRate / 100)).toFixed(2));
          const totalAmount = Number((subtotal + taxAmount).toFixed(2));

          if (!invoice) {
            invoice = await MasterInvoice.create({
              tenant_id: t.id,
              invoice_number: invoiceNumber,
              billing_period_start: activeLicense.valid_from || (t as any).created_at || new Date(),
              billing_period_end: activeLicense.valid_till,
              due_date: activeLicense.next_payment_date || activeLicense.valid_till,
              subtotal,
              tax_rate: taxRate,
              tax_amount: taxAmount,
              total_amount: totalAmount,
              status: activeLicense.payment_status === 'PAID' ? 'PAID' : 'ISSUED',
            });
          }

          // Check if already dispatched for this invoice or sent today
          const canSendRenewal = this.canSendDailyNotification(t, 'RENEWAL_10D');
          const alreadySentForInvoice = meta.last_10d_invoice_email_sent_for === invoiceNumber;

          if (canSendRenewal && !alreadySentForInvoice) {
            let pdfBuffer: Buffer | undefined;
            try {
              pdfBuffer = await generateSubscriptionInvoicePdf({
                invoiceNumber,
                issueDate: invoice.billing_period_start || new Date(),
                dueDate: invoice.due_date,
                paymentStatus: activeLicense.payment_status === 'PAID' ? 'PAID' : 'PENDING',
                tenant: {
                  clientCode: t.client_code,
                  legalName: t.legal_name,
                  contactEmail: t.contact_email,
                  contactPhone: t.contact_phone,
                  taxIdentifier: (t as any).tax_identifier,
                  billingAddress: (t as any).billing_address,
                  country: meta.country || 'India',
                },
                license: {
                  tierName: activeLicense.tier_name || 'ENTERPRISE',
                  maxTerminals: activeLicense.max_terminals || 3,
                  maxOutlets: activeLicense.max_outlets || 1,
                  validFrom: activeLicense.valid_from,
                  validTill: activeLicense.valid_till,
                  gracePeriodDays: activeLicense.grace_period_days || 15,
                },
                pricing: {
                  subtotal,
                  taxRate,
                  taxAmount,
                  totalAmount,
                  currency: meta.currency || 'INR',
                },
              });
            } catch (e: any) {
              console.warn(`[INVOICE PDF GENERATION NOTICE] Proceeding without attachment: ${e.message}`);
            }

            const sent = await this.notifyRenewalInvoice(t, activeLicense, invoice, pdfBuffer);
            if (sent) {
              await this.recordDailyNotificationSent(propertyDb, t, 'RENEWAL_10D', {
                invoiceNumber,
                valid_till: activeLicense.valid_till,
              });
              renewalCount++;
            }
          }
        }

        // ON EXPIRED: Daily Email Guard guarantees max 1 expired alert per day
        if (daysLeft < 0) {
          const canSendExpired = this.canSendDailyNotification(t, 'EXPIRED_ALERT');
          if (canSendExpired) {
            const sent = await this.notifyLicenseExpired(t, activeLicense);
            if (sent) {
              await this.recordDailyNotificationSent(propertyDb, t, 'EXPIRED_ALERT', {
                valid_till: activeLicense.valid_till,
                daysExpired: Math.abs(daysLeft),
              });
              expiredCount++;
            }
          }
        }
      }
    } catch (err: any) {
      console.error('[AUTO DISPATCH CHECK ERROR]', err);
    }

    return { renewalCount, expiredCount };
  }
}

export default ControlPlaneNotificationService;
