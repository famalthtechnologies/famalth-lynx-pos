const { Op, Sequelize } = require('sequelize');

const getAppointments = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { search, from_date, to_date, status, doctor_name } = req.query;

        const where = { outlet_id };

        if (status && status !== 'ALL') {
            where.status = status;
        }

        if (doctor_name && doctor_name.trim()) {
            where.doctor_name = { [Op.iLike]: `%${doctor_name.trim()}%` };
        }

        if (from_date && to_date) {
            where.appointment_date = { [Op.between]: [from_date, to_date] };
        } else if (from_date) {
            where.appointment_date = from_date;
        }

        if (search && search.trim()) {
            const q = search.trim();
            where[Op.or] = [
                { patient_name: { [Op.iLike]: `%${q}%` } },
                { patient_phone: { [Op.iLike]: `%${q}%` } },
                { doctor_name: { [Op.iLike]: `%${q}%` } }
            ];
        }

        const data = await req.propertyDb.models.clinic_appointments.findAll({
            where,
            order: [
                ['appointment_date', 'DESC'],
                ['appointment_time', 'ASC']
            ]
        });

        return res.json({
            success: true,
            count: data.length,
            data
        });
    } catch (err) {
        console.error('[GET APPOINTMENTS ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const createAppointment = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const {
            patient_name,
            patient_phone,
            patient_email,
            patient_age,
            patient_gender,
            appointment_date,
            appointment_time,
            doctor_name,
            department,
            reason_for_visit,
            source = 'POS'
        } = req.body;

        if (!patient_name || !patient_phone || !appointment_date || !appointment_time) {
            return res.status(400).json({
                success: false,
                message: 'Patient name, phone number, appointment date, and time are required.'
            });
        }

        // Auto find or create customer record
        let customer = await req.propertyDb.models.customers.findOne({
            where: {
                outlet_id,
                customer_phone: patient_phone.trim()
            }
        });

        if (!customer) {
            customer = await req.propertyDb.models.customers.create({
                outlet_id,
                customer_name: patient_name.trim(),
                customer_phone: patient_phone.trim(),
                customer_email: patient_email ? patient_email.trim().toLowerCase() : ''
            });
        }

        const appointment = await req.propertyDb.models.clinic_appointments.create({
            outlet_id,
            patient_id: customer.id,
            patient_name: patient_name.trim(),
            patient_phone: patient_phone.trim(),
            patient_email: patient_email ? patient_email.trim().toLowerCase() : null,
            patient_age: patient_age ? Number(patient_age) : null,
            patient_gender: patient_gender || null,
            appointment_date,
            appointment_time,
            doctor_name: doctor_name ? doctor_name.trim() : null,
            department: department ? department.trim() : null,
            reason_for_visit: reason_for_visit || null,
            status: 'SCHEDULED',
            source
        });

        return res.json({
            success: true,
            message: 'Appointment booked successfully!',
            data: appointment
        });
    } catch (err) {
        console.error('[CREATE APPOINTMENT ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const updateAppointmentStatus = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { status, doctor_name } = req.body;

        const appointment = await req.propertyDb.models.clinic_appointments.findOne({
            where: { id, outlet_id }
        });

        if (!appointment) {
            return res.status(404).json({ success: false, message: 'Appointment not found' });
        }

        const updates = { status };
        if (status === 'VISITED') {
            updates.visited_at = new Date();
        }
        if (doctor_name) {
            updates.doctor_name = doctor_name;
        }

        await appointment.update(updates);

        return res.json({
            success: true,
            message: `Appointment marked as ${status}`,
            data: appointment
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

const savePrescription = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const { prescription_notes, prescribed_medicines, doctor_name, prescription_file_url, diagnosis, vital_signs } = req.body;

        const appointment = await req.propertyDb.models.clinic_appointments.findOne({
            where: { id, outlet_id }
        });

        if (!appointment) {
            return res.status(404).json({ success: false, message: 'Appointment not found' });
        }

        const updates = {
            prescription_notes: prescription_notes || '',
            prescribed_medicines: Array.isArray(prescribed_medicines) ? prescribed_medicines : [],
            status: 'VISITED',
            visited_at: appointment.visited_at || new Date()
        };

        if (doctor_name) updates.doctor_name = doctor_name;
        if (prescription_file_url !== undefined) updates.prescription_file_url = prescription_file_url;
        if (diagnosis !== undefined) updates.diagnosis = diagnosis;
        if (vital_signs !== undefined) updates.vital_signs = vital_signs;

        await appointment.update(updates);

        return res.json({
            success: true,
            message: 'Prescription saved successfully!',
            data: appointment
        });
    } catch (err) {
        console.error('[SAVE PRESCRIPTION ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const sendToBillingDraft = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const { id } = req.params;

        const appointment = await req.propertyDb.models.clinic_appointments.findOne({
            where: { id, outlet_id }
        });

        if (!appointment) {
            return res.status(404).json({ success: false, message: 'Appointment not found' });
        }

        const medicines = appointment.prescribed_medicines || [];
        if (!Array.isArray(medicines) || medicines.length === 0) {
            return res.status(400).json({
                success: false,
                message: 'No medicines have been prescribed for this appointment to send to billing.'
            });
        }

        // Format items for POS sales draft
        let subtotal = 0;
        const cartItems = medicines.map((m) => {
            const rate = Number(m.rate || m.retail_sale_price || 0);
            const qty = Number(m.qty || 1);
            const lineTotal = Number((rate * qty).toFixed(2));
            subtotal += lineTotal;

            return {
                item_id: m.item_id || null,
                item_code: m.item_code || '',
                item_name: m.item_name || '',
                brand: m.brand || 'General',
                unit: m.unit || 'PCS',
                qty,
                rate,
                tax_percent: Number(m.tax_percent || 0),
                tax_amount: Number((lineTotal * (Number(m.tax_percent || 0) / 100)).toFixed(2)),
                line_total: lineTotal,
                notes: `Prescription: ${m.dosage || ''} ${m.frequency || ''} ${m.duration ? 'x ' + m.duration : ''}`.trim()
            };
        });

        // Store draft sale in draft_sales or return cart package for POS
        let draftRecord = null;
        if (req.propertyDb.models.draft_sales) {
            draftRecord = await req.propertyDb.models.draft_sales.create({
                outlet_id,
                created_by: user_id,
                customer_name: appointment.patient_name,
                customer_phone: appointment.patient_phone,
                customer_id: appointment.patient_id,
                cart_items: cartItems,
                subtotal: Number(subtotal.toFixed(2)),
                notes: `Doctor Consultation Draft - Patient: ${appointment.patient_name} (${appointment.doctor_name || 'Clinic'})`
            }).catch(() => null);
        }

        await appointment.update({
            billing_status: 'DRAFT_SENT'
        });

        return res.json({
            success: true,
            message: 'Prescription sent to billing system draft successfully!',
            data: {
                appointment_id: appointment.id,
                patient_name: appointment.patient_name,
                patient_phone: appointment.patient_phone,
                doctor_name: appointment.doctor_name,
                cart_items: cartItems,
                subtotal,
                draft_id: draftRecord ? draftRecord.id : null
            }
        });
    } catch (err) {
        console.error('[SEND TO BILLING DRAFT ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getAvailableMedicines = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { search } = req.query;

        const where = { outlet_id, is_active: true };
        if (search && search.trim()) {
            const q = search.trim();
            where[Op.or] = [
                { item_name: { [Op.iLike]: `%${q}%` } },
                { item_code: { [Op.iLike]: `%${q}%` } },
                { brand: { [Op.iLike]: `%${q}%` } }
            ];
        }

        const items = await req.propertyDb.models.item_master.findAll({
            where,
            attributes: [
                'id',
                'item_code',
                'item_name',
                'brand',
                'unit',
                'rate',
                'retail_sale_price',
                'tax_percent',
                'opening_balance'
            ],
            limit: 100,
            order: [['item_name', 'ASC']]
        });

        // Resolve current stock balance for items
        const results = [];
        for (const it of items) {
            const lastLedger = await req.propertyDb.models.stock_ledger.findOne({
                where: { outlet_id, item_code: it.item_code },
                order: [['id', 'DESC']],
                attributes: ['balance']
            });

            const stock = lastLedger && lastLedger.balance !== null
                ? Number(lastLedger.balance)
                : Number(it.opening_balance || 0);

            results.push({
                id: it.id,
                item_code: it.item_code,
                item_name: it.item_name,
                brand: it.brand || 'General',
                unit: it.unit || 'PCS',
                purchase_rate: Number(it.rate || 0),
                retail_sale_price: Number(it.retail_sale_price || it.rate || 0),
                tax_percent: Number(it.tax_percent || 0),
                current_stock: stock,
                in_stock: stock > 0
            });
        }

        return res.json({
            success: true,
            data: results
        });
    } catch (err) {
        console.error('[GET MEDICINES ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getClinicAnalytics = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { from_date, to_date } = req.query;

        const where = { outlet_id };
        if (from_date && to_date) {
            where.appointment_date = { [Op.between]: [from_date, to_date] };
        }

        const allAppointments = await req.propertyDb.models.clinic_appointments.findAll({
            where
        });

        const totalAppointments = allAppointments.length;
        const visitedCount = allAppointments.filter((a) => a.status === 'VISITED').length;
        const scheduledCount = allAppointments.filter((a) => a.status === 'SCHEDULED' || a.status === 'CONFIRMED').length;
        const cancelledCount = allAppointments.filter((a) => a.status === 'CANCELLED' || a.status === 'NO_SHOW').length;
        const draftSentCount = allAppointments.filter((a) => a.billing_status === 'DRAFT_SENT' || a.billing_status === 'BILLED').length;

        const uniquePhones = new Set(allAppointments.map((a) => a.patient_phone).filter(Boolean));
        const totalConsultationFees = allAppointments.reduce((acc, a) => acc + Number(a.consultation_fee || 0), 0);

        // Daily trend timeline (grouped by appointment_date)
        const dateMap = {};
        // Doctor performance & workload
        const docMap = {};
        // Top prescribed medicines
        const medMap = {};
        // Gender breakdown
        let maleCount = 0, femaleCount = 0, otherCount = 0;

        for (const a of allAppointments) {
            const d = a.appointment_date ? a.appointment_date.toString().substring(0, 10) : 'Other';
            if (!dateMap[d]) {
                dateMap[d] = { date: d, appointments: 0, visited: 0, billed: 0, cancelled: 0 };
            }
            dateMap[d].appointments++;
            if (a.status === 'VISITED') dateMap[d].visited++;
            if (a.status === 'CANCELLED' || a.status === 'NO_SHOW') dateMap[d].cancelled++;
            if (a.billing_status === 'DRAFT_SENT' || a.billing_status === 'BILLED') dateMap[d].billed++;

            // Doctor
            const docName = (a.doctor_name || 'General Physician').trim();
            if (!docMap[docName]) {
                docMap[docName] = { doctor: docName, count: 0, visited: 0 };
            }
            docMap[docName].count++;
            if (a.status === 'VISITED') docMap[docName].visited++;

            // Gender
            const g = (a.patient_gender || '').toUpperCase();
            if (g === 'MALE' || g === 'M') maleCount++;
            else if (g === 'FEMALE' || g === 'F') femaleCount++;
            else otherCount++;

            // Medicines
            if (Array.isArray(a.prescribed_medicines)) {
                for (const m of a.prescribed_medicines) {
                    const mKey = (m.item_code || m.item_name || 'Rx').toString();
                    if (!medMap[mKey]) {
                        medMap[mKey] = {
                            item_name: m.item_name || 'Medicine',
                            item_code: m.item_code || '-',
                            times_prescribed: 0,
                            total_qty: 0
                        };
                    }
                    medMap[mKey].times_prescribed++;
                    medMap[mKey].total_qty += Number(m.qty || 1);
                }
            }
        }

        const dailyTrends = Object.values(dateMap).sort((a, b) => a.date.localeCompare(b.date));
        const doctorWorkload = Object.values(docMap).sort((a, b) => b.count - a.count);
        const topMedicines = Object.values(medMap).sort((a, b) => b.times_prescribed - a.times_prescribed).slice(0, 10);

        return res.json({
            success: true,
            data: {
                total_appointments: totalAppointments,
                visited_count: visitedCount,
                scheduled_count: scheduledCount,
                cancelled_count: cancelledCount,
                draft_sent_count: draftSentCount,
                unique_patients_count: uniquePhones.size,
                total_consultation_fees: totalConsultationFees,
                attendance_rate_percent: totalAppointments > 0 ? Number(((visitedCount / totalAppointments) * 100).toFixed(1)) : 0,
                billing_conversion_percent: visitedCount > 0 ? Number(((draftSentCount / visitedCount) * 100).toFixed(1)) : 0,
                gender_demographics: { male: maleCount, female: femaleCount, other: otherCount },
                daily_trends: dailyTrends,
                doctor_workload: doctorWorkload,
                top_medicines: topMedicines
            }
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

const patientOtpStore = new Map();

const requestPatientEmailOtp = async (req, res) => {
    try {
        const { email } = req.body;
        const cleanEmail = (email || '').toString().trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes('@')) {
            return res.status(400).json({ success: false, message: 'Valid email address is required for verification.' });
        }

        const otp = Math.floor(100000 + Math.random() * 900000).toString();
        patientOtpStore.set(cleanEmail, {
            otp,
            expiresAt: Date.now() + 10 * 60 * 1000,
            email: cleanEmail,
            verified: false
        });

        const { sendOtpEmail } = require('../../modules/emailService');
        await sendOtpEmail(cleanEmail, otp, 'Patient Registration & Report Delivery Verification');

        return res.json({
            success: true,
            message: `Verification code sent to ${cleanEmail}. Enter this code to verify your email for medical reports and invoice delivery.`
        });
    } catch (err) {
        console.error('[PATIENT EMAIL OTP ERR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const verifyPatientEmailOtp = async (req, res) => {
    try {
        const { email, otp } = req.body;
        const cleanEmail = (email || '').toString().trim().toLowerCase();
        const entry = patientOtpStore.get(cleanEmail);

        if (!entry || entry.otp !== (otp || '').toString().trim() || Date.now() > entry.expiresAt) {
            return res.status(400).json({ success: false, message: 'Invalid or expired verification code. Please request a new code.' });
        }

        entry.verified = true;
        patientOtpStore.set(cleanEmail, entry);

        let existingCustomer = null;
        try {
            existingCustomer = await req.propertyDb.models.customers.findOne({
                where: { customer_email: cleanEmail },
                order: [['id', 'DESC']]
            });
        } catch (_) {}

        return res.json({
            success: true,
            message: 'Email successfully verified!',
            is_registered: !!existingCustomer,
            patient: existingCustomer ? {
                id: existingCustomer.id,
                name: existingCustomer.customer_name,
                phone: existingCustomer.customer_phone,
                email: existingCustomer.customer_email,
                address: existingCustomer.customer_address
            } : null
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getPublicDoctorCities = async (req, res) => {
    try {
        const propInfos = await req.propertyDb.models.property_info.findAll({
            attributes: ['city'],
            raw: true
        });

        const doctorUsers = await req.propertyDb.models.users.findAll({
            where: {
                [Op.or]: [
                    { role: 'DOCTOR' },
                    { is_public_listed: true }
                ]
            },
            attributes: ['doctor_city'],
            raw: true
        });

        const citiesSet = new Set();
        for (const p of propInfos) {
            if (p.city && p.city.trim()) citiesSet.add(p.city.trim());
        }
        for (const u of doctorUsers) {
            if (u.doctor_city && u.doctor_city.trim()) citiesSet.add(u.doctor_city.trim());
        }

        if (citiesSet.size === 0) {
            ['New Delhi', 'Mumbai', 'Bangalore', 'Hyderabad', 'Chennai', 'Kolkata', 'Pune', 'Ahmedabad'].forEach(c => citiesSet.add(c));
        }

        const cities = Array.from(citiesSet).sort();
        return res.json({
            success: true,
            data: cities
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getPublicSpecialities = async (req, res) => {
    try {
        const specialities = [
            'General Physician',
            'Cardiologist',
            'Dermatologist',
            'Pediatrician',
            'Dentist',
            'Orthopedic',
            'Gynecologist',
            'Neurologist',
            'Psychiatrist',
            'Physiotherapy',
            'ENT Specialist',
            'Ophthalmology'
        ];

        return res.json({
            success: true,
            data: specialities
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getPublicDoctors = async (req, res) => {
    try {
        const { city, speciality, search } = req.query;

        const userWhere = {
            is_active: true,
            [Op.or]: [
                { role: 'DOCTOR' },
                { is_public_listed: true }
            ]
        };

        if (speciality && speciality !== 'ALL') {
            userWhere.speciality = { [Op.iLike]: `%${speciality.trim()}%` };
        }

        const doctorUsers = await req.propertyDb.models.users.findAll({
            where: userWhere
        });

        const clinics = await req.propertyDb.models.property_info.findAll();
        const clinicByOutlet = new Map();
        for (const c of clinics) {
            clinicByOutlet.set(c.outlet_id, c);
        }

        let results = [];
        for (const d of doctorUsers) {
            const clinic = clinicByOutlet.get(d.outlet_id) || {};
            const docCity = d.doctor_city || clinic.city || 'General';

            results.push({
                id: d.id,
                name: d.full_name || d.username,
                speciality: d.speciality || 'General Physician',
                qualification: d.qualification || 'MBBS, MD',
                experience_years: d.experience_years || 5,
                consultation_fee: Number(d.consultation_fee || 500),
                is_verified_badge: d.is_verified_badge !== false,
                rating: 4.9,
                doctor_bio: d.doctor_bio || `Senior Specialist with ${d.experience_years || 5}+ years clinical experience.`,
                clinic_name: clinic.property_name || 'Famalth Lynx Healthcare Clinic',
                city: docCity,
                address: clinic.address || clinic.address_line1 || 'Main Medical Center',
                phone: clinic.mobile || d.mobile || '',
                outlet_id: d.outlet_id,
                available_days: (d.available_days || 'Mon,Tue,Wed,Thu,Fri,Sat').split(',')
            });
        }

        if (results.length === 0) {
            for (const c of clinics) {
                const docCity = c.city || 'New Delhi';
                results.push({
                    id: 1,
                    name: 'Dr. Aarav Sharma',
                    speciality: 'Cardiologist',
                    qualification: 'MBBS, MD, DM (Cardiology)',
                    experience_years: 14,
                    consultation_fee: 800,
                    is_verified_badge: true,
                    rating: 4.9,
                    doctor_bio: 'Senior Cardiologist specializing in preventive heart health and diagnostics.',
                    clinic_name: c.property_name || 'Apex Health & Heart Clinic',
                    city: docCity,
                    address: c.address || 'Medical Enclave, Main Road',
                    phone: c.mobile || '',
                    outlet_id: c.outlet_id,
                    available_days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri']
                }, {
                    id: 2,
                    name: 'Dr. Priya Patel',
                    speciality: 'Dermatologist',
                    qualification: 'MBBS, MD (Dermatology)',
                    experience_years: 10,
                    consultation_fee: 600,
                    is_verified_badge: true,
                    rating: 4.8,
                    doctor_bio: 'Expert Dermatologist and cosmetologist.',
                    clinic_name: c.property_name || 'Skin & Wellness Clinic',
                    city: docCity,
                    address: c.address || 'Suite 201, Health Hub',
                    phone: c.mobile || '',
                    outlet_id: c.outlet_id,
                    available_days: ['Mon', 'Wed', 'Fri', 'Sat']
                }, {
                    id: 3,
                    name: 'Dr. Rajesh Verma',
                    speciality: 'General Physician',
                    qualification: 'MBBS, DNB (Internal Medicine)',
                    experience_years: 16,
                    consultation_fee: 500,
                    is_verified_badge: true,
                    rating: 4.9,
                    doctor_bio: 'Comprehensive internal medicine, family wellness, and viral fever care.',
                    clinic_name: c.property_name || 'City Care Medical Clinic',
                    city: docCity,
                    address: c.address || 'Central Market Block B',
                    phone: c.mobile || '',
                    outlet_id: c.outlet_id,
                    available_days: ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat']
                }, {
                    id: 4,
                    name: 'Dr. Ananya Roy',
                    speciality: 'Pediatrician',
                    qualification: 'MBBS, MD (Pediatrics)',
                    experience_years: 9,
                    consultation_fee: 550,
                    is_verified_badge: true,
                    rating: 4.9,
                    doctor_bio: 'Child healthcare, vaccinations, and pediatric nutrition guidance.',
                    clinic_name: c.property_name || 'Little Steps Child Clinic',
                    city: docCity,
                    address: c.address || 'First Floor, Rainbow Plaza',
                    phone: c.mobile || '',
                    outlet_id: c.outlet_id,
                    available_days: ['Mon', 'Tue', 'Thu', 'Fri', 'Sat']
                });
            }
        }

        if (city && city.trim() && city !== 'ALL') {
            const cleanCity = city.trim().toLowerCase();
            results = results.filter((d) => (d.city || '').toLowerCase().includes(cleanCity));
        }

        if (speciality && speciality !== 'ALL') {
            const cleanSpec = speciality.trim().toLowerCase();
            results = results.filter((d) => (d.speciality || '').toLowerCase().includes(cleanSpec));
        }

        if (search && search.trim()) {
            const q = search.trim().toLowerCase();
            results = results.filter((d) =>
                (d.name || '').toLowerCase().includes(q) ||
                (d.speciality || '').toLowerCase().includes(q) ||
                (d.clinic_name || '').toLowerCase().includes(q) ||
                (d.city || '').toLowerCase().includes(q)
            );
        }

        return res.json({
            success: true,
            count: results.length,
            city_filter: city || 'ALL',
            data: results
        });
    } catch (err) {
        console.error('[GET PUBLIC DOCTORS ERR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const bookAppointmentPublic = async (req, res) => {
    try {
        let outlet_id = req.body.outlet_id || req.query.outlet_id;
        if (!outlet_id) {
            const firstActive = await req.propertyDb.models.outlets.findOne({ where: { is_active: true } });
            outlet_id = firstActive ? firstActive.id : null;
        }

        if (!outlet_id) {
            return res.status(400).json({ success: false, message: 'Valid outlet ID is required' });
        }

        const settings = await req.propertyDb.models.system_settings.findOne({ where: { outlet_id } });
        if (settings && settings.allow_public_appointments === false) {
            return res.status(403).json({
                success: false,
                message: 'Online appointment booking is currently disabled for this clinic.'
            });
        }

        const {
            patient_name,
            patient_phone,
            patient_email,
            email_otp,
            patient_age,
            patient_gender,
            appointment_date,
            appointment_time,
            doctor_name,
            doctor_id,
            consultation_fee,
            department,
            reason_for_visit
        } = req.body;

        if (!patient_name || !patient_phone || !appointment_date || !appointment_time) {
            return res.status(400).json({
                success: false,
                message: 'Patient name, phone number, appointment date, and time are required.'
            });
        }

        const cleanEmail = (patient_email || '').toString().trim().toLowerCase();
        if (!cleanEmail || !cleanEmail.includes('@')) {
            return res.status(400).json({
                success: false,
                message: 'A valid email address is required for sending medical reports and invoices.'
            });
        }

        // Email Verification Enforcement
        let isEmailVerified = false;
        const existingCustomer = await req.propertyDb.models.customers.findOne({
            where: {
                outlet_id,
                [Op.or]: [
                    { customer_email: cleanEmail },
                    { customer_phone: patient_phone.trim() }
                ]
            }
        });

        if (existingCustomer && existingCustomer.is_email_verified) {
            isEmailVerified = true;
        } else if (email_otp) {
            const entry = patientOtpStore.get(cleanEmail);
            if (entry && entry.otp === String(email_otp).trim() && Date.now() <= entry.expiresAt) {
                isEmailVerified = true;
                entry.verified = true;
            } else {
                return res.status(400).json({
                    success: false,
                    message: 'Invalid or expired email verification code. Please verify your email first.'
                });
            }
        } else {
            const entry = patientOtpStore.get(cleanEmail);
            if (entry && entry.verified) {
                isEmailVerified = true;
            } else {
                return res.status(400).json({
                    success: false,
                    requires_email_verification: true,
                    message: 'Email verification code is required to receive appointment reports and invoice.'
                });
            }
        }

        const phone = patient_phone.trim();
        let customer = existingCustomer;
        if (!customer) {
            customer = await req.propertyDb.models.customers.create({
                outlet_id,
                customer_name: patient_name.trim(),
                customer_phone: phone,
                customer_email: cleanEmail,
                is_email_verified: isEmailVerified,
                email_verified_at: isEmailVerified ? new Date() : null
            });
        } else {
            await customer.update({
                customer_name: patient_name.trim(),
                customer_email: cleanEmail,
                is_email_verified: isEmailVerified,
                email_verified_at: isEmailVerified ? new Date() : customer.email_verified_at
            });
        }

        const appointment = await req.propertyDb.models.clinic_appointments.create({
            outlet_id,
            patient_id: customer.id,
            patient_name: patient_name.trim(),
            patient_phone: phone,
            patient_email: cleanEmail,
            patient_age: patient_age ? Number(patient_age) : null,
            patient_gender: patient_gender || null,
            appointment_date,
            appointment_time,
            doctor_name: doctor_name ? doctor_name.trim() : null,
            doctor_id: doctor_id ? Number(doctor_id) : null,
            consultation_fee: consultation_fee ? Number(consultation_fee) : 0.00,
            is_email_verified: isEmailVerified,
            email_otp_verified_at: isEmailVerified ? new Date() : null,
            department: department ? department.trim() : null,
            reason_for_visit: reason_for_visit || null,
            status: 'SCHEDULED',
            source: 'ONLINE_WEB'
        });

        try {
            const { getSocketHub } = require('../../services/socketHub.service');
            const io = getSocketHub();
            if (io) {
                io.emit('clinic_appointment_created', {
                    outlet_id,
                    appointment_id: appointment.id,
                    patient_name: appointment.patient_name,
                    patient_phone: appointment.patient_phone,
                    patient_email: appointment.patient_email,
                    appointment_date: appointment.appointment_date,
                    appointment_time: appointment.appointment_time,
                    doctor_name: appointment.doctor_name,
                    source: 'ONLINE_WEB'
                });
            }
        } catch (sErr) {}

        try {
            await req.propertyDb.models.system_notifications.create({
                outlet_id,
                title: 'New Clinic Appointment Booked Online',
                message: `Patient ${patient_name} (${cleanEmail} / ${phone}) booked with Dr. ${doctor_name || 'General'} on ${appointment_date} at ${appointment_time}`,
                type: 'INFO',
                is_read: false
            });
        } catch (nErr) {}

        return res.json({
            success: true,
            message: 'Appointment booked successfully! Confirmation and reports will be sent to your verified email.',
            data: appointment
        });
    } catch (err) {
        console.error('[BOOK APPOINTMENT PUBLIC ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getPatientHistoryPublic = async (req, res) => {
    try {
        const phone = req.query.phone ? req.query.phone.trim() : '';
        const email = req.query.email ? req.query.email.trim().toLowerCase() : '';

        if (!phone && !email) {
            return res.status(400).json({ success: false, message: 'Patient phone number or verified email is required.' });
        }

        const where = {};
        if (phone && email) {
            where[Op.or] = [
                { patient_phone: phone },
                { patient_email: email }
            ];
        } else if (phone) {
            where.patient_phone = phone;
        } else {
            where.patient_email = email;
        }

        const appointments = await req.propertyDb.models.clinic_appointments.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.outlets,
                    as: 'outlet',
                    attributes: ['id', 'outlet_code', 'outlet_name'],
                    required: false
                }
            ],
            order: [
                ['appointment_date', 'DESC'],
                ['appointment_time', 'DESC']
            ]
        });

        const enriched = [];
        for (const a of appointments) {
            const json = a.toJSON();
            const propInfo = await req.propertyDb.models.property_info.findOne({
                where: { outlet_id: json.outlet_id },
                attributes: ['property_name', 'city', 'address', 'mobile']
            });

            json.clinic_name = propInfo ? propInfo.property_name : (json.outlet ? json.outlet.outlet_name : 'Clinic');
            json.clinic_city = propInfo ? propInfo.city : '';
            json.clinic_address = propInfo ? propInfo.address : '';
            enriched.push(json);
        }

        return res.json({
            success: true,
            count: enriched.length,
            data: enriched
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = {
    getAppointments,
    createAppointment,
    updateAppointmentStatus,
    savePrescription,
    sendToBillingDraft,
    getAvailableMedicines,
    getClinicAnalytics,
    requestPatientEmailOtp,
    verifyPatientEmailOtp,
    getPublicDoctorCities,
    getPublicSpecialities,
    getPublicDoctors,
    bookAppointmentPublic,
    getPatientHistoryPublic
};
