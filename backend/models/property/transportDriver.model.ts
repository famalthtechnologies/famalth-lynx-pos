module.exports = (sequelize: any, DataTypes: any) => {
    const TransportDriver = sequelize.define('transport_drivers', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        driver_name: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        phone: {
            type: DataTypes.STRING(30),
            allowNull: false
        },
        license_number: {
            type: DataTypes.STRING(50),
            allowNull: true
        },
        address: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(30),
            defaultValue: 'AVAILABLE' // 'AVAILABLE', 'BOOKED', 'ON_LEAVE'
        },
        current_vehicle_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        }
    }, {
        tableName: 'transport_drivers',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    TransportDriver.associate = (models: any) => {
        if (models.transport_vehicles) {
            TransportDriver.belongsTo(models.transport_vehicles, {
                foreignKey: 'current_vehicle_id',
                as: 'current_vehicle'
            });
        }
        if (models.delivery_challan_headers) {
            TransportDriver.hasMany(models.delivery_challan_headers, {
                foreignKey: 'driver_id',
                as: 'delivered_challans'
            });
        }
    };

    return TransportDriver;
};

export default module.exports;
