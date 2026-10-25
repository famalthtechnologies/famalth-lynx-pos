const { Op, Sequelize } = require('sequelize');

const getExpiryTracker = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const { search, status_filter } = req.query;

        // Fetch all goods receipt items that have expiry_date set
        const receiptItems = await req.propertyDb.models.goods_receipt_items.findAll({
            where: {
                expiry_date: {
                    [Op.ne]: null
                }
            },
            include: [
                {
                    model: req.propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date', 'supplier_id', 'supplier_bill_no']
                }
            ],
            order: [
                ['expiry_date', 'ASC'],
                ['created_at', 'DESC']
            ]
        });

        // Group by item_code or item_id
        const itemMap = {};

        for (const item of receiptItems) {
            const key = item.item_id ? String(item.item_id) : String(item.item_code || item.item_name);
            if (!itemMap[key]) {
                itemMap[key] = {
                    item_id: item.item_id,
                    item_code: item.item_code,
                    item_name: item.item_name,
                    brand: item.brand,
                    unit: item.unit,
                    total_received_qty: 0,
                    batches: []
                };
            }

            itemMap[key].total_received_qty += Number(item.qty || 0);
            itemMap[key].batches.push({
                grn_id: item.grn_id,
                grn_no: item.grn?.grn_no || '--',
                receipt_date: item.grn?.receipt_date,
                supplier_id: item.grn?.supplier_id,
                supplier_bill_no: item.grn?.supplier_bill_no,
                qty: Number(item.qty || 0),
                rate: Number(item.rate || 0),
                expiry_date: item.expiry_date
            });
        }

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const list = [];
        for (const key of Object.keys(itemMap)) {
            const data = itemMap[key];
            const batches = data.batches;

            // Sort batches by receipt_date descending
            batches.sort((a, b) => new Date(b.receipt_date).getTime() - new Date(a.receipt_date).getTime());

            const newestBatch = batches[0];
            const olderBatches = batches.slice(1);
            const oldestBatchWithStock = olderBatches.length > 0 ? olderBatches[olderBatches.length - 1] : null;

            // Nearest expiring batch
            const sortedByExpiry = [...batches].sort((a, b) => new Date(a.expiry_date).getTime() - new Date(b.expiry_date).getTime());
            const nearestExpBatch = sortedByExpiry[0];

            const expDate = new Date(nearestExpBatch.expiry_date);
            const diffTime = expDate.getTime() - today.getTime();
            const daysRemaining = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            let status = 'HEALTHY';
            if (daysRemaining < 0) {
                status = 'EXPIRED';
            } else if (daysRemaining <= 30) {
                status = 'CRITICAL';
            } else if (daysRemaining <= 90) {
                status = 'WARNING';
            }

            // Expiry comparison: Old stock vs New received item
            let expiryComparison = 'NORMAL';
            let daysDifference = 0;
            if (oldestBatchWithStock) {
                const newExpTime = new Date(newestBatch.expiry_date).getTime();
                const oldExpTime = new Date(oldestBatchWithStock.expiry_date).getTime();
                const diffDays = Math.round((newExpTime - oldExpTime) / (1000 * 60 * 60 * 24));
                daysDifference = diffDays;
                if (diffDays < 0) {
                    expiryComparison = 'NEW_SHORTER_THAN_OLD';
                } else if (diffDays > 0) {
                    expiryComparison = 'NEW_LONGER_THAN_OLD';
                } else {
                    expiryComparison = 'SAME_EXPIRY';
                }
            }

            // Get live stock balance
            let currentStock = data.total_received_qty;
            if (data.item_id) {
                const itemMaster = await req.propertyDb.models.item_master.findByPk(data.item_id, {
                    attributes: ['opening_balance']
                });
                const lastLedger = await req.propertyDb.models.stock_ledger.findOne({
                    where: { outlet_id, item_code: data.item_code },
                    order: [['id', 'DESC']],
                    attributes: ['balance']
                });
                if (lastLedger && lastLedger.balance !== null) {
                    currentStock = Number(lastLedger.balance);
                } else if (itemMaster && itemMaster.opening_balance !== null) {
                    currentStock = Number(itemMaster.opening_balance);
                }
            }

            const itemEntry = {
                item_id: data.item_id,
                item_code: data.item_code,
                item_name: data.item_name,
                brand: data.brand || 'General',
                unit: data.unit || 'PCS',
                current_stock: currentStock,
                total_received_qty: data.total_received_qty,
                nearest_expiry_date: nearestExpBatch.expiry_date,
                days_remaining: daysRemaining,
                status,
                newest_batch_expiry: newestBatch.expiry_date,
                old_batch_expiry: oldestBatchWithStock ? oldestBatchWithStock.expiry_date : null,
                expiry_comparison: expiryComparison,
                days_difference: daysDifference,
                batches_count: batches.length
            };

            if (status_filter && status_filter !== 'ALL' && itemEntry.status !== status_filter) {
                continue;
            }
            if (search) {
                const q = search.toLowerCase();
                const match = itemEntry.item_name.toLowerCase().includes(q) ||
                    (itemEntry.item_code && itemEntry.item_code.toLowerCase().includes(q)) ||
                    (itemEntry.brand && itemEntry.brand.toLowerCase().includes(q));
                if (!match) continue;
            }

            list.push(itemEntry);
        }

        const expiredCount = list.filter(i => i.status === 'EXPIRED').length;
        const criticalCount = list.filter(i => i.status === 'CRITICAL').length;
        const warningCount = list.filter(i => i.status === 'WARNING').length;
        const newShorterAlerts = list.filter(i => i.expiry_comparison === 'NEW_SHORTER_THAN_OLD').length;

        return res.json({
            success: true,
            summary: {
                total_tracked_items: list.length,
                expired_count: expiredCount,
                critical_count: criticalCount,
                warning_count: warningCount,
                new_shorter_alerts: newShorterAlerts
            },
            data: list
        });
    } catch (err) {
        console.error('[GET EXPIRY TRACKER ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const getExpiryLedgerByItem = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const itemId = req.params.itemId;

        const whereItem = {};
        if (Number(itemId)) {
            whereItem.item_id = Number(itemId);
        } else {
            whereItem.item_code = itemId;
        }

        const items = await req.propertyDb.models.goods_receipt_items.findAll({
            where: {
                ...whereItem,
                expiry_date: { [Op.ne]: null }
            },
            include: [
                {
                    model: req.propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date', 'supplier_id', 'supplier_bill_no']
                }
            ],
            order: [['created_at', 'DESC']]
        });

        const supplierIds = [...new Set(items.map(i => i.grn?.supplier_id).filter(Boolean))];
        const suppliers = await req.propertyDb.models.supplier_master.findAll({
            where: { id: { [Op.in]: supplierIds } },
            attributes: ['id', 'supplier_name']
        });
        const supplierMap = {};
        suppliers.forEach(s => supplierMap[s.id] = s.supplier_name);

        const today = new Date();
        today.setHours(0, 0, 0, 0);

        const ledger = items.map((i, index) => {
            const expDate = new Date(i.expiry_date);
            const diffTime = expDate.getTime() - today.getTime();
            const daysLeft = Math.ceil(diffTime / (1000 * 60 * 60 * 24));

            return {
                batch_no: `BATCH-${i.grn?.grn_no || index + 1}`,
                grn_no: i.grn?.grn_no || '--',
                receipt_date: i.grn?.receipt_date,
                supplier_bill_no: i.grn?.supplier_bill_no || '--',
                supplier_name: supplierMap[i.grn?.supplier_id] || 'Direct Supplier',
                qty_received: Number(i.qty || 0),
                purchase_rate: Number(i.rate || 0),
                expiry_date: i.expiry_date,
                days_left: daysLeft,
                status: daysLeft < 0 ? 'EXPIRED' : (daysLeft <= 30 ? 'CRITICAL' : 'ACTIVE'),
                is_latest_receiving: index === 0
            };
        });

        return res.json({
            success: true,
            data: ledger
        });
    } catch (err) {
        console.error('[GET EXPIRY LEDGER ERROR]', err);
        return res.status(500).json({ success: false, message: err.message });
    }
};

