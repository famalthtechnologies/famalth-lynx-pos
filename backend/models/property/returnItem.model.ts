module.exports = (sequelize, DataTypes) => {
    const return_items = sequelize.define('return_items', {
        return_id: DataTypes.INTEGER,
        issue_item_id: DataTypes.INTEGER,
        item_id: DataTypes.INTEGER,
        qty: DataTypes.DECIMAL(12, 2),
        rate: DataTypes.DECIMAL(12, 2),
        tax: DataTypes.DECIMAL(5, 2),
        tax_amount: DataTypes.DECIMAL(12, 2),
        amount: DataTypes.DECIMAL(12, 2),
        total_after_tax: DataTypes.DECIMAL(12, 2)
    }, {
        tableName: 'return_items',
        timestamps: false
    });

    if (sequelize && typeof sequelize.query === 'function') {
        sequelize.query(`
            ALTER TABLE return_items ADD COLUMN IF NOT EXISTS tax DECIMAL(5, 2) DEFAULT 0;
            ALTER TABLE return_items ADD COLUMN IF NOT EXISTS tax_amount DECIMAL(12, 2) DEFAULT 0;
            ALTER TABLE return_items ADD COLUMN IF NOT EXISTS amount DECIMAL(12, 2);
            ALTER TABLE return_items ADD COLUMN IF NOT EXISTS total_after_tax DECIMAL(12, 2);
        `).catch(() => {});
    }

    return_items.associate = (models) => {


        return_items.belongsTo(models.return_headers, {
            foreignKey: 'return_id',
            as: 'return_header'
        });

        return_items.belongsTo(models.item_master, {
            foreignKey: 'item_id',
            as: 'item_master'
        });

        return_items.belongsTo(models.issue_items, {
            foreignKey: 'issue_item_id',
            as: 'issue_item'
        });
    };
    return return_items;
};


export default module.exports;
