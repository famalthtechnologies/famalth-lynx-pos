"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
module.exports = (sequelize, DataTypes) => {
    const purchase_order = sequelize.define('purchase_orders', {
        outlet_id: DataTypes.INTEGER,
        po_no: DataTypes.STRING,
        manual_no: DataTypes.STRING,
        supplier_id: DataTypes.INTEGER,
        po_date: DataTypes.DATEONLY,
        total_amount: DataTypes.DECIMAL(12, 2),
        round_off_amount: { type: DataTypes.DECIMAL(12, 2), defaultValue: 0.00 },
        status: DataTypes.STRING,
        created_by: DataTypes.INTEGER,
        approval_status: { type: DataTypes.STRING(20), defaultValue: 'APPROVED' },
        approved_by: DataTypes.INTEGER,
        approved_at: DataTypes.DATE,
        rejected_by: DataTypes.INTEGER,
        rejected_at: DataTypes.DATE,
        rejection_reason: DataTypes.TEXT
    }, {
        tableName: 'purchase_orders',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    if (sequelize && typeof sequelize.query === 'function') {
        sequelize.query(`
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS approval_status VARCHAR(20) DEFAULT 'APPROVED';
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS approved_by INTEGER;
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS approved_at TIMESTAMP;
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS rejected_by INTEGER;
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS rejected_at TIMESTAMP;
            ALTER TABLE purchase_orders ADD COLUMN IF NOT EXISTS rejection_reason TEXT;
            UPDATE purchase_orders SET approval_status = 'APPROVED' WHERE approval_status IS NULL;
        `).catch(() => {});
    }
    purchase_order.associate = (models) => {
        purchase_order.hasMany(models.purchase_order_items, {
            foreignKey: 'po_id',
            as: 'items'
        });
    };
    purchase_order.associate = (models) => {
        purchase_order.belongsTo(models.supplier_master, {
            foreignKey: 'supplier_id',
            as: 'supplier'
        });
        purchase_order.hasMany(models.purchase_order_items, {
            foreignKey: 'po_id',
            as: 'items'
        });
    };
    return purchase_order;
};
exports.default = module.exports;
