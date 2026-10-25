module.exports = (sequelize, DataTypes) => {
    if (sequelize && typeof sequelize.query === 'function') {
        sequelize.query(`
            ALTER TABLE clinic_appointments
            ADD COLUMN IF NOT EXISTS attended_by_doctor_name VARCHAR(150);
        `).catch(() => {});
    }

    const ClinicAppointment = sequelize.define('clinic_appointments', {
        attended_by_doctor_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
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
        prescription_file_url: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        diagnosis: {
            type: DataTypes.TEXT,
            allowNull: true
        },
        vital_signs: {
            type: DataTypes.JSONB,
            allowNull: true,
            defaultValue: {}
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
        billing_sale_no: {
            type: DataTypes.STRING(50),
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
        },
        payment_status: {
            type: DataTypes.STRING(30),
            allowNull: false,
            defaultValue: 'UNPAID' // UNPAID, PAID, PAY_LATER, PACKAGE_INCLUDED
        },
        payment_mode: {
            type: DataTypes.STRING(50),
            allowNull: true,
            defaultValue: null // CASH, CARD, UPI, PREPAID, PACKAGE
        },
        paid_amount: {
            type: DataTypes.DECIMAL(10, 2),
            allowNull: false,
            defaultValue: 0.00
        },
        package_name: {
            type: DataTypes.STRING(150),
            allowNull: true
        },
        session_number: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 0
        },
        total_package_sessions: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 0
        },
        token_number: {
            type: DataTypes.INTEGER,
            allowNull: true,
            defaultValue: 1
        },
        is_package_session: {
            type: DataTypes.BOOLEAN,
            allowNull: false,
            defaultValue: false
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
