"use strict";
/**
 * International Phone Number Utility (Famalth Lynx Core)
 * Strictly follows ITU-T E.164 international standard (supporting 3 to 15 digits).
 * Supports global phone numbers without arbitrary chopping or regional hardcoding.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.normalizePhoneNumber = normalizePhoneNumber;
exports.getPhoneSearchVariants = getPhoneSearchVariants;

function normalizePhoneNumber(raw) {
    if (raw === null || raw === undefined) return '';
    const str = String(raw).trim();
    if (!str) return '';

    const hasPlus = str.startsWith('+');
    // Strip non-digits (formatting spaces, hyphens, brackets, dots)
    const digits = str.replace(/\D/g, '');
    if (!digits) return '';

    // ITU-T E.164 allows up to 15 digits (excluding +)
    const sanitized = digits.length > 15 ? digits.slice(0, 15) : digits;
    return hasPlus ? `+${sanitized}` : sanitized;
}

/**
 * Returns phone search variants for international and local formats
 * Enables bidirectional matching (with/without +, with/without country codes)
 */
function getPhoneSearchVariants(raw) {
    const norm = normalizePhoneNumber(raw);
    if (!norm) return [];
    const digits = norm.replace(/\D/g, '');
    const variants = new Set();

    variants.add(norm);
    variants.add(digits);
    if (!norm.startsWith('+')) {
        variants.add(`+${digits}`);
    }

    // Common international prefixes (India +91, US +1, UK +44, UAE +971, Australia +61, etc.)
    if (digits.startsWith('91') && digits.length >= 12) {
        const local = digits.slice(2);
        variants.add(local);
        variants.add(`+91${local}`);
        variants.add(`0${local}`);
    }
    if (digits.startsWith('1') && digits.length === 11) {
        const local = digits.slice(1);
        variants.add(local);
        variants.add(`+1${local}`);
    }
    if (digits.startsWith('44') && digits.length >= 11) {
        const local = digits.slice(2);
        variants.add(local);
        variants.add(`0${local}`);
        variants.add(`+44${local}`);
    }
    if (digits.startsWith('971') && digits.length >= 11) {
        const local = digits.slice(3);
        variants.add(local);
        variants.add(`0${local}`);
        variants.add(`+971${local}`);
    }
    if (digits.startsWith('61') && digits.length >= 10) {
        const local = digits.slice(2);
        variants.add(local);
        variants.add(`0${local}`);
        variants.add(`+61${local}`);
    }
    // Trunk prefix 0
    if (digits.startsWith('0') && digits.length >= 8) {
        const withoutZero = digits.slice(1);
        variants.add(withoutZero);
    }

    return Array.from(variants).filter(Boolean);
}
