"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.rejectRequest = exports.approveRequest = exports.getRequestDetails = exports.modifyRequest = exports.getRequestsByDate = exports.listRequests = exports.cancelRequest = exports.deleteRequestItem = exports.updateRequestItem = exports.updateRequest = exports.getNextRequestNo = exports.createRequest = void 0;
const audit = require('../../services/audit.service');
const { Op } = require('sequelize');
const { normalizeDateKey } = require('../../utils/dateQuery');
function normalizeLineStatus(value) {
    const status = String(value || 'CLOSED').trim().toUpperCase();
    return ['OPEN', 'CLOSED', 'CANCELLED'].includes(status) ? status : 'CLOSED';
}
function deriveHeaderStatus(items) {
    const statuses = items.map(item => normalizeLineStatus(item.line_status));
    const hasOpen = statuses.includes('OPEN');
    const hasClosed = statuses.includes('CLOSED');
    const allCancelled = statuses.length > 0 && statuses.every(status => status === 'CANCELLED');
    if (allCancelled)
        return 'CANCELLED';
    if (hasOpen && hasClosed)
        return 'PARTIAL';
    if (hasOpen)
        return 'OPEN';
    return 'CLOSED';
}
function isIssuedRequestStatus(value) {
    return ['PARTIAL', 'CLOSED', 'ISSUED'].includes(String(value || '').trim().toUpperCase());
}
const createRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { department, request_date, open_request_no, items = [] } = req.body;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        let effectiveRequestNo = String(open_request_no || '').trim();
        // On actual insert, ALWAYS mint official sequential Request number atomically from DB
        try {
            const numberingHelper = require('./numberingSettingsV2.controller');
            const resolved = await numberingHelper.allocateNextNumber({
                db: req.propertyDb,
                module: 'REQUEST',
                date: request_date || new Date(),
                outlet_id,
                transaction: t
            });
            if (resolved && resolved.number) {
                effectiveRequestNo = resolved.number;
            }
        }
        catch (seqErr) {
            console.warn('[REQUEST SEQ] Auto-resolve numbering warning:', seqErr?.message || seqErr);
        }
        // 1️⃣ Create header
        const header = await req.propertyDb.models.request_headers.create({
            request_no: effectiveRequestNo,
            department,
            request_date,
            open_request_no: effectiveRequestNo,
            status: 'OPEN',
            approval_status: 'PENDING',
            outlet_id,
            created_by: user_id
        }, { transaction: t });
        // 2️⃣ Create items
        for (const it of items) {
            await req.propertyDb.models.request_items.create({
                request_id: header.id,
                item_id: it.item_id,
                item_code: it.code,
                qty: it.qty,
                rate: it.rate
            }, { transaction: t });
        }
        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'REQUEST',
            title: 'New Item Request',
            message: `Request #${header.id} created`,
            type: 'INFO',
            entity_id: header.id
        }, { transaction: t });
        await audit.log({
            req,
            module: 'request_item',
            action: 'CREATE_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: header.toJSON()
        }, { transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Request saved successfully' });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.createRequest = createRequest;
const getNextRequestNo = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const last = await req.propertyDb.models.request_headers.findOne({
            where: { outlet_id },
            order: [['id', 'DESC']]
        });
        let nextNo = last ? last.id + 1 : 1;
        res.json({
            success: true,
            data: `REQ-${nextNo}`
        });
    }
    catch (err) {
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.getNextRequestNo = getNextRequestNo;
const updateRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const header = await req.propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });
        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        const oldData = header.toJSON();
        await header.update(req.body, { transaction: t });
        await req.propertyDb.models.audit_logs.create({
            user_id,
            outlet_id: outlet_id,
            module: 'REQUEST',
            action: 'UPDATE',
            table_name: 'request_headers',
            record_id: header.id,
            old_data: oldData,
            new_data: header.toJSON()
        }, { transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Request updated' });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.updateRequest = updateRequest;
const updateRequestItem = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { qty, rate } = req.body;
        const user_id = req.user.id;
        const item = await req.propertyDb.models.request_items.findByPk(id);
        if (!item) {
            return res.status(404).json({ success: false, message: 'Item not found' });
        }
        const header = await req.propertyDb.models.request_headers.findByPk(item.request_id, { transaction: t });
        if (header && isIssuedRequestStatus(header.status)) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Issued requests cannot be modified' });
        }
        const oldData = item.toJSON();
        await item.update({ qty, rate }, { transaction: t });
        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'UPDATE_ITEM',
            table_name: 'request_items',
            record_id: item.id,
            old_data: oldData,
            new_data: item.toJSON()
        }, { transaction: t });
        await t.commit();
        res.json({ success: true });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.updateRequestItem = updateRequestItem;
