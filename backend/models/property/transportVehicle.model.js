"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
module.exports = (sequelize, DataTypes) => {
    const TransportVehicle = sequelize.define('transport_vehicles', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        vehicle_number: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        vehicle_type: {
            type: DataTypes.STRING(50),
            allowNull: false,
            defaultValue: 'Truck'
        },
        capacity_tonnage: {
            type: DataTypes.DECIMAL(10, 2),
            defaultValue: 0.00
        },
        capacity_unit: {
            type: DataTypes.STRING(20),
            defaultValue: 'Tons'
        },
        model: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'AVAILABLE' // 'AVAILABLE', 'BOOKED', 'IN_TRANSIT', 'MAINTENANCE'
        },
        current_trip_id: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        current_driver_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        notes: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'transport_vehicles',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
    TransportVehicle.associate = (models) => {
        if (models.transport_drivers) {
            TransportVehicle.belongsTo(models.transport_drivers, {
                foreignKey: 'current_driver_id',
                as: 'current_driver'
            });
        }
        if (models.delivery_challan_headers) {
            TransportVehicle.hasMany(models.delivery_challan_headers, {
                foreignKey: 'vehicle_id',
                as: 'assigned_challans'
            });
        }
    };
    return TransportVehicle;
};
exports.default = module.exports;
