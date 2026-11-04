"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.updateChallanStatus = exports.createChallan = exports.getChallanDetails = exports.listChallans = void 0;
const sequelize_1 = require("sequelize");
const { insertLedger } = require('../../services/stockLedger.service');
const audit = require('../../services/audit.service');
const { createLedgerEntry } = require('../../services/cashLedger.service');
const listChallans = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const challans = await req.propertyDb.models.delivery_challan_headers.findAll({
            where: { outlet_id },
            order: [['challan_date', 'DESC']]
        });
        return res.json({ success: true, data: challans });
    }
    catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};
exports.listChallans = listChallans;
const getChallanDetails = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { id } = req.params;
        const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
            where: { id, outlet_id },
            include: [{ model: req.propertyDb.models.delivery_challan_items, as: 'items' }]
        });
        if (!challan)
            return res.status(404).json({ success: false, message: 'Challan not found' });
        return res.json({ success: true, data: challan });
    }
    catch (err) {
        return res.status(500).json({ success: false, error: err.message });
    }
};
exports.getChallanDetails = getChallanDetails;
const createChallan = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.user_id || req.user.id;
        const { customer_name, customer_phone, items, vehicle_id, vehicle_number, vehicle_type, driver_id, driver_name, driver_phone, e_way_bill_no, destination_address } = req.body;
        if (!items || items.length === 0)
            throw new Error('Cannot create Challan without items');
        // Generate Challan Number
        const today = new Date();
        const dateStr = `${today.getFullYear()}${String(today.getMonth() + 1).padStart(2, '0')}${String(today.getDate()).padStart(2, '0')}`;
        const count = await req.propertyDb.models.delivery_challan_headers.count({
            where: {
                outlet_id,
                created_at: {
                    [sequelize_1.Op.gte]: new Date(today.setHours(0, 0, 0, 0))
                }
            },
            transaction: t
        });
        const seq = String(count + 1).padStart(4, '0');
        const challan_no = `DC-${dateStr}-${seq}`;
        // Generate Delivery OTP if vehicle or driver assigned
        let delivery_otp = null;
        let delivery_status = 'PENDING';
        let trip_id = null;
        if (vehicle_id || driver_id) {
            delivery_otp = String(Math.floor(100000 + Math.random() * 900000));
            delivery_status = 'IN_TRANSIT';
            trip_id = `TRIP-${dateStr}-${Math.random().toString(36).substring(2, 6).toUpperCase()}`;
            if (vehicle_id && req.propertyDb.models.transport_vehicles) {
                await req.propertyDb.models.transport_vehicles.update({ status: 'BOOKED', current_trip_id: trip_id, current_driver_id: driver_id || null }, { where: { id: vehicle_id, outlet_id }, transaction: t });
            }
            if (driver_id && req.propertyDb.models.transport_drivers) {
                await req.propertyDb.models.transport_drivers.update({ status: 'BOOKED', current_vehicle_id: vehicle_id || null }, { where: { id: driver_id, outlet_id }, transaction: t });
            }
        }
        let totalQty = 0;
        const itemsToCreate = [];
        for (const item of items) {
            const itemDef = await req.propertyDb.models.item_master.findOne({
                where: { id: item.item_id, outlet_id },
                transaction: t
            });
            if (!itemDef)
                throw new Error(`Item ${item.item_name} not found`);
            const qty = Number(item.qty) || 1.0;
            totalQty += qty;
            itemsToCreate.push({
                item_id: item.item_id,
                item_code: itemDef.item_code,
                item_name: itemDef.item_name,
                qty,
                unit: itemDef.unit || 'PCS'
            });
        }
        // Create Header
        const header = await req.propertyDb.models.delivery_challan_headers.create({
            outlet_id,
            challan_no,
            challan_date: new Date(),
            customer_name,
            customer_phone,
            total_qty: totalQty,
            status: delivery_status === 'IN_TRANSIT' ? 'In-Transit' : 'Issued',
            created_by: user_id,
            vehicle_id: vehicle_id || null,
            vehicle_number: vehicle_number || null,
            vehicle_type: vehicle_type || null,
            driver_id: driver_id || null,
            driver_name: driver_name || null,
            driver_phone: driver_phone || null,
            trip_id: trip_id || null,
            delivery_status,
            delivery_otp,
            e_way_bill_no: e_way_bill_no || null,
            destination_address: destination_address || null
        }, { transaction: t });
        // Save items and write to Stock Ledger
        for (const item of itemsToCreate) {
            await req.propertyDb.models.delivery_challan_items.create({
                challan_id: header.id,
                item_id: item.item_id,
                item_code: item.item_code,
                item_name: item.item_name,
                qty: item.qty,
                unit: item.unit
            }, { transaction: t });
            // Deduct stock instantly
            await insertLedger({
                db: req.propertyDb,
                outlet_id,
                item_code: item.item_code,
                txn_date: today,
                txn_type: 'CHALLAN_OUT',
                ref_no: challan_no,
                qty_out: item.qty,
                transaction: t,
                allow_negative: true
            });
        }
        await audit.log({
            req,
            module: 'INVENTORY',
            action: 'CHALLAN_CREATE',
            table: 'delivery_challan_headers',
            recordId: header.id,
            description: `Issued Delivery Challan ${challan_no} to ${customer_name}`,
            outlet_id,
            user_id
        });
        await t.commit();
        return res.json({ success: true, data: header });
    }
    catch (err) {
        await t.rollback();
        return res.status(400).json({ success: false, error: err.message });
    }
};
exports.createChallan = createChallan;
const updateChallanStatus = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const { id } = req.params;
        const { status } = req.body;
        const challan = await req.propertyDb.models.delivery_challan_headers.findOne({
            where: { id, outlet_id },
            include: [{ model: req.propertyDb.models.delivery_challan_items, as: 'items' }],
            transaction: t
        });
        if (!challan) {
            await t.rollback();
            return res.status(404).json({ success: false, message: 'Challan not found' });
        }
        const updateData = { status };
        if (status === 'Delivered') {
            updateData.delivery_status = 'DELIVERED';
            updateData.delivered_at = new Date();
            if (!updateData.delivered_by_remark) {
                updateData.delivered_by_remark = 'Marked as Delivered';
            }
        }
        await challan.update(updateData, { transaction: t });
        // If marked Delivered or Converted_To_Sale, check if vehicle and driver can be liberated
        if (status === 'Delivered' || status === 'Converted_To_Sale') {
            if (challan.vehicle_id && req.propertyDb.models.transport_vehicles) {
                const remainingOnVehicle = await req.propertyDb.models.delivery_challan_headers.count({
                    where: {
                        outlet_id,
                        vehicle_id: challan.vehicle_id,
                        delivery_status: { [sequelize_1.Op.ne]: 'DELIVERED' }
                    },
                    transaction: t
                });
                if (remainingOnVehicle === 0) {
                    await req.propertyDb.models.transport_vehicles.update({ status: 'AVAILABLE', current_trip_id: null, current_driver_id: null }, { where: { id: challan.vehicle_id, outlet_id }, transaction: t });
                    if (challan.driver_id && req.propertyDb.models.transport_drivers) {
                        await req.propertyDb.models.transport_drivers.update({ status: 'AVAILABLE', current_vehicle_id: null }, { where: { id: challan.driver_id, outlet_id }, transaction: t });
                    }
                }
            }
        }
        // If status is Converted_To_Sale, create Sales Record and Cash Ledger revenue entry (NO stock re-deduction)
        if (status === 'Converted_To_Sale') {
            let grandTotal = 0;
            const itemsProcessed = [];
            if (challan.items && challan.items.length > 0) {
                for (const item of challan.items) {
                    const itemDef = await req.propertyDb.models.item_master.findOne({
                        where: { id: item.item_id, outlet_id },
                        transaction: t
                    });
                    const rate = itemDef
                        ? parseFloat(itemDef.retail_sale_price) || parseFloat(itemDef.rate) || 0
                        : 0;
                    const qty = parseFloat(item.qty) || 1.0;
                    const amount = qty * rate;
                    grandTotal += amount;
                    itemsProcessed.push({
                        item_id: item.item_id,
                        item_code: item.item_code,
                        item_name: item.item_name,
                        unit: item.unit,
                        qty,
                        rate,
                        amount
                    });
                }
            }
            const saleNo = `SALE-${challan.challan_no}`;
            // Create Sales Header in database if sales_headers model exists
            if (req.propertyDb.models.sales_headers) {
                const saleHeader = await req.propertyDb.models.sales_headers.create({
                    outlet_id,
                    sale_no: saleNo,
                    sale_date: new Date(),
                    customer_name: challan.customer_name || 'Walk-in Customer',
                    customer_phone: challan.customer_phone || '',
                    payment_mode: 'CASH',
                    total_qty: challan.total_qty || 0,
                    sub_total: grandTotal,
                    net_amount: grandTotal,
                    amount_paid: grandTotal,
                    balance_due: 0,
                    status: 'COMPLETED',
                    notes: `Converted from Delivery Challan ${challan.challan_no}`,
                    is_latest: true,
                    is_deleted: false
                }, { transaction: t });
                if (req.propertyDb.models.sales_items) {
                    for (const it of itemsProcessed) {
                        await req.propertyDb.models.sales_items.create({
                            outlet_id,
                            sale_id: saleHeader.id,
                            item_id: it.item_id,
                            item_code: it.item_code,
                            item_name: it.item_name,
                            qty: it.qty,
                            original_qty: it.qty,
                            unit: it.unit,
                            rate: it.rate,
                            amount: it.amount
                        }, { transaction: t });
                    }
                }
            }
            // Post Revenue Entry into Cash Ledger
            if (grandTotal > 0) {
                await createLedgerEntry({
                    db: req.propertyDb,
                    outlet_id,
                    txn_date: new Date(),
                    transaction_type: 'SALE',
                    reference_type: 'DELIVERY_CHALLAN',
                    reference_id: challan.id,
                    reference_no: saleNo,
                    party_name: challan.customer_name || 'Walk-in Customer',
                    payment_method: 'CASH',
                    amount_in: grandTotal,
                    notes: `Revenue from converted Delivery Challan ${challan.challan_no}`,
                    created_by: user_id,
                    transaction: t
                });
            }
            await audit.log({
                req,
                module: 'INVENTORY',
                action: 'CHALLAN_CONVERT_TO_SALE',
                table: 'delivery_challan_headers',
                recordId: challan.id,
                description: `Converted Delivery Challan ${challan.challan_no} to Sale Invoice ${saleNo} (${grandTotal.toFixed(2)})`,
                outlet_id,
                user_id
            });
        }
        await t.commit();
        return res.json({
            success: true,
            data: challan,
            message: 'Challan successfully converted to Sales Invoice!'
        });
    }
    catch (err) {
        await t.rollback();
        return res.status(400).json({ success: false, error: err.message });
    }
};
exports.updateChallanStatus = updateChallanStatus;
module.exports = {
    listChallans: exports.listChallans,
    getChallanDetails: exports.getChallanDetails,
    createChallan: exports.createChallan,
    updateChallanStatus: exports.updateChallanStatus
};
