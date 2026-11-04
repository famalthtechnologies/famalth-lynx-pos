module.exports = (sequelize: any, DataTypes: any) => {
    return sequelize.define('outlet_storage_quotas', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        outlet_code: {
            type: DataTypes.STRING(64),
            allowNull: false,
            unique: true
        },
        base_quota_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 16106127360 // 15 GB
        },
        addon_quota_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        promotional_bonus_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        total_allocated_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 16106127360
        },
        current_backups_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        current_uploads_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        current_db_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        total_used_bytes: {
            type: DataTypes.BIGINT,
            allowNull: false,
            defaultValue: 0
        },
        warning_threshold_pct: {
            type: DataTypes.INTEGER,
            allowNull: false,
            defaultValue: 80
        },
        is_frozen: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        active_plan_code: {
            type: DataTypes.STRING(64),
            allowNull: false,
            defaultValue: 'STARTER_15GB'
        },
        plan_expires_at: {
            type: DataTypes.DATE,
            allowNull: true
        }
    }, {
        tableName: 'outlet_storage_quotas',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });
};
