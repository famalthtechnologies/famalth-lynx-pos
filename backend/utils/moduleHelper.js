"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.resolveBusinessModule = resolveBusinessModule;

function resolveBusinessModule(mod, type) {
    var rawMod = (mod || '').toString().trim().toUpperCase();
    var rawType = (type || '').toString().trim().toUpperCase();

    // If an explicit module has been set (including ALL, RETAIL, RESTAURANT, CLINIC, HRMS, INVENTORY), respect it!
    if (rawMod && ['RETAIL', 'RESTAURANT', 'CLINIC', 'HRMS', 'INVENTORY', 'ALL'].includes(rawMod)) {
        return rawMod;
    }

    // If 'ALL' or empty, derive module from outlet_type / business_type
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

exports.default = { resolveBusinessModule: resolveBusinessModule };
