var __defProp = Object.defineProperty;
var __getOwnPropDesc = Object.getOwnPropertyDescriptor;
var __getOwnPropNames = Object.getOwnPropertyNames;
var __hasOwnProp = Object.prototype.hasOwnProperty;
var __export = (target, all) => {
  for (var name in all)
    __defProp(target, name, { get: all[name], enumerable: true });
};
var __copyProps = (to, from, except, desc) => {
  if (from && typeof from === "object" || typeof from === "function") {
    for (let key of __getOwnPropNames(from))
      if (!__hasOwnProp.call(to, key) && key !== except)
        __defProp(to, key, { get: () => from[key], enumerable: !(desc = __getOwnPropDesc(from, key)) || desc.enumerable });
  }
  return to;
};
var __toCommonJS = (mod) => __copyProps(__defProp({}, "__esModule", { value: true }), mod);
var clinic_controller_exports = {};
__export(clinic_controller_exports, {
  acceptAndPayAppointment: () => acceptAndPayAppointment,
  bookAppointmentPublic: () => bookAppointmentPublic,
  completeAppointmentBilling: () => completeAppointmentBilling,
  consumeClinicSubscriptionSession: () => consumeClinicSubscriptionSession,
  createAppointment: () => createAppointment,
  createClinicDoctor: () => createClinicDoctor,
  createClinicSubscription: () => createClinicSubscription,
  default: () => clinic_controller_default,
  deleteClinicDoctor: () => deleteClinicDoctor,
  getAppointments: () => getAppointments,
  getAvailableMedicines: () => getAvailableMedicines,
  getClinicAnalytics: () => getClinicAnalytics,
  getClinicDoctors: () => getClinicDoctors,
  getClinicPatientHistory: () => getClinicPatientHistory,
  getClinicSubscriptionLedger: () => getClinicSubscriptionLedger,
  getClinicSubscriptions: () => getClinicSubscriptions,
  getClinicalTestsMaster: () => getClinicalTestsMaster,
  getPatientHistoryPublic: () => getPatientHistoryPublic,
  getPublicDoctorCities: () => getPublicDoctorCities,
  getPublicDoctors: () => getPublicDoctors,
  getPublicPatientSubscriptions: () => getPublicPatientSubscriptions,
  getPublicSpecialities: () => getPublicSpecialities,
  requestPatientEmailOtp: () => requestPatientEmailOtp,
  saveClinicalTestMaster: () => saveClinicalTestMaster,
  savePrescription: () => savePrescription,
  sendToBillingDraft: () => sendToBillingDraft,
  updateAppointmentStatus: () => updateAppointmentStatus,
  updateClinicDoctor: () => updateClinicDoctor,
  verifyPatientEmailOtp: () => verifyPatientEmailOtp
});
module.exports = __toCommonJS(clinic_controller_exports);
var import_sequelize = require("sequelize");
const getAppointments = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { search, from_date: from_date2, to_date: to_date2, status, doctor_name, doctor_id, attendance, fee_status, billing_status, department_view } = req.query;
    const where = { outlet_id: outlet_id2 };
    if (status && status !== "ALL") {
      where.status = status;
    }
    if (attendance && attendance !== "ALL") {
      if (attendance === "ATTENDED") {
        where.status = { [import_sequelize.Op.in]: ["VISITED", "COMPLETED"] };
      } else if (attendance === "UNATTENDED") {
        where.status = { [import_sequelize.Op.in]: ["SCHEDULED", "CONFIRMED"] };
      }
    }
    if (fee_status && fee_status !== "ALL") {
      if (fee_status === "PAID") {
        where.payment_status = { [import_sequelize.Op.in]: ["PAID", "PACKAGE_INCLUDED"] };
      } else if (fee_status === "UNPAID") {
        where.payment_status = { [import_sequelize.Op.in]: ["UNPAID", "PAY_LATER"] };
      }
    }
    if (billing_status && billing_status !== "ALL") {
      if (billing_status === "BILLED") {
        where.billing_status = "BILLED";
      } else if (billing_status === "UNBILLED") {
        where.billing_status = { [import_sequelize.Op.ne]: "BILLED" };
      }
    }
    if (doctor_id) {
      where.doctor_id = Number(doctor_id);
    } else if (doctor_name && doctor_name.trim() && doctor_name !== "ALL") {
      where.doctor_name = { [import_sequelize.Op.iLike]: `%${doctor_name.trim()}%` };
    }
    if (from_date2 && to_date2) {
      where.appointment_date = { [import_sequelize.Op.between]: [from_date2, to_date2] };
    } else if (from_date2) {
      where.appointment_date = from_date2;
    }
    if (search && search.trim()) {
      const q = search.trim();
      where[import_sequelize.Op.or] = [
        { patient_name: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { patient_phone: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { doctor_name: { [import_sequelize.Op.iLike]: `%${q}%` } }
      ];
    }
    const data = await req.propertyDb.models.clinic_appointments.findAll({
      where,
      order: [
        ["appointment_date", "DESC"],
        ["token_number", "ASC"],
        ["appointment_time", "ASC"]
      ]
    });
    for (const appt of data) {
      if (appt.billing_sale_id) {
        try {
          const sale = await req.propertyDb.models.sales_headers.findOne({
            where: { id: appt.billing_sale_id, outlet_id: outlet_id2 }
          });
          if (sale) {
            const saleTime = new Date(sale.created_at || sale.sale_date).getTime();
            const apptTime = new Date(appt.created_at || appt.appointment_date + "T" + (appt.appointment_time || "00:00:00")).getTime();
            if (saleTime < apptTime - 6e4) {
              appt.billing_status = "PENDING";
              appt.billing_sale_id = null;
              appt.billing_sale_no = null;
              await appt.update({
                billing_status: "PENDING",
                billing_sale_id: null,
                billing_sale_no: null
              }).catch(() => null);
            }
          }
        } catch (_) {
        }
      }
      const phone = (appt.patient_phone || "").toString().trim();
      if (phone) {
        try {
          const priorCount = await req.propertyDb.models.clinic_appointments.count({
            where: {
              outlet_id: outlet_id2,
              patient_phone: phone,
              status: "VISITED"
            }
          });
          const isRepeat = priorCount > 0;
          if (appt.setDataValue) {
            appt.setDataValue("is_repeat_patient", isRepeat);
            appt.setDataValue("total_prior_visits", priorCount);
          } else {
            appt.is_repeat_patient = isRepeat;
            appt.total_prior_visits = priorCount;
          }
        } catch (_) {
        }
      }
      const attendedDoc = appt.attended_by_doctor_name || appt.vital_signs && appt.vital_signs.attended_by_doctor_name || (appt.status === "VISITED" ? appt.doctor_name : null);
      if (appt.setDataValue) {
        appt.setDataValue("attended_by_doctor_name", attendedDoc);
      } else {
        appt.attended_by_doctor_name = attendedDoc;
      }
      if (phone && req.propertyDb.models.milk_subscriptions) {
        try {
          const activeSub = await req.propertyDb.models.milk_subscriptions.findOne({
            where: {
              outlet_id: outlet_id2,
              customer_phone: phone,
              status: "ACTIVE"
            },
            order: [["id", "DESC"]]
          });
          if (activeSub) {
            const totalAllowed = Number(activeSub.total_allowed_services || 0) + Number(activeSub.bonus_qty || 0);
            const consumed = Number(activeSub.services_consumed || 0);
            const remaining = Math.max(0, totalAllowed - consumed);
            const packageInfo = {
              id: activeSub.id,
              package_name: activeSub.item_name || "Therapy Package",
              total_sessions: totalAllowed,
              services_consumed: consumed,
              remaining_sessions: remaining,
              is_exhausted: remaining <= 0
            };
            if (appt.setDataValue) {
              appt.setDataValue("active_subscription", packageInfo);
            } else {
              appt.active_subscription = packageInfo;
            }
          }
        } catch (_) {
        }
      }
    }
    const todayStr = (/* @__PURE__ */ new Date()).toISOString().split("T")[0];
    let upcomingScheduledCount = 0;
    let nextUpcomingDate = null;
    try {
      const upcomingAppts = await req.propertyDb.models.clinic_appointments.findAll({
        where: {
          outlet_id: outlet_id2,
          status: { [import_sequelize.Op.in]: ["SCHEDULED", "CONFIRMED"] },
          appointment_date: { [import_sequelize.Op.gt]: to_date2 || from_date2 || todayStr }
        },
        order: [["appointment_date", "ASC"], ["id", "ASC"]],
        limit: 10,
        attributes: ["id", "appointment_date", "doctor_name", "patient_name"]
      });
      upcomingScheduledCount = upcomingAppts.length;
      if (upcomingScheduledCount > 0) {
        nextUpcomingDate = upcomingAppts[0].appointment_date;
      }
    } catch (_) {
    }
    return res.json({
      success: true,
      count: data.length,
      upcoming_scheduled_count: upcomingScheduledCount,
      next_upcoming_date: nextUpcomingDate,
      data
    });
  } catch (err) {
    console.error("[GET APPOINTMENTS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const createAppointment = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const {
      patient_name,
      patient_phone,
      patient_email,
      patient_age,
      patient_gender,
      appointment_date,
      appointment_time,
      doctor_name,
      doctor_id,
      consultation_fee,
      department,
      reason_for_visit,
      payment_status = "UNPAID",
      payment_mode,
      paid_amount,
      package_name,
      session_number,
      total_package_sessions,
      is_package_session = false,
      source = "POS"
    } = req.body;
    if (!patient_name || !patient_phone || !appointment_date || !appointment_time) {
      return res.status(400).json({
        success: false,
        message: "Patient name, phone number, appointment date, and time are required."
      });
    }
    let customer = await req.propertyDb.models.customers.findOne({
      where: {
        outlet_id: outlet_id2,
        customer_phone: patient_phone.trim()
      }
    });
    if (!customer) {
      customer = await req.propertyDb.models.customers.create({
        outlet_id: outlet_id2,
        customer_name: patient_name.trim(),
        customer_phone: patient_phone.trim(),
        customer_email: patient_email ? patient_email.trim().toLowerCase() : ""
      });
    }
    const todayCount = await req.propertyDb.models.clinic_appointments.count({
      where: {
        outlet_id: outlet_id2,
        appointment_date
      }
    });
    const token_number = todayCount + 1;
    const finalPaid = paid_amount ? Number(paid_amount) : payment_status === "PAID" ? Number(consultation_fee || 0) : 0;
    const appointment = await req.propertyDb.models.clinic_appointments.create({
      outlet_id: outlet_id2,
      token_number,
      patient_id: customer.id,
      patient_name: patient_name.trim(),
      patient_phone: patient_phone.trim(),
      patient_email: patient_email ? patient_email.trim().toLowerCase() : null,
      patient_age: patient_age ? Number(patient_age) : null,
      patient_gender: patient_gender || null,
      appointment_date,
      appointment_time,
      doctor_name: doctor_name ? doctor_name.trim() : null,
      doctor_id: doctor_id ? Number(doctor_id) : null,
      consultation_fee: consultation_fee ? Number(consultation_fee) : 0,
      payment_status: payment_status || "UNPAID",
      payment_mode: payment_mode || null,
      paid_amount: finalPaid,
      package_name: package_name || null,
      session_number: session_number ? Number(session_number) : 0,
      total_package_sessions: total_package_sessions ? Number(total_package_sessions) : 0,
      is_package_session: is_package_session === true || is_package_session === "true",
      department: department ? department.trim() : null,
      reason_for_visit: reason_for_visit || null,
      status: "SCHEDULED",
      source
    });
    if (payment_status === "PAID" && finalPaid > 0) {
      try {
        const { createLedgerEntry } = require("../../services/cashLedger.service");
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: appointment_date || /* @__PURE__ */ new Date(),
          transaction_type: "CONSULTATION_FEE",
          reference_type: "CLINIC_APPOINTMENT",
          reference_id: appointment.id,
          reference_no: `APPT-${appointment.id}`,
          party_name: appointment.patient_name,
          payment_method: payment_mode || "CASH",
          amount_in: finalPaid,
          notes: `OPD Consultation Fee: Token #${token_number} - ${appointment.patient_name} (${appointment.doctor_name || "Clinic"})`
        });
      } catch (ledgerErr) {
        console.error("[LEDGER RECEPTION BOOKING ERR]", ledgerErr);
      }
    } else if (payment_status === "PAY_LATER" && (consultation_fee ? Number(consultation_fee) : 0) > 0) {
      try {
        const dueAmount = Number(consultation_fee);
        const { createLedgerEntry } = require("../../services/cashLedger.service");
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: appointment_date || /* @__PURE__ */ new Date(),
          transaction_type: "SALE_CREDIT",
          reference_type: "CLINIC_APPOINTMENT",
          reference_id: appointment.id,
          reference_no: `APPT-${appointment.id}`,
          party_name: appointment.patient_name,
          payment_method: "CREDIT",
          amount_in: 0,
          adjustment_amount: dueAmount,
          notes: `Consultation Fee Due (Pay Later): Token #${token_number} - ${appointment.patient_name} (${appointment.doctor_name || "Clinic"})`
        });
        if (req.propertyDb.models.sales_headers) {
          await req.propertyDb.models.sales_headers.create({
            outlet_id: outlet_id2,
            sale_no: `APPT-${appointment.id}`,
            sale_date: appointment_date || /* @__PURE__ */ new Date(),
            customer_name: appointment.patient_name,
            customer_phone: appointment.patient_phone || "",
            net_amount: dueAmount,
            total_amount: dueAmount,
            amount_paid: 0,
            balance_amount: dueAmount,
            payment_mode: "CREDIT",
            order_type: "CLINIC_APPOINTMENT",
            status: "COMPLETED",
            is_latest: true,
            is_deleted: false,
            notes: `Consultation Fee Due (Pay Later) - Token #${token_number} (${appointment.doctor_name || "Clinic"})`
          }).catch(() => null);
        }
      } catch (creditErr) {
        console.error("[LEDGER BOOKING (CREDIT) ERR]", creditErr);
      }
    }
    return res.json({
      success: true,
      message: "Appointment booked successfully!",
      data: appointment
    });
  } catch (err) {
    console.error("[CREATE APPOINTMENT ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const updateAppointmentStatus = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const { status, doctor_name } = req.body;
    const appointment = await req.propertyDb.models.clinic_appointments.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!appointment) {
      return res.status(404).json({ success: false, message: "Appointment not found" });
    }
    const updates = { status };
    if (status === "VISITED") {
      updates.visited_at = /* @__PURE__ */ new Date();
      if (appointment.is_package_session && appointment.package_name && appointment.status !== "VISITED") {
        try {
          const sub = await req.propertyDb.models.milk_subscriptions.findOne({
            where: {
              outlet_id: outlet_id2,
              customer_phone: appointment.patient_phone,
              status: "ACTIVE"
            },
            order: [["id", "DESC"]]
          });
          if (sub) {
            const totalAllowed = Number(sub.total_allowed_services || 0) + Number(sub.bonus_qty || 0);
            let consumed = Number(sub.services_consumed || 0);
            if (consumed < totalAllowed) {
              consumed += 1;
              const isExhausted = consumed >= totalAllowed;
              await sub.update({
                services_consumed: consumed,
                status: isExhausted ? "EXHAUSTED" : "ACTIVE",
                active_subscription: !isExhausted
              });
              updates.session_number = consumed;
              updates.total_package_sessions = totalAllowed;
              const perSessionRate = totalAllowed > 0 ? Math.round(Number(sub.total_payment_amount || 0) / totalAllowed * 100) / 100 : Number(sub.per_service_price || 0);
              const today = (/* @__PURE__ */ new Date()).toISOString().substring(0, 10);
              const { createLedgerEntry } = require("../../services/cashLedger.service");
              await createLedgerEntry({
                db: req.propertyDb,
                outlet_id: outlet_id2,
                txn_date: today,
                transaction_type: "SUBSCRIPTION_SETTLEMENT",
                reference_type: "CLINIC_SUBSCRIPTION",
                reference_id: sub.id,
                reference_no: `SESS-${sub.id}-${consumed}`,
                party_name: sub.customer_name || appointment.patient_name,
                payment_method: "PACKAGE",
                amount_in: 0,
                amount_out: perSessionRate,
                notes: `Doctor Attended \u2022 Therapy Session #${consumed} of ${totalAllowed} Consumed: ${sub.item_name} (Debited: \u20AC${perSessionRate.toFixed(2)})`
              });
              if (req.propertyDb.models.customer_advances) {
                const adv = await req.propertyDb.models.customer_advances.findOne({
                  where: { outlet_id: outlet_id2, reference_no: `SUB-CLINIC-${sub.id}` }
                });
                if (adv) {
                  const newAvail = Math.max(0, Number(adv.available_amount || 0) - perSessionRate);
                  await adv.update({ available_amount: newAvail });
                }
              }
            }
          }
        } catch (subErr) {
          console.error("[ATTENDED DOCTOR SESSION DEDUCT ERR]", subErr);
        }
      }
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
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const { prescription_notes, prescribed_medicines, doctor_name, prescription_file_url, diagnosis, vital_signs, attended_by_doctor_name } = req.body;
    const appointment = await req.propertyDb.models.clinic_appointments.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!appointment) {
      return res.status(404).json({ success: false, message: "Appointment not found" });
    }
    const updates = {
      prescription_notes: prescription_notes || "",
      prescribed_medicines: Array.isArray(prescribed_medicines) ? prescribed_medicines : [],
      status: "VISITED",
      visited_at: appointment.visited_at || /* @__PURE__ */ new Date()
    };
    const attending = attended_by_doctor_name || doctor_name || appointment.doctor_name;
    if (attending) {
      updates.attended_by_doctor_name = attending;
      updates.doctor_name = attending;
    }
    if (prescription_file_url !== void 0) updates.prescription_file_url = prescription_file_url;
    if (diagnosis !== void 0) updates.diagnosis = diagnosis;
    if (vital_signs !== void 0) updates.vital_signs = vital_signs;
    await appointment.update(updates);
    return res.json({
      success: true,
      message: "Prescription saved successfully!",
      data: appointment
    });
  } catch (err) {
    console.error("[SAVE PRESCRIPTION ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const sendToBillingDraft = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const user_id = req.user.id;
    const { id } = req.params;
    const appointment = await req.propertyDb.models.clinic_appointments.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!appointment) {
      return res.status(404).json({ success: false, message: "Appointment not found" });
    }
    const medicines = appointment.prescribed_medicines || [];
    if (!Array.isArray(medicines) || medicines.length === 0) {
      return res.status(400).json({
        success: false,
        message: "No medicines have been prescribed for this appointment to send to billing."
      });
    }
    let subtotal = 0;
    const cartItems = medicines.map((m) => {
      const rate = Number(m.rate || m.retail_sale_price || 0);
      const qty = Number(m.qty || 1);
      const lineTotal = Number((rate * qty).toFixed(2));
      subtotal += lineTotal;
      return {
        item_id: m.item_id || null,
        item_code: m.item_code || "",
        item_name: m.item_name || "",
        brand: m.brand || "General",
        unit: m.unit || "PCS",
        qty,
        rate,
        tax_percent: Number(m.tax_percent || 0),
        tax_amount: Number((lineTotal * (Number(m.tax_percent || 0) / 100)).toFixed(2)),
        line_total: lineTotal,
        notes: `Prescription: ${m.dosage || ""} ${m.frequency || ""} ${m.duration ? "x " + m.duration : ""}`.trim()
      };
    });
    let draftRecord = null;
    if (req.propertyDb.models.draft_sales) {
      draftRecord = await req.propertyDb.models.draft_sales.create({
        outlet_id: outlet_id2,
        created_by: user_id,
        customer_name: appointment.patient_name,
        customer_phone: appointment.patient_phone,
        customer_id: appointment.patient_id,
        cart_items: cartItems,
        subtotal: Number(subtotal.toFixed(2)),
        notes: `Doctor Consultation Draft - Patient: ${appointment.patient_name} (${appointment.doctor_name || "Clinic"})`
      }).catch(() => null);
    }
    await appointment.update({
      billing_status: "DRAFT_SENT"
    });
    return res.json({
      success: true,
      message: "Prescription sent to billing system draft successfully!",
      data: {
        appointment_id: appointment.id,
        patient_name: appointment.patient_name,
        patient_phone: appointment.patient_phone,
        doctor_name: appointment.doctor_name,
        cart_items: cartItems,
        subtotal,
        draft_id: draftRecord?.id || null
      }
    });
  } catch (err) {
    console.error("[SEND TO BILLING DRAFT ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getAvailableMedicines = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { search } = req.query;
    const where = { outlet_id: outlet_id2, is_active: true };
    if (search && search.trim()) {
      const q = search.trim();
      where[import_sequelize.Op.or] = [
        { item_name: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { item_code: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { brand: { [import_sequelize.Op.iLike]: `%${q}%` } }
      ];
    }
    const items = await req.propertyDb.models.item_master.findAll({
      where,
      attributes: [
        "id",
        "item_code",
        "item_name",
        "brand",
        "unit",
        "rate",
        "retail_sale_price",
        "tax_percent",
        "opening_balance"
      ],
      limit: 100,
      order: [["item_name", "ASC"]]
    });
    const results = [];
    for (const it of items) {
      const lastLedger = await req.propertyDb.models.stock_ledger.findOne({
        where: { outlet_id: outlet_id2, item_code: it.item_code },
        order: [["id", "DESC"]],
        attributes: ["balance"]
      });
      const stock = lastLedger && lastLedger.balance !== null ? Number(lastLedger.balance) : Number(it.opening_balance || 0);
      results.push({
        id: it.id,
        item_code: it.item_code,
        item_name: it.item_name,
        brand: it.brand || "General",
        unit: it.unit || "PCS",
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
    console.error("[GET MEDICINES ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const completeAppointmentBilling = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const { sale_id, sale_no } = req.body;
    const appointment = await req.propertyDb.models.clinic_appointments.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!appointment) {
      return res.status(404).json({ success: false, message: "Appointment not found." });
    }
    await appointment.update({
      billing_status: "BILLED",
      billing_sale_id: sale_id ? Number(sale_id) : appointment.billing_sale_id,
      billing_sale_no: sale_no ? String(sale_no).trim() : appointment.billing_sale_no
    });
    return res.json({
      success: true,
      message: "Appointment billing recorded successfully.",
      data: appointment
    });
  } catch (err) {
    console.error("[COMPLETE APPOINTMENT BILLING ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getClinicDoctors = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    let doctors = await req.propertyDb.models.users.findAll({
      where: {
        outlet_id: outlet_id2,
        [import_sequelize.Op.or]: [
          { role: "DOCTOR" },
          { speciality: { [import_sequelize.Op.ne]: null } }
        ]
      },
      order: [["id", "ASC"]]
    });
    if (doctors.length === 0) {
      const clinic = await req.propertyDb.models.property_info.findOne({ where: { outlet_id: outlet_id2 } });
      const clinicName = clinic?.property_name || "Clinic";
      const defaultDoc = await req.propertyDb.models.users.create({
        outlet_id: outlet_id2,
        username: `dr_${Date.now()}`,
        full_name: "Dr. Primary Consultant",
        role: "DOCTOR",
        speciality: "General Physician",
        qualification: "MBBS, MD",
        registration_no: "MCI-REG-101",
        experience_years: 8,
        consultation_fee: 500,
        mobile: clinic?.mobile || "",
        whatsapp_no: clinic?.mobile || "",
        contact_email: clinic?.email || "",
        is_public_listed: true,
        doctor_city: clinic?.city || "General",
        doctor_bio: "Senior Consultant providing comprehensive patient care and clinical consultations.",
        available_days: "Mon,Tue,Wed,Thu,Fri,Sat",
        public_display_options: {
          show_clinic_name: true,
          show_doctor_name: true,
          show_address: true,
          show_phone: true,
          show_whatsapp: true,
          show_email: true,
          show_fees: true
        },
        is_active: true
      });
      doctors = [defaultDoc];
    }
    const results = [];
    for (const d of doctors) {
      const rawName = (d.full_name || d.username).trim();
      const cleanName = rawName.replace(/^Dr\.?\s+/i, "").trim();
      const appointments = await req.propertyDb.models.clinic_appointments.findAll({
        where: {
          outlet_id: outlet_id2,
          [import_sequelize.Op.or]: [
            { doctor_id: d.id },
            { doctor_name: { [import_sequelize.Op.iLike]: `%${cleanName}%` } },
            { doctor_name: { [import_sequelize.Op.iLike]: `%${rawName}%` } }
          ]
        }
      });
      const totalPatients = appointments.length;
      const visitedPatients = appointments.filter((a) => a.status === "VISITED").length;
      let totalFeesCollected = 0;
      const feesByMode = { CASH: 0, CARD: 0, UPI: 0, PREPAID: 0, PAY_LATER: 0, PACKAGE: 0 };
      for (const a of appointments) {
        const fee = Number(a.paid_amount || (a.payment_status === "PAID" ? a.consultation_fee : 0));
        if (a.payment_status === "PAID" || fee > 0) {
          totalFeesCollected += fee;
          const mode = (a.payment_mode || "CASH").toUpperCase();
          feesByMode[mode] = (feesByMode[mode] || 0) + fee;
        } else if (a.payment_status === "PAY_LATER") {
          if (a.is_package_session) {
            feesByMode["PACKAGE"] = (feesByMode["PACKAGE"] || 0) + 1;
          } else {
            feesByMode["PAY_LATER"] = (feesByMode["PAY_LATER"] || 0) + Number(a.consultation_fee || 0);
          }
        } else if (a.payment_status === "PACKAGE_INCLUDED" || a.is_package_session || a.payment_mode === "PACKAGE_SUBSCRIPTION") {
          feesByMode["PACKAGE"] = (feesByMode["PACKAGE"] || 0) + 1;
        }
      }
      let referredMedicineSales = 0;
      try {
        const sales = await req.propertyDb.models.sales_headers.findAll({
          where: {
            outlet_id: outlet_id2,
            [import_sequelize.Op.or]: [
              { doctor_name: { [import_sequelize.Op.iLike]: `%${cleanName}%` } },
              { doctor_name: { [import_sequelize.Op.iLike]: `%${rawName}%` } }
            ]
          },
          attributes: ["net_amount", "total_amount"]
        });
        referredMedicineSales = sales.reduce((sum, s) => sum + Number(s.net_amount || s.total_amount || 0), 0);
      } catch (_) {
      }
      results.push({
        id: d.id,
        full_name: d.full_name || d.username,
        speciality: d.speciality || "General Physician",
        qualification: d.qualification || "MBBS",
        registration_no: d.registration_no || "",
        experience_years: d.experience_years || 0,
        consultation_fee: Number(d.consultation_fee || 0),
        mobile: d.mobile || "",
        whatsapp_no: d.whatsapp_no || d.mobile || "",
        contact_email: d.contact_email || "",
        is_public_listed: d.is_public_listed !== false,
        doctor_city: d.doctor_city || "",
        doctor_bio: d.doctor_bio || "",
        available_days: d.available_days || "Mon,Tue,Wed,Thu,Fri,Sat",
        public_display_options: d.public_display_options || {
          show_clinic_name: true,
          show_doctor_name: true,
          show_address: true,
          show_phone: true,
          show_whatsapp: true,
          show_email: true,
          show_fees: true
        },
        total_patients: totalPatients,
        total_appointments: totalPatients,
        visited_patients: visitedPatients,
        visited_appointments: visitedPatients,
        total_fees_collected: totalFeesCollected,
        fees_by_mode: feesByMode,
        referred_medicine_sales: referredMedicineSales,
        medicine_sales_referred: referredMedicineSales
      });
    }
    return res.json({
      success: true,
      count: results.length,
      data: results
    });
  } catch (err) {
    console.error("[GET CLINIC DOCTORS ERR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const createClinicDoctor = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const {
      full_name,
      speciality,
      qualification,
      registration_no,
      experience_years,
      consultation_fee,
      mobile,
      whatsapp_no,
      contact_email,
      is_public_listed,
      doctor_city,
      doctor_bio,
      available_days,
      public_display_options
    } = req.body;
    if (!full_name || !full_name.trim()) {
      return res.status(400).json({ success: false, message: "Doctor full name is required." });
    }
    const cleanName = full_name.trim();
    const baseUsername = cleanName.toLowerCase().replace(/[^a-z0-9]/g, "") || `doc_${Date.now()}`;
    let username = baseUsername;
    let counter = 1;
    while (await req.propertyDb.models.users.findOne({ where: { outlet_id: outlet_id2, username } })) {
      username = `${baseUsername}_${counter++}`;
    }
    const doctor = await req.propertyDb.models.users.create({
      outlet_id: outlet_id2,
      username,
      full_name: cleanName,
      role: "DOCTOR",
      speciality: speciality ? speciality.trim() : "General Physician",
      qualification: qualification ? qualification.trim() : "MBBS",
      registration_no: registration_no ? registration_no.trim() : "",
      experience_years: experience_years ? Number(experience_years) : 5,
      consultation_fee: consultation_fee ? Number(consultation_fee) : 500,
      mobile: mobile ? mobile.trim() : "",
      whatsapp_no: whatsapp_no ? whatsapp_no.trim() : mobile ? mobile.trim() : "",
      contact_email: contact_email ? contact_email.trim().toLowerCase() : "",
      is_public_listed: is_public_listed !== false,
      doctor_city: doctor_city ? doctor_city.trim() : "",
      doctor_bio: doctor_bio ? doctor_bio.trim() : "",
      available_days: available_days || "Mon,Tue,Wed,Thu,Fri,Sat",
      public_display_options: public_display_options || {
        show_clinic_name: true,
        show_doctor_name: true,
        show_address: true,
        show_phone: true,
        show_whatsapp: true,
        show_email: true,
        show_fees: true
      },
      is_active: true
    });
    return res.json({
      success: true,
      message: `Doctor ${cleanName} added successfully to clinic!`,
      data: doctor
    });
  } catch (err) {
    console.error("[CREATE DOCTOR ERR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const updateClinicDoctor = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const doctor = await req.propertyDb.models.users.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!doctor) {
      return res.status(404).json({ success: false, message: "Doctor not found in this clinic." });
    }
    const fields = [
      "full_name",
      "speciality",
      "qualification",
      "registration_no",
      "experience_years",
      "consultation_fee",
      "mobile",
      "whatsapp_no",
      "contact_email",
      "is_public_listed",
      "doctor_city",
      "doctor_bio",
      "available_days",
      "public_display_options",
      "is_active"
    ];
    const payload = {};
    for (const f of fields) {
      if (req.body[f] !== void 0) {
        payload[f] = req.body[f];
      }
    }
    await doctor.update(payload);
    return res.json({
      success: true,
      message: "Doctor profile and public display settings updated successfully!",
      data: doctor
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
const deleteClinicDoctor = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const doctor = await req.propertyDb.models.users.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!doctor) {
      return res.status(404).json({ success: false, message: "Doctor not found." });
    }
    await doctor.update({ is_active: false });
    return res.json({
      success: true,
      message: "Doctor deactivated successfully."
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
const acceptAndPayAppointment = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const {
      payment_status = "PAID",
      // PAID, PAY_LATER
      payment_mode = "CASH",
      // CASH, CARD, UPI, PREPAID
      paid_amount,
      package_name,
      session_number,
      total_package_sessions,
      is_package_session
    } = req.body;
    const appointment = await req.propertyDb.models.clinic_appointments.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!appointment) {
      return res.status(404).json({ success: false, message: "Appointment not found." });
    }
    const feeToPay = paid_amount !== void 0 ? Number(paid_amount) : Number(appointment.consultation_fee || 0);
    const sessNum = session_number ? Number(session_number) : 0;
    const totalSess = total_package_sessions ? Number(total_package_sessions) : 0;
    const isPack = is_package_session === true || sessNum > 0 && totalSess > 0 && sessNum <= totalSess;
    const updateData = {
      status: appointment.status === "VISITED" ? "VISITED" : "CONFIRMED",
      payment_status: isPack ? "PACKAGE_INCLUDED" : payment_status,
      payment_mode: isPack ? "PACKAGE" : payment_mode,
      paid_amount: isPack ? 0 : payment_status === "PAID" ? feeToPay : 0,
      package_name: package_name || null,
      session_number: sessNum,
      total_package_sessions: totalSess,
      is_package_session: isPack
    };
    if (req.body.doctor_name && req.body.doctor_name.trim()) {
      updateData.doctor_name = req.body.doctor_name.trim();
      if (req.body.doctor_id) updateData.doctor_id = Number(req.body.doctor_id);
    }
    await appointment.update(updateData);
    if (!isPack && payment_status === "PAID" && feeToPay > 0) {
      try {
        const { createLedgerEntry } = require("../../services/cashLedger.service");
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: appointment.appointment_date || /* @__PURE__ */ new Date(),
          transaction_type: "CONSULTATION_FEE",
          reference_type: "CLINIC_APPOINTMENT",
          reference_id: appointment.id,
          reference_no: `APPT-${appointment.id}`,
          party_name: appointment.patient_name,
          payment_method: payment_mode || "CASH",
          amount_in: feeToPay,
          notes: `Reception OPD Fee Collection: Token #${appointment.token_number || appointment.id} - ${appointment.patient_name} (${updateData.doctor_name || appointment.doctor_name || "Clinic"})`
        });
        if (req.propertyDb.models.sales_headers) {
          const existingSale = await req.propertyDb.models.sales_headers.findOne({
            where: {
              outlet_id: outlet_id2,
              sale_no: `APPT-${appointment.id}`
            }
          });
          if (existingSale) {
            await existingSale.update({
              amount_paid: feeToPay,
              balance_amount: 0,
              payment_mode: payment_mode || "CASH"
            });
          }
        }
      } catch (ledgerErr) {
        console.error("[LEDGER ACCEPT & PAY ERR]", ledgerErr);
      }
    } else if (!isPack && payment_status === "PAY_LATER" && feeToPay > 0) {
      try {
        const { createLedgerEntry } = require("../../services/cashLedger.service");
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: appointment.appointment_date || /* @__PURE__ */ new Date(),
          transaction_type: "SALE_CREDIT",
          reference_type: "CLINIC_APPOINTMENT",
          reference_id: appointment.id,
          reference_no: `APPT-${appointment.id}`,
          party_name: appointment.patient_name,
          payment_method: "CREDIT",
          amount_in: 0,
          adjustment_amount: feeToPay,
          notes: `Consultation Fee Due (Pay Later): Token #${appointment.token_number || appointment.id} - ${appointment.patient_name} (${updateData.doctor_name || appointment.doctor_name || "Clinic"})`
        });
        if (req.propertyDb.models.sales_headers) {
          const existingSale = await req.propertyDb.models.sales_headers.findOne({
            where: {
              outlet_id: outlet_id2,
              sale_no: `APPT-${appointment.id}`
            }
          });
          if (existingSale) {
            await existingSale.update({
              net_amount: feeToPay,
              total_amount: feeToPay,
              amount_paid: 0,
              balance_amount: feeToPay,
              payment_mode: "CREDIT",
              status: "COMPLETED"
            });
          } else {
            await req.propertyDb.models.sales_headers.create({
              outlet_id: outlet_id2,
              sale_no: `APPT-${appointment.id}`,
              sale_date: appointment.appointment_date || /* @__PURE__ */ new Date(),
              customer_name: appointment.patient_name,
              customer_phone: appointment.patient_phone || "",
              net_amount: feeToPay,
              total_amount: feeToPay,
              amount_paid: 0,
              balance_amount: feeToPay,
              payment_mode: "CREDIT",
              order_type: "CLINIC_APPOINTMENT",
              status: "COMPLETED",
              is_latest: true,
              is_deleted: false,
              notes: `Consultation Fee Due (Pay Later) - Token #${appointment.token_number || appointment.id} (${updateData.doctor_name || appointment.doctor_name || "Clinic"})`
            }).catch(() => null);
          }
        }
      } catch (creditErr) {
        console.error("[LEDGER ACCEPT & PAY (CREDIT) ERR]", creditErr);
      }
    }
    return res.json({
      success: true,
      message: isPack ? `Appointment confirmed under package ${package_name || "Therapy"} (Session ${sessNum}/${totalSess} - Included).` : payment_status === "PAID" ? `Appointment accepted & consultation fee of ${feeToPay} collected via ${payment_mode}.` : "Appointment accepted with Pay Later option.",
      data: appointment
    });
  } catch (err) {
    console.error("[ACCEPT & PAY APPOINTMENT ERR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getClinicAnalytics = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { from_date: from_date2, to_date: to_date2 } = req.query;
    const where = { outlet_id: outlet_id2 };
    if (from_date2 && to_date2) {
      where.appointment_date = { [import_sequelize.Op.between]: [from_date2, to_date2] };
    }
    const allAppointments = await req.propertyDb.models.clinic_appointments.findAll({
      where
    });
    const totalAppointments = allAppointments.length;
    const visitedCount = allAppointments.filter((a) => a.status === "VISITED").length;
    const scheduledCount = allAppointments.filter((a) => a.status === "SCHEDULED" || a.status === "CONFIRMED").length;
    const cancelledCount = allAppointments.filter((a) => a.status === "CANCELLED" || a.status === "NO_SHOW").length;
    const draftSentCount = allAppointments.filter((a) => a.billing_status === "DRAFT_SENT" || a.billing_status === "BILLED").length;
    const uniquePhones = new Set(allAppointments.map((a) => a.patient_phone).filter(Boolean));
    const totalConsultationFees = allAppointments.filter((a) => a.payment_status === "PAID").reduce((acc, a) => acc + Number(a.paid_amount || a.consultation_fee || 0), 0);
    let totalSubscriptionRevenue = 0;
    try {
      if (req.propertyDb.models.milk_subscriptions) {
        const subWhere = { outlet_id: outlet_id2 };
        if (from_date2 && to_date2) {
          subWhere.created_at = { [import_sequelize.Op.between]: [from_date2 + " 00:00:00", to_date2 + " 23:59:59"] };
        }
        const subs = await req.propertyDb.models.milk_subscriptions.findAll({ where: subWhere });
        totalSubscriptionRevenue = subs.reduce((acc, s) => acc + Number(s.total_payment_amount || 0), 0);
      }
    } catch (_) {
    }
    let totalMedicineRevenue = 0;
    try {
      const billedSaleIds = allAppointments.filter((a) => a.billing_sale_id).map((a) => a.billing_sale_id);
      if (billedSaleIds.length > 0 && req.propertyDb.models.sales_headers) {
        const sales = await req.propertyDb.models.sales_headers.findAll({
          where: {
            id: { [import_sequelize.Op.in]: billedSaleIds },
            outlet_id: outlet_id2,
            status: "COMPLETED"
          }
        });
        totalMedicineRevenue = sales.reduce((acc, s) => acc + Number(s.total_amount || 0), 0);
      }
    } catch (_) {
    }
    const totalClinicRevenue = Number((totalConsultationFees + totalSubscriptionRevenue + totalMedicineRevenue).toFixed(2));
    const dateMap = {};
    const docMap = {};
    const medMap = {};
    let maleCount = 0, femaleCount = 0, otherCount = 0;
    for (const a of allAppointments) {
      const d = a.appointment_date ? a.appointment_date.toString().substring(0, 10) : "Other";
      if (!dateMap[d]) {
        dateMap[d] = { date: d, appointments: 0, visited: 0, billed: 0, cancelled: 0 };
      }
      dateMap[d].appointments++;
      if (a.status === "VISITED") dateMap[d].visited++;
      if (a.status === "CANCELLED" || a.status === "NO_SHOW") dateMap[d].cancelled++;
      if (a.billing_status === "DRAFT_SENT" || a.billing_status === "BILLED") dateMap[d].billed++;
      const docName = (a.doctor_name || "General Physician").trim();
      if (!docMap[docName]) {
        docMap[docName] = { doctor: docName, count: 0, visited: 0 };
      }
      docMap[docName].count++;
      if (a.status === "VISITED") docMap[docName].visited++;
      const g = (a.patient_gender || "").toUpperCase();
      if (g === "MALE" || g === "M") maleCount++;
      else if (g === "FEMALE" || g === "F") femaleCount++;
      else otherCount++;
      if (Array.isArray(a.prescribed_medicines)) {
        for (const m of a.prescribed_medicines) {
          const mKey = (m.item_code || m.item_name || "Rx").toString();
          if (!medMap[mKey]) {
            medMap[mKey] = {
              item_name: m.item_name || "Medicine",
              item_code: m.item_code || "-",
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
        total_subscription_revenue: totalSubscriptionRevenue,
        total_medicine_revenue: totalMedicineRevenue,
        total_clinic_revenue: totalClinicRevenue,
        attendance_rate_percent: totalAppointments > 0 ? Number((visitedCount / totalAppointments * 100).toFixed(1)) : 0,
        billing_conversion_percent: visitedCount > 0 ? Number((draftSentCount / visitedCount * 100).toFixed(1)) : 0,
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
const patientOtpStore = /* @__PURE__ */ new Map();
const requestPatientEmailOtp = async (req, res) => {
  try {
    const { email } = req.body;
    const cleanEmail = (email || "").toString().trim().toLowerCase();
    if (!cleanEmail || !cleanEmail.includes("@")) {
      return res.status(400).json({ success: false, message: "Valid email address is required for verification." });
    }
    const otp = Math.floor(1e5 + Math.random() * 9e5).toString();
    patientOtpStore.set(cleanEmail, {
      otp,
      expiresAt: Date.now() + 10 * 60 * 1e3,
      email: cleanEmail,
      verified: false
    });
    const { sendOtpEmail } = require("../../modules/emailService");
    await sendOtpEmail(cleanEmail, otp, "Patient Registration & Report Delivery Verification");
    return res.json({
      success: true,
      message: `Verification code sent to ${cleanEmail}. Enter this code to verify your email for medical reports and invoice delivery.`
    });
  } catch (err) {
    console.error("[PATIENT EMAIL OTP ERR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const verifyPatientEmailOtp = async (req, res) => {
  try {
    const { email, otp } = req.body;
    const cleanEmail = (email || "").toString().trim().toLowerCase();
    const entry = patientOtpStore.get(cleanEmail);
    if (!entry || entry.otp !== (otp || "").toString().trim() || Date.now() > entry.expiresAt) {
      return res.status(400).json({ success: false, message: "Invalid or expired verification code. Please request a new code." });
    }
    entry.verified = true;
    patientOtpStore.set(cleanEmail, entry);
    let existingCustomer = null;
    try {
      existingCustomer = await req.propertyDb.models.customers.findOne({
        where: { customer_email: cleanEmail },
        order: [["id", "DESC"]]
      });
    } catch (_) {
    }
    return res.json({
      success: true,
      message: "Email successfully verified!",
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
      attributes: ["city"],
      raw: true
    });
    const doctorUsers = await req.propertyDb.models.users.findAll({
      where: {
        [import_sequelize.Op.or]: [
          { role: "DOCTOR" },
          { is_public_listed: true }
        ]
      },
      attributes: ["doctor_city"],
      raw: true
    });
    const citiesSet = /* @__PURE__ */ new Set();
    for (const p of propInfos) {
      if (p.city && p.city.trim()) citiesSet.add(p.city.trim());
    }
    for (const u of doctorUsers) {
      if (u.doctor_city && u.doctor_city.trim()) citiesSet.add(u.doctor_city.trim());
    }
    if (citiesSet.size === 0) {
      ["New Delhi", "Mumbai", "Bangalore", "Hyderabad", "Chennai", "Kolkata", "Pune", "Ahmedabad"].forEach((c) => citiesSet.add(c));
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
      "General Physician",
      "Cardiologist",
      "Dermatologist",
      "Pediatrician",
      "Dentist",
      "Orthopedic",
      "Gynecologist",
      "Neurologist",
      "Psychiatrist",
      "Physiotherapy",
      "ENT Specialist",
      "Ophthalmology"
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
      is_public_listed: true,
      [import_sequelize.Op.or]: [
        { role: { [import_sequelize.Op.iLike]: "%doctor%" } },
        { role: { [import_sequelize.Op.iLike]: "%physician%" } },
        { role: { [import_sequelize.Op.iLike]: "%clinician%" } },
        { speciality: { [import_sequelize.Op.ne]: null } },
        { consultation_fee: { [import_sequelize.Op.gt]: 0 } }
      ]
    };
    if (speciality && speciality !== "ALL") {
      userWhere.speciality = { [import_sequelize.Op.iLike]: `%${speciality.trim()}%` };
    }
    const doctorUsers = await req.propertyDb.models.users.findAll({
      where: userWhere
    });
    const clinics = await req.propertyDb.models.property_info.findAll();
    const clinicByOutlet = /* @__PURE__ */ new Map();
    for (const c of clinics) {
      clinicByOutlet.set(c.outlet_id, c);
    }
    const settingsList = await req.propertyDb.models.system_settings.findAll().catch(() => []);
    const settingsByOutlet = /* @__PURE__ */ new Map();
    for (const s of settingsList) {
      settingsByOutlet.set(s.outlet_id, s);
    }
    const doctorsByOutlet = /* @__PURE__ */ new Map();
    for (const d of doctorUsers) {
      if (!doctorsByOutlet.has(d.outlet_id)) {
        doctorsByOutlet.set(d.outlet_id, []);
      }
      doctorsByOutlet.get(d.outlet_id).push(d);
    }
    let results = [];
    for (const d of doctorUsers) {
      const clinic = clinicByOutlet.get(d.outlet_id) || {};
      const st = settingsByOutlet.get(d.outlet_id);
      const isGatewayEnabled = Boolean(st?.enable_payment_gateway);
      const docCity = d.doctor_city || clinic.city || "Dehradun";
      if (city && city.trim() && city.toUpperCase() !== "ALL" && docCity.toLowerCase() !== city.trim().toLowerCase()) {
        continue;
      }
      const allOutletDocs = doctorsByOutlet.get(d.outlet_id) || [];
      const mapDoctorHelper = (docItem) => {
        const itemOpts = docItem.public_display_options || {};
        const days = (docItem.available_days || itemOpts.available_days || "Mon,Tue,Wed,Thu,Fri,Sat").split(",").map((x) => x.trim()).filter(Boolean);
        return {
          id: docItem.id,
          name: docItem.full_name || docItem.username,
          speciality: docItem.speciality || "General Physician",
          qualification: docItem.qualifications || docItem.qualification || "MBBS",
          registration_no: docItem.registration_no || "",
          consultation_fee: Number(docItem.consultation_fee || 0),
          phone: docItem.phone_no || docItem.mobile || "",
          whatsapp: docItem.whatsapp_no || "",
          available_days: days,
          start_time: itemOpts.start_time || "09:00 AM",
          end_time: itemOpts.end_time || "06:00 PM",
          slot_duration_minutes: Number(itemOpts.slot_duration_minutes || 30),
          is_gateway_enabled: isGatewayEnabled
        };
      };
      const otherDocs = allOutletDocs.filter((od) => od.id !== d.id).map(mapDoctorHelper);
      const opts = d.public_display_options || {};
      const activeDays = (d.available_days || opts.available_days || "Mon,Tue,Wed,Thu,Fri,Sat").split(",").map((x) => x.trim()).filter(Boolean);
      results.push({
        id: d.id,
        name: opts.show_doctor_name !== false ? d.full_name || d.username : "Consultant Clinician",
        speciality: d.speciality || "General Physician",
        qualification: d.qualifications || d.qualification || "MBBS, MD",
        registration_no: d.registration_no || "",
        experience_years: d.experience_years || 8,
        consultation_fee: Number(d.consultation_fee || 0),
        is_verified_badge: true,
        rating: 0,
        rating_count: 0,
        doctor_bio: "Specialist in " + (d.speciality || "general clinical medicine") + " with dedicated patient care.",
        clinic_name: opts.show_clinic_name !== false ? clinic.property_name || "Healthcare Clinic" : "Healthcare Clinic",
        city: docCity,
        address: opts.show_address !== false ? clinic.address || clinic.address_line1 || "" : "",
        phone: opts.show_phone !== false ? clinic.mobile || d.phone_no || d.mobile || "" : "",
        whatsapp: opts.show_whatsapp !== false ? d.whatsapp_no || clinic.mobile || "" : "",
        email: opts.show_email !== false ? d.email || d.contact_email || "" : "",
        outlet_id: d.outlet_id,
        available_days: activeDays,
        start_time: opts.start_time || "09:00 AM",
        end_time: opts.end_time || "06:00 PM",
        slot_duration_minutes: Number(opts.slot_duration_minutes || 30),
        is_gateway_enabled: isGatewayEnabled,
        other_doctors_count: otherDocs.length,
        clinic_doctors: allOutletDocs.map(mapDoctorHelper)
      });
    }
    if (results.length === 0) {
      for (const c of clinics) {
        const docCity = c.city || "New Delhi";
        results.push({
          id: 1,
          name: "Dr. Aarav Sharma",
          speciality: "Cardiologist",
          qualification: "MBBS, MD, DM (Cardiology)",
          experience_years: 14,
          consultation_fee: 800,
          is_verified_badge: true,
          rating: 0,
          rating_count: 0,
          doctor_bio: "Senior Cardiologist specializing in preventive heart health and diagnostics.",
          clinic_name: c.property_name || "Apex Health & Heart Clinic",
          city: docCity,
          address: c.address || "Medical Enclave, Main Road",
          phone: c.mobile || "",
          outlet_id: c.outlet_id,
          available_days: ["Mon", "Tue", "Wed", "Thu", "Fri"]
        }, {
          id: 2,
          name: "Dr. Priya Patel",
          speciality: "Dermatologist",
          qualification: "MBBS, MD (Dermatology)",
          experience_years: 10,
          consultation_fee: 600,
          is_verified_badge: true,
          rating: 4.8,
          doctor_bio: "Expert Dermatologist and cosmetologist.",
          clinic_name: c.property_name || "Skin & Wellness Clinic",
          city: docCity,
          address: c.address || "Suite 201, Health Hub",
          phone: c.mobile || "",
          outlet_id: c.outlet_id,
          available_days: ["Mon", "Wed", "Fri", "Sat"]
        }, {
          id: 3,
          name: "Dr. Rajesh Verma",
          speciality: "General Physician",
          qualification: "MBBS, DNB (Internal Medicine)",
          experience_years: 16,
          consultation_fee: 500,
          is_verified_badge: true,
          rating: 0,
          rating_count: 0,
          doctor_bio: "Comprehensive internal medicine, family wellness, and viral fever care.",
          clinic_name: c.property_name || "City Care Medical Clinic",
          city: docCity,
          address: c.address || "Central Market Block B",
          phone: c.mobile || "",
          outlet_id: c.outlet_id,
          available_days: ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        }, {
          id: 4,
          name: "Dr. Ananya Roy",
          speciality: "Pediatrician",
          qualification: "MBBS, MD (Pediatrics)",
          experience_years: 9,
          consultation_fee: 550,
          is_verified_badge: true,
          rating: 0,
          rating_count: 0,
          doctor_bio: "Child healthcare, vaccinations, and pediatric nutrition guidance.",
          clinic_name: c.property_name || "Little Steps Child Clinic",
          city: docCity,
          address: c.address || "First Floor, Rainbow Plaza",
          phone: c.mobile || "",
          outlet_id: c.outlet_id,
          available_days: ["Mon", "Tue", "Thu", "Fri", "Sat"]
        });
      }
    }
    if (city && city.trim() && city !== "ALL") {
      const cleanCity = city.trim().toLowerCase();
      results = results.filter((d) => (d.city || "").toLowerCase().includes(cleanCity));
    }
    if (speciality && speciality.trim() && speciality !== "ALL") {
      const cleanSpec = speciality.trim().toLowerCase();
      results = results.filter((d) => (d.speciality || "").toLowerCase().includes(cleanSpec));
    }
    if (search && search.trim()) {
      const q = search.trim().toLowerCase();
      results = results.filter(
        (d) => (d.name || "").toLowerCase().includes(q) || (d.speciality || "").toLowerCase().includes(q) || (d.clinic_name || "").toLowerCase().includes(q) || (d.city || "").toLowerCase().includes(q)
      );
    }
    return res.json({
      success: true,
      count: results.length,
      city_filter: city || "ALL",
      data: results
    });
  } catch (err) {
    console.error("[GET PUBLIC DOCTORS ERR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const bookAppointmentPublic = async (req, res) => {
  try {
    let outlet_id2 = req.body.outlet_id || req.query.outlet_id;
    if (!outlet_id2) {
      const firstActive = await req.propertyDb.models.outlets.findOne({ where: { is_active: true } });
      outlet_id2 = firstActive ? firstActive.id : null;
    }
    if (!outlet_id2) {
      return res.status(400).json({ success: false, message: "Valid outlet ID is required" });
    }
    const settings = await req.propertyDb.models.system_settings.findOne({ where: { outlet_id: outlet_id2 } });
    if (settings && settings.allow_public_appointments === false) {
      return res.status(403).json({
        success: false,
        message: "Online appointment booking is currently disabled for this clinic."
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
      reason_for_visit,
      payment_status = "UNPAID",
      payment_mode,
      paid_amount,
      package_name,
      session_number,
      total_package_sessions,
      is_package_session = false
    } = req.body;
    if (!patient_name || !patient_phone || !appointment_date || !appointment_time) {
      return res.status(400).json({
        success: false,
        message: "Patient name, phone number, appointment date, and time are required."
      });
    }
    const cleanEmail = (patient_email || "").toString().trim().toLowerCase();
    if (!cleanEmail || !cleanEmail.includes("@")) {
      return res.status(400).json({
        success: false,
        message: "A valid email address is required for sending medical reports and invoices."
      });
    }
    let isEmailVerified = false;
    const passedVerified = req.body.is_verified === true || req.body.is_email_verified === true;
    let existingCustomer = null;
    try {
      existingCustomer = await req.propertyDb.models.customers.findOne({
        where: {
          [import_sequelize.Op.or]: [
            { customer_email: cleanEmail },
            { customer_phone: patient_phone.trim() }
          ]
        },
        order: [["id", "DESC"]]
      });
    } catch (_) {
    }
    let priorVerifiedAppt = null;
    try {
      priorVerifiedAppt = await req.propertyDb.models.clinic_appointments.findOne({
        where: {
          is_email_verified: true,
          [import_sequelize.Op.or]: [
            { patient_email: cleanEmail },
            { patient_phone: patient_phone.trim() }
          ]
        }
      });
    } catch (_) {
    }
    const entry = patientOtpStore.get(cleanEmail);
    if (passedVerified || existingCustomer && existingCustomer.is_email_verified || priorVerifiedAppt || entry && entry.verified) {
      isEmailVerified = true;
      if (existingCustomer && !existingCustomer.is_email_verified) {
        existingCustomer.update({ is_email_verified: true }).catch(() => null);
      }
    } else if (email_otp) {
      if (entry && entry.otp === String(email_otp).trim() && Date.now() <= entry.expiresAt) {
        isEmailVerified = true;
        entry.verified = true;
        if (existingCustomer) {
          existingCustomer.update({ is_email_verified: true }).catch(() => null);
        }
      } else {
        return res.status(400).json({
          success: false,
          message: "Invalid or expired email verification code. Please verify your email first."
        });
      }
    } else {
      if (existingCustomer) {
        isEmailVerified = true;
        existingCustomer.update({ is_email_verified: true }).catch(() => null);
      } else {
        return res.status(400).json({
          success: false,
          requires_email_verification: true,
          message: "Email verification code is required to receive appointment reports and invoice."
        });
      }
    }
    const phone = patient_phone.trim();
    let customer = existingCustomer;
    if (!customer) {
      customer = await req.propertyDb.models.customers.create({
        outlet_id: outlet_id2,
        customer_name: patient_name.trim(),
        customer_phone: phone,
        customer_email: cleanEmail,
        is_email_verified: isEmailVerified,
        email_verified_at: isEmailVerified ? /* @__PURE__ */ new Date() : null
      });
    } else {
      await customer.update({
        customer_name: patient_name.trim(),
        customer_email: cleanEmail,
        is_email_verified: isEmailVerified,
        email_verified_at: isEmailVerified ? /* @__PURE__ */ new Date() : customer.email_verified_at
      });
    }
    const todayCount = await req.propertyDb.models.clinic_appointments.count({
      where: {
        outlet_id: outlet_id2,
        appointment_date
      }
    });
    const token_number = todayCount + 1;
    const finalPaid = paid_amount ? Number(paid_amount) : payment_status === "PAID" ? Number(consultation_fee || 0) : 0;
    const appointment = await req.propertyDb.models.clinic_appointments.create({
      outlet_id: outlet_id2,
      token_number,
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
      consultation_fee: consultation_fee ? Number(consultation_fee) : 0,
      payment_status: payment_status || "UNPAID",
      payment_mode: payment_mode || null,
      paid_amount: finalPaid,
      package_name: package_name || null,
      session_number: session_number ? Number(session_number) : 0,
      total_package_sessions: total_package_sessions ? Number(total_package_sessions) : 0,
      is_package_session: is_package_session === true || is_package_session === "true",
      is_email_verified: isEmailVerified,
      email_otp_verified_at: isEmailVerified ? /* @__PURE__ */ new Date() : null,
      department: department ? department.trim() : null,
      reason_for_visit: reason_for_visit || null,
      status: "SCHEDULED",
      source: "ONLINE_WEB"
    });
    if (payment_status === "PAID" && finalPaid > 0) {
      try {
        const { createLedgerEntry } = require("../../services/cashLedger.service");
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: appointment_date || /* @__PURE__ */ new Date(),
          transaction_type: "CONSULTATION_FEE",
          reference_type: "CLINIC_APPOINTMENT",
          reference_id: appointment.id,
          reference_no: `APPT-${appointment.id}`,
          party_name: appointment.patient_name,
          payment_method: payment_mode || "ONLINE",
          amount_in: finalPaid,
          notes: `Online Prepaid OPD Fee: Token #${token_number} - ${appointment.patient_name} (${appointment.doctor_name || "Clinic"})`
        });
      } catch (ledgerErr) {
        console.error("[LEDGER ONLINE BOOKING ERR]", ledgerErr);
      }
    }
    try {
      const { getSocketHub } = require("../../services/socketHub.service");
      const io = getSocketHub();
      if (io) {
        io.emit("clinic_appointment_created", {
          outlet_id: outlet_id2,
          appointment_id: appointment.id,
          patient_name: appointment.patient_name,
          patient_phone: appointment.patient_phone,
          patient_email: appointment.patient_email,
          appointment_date: appointment.appointment_date,
          appointment_time: appointment.appointment_time,
          doctor_name: appointment.doctor_name,
          source: "ONLINE_WEB"
        });
      }
    } catch (sErr) {
    }
    try {
      await req.propertyDb.models.system_notifications.create({
        outlet_id: outlet_id2,
        title: "New Clinic Appointment Booked Online",
        message: `Patient ${patient_name} (${cleanEmail} / ${phone}) booked with Dr. ${doctor_name || "General"} on ${appointment_date} at ${appointment_time}`,
        type: "INFO",
        is_read: false
      });
    } catch (nErr) {
    }
    return res.json({
      success: true,
      message: "Appointment booked successfully! Confirmation and reports will be sent to your verified email.",
      data: appointment
    });
  } catch (err) {
    console.error("[BOOK APPOINTMENT PUBLIC ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getPatientHistoryPublic = async (req, res) => {
  try {
    const phone = req.query.phone ? req.query.phone.trim() : "";
    const email = req.query.email ? req.query.email.trim().toLowerCase() : "";
    if (!phone && !email) {
      return res.status(400).json({ success: false, message: "Patient phone number or verified email is required." });
    }
    const where = {};
    if (phone && email) {
      where[import_sequelize.Op.or] = [
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
          as: "outlet",
          attributes: ["id", "outlet_code", "outlet_name"],
          required: false
        }
      ],
      order: [
        ["appointment_date", "DESC"],
        ["appointment_time", "DESC"]
      ]
    });
    const enriched = [];
    for (const a of appointments) {
      const json = a.toJSON();
      const propInfo = await req.propertyDb.models.property_info.findOne({
        where: { outlet_id: json.outlet_id },
        attributes: ["property_name", "city", "address", "mobile"]
      });
      json.clinic_name = propInfo?.property_name || json.outlet?.outlet_name || "Clinic";
      json.clinic_city = propInfo?.city || "";
      json.clinic_address = propInfo?.address || "";
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
const getClinicSubscriptions = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { search, status, customer_phone } = req.query;
    const where = { outlet_id: outlet_id2 };
    if (status && status !== "ALL") {
      where.status = status;
    }
    if (customer_phone && customer_phone.trim()) {
      where.customer_phone = customer_phone.trim();
    }
    if (search && search.trim()) {
      const q = search.trim();
      where[import_sequelize.Op.or] = [
        { customer_name: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { customer_phone: { [import_sequelize.Op.iLike]: `%${q}%` } },
        { item_name: { [import_sequelize.Op.iLike]: `%${q}%` } }
      ];
    }
    const subscriptions = await req.propertyDb.models.milk_subscriptions.findAll({
      where,
      order: [["created_at", "DESC"], ["id", "DESC"]]
    });
    const results = [];
    for (const sub of subscriptions) {
      const subJson = sub.toJSON ? sub.toJSON() : sub;
      const consumptions = await req.propertyDb.models.milk_subscription_consumptions.findAll({
        where: { subscription_id: sub.id, outlet_id: outlet_id2 },
        order: [["txn_date", "ASC"], ["id", "ASC"]]
      }).catch(() => []);
      const totalAllowed = Number(sub.total_allowed_services || 0) + Number(sub.bonus_qty || 0);
      const consumed = Number(sub.services_consumed || consumptions.length || 0);
      const remaining = Math.max(0, totalAllowed - consumed);
      results.push({
        ...subJson,
        total_package_sessions: totalAllowed,
        services_consumed: consumed,
        remaining_sessions: remaining,
        is_exhausted: remaining <= 0,
        consumptions
      });
    }
    return res.json({
      success: true,
      count: results.length,
      data: results
    });
  } catch (err) {
    console.error("[GET CLINIC SUBSCRIPTIONS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const createClinicSubscription = async (req, res) => {
  const t = await req.propertyDb.transaction();
  try {
    const outlet_id2 = req.user.outlet_id;
    const user_id = req.user.id;
    const {
      customer_name,
      customer_phone,
      customer_email,
      item_id,
      monthly_sessions = 6,
      bonus_sessions = 0,
      total_fee,
      start_date,
      end_date,
      payment_mode = "CASH"
    } = req.body;
    if (!customer_name || !customer_phone) {
      await t.rollback();
      return res.status(400).json({ success: false, message: "Customer name and phone number are required." });
    }
    let serviceItem = null;
    if (item_id) {
      serviceItem = await req.propertyDb.models.item_master.findOne({
        where: { id: item_id, outlet_id: outlet_id2 },
        transaction: t
      });
    }
    const itemName = serviceItem ? serviceItem.item_name : req.body.item_name || "Therapy / Clinic Package";
    const allowed = Number(monthly_sessions) || 6;
    const bonus = Number(bonus_sessions) || 0;
    const totalSessions = allowed + bonus;
    const paymentAmount = Number(total_fee) || (serviceItem ? Number(serviceItem.retail_sale_price || 0) * allowed : 0);
    const perSessionPrice = totalSessions > 0 ? Number((paymentAmount / totalSessions).toFixed(2)) : 0;
    const today = (/* @__PURE__ */ new Date()).toISOString().substring(0, 10);
    const validStart = start_date || today;
    const validEnd = end_date || new Date(Date.now() + 30 * 24 * 60 * 60 * 1e3).toISOString().substring(0, 10);
    let customer = await req.propertyDb.models.customers.findOne({
      where: { outlet_id: outlet_id2, customer_phone: customer_phone.trim() },
      transaction: t
    });
    if (!customer) {
      customer = await req.propertyDb.models.customers.create({
        outlet_id: outlet_id2,
        customer_name: customer_name.trim(),
        customer_phone: customer_phone.trim(),
        customer_email: customer_email ? customer_email.trim().toLowerCase() : ""
      }, { transaction: t });
    }
    const subscription = await req.propertyDb.models.milk_subscriptions.create({
      outlet_id: outlet_id2,
      customer_name: customer_name.trim(),
      customer_phone: customer_phone.trim(),
      item_id: serviceItem ? serviceItem.id : 0,
      item_name: itemName,
      start_date: validStart,
      end_date: validEnd,
      subscription_type: "MONTHLY_SERVICES",
      total_allowed_services: allowed,
      bonus_qty: bonus,
      services_consumed: 0,
      service_unit_name: "Sessions",
      per_service_price: perSessionPrice,
      total_payment_amount: paymentAmount,
      delivery_type: "STORE",
      status: "ACTIVE",
      active_subscription: true,
      created_by: user_id,
      updated_by: user_id
    }, { transaction: t });
    const isPayLater = String(payment_mode || "").toUpperCase() === "PAY_LATER" || String(payment_mode || "").toUpperCase() === "CREDIT";
    if (paymentAmount > 0) {
      if (isPayLater) {
        try {
          const { createLedgerEntry } = require("../../services/cashLedger.service");
          await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: outlet_id2,
            txn_date: today,
            transaction_type: "SALE_CREDIT",
            reference_type: "CLINIC_SUBSCRIPTION",
            reference_id: subscription.id,
            reference_no: `SUB-CLINIC-${subscription.id}`,
            party_name: customer_name.trim(),
            payment_method: "CREDIT",
            amount_in: 0,
            adjustment_amount: paymentAmount,
            notes: `Clinic Therapy Package Subscription on Credit: ${itemName} (${totalSessions} sessions)`,
            created_by: user_id,
            transaction: t
          });
          if (req.propertyDb.models.sales_headers) {
            await req.propertyDb.models.sales_headers.create({
              outlet_id: outlet_id2,
              sale_no: `SUB-CLINIC-${subscription.id}`,
              sale_date: today,
              customer_name: customer_name.trim(),
              customer_phone: customer_phone.trim(),
              net_amount: paymentAmount,
              total_amount: paymentAmount,
              amount_paid: 0,
              balance_amount: paymentAmount,
              payment_mode: "CREDIT",
              order_type: "CLINIC_SUBSCRIPTION",
              status: "COMPLETED",
              is_latest: true,
              is_deleted: false,
              notes: `Clinic Therapy Package Subscription (Credit Due) - ${itemName} (${totalSessions} sessions)`
            }, { transaction: t }).catch(() => null);
          }
        } catch (creditErr) {
          console.error("[LEDGER SUB CREDIT ERR]", creditErr);
        }
      } else {
        if (req.propertyDb.models.customer_advances) {
          await req.propertyDb.models.customer_advances.create({
            outlet_id: outlet_id2,
            customer_name: customer_name.trim(),
            customer_phone: customer_phone.trim(),
            advance_date: today,
            original_amount: paymentAmount,
            available_amount: paymentAmount,
            payment_mode: String(payment_mode).toUpperCase(),
            reference_no: `SUB-CLINIC-${subscription.id}`,
            note: `Prepaid clinic package: ${itemName} (${totalSessions} sessions)`,
            created_by: user_id
          }, { transaction: t }).catch(() => null);
        }
        try {
          const { createLedgerEntry } = require("../../services/cashLedger.service");
          await createLedgerEntry({
            db: req.propertyDb,
            outlet_id: outlet_id2,
            txn_date: today,
            transaction_type: "CUSTOMER_ADVANCE",
            reference_type: "SUBSCRIPTION",
            reference_id: subscription.id,
            reference_no: `SUB-CLINIC-${subscription.id}`,
            party_name: customer_name.trim(),
            payment_method: String(payment_mode || "CASH").toUpperCase(),
            amount_in: paymentAmount,
            amount_out: 0,
            notes: `Clinic Therapy Package Subscription: ${itemName} (${totalSessions} sessions)`,
            created_by: user_id,
            transaction: t
          });
        } catch (ledgerErr) {
          console.error("[LEDGER SUB CREATE ERR]", ledgerErr);
        }
      }
    }
    await t.commit();
    return res.json({
      success: true,
      message: "Therapy package subscription created successfully!",
      data: subscription
    });
  } catch (err) {
    await t.rollback();
    console.error("[CREATE CLINIC SUBSCRIPTION ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const consumeClinicSubscriptionSession = async (req, res) => {
  const t = await req.propertyDb.transaction();
  try {
    const outlet_id2 = req.user.outlet_id;
    const user_id = req.user.id;
    const { id } = req.params;
    const { appointment_id, notes, fee, payment_mode } = req.body;
    const sub = await req.propertyDb.models.milk_subscriptions.findOne({
      where: { id, outlet_id: outlet_id2 },
      transaction: t
    });
    if (!sub) {
      await t.rollback();
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }
    const totalAllowed = Number(sub.total_allowed_services || 0) + Number(sub.bonus_qty || 0);
    let consumed = Number(sub.services_consumed || 0);
    if (consumed >= totalAllowed) {
      await t.rollback();
      return res.status(400).json({
        success: false,
        message: `Package fully exhausted! All ${totalAllowed} sessions have been consumed.`
      });
    }
    consumed += 1;
    const today = (/* @__PURE__ */ new Date()).toISOString().substring(0, 10);
    const additionalFee = Number(fee || 0);
    const activePaymentMode = additionalFee > 0 ? (payment_mode || "CASH").toUpperCase() : "PACKAGE_SUBSCRIPTION";
    const perSessionRate = totalAllowed > 0 ? Math.round(Number(sub.total_payment_amount || 0) / totalAllowed * 100) / 100 : Number(sub.per_service_price || 0);
    if (req.propertyDb.models.milk_subscription_consumptions) {
      await req.propertyDb.models.milk_subscription_consumptions.create({
        outlet_id: outlet_id2,
        subscription_id: sub.id,
        txn_date: today,
        item_id: sub.item_id || 0,
        item_name: sub.item_name || "Therapy Session",
        cart_qty: 1,
        covered_qty: 1,
        excess_qty: 0,
        rate: perSessionRate,
        covered_amount: perSessionRate,
        notes: notes || `Session #${consumed} of ${totalAllowed}${additionalFee > 0 ? ` (Co-pay Fee: ${additionalFee} via ${activePaymentMode})` : ""}`
      }, { transaction: t }).catch(() => null);
    }
    const isExhausted = consumed >= totalAllowed;
    await sub.update({
      services_consumed: consumed,
      status: isExhausted ? "EXHAUSTED" : "ACTIVE",
      active_subscription: !isExhausted,
      updated_by: user_id
    }, { transaction: t });
    try {
      const { createLedgerEntry } = require("../../services/cashLedger.service");
      await createLedgerEntry({
        db: req.propertyDb,
        outlet_id: outlet_id2,
        txn_date: today,
        transaction_type: "SUBSCRIPTION_SETTLEMENT",
        reference_type: "CLINIC_SUBSCRIPTION",
        reference_id: sub.id,
        reference_no: `SESS-${sub.id}-${consumed}`,
        party_name: sub.customer_name || "Patient",
        payment_method: "PACKAGE",
        amount_in: 0,
        amount_out: perSessionRate,
        notes: `Therapy Session #${consumed} of ${totalAllowed} Consumed: ${sub.item_name} (Debited: \u20AC${perSessionRate.toFixed(2)})`,
        created_by: user_id,
        transaction: t
      });
      if (additionalFee > 0) {
        await createLedgerEntry({
          db: req.propertyDb,
          outlet_id: outlet_id2,
          txn_date: today,
          transaction_type: "CLINIC_SESSION_FEE",
          reference_type: "CLINIC_SUBSCRIPTION",
          reference_id: sub.id,
          reference_no: `SESS-FEE-${sub.id}-${consumed}`,
          party_name: sub.customer_name || "Patient",
          payment_method: activePaymentMode,
          amount_in: additionalFee,
          amount_out: 0,
          notes: `Therapy Session #${consumed} Co-pay Fee: ${sub.item_name} via ${activePaymentMode}`,
          created_by: user_id,
          transaction: t
        });
      }
      if (req.propertyDb.models.customer_advances) {
        const adv = await req.propertyDb.models.customer_advances.findOne({
          where: {
            outlet_id: outlet_id2,
            reference_no: `SUB-CLINIC-${sub.id}`
          },
          transaction: t
        });
        if (adv) {
          const newAvail = Math.max(0, Number(adv.available_amount || 0) - perSessionRate);
          await adv.update({ available_amount: newAvail }, { transaction: t });
        }
      }
    } catch (ledgerErr) {
      console.error("[LEDGER SESSION CONSUME ERR]", ledgerErr);
    }
    if (appointment_id) {
      const appt = await req.propertyDb.models.clinic_appointments.findOne({
        where: { id: appointment_id, outlet_id: outlet_id2 },
        transaction: t
      });
      if (appt) {
        await appt.update({
          package_name: sub.item_name,
          session_number: consumed,
          total_package_sessions: totalAllowed,
          is_package_session: true,
          consultation_fee: additionalFee,
          paid_amount: additionalFee,
          payment_status: "PAID",
          payment_mode: activePaymentMode,
          status: appt.status === "VISITED" ? "VISITED" : "CONFIRMED"
        }, { transaction: t });
      }
    }
    await t.commit();
    return res.json({
      success: true,
      message: `Session #${consumed} successfully consumed! ${Math.max(0, totalAllowed - consumed)} sessions remaining.`,
      data: {
        subscription_id: sub.id,
        consumed_session: consumed,
        total_sessions: totalAllowed,
        remaining_sessions: Math.max(0, totalAllowed - consumed),
        status: isExhausted ? "EXHAUSTED" : "ACTIVE"
      }
    });
  } catch (err) {
    await t.rollback();
    console.error("[CONSUME SUBSCRIPTION SESSION ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getClinicSubscriptionLedger = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { id } = req.params;
    const sub = await req.propertyDb.models.milk_subscriptions.findOne({
      where: { id, outlet_id: outlet_id2 }
    });
    if (!sub) {
      return res.status(404).json({ success: false, message: "Subscription not found" });
    }
    const totalAllowed = Number(sub.total_allowed_services || 0) + Number(sub.bonus_qty || 0);
    const consumed = Number(sub.services_consumed || 0);
    const perSessionPrice = Number(sub.per_service_price || 0);
    const consumptions = await req.propertyDb.models.milk_subscription_consumptions.findAll({
      where: { subscription_id: sub.id, outlet_id: outlet_id2 },
      order: [["txn_date", "ASC"], ["id", "ASC"]]
    }).catch(() => []);
    const ledger = [
      {
        date: sub.start_date || sub.created_at,
        description: `Package Purchase: ${sub.item_name} (${totalAllowed} Sessions)`,
        type: "CREDIT",
        amount: Number(sub.total_payment_amount || 0),
        sessions: totalAllowed,
        balance_amount: Number(sub.total_payment_amount || 0),
        remaining_sessions: totalAllowed,
        reference: `SUB-CLINIC-${sub.id}`
      }
    ];
    let runningBalance = Number(sub.total_payment_amount || 0);
    let remainingSessions = totalAllowed;
    consumptions.forEach((c, idx) => {
      const cost = Number(c.covered_amount || perSessionPrice);
      runningBalance -= cost;
      remainingSessions -= 1;
      ledger.push({
        date: c.txn_date || c.created_at,
        description: `Therapy Session #${idx + 1} Consumed`,
        type: "DEBIT",
        amount: cost,
        sessions: 1,
        balance_amount: Math.max(0, runningBalance),
        remaining_sessions: Math.max(0, remainingSessions),
        reference: c.sale_no || `SES-${c.id}`
      });
    });
    return res.json({
      success: true,
      data: {
        subscription: sub,
        total_package_sessions: totalAllowed,
        services_consumed: consumed,
        remaining_sessions: Math.max(0, totalAllowed - consumed),
        total_collected: Number(sub.total_payment_amount || 0),
        remaining_value: Math.max(0, runningBalance),
        ledger
      }
    });
  } catch (err) {
    console.error("[GET SUBSCRIPTION LEDGER ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getPublicPatientSubscriptions = async (req, res) => {
  try {
    const { phone, email } = req.query;
    if (!phone && !email) {
      return res.status(400).json({ success: false, message: "Patient phone or email is required" });
    }
    const where = {
      [import_sequelize.Op.and]: [
        {
          [import_sequelize.Op.or]: [
            { subscription_type: "MONTHLY_SERVICES" },
            { service_unit_name: "Sessions" },
            { delivery_type: "STORE" }
          ]
        },
        {
          delivery_type: { [import_sequelize.Op.ne]: "DELIVERY" }
        }
      ]
    };
    if (phone) where.customer_phone = phone.trim();
    else if (email) where.customer_email = email.trim().toLowerCase();
    const subs = await req.propertyDb.models.milk_subscriptions.findAll({
      where,
      order: [["created_at", "DESC"]]
    });
    const data = [];
    for (const s of subs) {
      const nameLower = (s.item_name || "").toLowerCase();
      if (nameLower.includes("milk") || nameLower.includes("rice") || nameLower.includes("backpack") || nameLower.includes("oil") || nameLower.includes("ghee")) {
        continue;
      }
      const consumptions = await req.propertyDb.models.milk_subscription_consumptions.findAll({
        where: { subscription_id: s.id },
        order: [["txn_date", "ASC"]]
      }).catch(() => []);
      const totalAllowed = Number(s.total_allowed_services || 0) + Number(s.bonus_qty || 0);
      const consumed = Number(s.services_consumed || consumptions.length || 0);
      data.push({
        id: s.id,
        package_name: s.item_name || "Therapy Package",
        total_sessions: totalAllowed,
        services_consumed: consumed,
        remaining_sessions: Math.max(0, totalAllowed - consumed),
        start_date: s.start_date,
        end_date: s.end_date,
        status: s.status,
        consumptions: consumptions.map((c) => ({
          date: c.txn_date,
          notes: c.notes
        }))
      });
    }
    const todayStr = (/* @__PURE__ */ new Date()).toISOString().split("T")[0];
    let upcomingScheduledCount = 0;
    let nextUpcomingDate = null;
    try {
      const upcomingAppts = await req.propertyDb.models.clinic_appointments.findAll({
        where: {
          outlet_id,
          status: { [import_sequelize.Op.in]: ["SCHEDULED", "CONFIRMED"] },
          appointment_date: { [import_sequelize.Op.gt]: to_date || from_date || todayStr }
        },
        order: [["appointment_date", "ASC"], ["id", "ASC"]],
        limit: 10,
        attributes: ["id", "appointment_date", "doctor_name", "patient_name"]
      });
      upcomingScheduledCount = upcomingAppts.length;
      if (upcomingScheduledCount > 0) {
        nextUpcomingDate = upcomingAppts[0].appointment_date;
      }
    } catch (_) {
    }
    return res.json({
      success: true,
      count: data.length,
      upcoming_scheduled_count: upcomingScheduledCount,
      next_upcoming_date: nextUpcomingDate,
      data
    });
  } catch (err) {
    console.error("[GET PUBLIC PATIENT SUBSCRIPTIONS ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getClinicPatientHistory = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const phone = (req.query.phone || "").toString().trim();
    const patient_id = req.query.patient_id ? Number(req.query.patient_id) : null;
    if (!phone && !patient_id) {
      return res.status(400).json({ success: false, message: "Patient phone or ID is required." });
    }
    const where = { outlet_id: outlet_id2, status: "VISITED" };
    if (patient_id) {
      where.patient_id = patient_id;
    } else {
      where.patient_phone = phone;
    }
    const history = await req.propertyDb.models.clinic_appointments.findAll({
      where,
      order: [["appointment_date", "DESC"], ["id", "DESC"]],
      limit: 25
    });
    return res.json({
      success: true,
      data: history
    });
  } catch (err) {
    console.error("[PATIENT HISTORY ERROR]", err);
    return res.status(500).json({ success: false, message: err.message });
  }
};
const getClinicalTestsMaster = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const standardTests = [
      { test_name: "Blood Pressure (BP)", category: "VITALS", default_unit: "mmHg", normal_range: "120/80" },
      { test_name: "Pulse / Heart Rate", category: "VITALS", default_unit: "bpm", normal_range: "72" },
      { test_name: "Body Temperature", category: "VITALS", default_unit: "\xB0F", normal_range: "98.6" },
      { test_name: "Blood Sugar (Fasting)", category: "DIABETIC", default_unit: "mg/dL", normal_range: "70-100" },
      { test_name: "Blood Sugar (PP)", category: "DIABETIC", default_unit: "mg/dL", normal_range: "120-140" },
      { test_name: "Blood Sugar (Random)", category: "DIABETIC", default_unit: "mg/dL", normal_range: "80-140" },
      { test_name: "HbA1c", category: "DIABETIC", default_unit: "%", normal_range: "< 5.7" },
      { test_name: "Hemoglobin (Hb)", category: "BLOOD", default_unit: "g/dL", normal_range: "13.5-17.5" },
      { test_name: "CBC (Complete Blood Count)", category: "BLOOD", default_unit: "", normal_range: "Normal" },
      { test_name: "TLC (Total Leukocyte Count)", category: "BLOOD", default_unit: "/cu.mm", normal_range: "4000-11000" },
      { test_name: "DLC (Differential Count)", category: "BLOOD", default_unit: "", normal_range: "" },
      { test_name: "Urine Routine & Microscopic", category: "URINE", default_unit: "", normal_range: "Normal" },
      { test_name: "Serum Uric Acid", category: "BIOCHEM", default_unit: "mg/dL", normal_range: "3.5-7.2" },
      { test_name: "Thyroid TSH", category: "ENDOCRINE", default_unit: "uIU/mL", normal_range: "0.4-4.0" },
      { test_name: "X-Ray Chest (PA View)", category: "RADIOLOGY", default_unit: "", normal_range: "Clear" },
      { test_name: "Ultrasound (USG) Whole Abdomen", category: "RADIOLOGY", default_unit: "", normal_range: "Normal" },
      { test_name: "ECG (12 Lead)", category: "CARDIOLOGY", default_unit: "", normal_range: "Normal Sinus Rhythm" },
      { test_name: "Widal / Typhoid Test", category: "SEROLOGY", default_unit: "", normal_range: "Negative" },
      { test_name: "Chikungunya IgM", category: "SEROLOGY", default_unit: "", normal_range: "Negative" },
      { test_name: "Dengue NS1 Antigen", category: "SEROLOGY", default_unit: "", normal_range: "Negative" },
      { test_name: "Serum Creatinine", category: "RENAL", default_unit: "mg/dL", normal_range: "0.7-1.3" },
      { test_name: "Lipid Profile", category: "CARDIOLOGY", default_unit: "", normal_range: "" }
    ];
    let customTests = [];
    try {
      await req.propertyDb.query(`
                CREATE TABLE IF NOT EXISTS clinic_test_master (
                    id SERIAL PRIMARY KEY,
                    outlet_id INTEGER NOT NULL,
                    test_name VARCHAR(150) NOT NULL,
                    category VARCHAR(100) DEFAULT 'CUSTOM',
                    default_unit VARCHAR(50) DEFAULT '',
                    normal_range VARCHAR(100) DEFAULT '',
                    created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                    updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
                );
            `);
      const [rows] = await req.propertyDb.query(
        `SELECT test_name, category, default_unit, normal_range FROM clinic_test_master WHERE outlet_id = ? ORDER BY test_name ASC;`,
        { replacements: [outlet_id2] }
      );
      customTests = rows || [];
    } catch (_) {
    }
    return res.json({
      success: true,
      data: {
        standard_tests: standardTests,
        custom_tests: customTests
      }
    });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
const saveClinicalTestMaster = async (req, res) => {
  try {
    const outlet_id2 = req.user.outlet_id;
    const { test_name, category, default_unit, normal_range } = req.body;
    if (!test_name || !test_name.trim()) {
      return res.status(400).json({ success: false, message: "Test name is required." });
    }
    await req.propertyDb.query(`
            CREATE TABLE IF NOT EXISTS clinic_test_master (
                id SERIAL PRIMARY KEY,
                outlet_id INTEGER NOT NULL,
                test_name VARCHAR(150) NOT NULL,
                category VARCHAR(100) DEFAULT 'CUSTOM',
                default_unit VARCHAR(50) DEFAULT '',
                normal_range VARCHAR(100) DEFAULT '',
                created_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
                updated_at TIMESTAMP DEFAULT CURRENT_TIMESTAMP
            );
        `);
    await req.propertyDb.query(
      `INSERT INTO clinic_test_master (outlet_id, test_name, category, default_unit, normal_range)
             VALUES (?, ?, ?, ?, ?)
             ON CONFLICT DO NOTHING;`,
      { replacements: [outlet_id2, test_name.trim(), category || "CUSTOM", default_unit || "", normal_range || ""] }
    );
    return res.json({ success: true, message: `Clinical test "${test_name.trim()}" saved to Master!` });
  } catch (err) {
    return res.status(500).json({ success: false, message: err.message });
  }
};
module.exports = {
  getClinicSubscriptions,
  createClinicSubscription,
  consumeClinicSubscriptionSession,
  getClinicSubscriptionLedger,
  getPublicPatientSubscriptions,
  getAppointments,
  createAppointment,
  updateAppointmentStatus,
  savePrescription,
  sendToBillingDraft,
  getAvailableMedicines,
  getClinicDoctors,
  createClinicDoctor,
  updateClinicDoctor,
  deleteClinicDoctor,
  acceptAndPayAppointment,
  completeAppointmentBilling,
  getClinicAnalytics,
  requestPatientEmailOtp,
  verifyPatientEmailOtp,
  getPublicDoctorCities,
  getPublicSpecialities,
  getPublicDoctors,
  bookAppointmentPublic,
  getPatientHistoryPublic,
  getClinicPatientHistory,
  getClinicalTestsMaster,
  saveClinicalTestMaster
};
var clinic_controller_default = {
  getClinicSubscriptions,
  createClinicSubscription,
  consumeClinicSubscriptionSession,
  getClinicSubscriptionLedger,
  getPublicPatientSubscriptions,
  getAppointments,
  createAppointment,
  updateAppointmentStatus,
  savePrescription,
  sendToBillingDraft,
  getAvailableMedicines,
  getClinicDoctors,
  createClinicDoctor,
  updateClinicDoctor,
  deleteClinicDoctor,
  acceptAndPayAppointment,
  completeAppointmentBilling,
  getClinicAnalytics,
  requestPatientEmailOtp,
  verifyPatientEmailOtp,
  getPublicDoctorCities,
  getPublicSpecialities,
  getPublicDoctors,
  bookAppointmentPublic,
  getPatientHistoryPublic,
  getClinicPatientHistory,
  getClinicalTestsMaster,
  saveClinicalTestMaster
};
// Annotate the CommonJS export names for ESM import in node:
0 && (module.exports = {
  acceptAndPayAppointment,
  bookAppointmentPublic,
  completeAppointmentBilling,
  consumeClinicSubscriptionSession,
  createAppointment,
  createClinicDoctor,
  createClinicSubscription,
  deleteClinicDoctor,
  getAppointments,
  getAvailableMedicines,
  getClinicAnalytics,
  getClinicDoctors,
  getClinicPatientHistory,
  getClinicSubscriptionLedger,
  getClinicSubscriptions,
  getClinicalTestsMaster,
  getPatientHistoryPublic,
  getPublicDoctorCities,
  getPublicDoctors,
  getPublicPatientSubscriptions,
  getPublicSpecialities,
  requestPatientEmailOtp,
  saveClinicalTestMaster,
  savePrescription,
  sendToBillingDraft,
  updateAppointmentStatus,
  updateClinicDoctor,
  verifyPatientEmailOtp
});
