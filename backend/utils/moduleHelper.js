"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveBusinessModule = resolveBusinessModule;
exports.parseModuleList = parseModuleList;
exports.hasInventory = hasInventory;
exports.hasBilling = hasBilling;
exports.hasRetail = hasRetail;
exports.hasRestaurant = hasRestaurant;
exports.hasHrms = hasHrms;
exports.hasClinic = hasClinic;
exports.VALID_MODULES = exports.CORE_MODULES = void 0;

const VALID_MODULES = [
    'RETAIL',
    'RESTAURANT',
    'INVENTORY',
    'CLINIC',
    'ACCOUNTING',
    'HRMS',
    'COMMUNITY',
    'ALL'
];
exports.VALID_MODULES = VALID_MODULES;

const CORE_MODULES = [
    'RETAIL',
    'RESTAURANT',
    'INVENTORY',
    'CLINIC',
    'ACCOUNTING',
    'HRMS'
];
exports.CORE_MODULES = CORE_MODULES;

function parseModuleList(raw) {
    if (!raw) return [];
    const str = raw.toString().trim().toUpperCase();
    if (!str) return [];
    if (str === 'ALL') return ['ALL'];

    const tokens = str.split(',').map(s => s.trim().toUpperCase()).filter(Boolean);
    const validSet = new Set();

    for (const t of tokens) {
        if (VALID_MODULES.includes(t)) {
            validSet.add(t);
        }
    }

    if (validSet.has('ALL')) return ['ALL'];
    return Array.from(validSet);
}

function hasInventory(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('INVENTORY');
}

function hasBilling(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('RETAIL') || list.includes('RESTAURANT') || list.includes('CLINIC');
}

function hasRetail(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('RETAIL');
}

function hasRestaurant(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('RESTAURANT');
}

function hasHrms(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('HRMS');
}

function hasClinic(mod) {
    if (!mod) return false;
    const str = mod.toString().trim().toUpperCase();
    if (str === 'ALL') return true;
    const list = parseModuleList(str);
    return list.includes('ALL') || list.includes('CLINIC');
}

function resolveBusinessModule(mod, type) {
    const rawMod = (mod || '').toString().trim().toUpperCase();
    const rawType = (type || '').toString().trim().toUpperCase();

    // Check if rawMod contains multiple modules or single module
    if (rawMod) {
        if (rawMod === 'ALL') return 'ALL';

        const parsed = parseModuleList(rawMod);
        if (parsed.length > 0) {
            if (parsed.includes('ALL')) return 'ALL';
            const hasAllCore = CORE_MODULES.every(m => parsed.includes(m));
            if (hasAllCore) return 'ALL';
            return parsed.join(',');
        }
    }

    // If empty or unresolved, derive module from outlet_type / business_type
    if (rawType) {
        if (
            rawType === 'RETAIL' ||
            rawType === 'RETAIL STORE' ||
            ['MART', 'KIRANA', 'CLOTHES', 'SHOES', 'PARTS', 'MACHINERY', 'PETS', 'SOFTWARE', 'SUPERMARKET', 'SHOP'].includes(rawType)
        ) {
            return 'RETAIL';
        }
        if (['RESTAURANT', 'CAFE', 'BAR', 'DINING', 'BAKERY', 'LOUNGE', 'DINER', 'FOOD'].includes(rawType)) {
            return 'RESTAURANT';
        }
        if (['CLINIC', 'HOSPITAL', 'DOCTOR', 'HEALTHCARE', 'MEDICAL', 'PHARMACY'].includes(rawType)) {
            return 'CLINIC';
        }
        if (['WAREHOUSE', 'LOGISTICS', 'INVENTORY', 'STOCK'].includes(rawType)) {
            return 'INVENTORY';
        }
        if (['HOTEL', 'LODGE', 'RESORT'].includes(rawType)) {
            return 'ALL';
        }
    }

    return rawMod || 'RETAIL';
}

exports.default = {
    VALID_MODULES,
    CORE_MODULES,
    parseModuleList,
    resolveBusinessModule,
    hasInventory,
    hasBilling,
    hasRetail,
    hasRestaurant,
    hasHrms,
    hasClinic
};
