"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.license = license;
const fs_1 = __importDefault(require("fs"));
const path_1 = __importDefault(require("path"));
const rootDir = process.pkg ? path_1.default.dirname(process.execPath) : process.cwd();
const LICENSE_PATH = path_1.default.join(rootDir, 'license.key');
function loadLicense() {
    const isCloudMode = !!(process.env.IS_CLOUD === 'true' || process.env.DATABASE_URL || process.env.DB_HOST);
    if (isCloudMode) {
        if (process.env.LICENSE_KEY_JSON) {
            try {
                return JSON.parse(process.env.LICENSE_KEY_JSON);
            } catch (e) {}
        }
        return {
            allowed_mode: 'ONLINE',
            valid_till: '2099-12-31',
            modules: ['INVENTORY', 'REPORTS', 'ADMIN', 'PURCHASE', 'SUPPLIER', 'ACCOUNTING', 'ANALYTICS', 'DELIVERY', 'FINANCE', 'NOTIFICATIONS']
        };
    }
    if (!fs_1.default.existsSync(LICENSE_PATH)) {
        throw new Error('LICENSE_FILE_MISSING');
    }
    try {
        return JSON.parse(fs_1.default.readFileSync(LICENSE_PATH, 'utf8'));
    }
    catch (e) {
        throw new Error('INVALID_LICENSE_FORMAT');
    }
}
function isExpired(validTill) {
    const today = new Date();
    today.setHours(0, 0, 0, 0);
    const expiry = new Date(validTill);
    expiry.setHours(23, 59, 59, 999);
    return today > expiry;
}
// ✅ EXPORT A FUNCTION (IMPORTANT)
function license(requiredModule) {
    return (req, res, next) => {
        try {
            const isCloudMode = !!(process.env.IS_CLOUD === 'true' || process.env.DATABASE_URL || process.env.DB_HOST);
            if (isCloudMode) {
                req.license = {
                    allowed_mode: 'ONLINE',
                    valid_till: '2099-12-31',
                    modules: ['INVENTORY', 'REPORTS', 'ADMIN', 'PURCHASE', 'SUPPLIER', 'ACCOUNTING', 'ANALYTICS', 'DELIVERY', 'FINANCE', 'NOTIFICATIONS']
                };
                return next();
            }
            const licenseData = loadLicense();
            if (isExpired(licenseData.valid_till)) {
                return res.status(403).json({
                    success: false,
                    code: 'LICENSE_EXPIRED',
                    message: 'License expired'
                });
            }
            if (requiredModule &&
                Array.isArray(licenseData.modules) &&
                !licenseData.modules.includes(requiredModule)) {
                return res.status(403).json({
                    success: false,
                    code: 'MODULE_NOT_LICENSED',
                    message: `${requiredModule} module not licensed`
                });
            }
            req.license = licenseData;
            next();
        }
        catch (err) {
            console.log(err.message);
            console.log(err);
            return res.status(403).json({
                success: false,
                code: err.message,
                message: 'License validation failed'
            });
        }
    };
}
module.exports = license;
exports.default = license;