const triggerExpiryNotifications = async (req, res) => {
    try {
        const outlet_id = req.user.outlet_id;
        const today = new Date();
        const thirtyDaysLater = new Date();
        thirtyDaysLater.setDate(today.getDate() + 30);

        const expiringItems = await req.propertyDb.models.goods_receipt_items.findAll({
            where: {
                expiry_date: {
                    [Op.lte]: thirtyDaysLater.toISOString().split('T')[0]
                }
            },
            include: [
                {
                    model: req.propertyDb.models.goods_receipts,
                    as: 'grn',
                    where: { outlet_id },
                    attributes: ['id', 'grn_no', 'receipt_date']
                }
            ],
            limit: 20
        });

        let createdCount = 0;
        for (const item of expiringItems) {
            const title = `⚠️ Expiry Alert: ${item.item_name}`;
            const message = `Item ${item.item_name} (Batch GRN #${item.grn?.grn_no || ''}) expires on ${item.expiry_date}. Please check stock balance.`;

            const exists = await req.propertyDb.models.system_notifications.findOne({
                where: {
                    outlet_id,
                    module: 'EXPIRY',
                    title
                }
            });

            if (!exists) {
                await req.propertyDb.models.system_notifications.create({
                    outlet_id,
                    module: 'EXPIRY',
                    title,
                    message,
                    type: 'WARNING',
                    is_read: false
                });
                createdCount++;
            }
        }

        return res.json({
            success: true,
            message: `Scanned expiring batches. Created ${createdCount} notification alerts.`,
            alerts_created: createdCount
        });
    } catch (err) {
        return res.status(500).json({ success: false, message: err.message });
    }
};

module.exports = {
    getExpiryTracker,
    getExpiryLedgerByItem,
    triggerExpiryNotifications
};
