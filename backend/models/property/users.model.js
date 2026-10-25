module.exports = (sequelize, DataTypes) => {
    return sequelize.define('users', {
        username: { type: DataTypes.STRING, allowNull: false },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },

        password_hash: DataTypes.TEXT,
        pin_code: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        show_in_quick_login: {
            type: DataTypes.BOOLEAN,
            defaultValue: false
        },
        login_qr_token: {
            type: DataTypes.STRING(255),
            allowNull: true
        },
        full_name: DataTypes.STRING,
        mobile: DataTypes.STRING,
        contact_email: {
            type: DataTypes.STRING(50)
        },
        role: DataTypes.STRING,
        speciality: DataTypes.STRING(100),
        qualification: DataTypes.STRING(100),
        experience_years: { type: DataTypes.INTEGER, defaultValue: 0 },
        consultation_fee: { type: DataTypes.DECIMAL(10, 2), defaultValue: 0.00 },
        is_public_listed: { type: DataTypes.BOOLEAN, defaultValue: true },
        is_verified_badge: { type: DataTypes.BOOLEAN, defaultValue: true },
        doctor_city: DataTypes.STRING(100),
        doctor_bio: DataTypes.TEXT,
        available_days: { type: DataTypes.STRING(100), defaultValue: 'Mon,Tue,Wed,Thu,Fri,Sat' },
        registration_no: DataTypes.STRING(100),
        whatsapp_no: DataTypes.STRING(50),
        public_display_options: {
            type: DataTypes.JSONB,
            allowNull: true,
            defaultValue: {
                show_clinic_name: true,
                show_doctor_name: true,
                show_address: true,
                show_phone: true,
                show_whatsapp: true,
                show_email: true,
                show_fees: true
            }
        },
        max_discount_percent: { type: DataTypes.DECIMAL(5, 2), defaultValue: 100.00 },
        is_active: { type: DataTypes.BOOLEAN, defaultValue: true },
        last_login: DataTypes.DATE
    }, {
        tableName: 'users',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at',
        indexes: [
            {
                name: 'users_outlet_username_unique',
                unique: true,
                fields: ['outlet_id', 'username']
            }
        ]
    });
};
