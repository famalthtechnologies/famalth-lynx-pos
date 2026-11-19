"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
module.exports = (sequelize, DataTypes) => {
    const HrOffice = sequelize.define('hr_offices', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 1 },
        office_code: { type: DataTypes.STRING(50), allowNull: false },
        office_name: { type: DataTypes.STRING(255), allowNull: false },
        address: { type: DataTypes.TEXT, allowNull: true },
        city: { type: DataTypes.STRING(100), allowNull: true },
        state: { type: DataTypes.STRING(100), allowNull: true },
        pincode: { type: DataTypes.STRING(20), allowNull: true },
        latitude: { type: DataTypes.DECIMAL(10, 7), allowNull: false, defaultValue: 0.0 },
        longitude: { type: DataTypes.DECIMAL(10, 7), allowNull: false, defaultValue: 0.0 },
        radius_meters: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 150 },
        is_active: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true }
    }, {
        tableName: 'hr_offices',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrOffice.associate = (models) => {
        HrOffice.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrOffice.hasMany(models.hr_employees, { foreignKey: 'office_id', as: 'employees' });
        HrOffice.hasMany(models.hr_attendance_punches, { foreignKey: 'office_id', as: 'punches' });
    };

    return HrOffice;
};
exports.default = module.exports;
