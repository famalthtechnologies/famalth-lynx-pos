module.exports = (sequelize, DataTypes) => {
    const HrBiometricDevice = sequelize.define('hr_biometric_devices', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        device_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        ip_address: {
            type: DataTypes.STRING(100),
            allowNull: false
        },
        port: {
            type: DataTypes.INTEGER,
            defaultValue: 4370
        },
        machine_id: {
            type: DataTypes.STRING(100),
            defaultValue: '1'
        },
        protocol: {
            type: DataTypes.STRING(50),
            defaultValue: 'STANDALONE_TCP'
        },
        push_api_key: {
            type: DataTypes.STRING(255)
        },
        is_active: {
            type: DataTypes.BOOLEAN,
            defaultValue: true
        },
        last_sync_at: {
            type: DataTypes.DATE
        },
        last_ping_status: {
            type: DataTypes.STRING(50),
            defaultValue: 'OFFLINE'
        },
        total_punches_synced: {
            type: DataTypes.INTEGER,
            defaultValue: 0
        }
    }, {
        tableName: 'hr_biometric_devices',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrBiometricDevice.associate = (models) => {
        HrBiometricDevice.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
    };

    return HrBiometricDevice;
};
