import fs from 'fs';
import path from 'path';

export interface LicensorBillingConfig {
  companyName: string;
  brandSubtitle: string;
  address: string;
  cityStatePin: string;
  country: string;
  taxIdentifier: string; // e.g. GSTIN or Corporate Tax ID
  cin: string;           // e.g. CIN / Registration No
  contactEmail: string;
  contactPhone: string;
  website: string;
  bankName: string;
  accountNumber: string;
  accountName: string;
  ifscSwift: string;
  upiId: string;
  paymentTerms: string;
}

const DEFAULT_CONFIG: LicensorBillingConfig = {
  companyName: 'Famalth Technologies',
  brandSubtitle: 'Famalth Lynx Enterprise Retail Platform',
  address: 'Dehradun, Uttarakhand 248001',
  cityStatePin: 'Dehradun, Uttarakhand 248001',
  country: 'India',
  taxIdentifier: 'GSTIN: 07AAAAF1234A1Z5',
  cin: 'U72900DL2022PTC123456',
  contactEmail: 'enterprise@famalth.com',
  contactPhone: '+91 00000 00000',
  website: 'www.famalth.com',
  bankName: '',
  accountNumber: '',
  accountName: '',
  ifscSwift: '',
  upiId: '',
  paymentTerms: 'Payment due within 15 days of invoice date. All payments subject to standard SaaS license terms.',
};

function getStoragePath(): string {
  const rootDir = (process as any).pkg ? path.dirname(process.execPath) : process.cwd();
  const dirPath = path.join(rootDir, 'backend', 'data');
  if (!fs.existsSync(dirPath)) {
    try {
      fs.mkdirSync(dirPath, { recursive: true });
    } catch (_) {}
  }
  return path.join(dirPath, 'licensor_billing_config.json');
}

class LicensorBillingService {
  private static instance: LicensorBillingService;
  private cachedConfig: LicensorBillingConfig | null = null;

  public static getInstance(): LicensorBillingService {
    if (!LicensorBillingService.instance) {
      LicensorBillingService.instance = new LicensorBillingService();
    }
    return LicensorBillingService.instance;
  }

  public getConfig(): LicensorBillingConfig {
    if (this.cachedConfig) {
      return { ...this.cachedConfig };
    }

    try {
      const filePath = getStoragePath();
      if (fs.existsSync(filePath)) {
        const raw = fs.readFileSync(filePath, 'utf8');
        const parsed = JSON.parse(raw);
        this.cachedConfig = {
          ...DEFAULT_CONFIG,
          ...parsed,
        };
        return { ...this.cachedConfig! };
      }
    } catch (e: any) {
      console.warn('⚠️ [LICENSOR_BILLING] Could not read billing config file, falling back to defaults:', e.message);
    }

    this.cachedConfig = { ...DEFAULT_CONFIG };
    return { ...this.cachedConfig };
  }

  public saveConfig(updates: Partial<LicensorBillingConfig>): LicensorBillingConfig {
    const current = this.getConfig();
    const updated: LicensorBillingConfig = {
      ...current,
      ...updates,
      companyName: (updates.companyName ?? current.companyName).trim(),
      brandSubtitle: (updates.brandSubtitle ?? current.brandSubtitle).trim(),
      address: (updates.address ?? current.address).trim(),
      cityStatePin: (updates.cityStatePin ?? current.cityStatePin).trim(),
      country: (updates.country ?? current.country).trim(),
      taxIdentifier: (updates.taxIdentifier ?? current.taxIdentifier).trim(),
      cin: (updates.cin ?? current.cin).trim(),
      contactEmail: (updates.contactEmail ?? current.contactEmail).trim(),
      contactPhone: (updates.contactPhone ?? current.contactPhone).trim(),
      website: (updates.website ?? current.website).trim(),
      bankName: (updates.bankName ?? current.bankName).trim(),
      accountNumber: (updates.accountNumber ?? current.accountNumber).trim(),
      accountName: (updates.accountName ?? current.accountName).trim(),
      ifscSwift: (updates.ifscSwift ?? current.ifscSwift).trim(),
      upiId: (updates.upiId ?? current.upiId).trim(),
      paymentTerms: (updates.paymentTerms ?? current.paymentTerms).trim(),
    };

    try {
      const filePath = getStoragePath();
      fs.writeFileSync(filePath, JSON.stringify(updated, null, 2), 'utf8');
      this.cachedConfig = updated;
      console.log('✅ [LICENSOR_BILLING] Licensor billing configuration updated and saved to disk.');
    } catch (e: any) {
      console.error('❌ [LICENSOR_BILLING] Failed to write billing config to disk:', e.message);
    }

    return updated;
  }
}

export const licensorBillingService = LicensorBillingService.getInstance();
export default licensorBillingService;
