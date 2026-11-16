"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
module.exports = (sequelize, DataTypes) => {
    const SupplierReturnItem = sequelize.define('supplier_return_items', {
        return_id: DataTypes.INTEGER,
        receipt_item_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        item_code: DataTypes.STRING(30),
        item_name: DataTypes.STRING(150),
        brand: DataTypes.STRING(150),
        unit: DataTypes.STRING(20),
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        amount: DataTypes.DECIMAL(12, 2),
        tax: DataTypes.DECIMAL(5, 2),
        tax_amount: DataTypes.DECIMAL(12, 2),
        total_after_tax: DataTypes.DECIMAL(12, 2)
    }, {
        tableName: 'supplier_return_items',
        timestamps: false
    });
    if (sequelize && typeof sequelize.query === 'function') {
        sequelize.query(`
            ALTER TABLE supplier_return_items ADD COLUMN IF NOT EXISTS tax DECIMAL(5, 2) DEFAULT 0;
            ALTER TABLE supplier_return_items ADD COLUMN IF NOT EXISTS brand VARCHAR(150);
            ALTER TABLE supplier_return_items ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(12, 2) DEFAULT 0;
            ALTER TABLE supplier_return_items ADD COLUMN IF NOT EXISTS total_after_tax DECIMAL(12, 2);
        `).catch(() => { });
    }
    SupplierReturnItem.associate = (models) => {
        SupplierReturnItem.belongsTo(models.supplier_return_headers, {
            foreignKey: 'return_id',
            as: 'return_header'
        });
        SupplierReturnItem.belongsTo(models.goods_receipt_items, {
            foreignKey: 'receipt_item_id',
            as: 'receipt_item'
        });
        SupplierReturnItem.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });
    };
    return SupplierReturnItem;
};
exports.default = module.exports;
