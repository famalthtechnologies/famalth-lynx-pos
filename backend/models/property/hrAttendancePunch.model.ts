module.exports = (sequelize, DataTypes) => {
    const HrAttendancePunch = sequelize.define('hr_attendance_punches', {
        id: { type: DataTypes.INTEGER, primaryKey: true, autoIncrement: true },
        outlet_id: { type: DataTypes.INTEGER, allowNull: false },
        employee_id: { type: DataTypes.INTEGER, allowNull: false },
        punch_date: { type: DataTypes.DATEONLY, allowNull: false },
        punch_in: { type: DataTypes.DATE, allowNull: true },
        punch_out: { type: DataTypes.DATE, allowNull: true },
        hours_worked: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0.00 },
        overtime_hours: { type: DataTypes.DECIMAL(5, 2), allowNull: false, defaultValue: 0.00 },
        lateness_mins: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 },
        status: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Absent' },
        punch_source: { type: DataTypes.STRING(50), allowNull: false, defaultValue: 'Manual' },
        updated_by: { type: DataTypes.INTEGER, allowNull: true },
        leave_type_id: { type: DataTypes.INTEGER, allowNull: true },
        office_id: { type: DataTypes.INTEGER, allowNull: true },
        checkin_latitude: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
        checkin_longitude: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
        checkin_distance_meters: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
        checkout_latitude: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
        checkout_longitude: { type: DataTypes.DECIMAL(10, 7), allowNull: true },
        checkout_distance_meters: { type: DataTypes.DECIMAL(10, 2), allowNull: true },
        is_geofence_compliant: { type: DataTypes.BOOLEAN, allowNull: false, defaultValue: true },
        early_departure_mins: { type: DataTypes.INTEGER, allowNull: false, defaultValue: 0 }
    }, {
        tableName: 'hr_attendance_punches',
        timestamps: true,
        createdAt: 'created_at',
        updatedAt: 'updated_at'
    });

    HrAttendancePunch.associate = (models: any) => {
        HrAttendancePunch.belongsTo(models.outlets, { foreignKey: 'outlet_id', as: 'outlet' });
        HrAttendancePunch.belongsTo(models.hr_employees, { foreignKey: 'employee_id', as: 'employee' });
        HrAttendancePunch.belongsTo(models.hr_leave_types, { foreignKey: 'leave_type_id', as: 'leaveType' });
        HrAttendancePunch.belongsTo(models.hr_offices, { foreignKey: 'office_id', as: 'office' });
    };

    return HrAttendancePunch;
};


export default module.exports;
