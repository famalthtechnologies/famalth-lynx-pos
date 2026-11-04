"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
module.exports = (sequelize, DataTypes) => {
    const DeliveryChallanHeader = sequelize.define('delivery_challan_headers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        challan_no: {
            type: DataTypes.STRING(50),
            allowNull: false
        },
        challan_date: {
            type: DataTypes.DATE,
            defaultValue: DataTypes.NOW
        },
        customer_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        customer_phone: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        total_qty: {
            type: DataTypes.DECIMAL(12, 2),
            defaultValue: 0.00
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'Issued'
        },
        created_by: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        // Fleet & Transportation Fields
        vehicle_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        vehicle_number: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        vehicle_type: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        driver_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        driver_name: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        driver_phone: {
            type: DataTypes.STRING(30),
            allowNull: true
        },
        trip_id: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        delivery_status: {
            type: DataTypes.STRING(30),
            defaultValue: 'PENDING' // 'PENDING', 'DISPATCHED', 'IN_TRANSIT', 'DELIVERED', 'RETURNED'
        },
        delivery_otp: {
            type: DataTypes.STRING(10),
            allowNull: true
        },
        delivered_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        delivered_by_remark: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        delivery_proof: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        e_way_bill_no: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        destination_address: {
            type: DataTypes.TEXT,
            allowNull: true
        }
    }, {
        tableName: 'delivery_challan_headers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
    DeliveryChallanHeader.associate = (models) => {
        if (models.users) {
            DeliveryChallanHeader.belongsTo(models.users, {
                foreignKey: 'created_by',
                as: 'creator'
            });
        }
        if (models.delivery_challan_items) {
            DeliveryChallanHeader.hasMany(models.delivery_challan_items, {
                foreignKey: 'challan_id',
                as: 'items'
            });
        }
        if (models.transport_vehicles) {
            DeliveryChallanHeader.belongsTo(models.transport_vehicles, {
                foreignKey: 'vehicle_id',
                as: 'vehicle'
            });
        }
        if (models.transport_drivers) {
            DeliveryChallanHeader.belongsTo(models.transport_drivers, {
                foreignKey: 'driver_id',
                as: 'driver'
            });
        }
    };
    return DeliveryChallanHeader;
};
exports.default = module.exports;
