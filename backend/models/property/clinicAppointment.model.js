module.exports = (sequelize, DataTypes) => {
    const ClinicAppointment = sequelize.define('clinic_appointments', {
        id: {
            type: DataTypes.INTEGER,
            primaryKey: true,
            autoIncrement: true
        },
        outlet_id: {
            type: DataTypes.INTEGER,
            allowNull: false
        },
        patient_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        patient_name: {
            type: DataTypes.STRING(150),
            allowNull: false
        },
        patient_phone: {
            type: DataTypes.STRING(20),
            allowNull: false
        },
        patient_email: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        patient_age: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        patient_gender: {
            type: DataTypes.STRING(20),
            allowNull: true
        },
        appointment_date: {
            type: DataTypes.DATEONLY,
            allowNull: false
        },
        appointment_time: {
            type: DataTypes.STRING(20),
            allowNull: false
        },
        doctor_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        doctor_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        consultation_fee: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        is_email_verified: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
        },
        email_otp_verified_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        department: {
            type: DataTypes.STRING(100),
            allowNull: true
        },
        reason_for_visit: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'SCHEDULED' // SCHEDULED, CONFIRMED, VISITED, CANCELLED, NO_SHOW
        },
        visited_at: {
            type: DataTypes.DATE,
            allowNull: true
        },
        prescription_notes: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        prescribed_medicines: {
            type: DataTypes.JSONB,
            allowNull: false,
            defaultValue: []
        },
        billing_sale_id: {
            type: DataTypes.INTEGER,
            allowNull: true
        },
        billing_status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'PENDING' // PENDING, DRAFT_SENT, BILLED
        },
        source: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'POS' // POS, WEB, APP, WALK_IN
        }
    }, {
        tableName: 'clinic_appointments',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    ClinicAppointment.associate = (models) => {
        ClinicAppointment.belongsTo(models.outlets, {
            foreignKey: 'outlet_id',
            as: 'outlet'
        });
        if (models.customers) {
            ClinicAppointment.belongsTo(models.customers, {
                foreignKey: 'patient_id',
                as: 'patient'
            });
        }
        if (models.sales_headers) {
            ClinicAppointment.belongsTo(models.sales_headers, {
                foreignKey: 'billing_sale_id',
                as: 'sale'
            });
        }
    };

    return ClinicAppointment;
};