const deleteRequestItem = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const user_id = req.user.id;
        const item = await req.propertyDb.models.request_items.findByPk(id);
        if (!item) {
            return res.status(404).json({ success: false });
        }
        const header = await req.propertyDb.models.request_headers.findByPk(item.request_id, { transaction: t });
        if (header && isIssuedRequestStatus(header.status)) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Items in issued requests cannot be deleted' });
        }
        const oldData = item.toJSON();
        await item.destroy({ transaction: t });
        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'DELETE_ITEM',
            table_name: 'request_items',
            record_id: id,
            old_data: oldData
        }, { transaction: t });
        await t.commit();
        res.json({ success: true });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.deleteRequestItem = deleteRequestItem;
const cancelRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const outlet_id = req.user.outlet_id;
        const user_id = req.user.id;
        const header = await req.propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });
        if (!header) {
            return res.status(404).json({ success: false });
        }
        if (isIssuedRequestStatus(header.status)) {
            await t.rollback();
            return res.status(400).json({ success: false, message: 'Issued requests cannot be cancelled' });
        }
        const oldData = header.toJSON();
        await header.update({ status: 'CANCELLED' }, { transaction: t });
        await req.propertyDb.models.audit_logs.create({
            user_id,
            module: 'REQUEST',
            action: 'CANCEL',
            table_name: 'request_headers',
            record_id: header.id,
            old_data: oldData,
            new_data: { status: 'CANCELLED' }
        }, { transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Request cancelled' });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.cancelRequest = cancelRequest;
const listRequests = async (req, res) => {
    try {
        const statusFilter = req.query.status;
        const data = await req.propertyDb.models.request_headers.findAll({
            where: {
                outlet_id: req.user.outlet_id,
                approval_status: 'APPROVED',
                status: {
                    [Op.in]: statusFilter ? [statusFilter] : ['OPEN', 'PARTIAL']
                },
            },
            attributes: [
                'id',
                'request_no',
                'department',
                'request_date',
                'status',
                'approval_status',
                'approved_at'
            ],
            order: [['request_date', 'DESC'], ['id', 'DESC']]
        });
        res.json({ success: true, data });
    }
    catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};
exports.listRequests = listRequests;
const getRequestsByDate = async (req, res) => {
    try {
        const { date, from_date, to_date } = req.query;
        const outlet_id = req.user.outlet_id;
        let dateClause = {};
        if (from_date && to_date) {
            const normFrom = normalizeDateKey(from_date) || from_date;
            const normTo = normalizeDateKey(to_date) || to_date;
            dateClause = { [Op.between]: [normFrom, normTo] };
        }
        else if (date) {
            const normalizedDate = normalizeDateKey(date) || date;
            dateClause = normalizedDate;
        }
        const where = { outlet_id };
        if (date || (from_date && to_date)) {
            where.request_date = dateClause;
        }
        const data = await req.propertyDb.models.request_headers.findAll({
            where,
            include: [
                {
                    model: req.propertyDb.models.request_items,
                    as: 'items',
                    attributes: ['id', 'qty', 'rate']
                }
            ],
            order: [['created_at', 'DESC'], ['id', 'DESC']]
        });
        const formatted = data.map((reqItem) => {
            const json = reqItem.toJSON();
            let total = 0;
            if (Array.isArray(json.items)) {
                total = json.items.reduce((sum, it) => sum + ((Number(it.qty) || 0) * (Number(it.rate) || 0)), 0);
            }
            json.total_amount = total;
            return json;
        });
        res.json({
            success: true,
            data: formatted
        });
    }
    catch (err) {
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};
exports.getRequestsByDate = getRequestsByDate;
const modifyRequest = async (req, res) => {
    const t = await req.propertyDb.transaction();
    try {
        const { id } = req.params;
        const { department, items = [] } = req.body;
        const outlet_id = req.user.outlet_id;
        const header = await req.propertyDb.models.request_headers.findOne({
            where: { id, outlet_id }
        });
        if (!header) {
            return res.status(404).json({ success: false });
        }
        if (isIssuedRequestStatus(header.status)) {
            await t.rollback();
            return res.status(400).json({
                success: false,
                message: 'Issued requests cannot be modified'
            });
        }
        /// UPDATE DEPARTMENT
        await header.update({ department }, { transaction: t });
        /// GET EXISTING ITEMS
        const existingItems = await req.propertyDb.models.request_items.findAll({
            where: { request_id: id },
            transaction: t
        });
        const existingIds = existingItems.map((i) => i.id);
        const incomingIds = items.map((i) => i.id).filter((i) => i);
        /// DELETE REMOVED ITEMS
        const deleteIds = existingIds.filter((existingId) => !incomingIds.includes(existingId));
        if (deleteIds.length > 0) {
            await req.propertyDb.models.request_items.destroy({
                where: {
                    id: deleteIds
                },
                transaction: t
            });
        }
        /// UPDATE EXISTING ITEMS
        for (const item of items) {
            await req.propertyDb.models.request_items.update({
                qty: item.qty,
                rate: item.rate
            }, {
                where: { id: item.id },
                transaction: t
            });
        }
        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'REQUEST',
            title: 'Item Request Modified',
            message: `Request #${id} was modified`,
            type: 'WARNING',
            entity_id: id
        }, { transaction: t });
        await t.commit();
        res.json({
            success: true,
            message: 'Request modified successfully'
        });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({
            success: false,
            message: err.message
        });
    }
};
exports.modifyRequest = modifyRequest;
const getRequestDetails = async (req, res) => {
    const { id } = req.params;
    const header = await req.propertyDb.models.request_headers.findOne({
        where: {
            id,
            outlet_id: req.user.outlet_id
        },
        include: [{
                model: req.propertyDb.models.request_items,
                as: 'items',
                include: [{
                        model: req.propertyDb.models.item_master,
                        as: 'item_master',
                        attributes: ['item_name', 'brand', 'unit']
                    }]
            }]
    });
    if (!header) {
        return res.status(404).json({ success: false, message: 'Not found' });
    }
    res.json({ success: true, data: header });
};
exports.getRequestDetails = getRequestDetails;
const approveRequest = async (req, res) => {
    if (req.user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can approve requests'
        });
    }
    const t = await req.propertyDb.transaction();
    try {
        const header = await req.propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });
        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        await header.update({
            approval_status: 'APPROVED',
            approved_by: req.user.id,
            approved_at: new Date(),
            rejected_by: null,
            rejected_at: null,
            rejection_reason: null
        }, { transaction: t });
        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'REQUEST',
            title: 'Request Approved',
            message: `Request ${header.request_no} approved`,
            type: 'SUCCESS',
            entity_id: header.id
        }, { transaction: t });
        await audit.log({
            req,
            module: 'request_item',
            action: 'APPROVE_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: { approval_status: 'APPROVED' }
        }, { transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Request approved successfully' });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.approveRequest = approveRequest;
const rejectRequest = async (req, res) => {
    if (req.user.role !== 'ADMIN') {
        return res.status(403).json({
            success: false,
            message: 'Only admin can reject requests'
        });
    }
    const t = await req.propertyDb.transaction();
    try {
        const rejectionReason = String(req.body.rejection_reason || '').trim();
        if (!rejectionReason) {
            return res.status(400).json({
                success: false,
                message: 'Rejection reason is required'
            });
        }
        const header = await req.propertyDb.models.request_headers.findOne({
            where: {
                id: req.params.id,
                outlet_id: req.user.outlet_id
            },
            transaction: t
        });
        if (!header) {
            return res.status(404).json({ success: false, message: 'Request not found' });
        }
        await header.update({
            approval_status: 'REJECTED',
            rejected_by: req.user.id,
            rejected_at: new Date(),
            rejection_reason: rejectionReason,
            approved_by: null,
            approved_at: null
        }, { transaction: t });
        await req.propertyDb.models.system_notifications.create({
            outlet_id: req.user.outlet_id,
            module: 'REQUEST',
            title: 'Request Rejected',
            message: `Request ${header.request_no} rejected`,
            type: 'WARNING',
            entity_id: header.id
        }, { transaction: t });
        await audit.log({
            req,
            module: 'request_item',
            action: 'REJECT_REQUEST',
            table: 'request_headers',
            recordId: header.id,
            newData: {
                approval_status: 'REJECTED',
                rejection_reason: rejectionReason
            }
        }, { transaction: t });
        await t.commit();
        res.json({ success: true, message: 'Request rejected successfully' });
    }
    catch (err) {
        await t.rollback();
        res.status(500).json({ success: false, error: err.message });
    }
};
exports.rejectRequest = rejectRequest;
exports.default = {
    createRequest: exports.createRequest,
    getNextRequestNo: exports.getNextRequestNo,
    updateRequest: exports.updateRequest,
    updateRequestItem: exports.updateRequestItem,
    deleteRequestItem: exports.deleteRequestItem,
    cancelRequest: exports.cancelRequest,
    listRequests: exports.listRequests,
    getRequestsByDate: exports.getRequestsByDate,
    modifyRequest: exports.modifyRequest,
    getRequestDetails: exports.getRequestDetails,
    approveRequest: exports.approveRequest,
    rejectRequest: exports.rejectRequest
};
