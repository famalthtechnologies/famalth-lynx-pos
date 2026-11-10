"use strict";
/**
 * FAMALTH LYNX - Model Context Protocol (MCP) & AI Gateway Service
 *
 * Strict Multi-Tenant Security Policy:
 * AI Models (ChatGPT, Gemini, Claude, Cursor) are strictly restricted to:
 * 1. Their particular assigned outlet, OR
 * 2. Authorized linked outlets (master outlet + child branches cluster).
 * Access to 'ALL' outlets or unauthorized tenant outlets is strictly blocked.
 */
Object.defineProperty(exports, "__esModule", { value: true });
exports.MCP_PROMPTS = exports.MCP_RESOURCES = exports.MCP_TOOLS = void 0;
exports.normalizeOutletScope = normalizeOutletScope;
exports.toolAnalyzeSales = toolAnalyzeSales;
exports.toolCreateOrderBill = toolCreateOrderBill;
exports.toolGetInventoryStatus = toolGetInventoryStatus;
exports.toolSearchProducts = toolSearchProducts;
exports.toolGetOrderDetails = toolGetOrderDetails;
exports.toolGetCustomerInsights = toolGetCustomerInsights;
exports.executeTool = executeTool;
exports.handleJsonRpc = handleJsonRpc;
exports.getChatGptOpenApiSpec = getChatGptOpenApiSpec;
exports.getGeminiToolsSpec = getGeminiToolsSpec;
exports.getClaudeConfigSnippet = getClaudeConfigSnippet;
const defaultDb = require('../db/models');
function normalizeOutletScope(ctxOrId) {
    if (ctxOrId && typeof ctxOrId === 'object' && Array.isArray(ctxOrId.allowedOutletIds)) {
        const pId = Number(ctxOrId.primaryOutletId) || 1;
        const allowed = ctxOrId.allowedOutletIds.map(Number).filter((n) => n > 0);
        if (!allowed.includes(pId))
            allowed.push(pId);
        return {
            primaryOutletId: pId,
            primaryOutletName: ctxOrId.primaryOutletName || `Outlet #${pId}`,
            isMaster: Boolean(ctxOrId.isMaster),
            allowedOutletIds: allowed.length > 0 ? allowed : [pId],
            linkedOutlets: ctxOrId.linkedOutlets || []
        };
    }
    const numId = Number(ctxOrId) || 1;
    return {
        primaryOutletId: numId,
        primaryOutletName: `Outlet #${numId}`,
        isMaster: false,
        allowedOutletIds: [numId],
        linkedOutlets: []
    };
}
exports.MCP_TOOLS = [
    {
        name: 'analyze_sales',
        description: 'Analyzes store sales revenue, order volumes, average order value, payment method breakdowns, peak selling hours, and top-performing products. Strictly isolated to your assigned outlet or linked branch cluster.',
        inputSchema: {
            type: 'object',
            properties: {
                timeframe: {
                    type: 'string',
                    enum: ['today', 'yesterday', 'this_week', 'last_7_days', 'this_month', 'last_month', 'custom'],
                    description: "Time range for analysis. Defaults to 'today'."
                },
                startDate: {
                    type: 'string',
                    description: "Start date in 'YYYY-MM-DD' format (required if timeframe is 'custom')"
                },
                endDate: {
                    type: 'string',
                    description: "End date in 'YYYY-MM-DD' format (required if timeframe is 'custom')"
                },
                groupBy: {
                    type: 'string',
                    enum: ['day', 'payment_mode', 'hourly', 'top_items'],
                    description: "Optional grouping dimension for granular breakdown"
                },
                outletId: {
                    type: 'number',
                    description: 'Specific outlet ID to analyze (must be your assigned outlet or one of your linked branches)'
                }
            }
        }
    },
    {
        name: 'create_order_bill',
        description: 'Creates and issues a live sales order / billing invoice in the POS system for your assigned outlet or linked branch. Matches catalog products, calculates item totals and discounts, records the transaction, updates inventory stock, and returns the official bill number and formatted receipt text.',
        inputSchema: {
            type: 'object',
            properties: {
                customerName: {
                    type: 'string',
                    description: "Customer full name (e.g. 'John Doe' or 'Walk-in Customer')"
                },
                customerPhone: {
                    type: 'string',
                    description: "Customer mobile number for SMS/WhatsApp receipt"
                },
                paymentMode: {
                    type: 'string',
                    enum: ['CASH', 'UPI', 'CARD', 'CREDIT', 'SPLIT'],
                    description: "Payment mode used for the bill. Default is 'CASH'."
                },
                items: {
                    type: 'array',
                    description: 'List of products/items to include in this bill',
                    items: {
                        type: 'object',
                        properties: {
                            name: {
                                type: 'string',
                                description: 'Product name or search keyword (e.g. Milk 1L, Cappuccino, Basmati Rice)'
                            },
                            quantity: {
                                type: 'number',
                                description: 'Quantity to purchase (must be greater than 0)'
                            },
                            unitPrice: {
                                type: 'number',
                                description: 'Unit selling price (optional; if omitted or 0, system fetches catalog price)'
                            },
                            itemCode: {
                                type: 'string',
                                description: 'Product item code or SKU (optional)'
                            },
                            barcode: {
                                type: 'string',
                                description: 'Product barcode (optional)'
                            },
                            discount: {
                                type: 'number',
                                description: 'Discount amount for this line item (optional)'
                            }
                        },
                        required: ['name', 'quantity']
                    }
                },
                discountAmount: {
                    type: 'number',
                    description: 'Overall flat bill discount amount (optional)'
                },
                notes: {
                    type: 'string',
                    description: "Special order remarks or AI billing note (e.g. 'Order generated via ChatGPT / Gemini Assistant')"
                },
                outletId: {
                    type: 'number',
                    description: 'Target Outlet ID (defaults to assigned primary outlet; must belong to your linked cluster)'
                }
            },
            required: ['items']
        }
    },
    {
        name: 'get_inventory_status',
        description: 'Queries store inventory for your designated outlet or linked cluster to check stock balances, identify low-stock items requiring reorder, out-of-stock items, and calculate inventory valuation.',
        inputSchema: {
            type: 'object',
            properties: {
                filter: {
                    type: 'string',
                    enum: ['all', 'low_stock', 'out_of_stock'],
                    description: "Filter items: 'all', 'low_stock' (stock <= threshold), or 'out_of_stock' (stock <= 0)"
                },
                threshold: {
                    type: 'number',
                    description: 'Threshold quantity for low stock warning. Default is 10.'
                },
                search: {
                    type: 'string',
                    description: 'Optional filter by item name, SKU, or category'
                },
                limit: {
                    type: 'number',
                    description: 'Maximum items to return (default 50, max 200)'
                },
                outletId: {
                    type: 'number',
                    description: 'Filter by specific linked outlet ID'
                }
            }
        }
    },
    {
        name: 'search_products',
        description: 'Searches product catalog of your assigned outlet and linked branches by name, barcode, SKU or category to verify pricing, unit of measure, and live stock levels before billing or answering customer queries.',
        inputSchema: {
            type: 'object',
            properties: {
                query: {
                    type: 'string',
                    description: 'Product name, barcode, code or category keyword'
                },
                limit: {
                    type: 'number',
                    description: 'Maximum results to return (default 20)'
                },
                outletId: {
                    type: 'number',
                    description: 'Filter by specific linked outlet ID'
                }
            },
            required: ['query']
        }
    },
    {
        name: 'get_order_details',
        description: 'Retrieves complete invoice details for a specific order by bill number or order ID within your authorized outlet cluster, including itemized lines, discounts, taxes, and customer details.',
        inputSchema: {
            type: 'object',
            properties: {
                billNumber: {
                    type: 'string',
                    description: "The sale bill/invoice number (e.g. 'BILL_1234' or 'INV-001')"
                },
                orderId: {
                    type: 'number',
                    description: 'The internal numeric order ID'
                }
            }
        }
    },
    {
        name: 'get_customer_insights',
        description: 'Fetches customer relationship metrics including total orders, lifetime expenditure, average order value, recent visits, and outstanding credit balance strictly within your authorized outlet cluster.',
        inputSchema: {
            type: 'object',
            properties: {
                phone: {
                    type: 'string',
                    description: 'Customer mobile phone number'
                },
                name: {
                    type: 'string',
                    description: 'Customer name (if phone number is unknown)'
                }
            }
        }
    }
];
exports.MCP_RESOURCES = [
    {
        uri: 'inventory://catalog',
        name: 'Product Catalog Summary',
        description: 'Real-time overview of active catalog products, prices, and available stock units for authorized outlets.',
        mimeType: 'application/json'
    },
    {
        uri: 'reports://daily_summary',
        name: "Today's Sales & Cashflow Snapshot",
        description: 'Live executive snapshot of today revenue, order count, and payment method totals for authorized outlets.',
        mimeType: 'application/json'
    }
];
exports.MCP_PROMPTS = [
    {
        name: 'retail_analyst',
        description: 'Role instruction for business intelligence, sales analysis, revenue trends, and inventory health auditing for assigned outlets.',
        arguments: [
            {
                name: 'timeframe',
                description: 'Timeframe to analyze (e.g. today, this_week, this_month)',
                required: false
            }
        ]
    },
    {
        name: 'pos_cashier',
        description: 'Role instruction for an automated POS cashier: checks stock, verifies item rates, builds order carts, and creates finalized sales bills for assigned outlets.',
        arguments: []
    }
];
/**
 * Helper to resolve database handle
 */
function resolveDb(dbOrReq) {
    if (!dbOrReq)
        return defaultDb;
    if (dbOrReq.query)
        return dbOrReq;
    if (dbOrReq.propertyDb && dbOrReq.propertyDb.query)
        return dbOrReq.propertyDb;
    return defaultDb;
}
/**
 * 1. Tool Implementation: analyze_sales
 * Strictly restricted to authorized outlet cluster.
 */
async function toolAnalyzeSales(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    const timeframe = args.timeframe || 'today';
    const groupBy = args.groupBy || 'payment_mode';
    // Strict outlet scoping: never allow unrestricted or unauthorized queries
    let effectiveOutletIds = [];
    if (args.outletId !== undefined && args.outletId !== null && args.outletId !== '') {
        const requestedId = Number(args.outletId);
        if (!scope.allowedOutletIds.includes(requestedId)) {
            throw new Error(`Security Access Denied: You requested sales data for Outlet #${requestedId}, but your credentials only grant access to your designated outlet and linked cluster: [${scope.allowedOutletIds.join(', ')}].`);
        }
        effectiveOutletIds = [requestedId];
    }
    else {
        effectiveOutletIds = scope.allowedOutletIds;
    }
    const outletFilter = `AND outlet_id IN (${effectiveOutletIds.join(',')})`;
    let dateCondition = `sale_date >= CURRENT_DATE`;
    let periodName = "Today";
    if (timeframe === 'yesterday') {
        dateCondition = `sale_date >= CURRENT_DATE - INTERVAL '1 day' AND sale_date < CURRENT_DATE`;
        periodName = "Yesterday";
    }
    else if (timeframe === 'this_week' || timeframe === 'last_7_days') {
        dateCondition = `sale_date >= CURRENT_DATE - INTERVAL '7 days'`;
        periodName = "Past 7 Days";
    }
    else if (timeframe === 'this_month') {
        dateCondition = `sale_date >= DATE_TRUNC('month', CURRENT_DATE)`;
        periodName = "This Month";
    }
    else if (timeframe === 'last_month') {
        dateCondition = `sale_date >= DATE_TRUNC('month', CURRENT_DATE - INTERVAL '1 month') AND sale_date < DATE_TRUNC('month', CURRENT_DATE)`;
        periodName = "Last Month";
    }
    else if (timeframe === 'custom' && args.startDate) {
        const start = args.startDate;
        const end = args.endDate || args.startDate;
        dateCondition = `sale_date >= '${start} 00:00:00' AND sale_date <= '${end} 23:59:59'`;
        periodName = `${start} to ${end}`;
    }
    // Overall summary query
    const summarySql = `
        SELECT 
            COUNT(*) as total_orders,
            COALESCE(SUM(net_amount), 0) as total_revenue,
            COALESCE(SUM(sub_total), 0) as gross_subtotal,
            COALESCE(SUM(total_discount), 0) as total_discounts,
            COALESCE(AVG(net_amount), 0) as avg_order_value,
            COALESCE(SUM(total_qty), 0) as total_units_sold
        FROM sales_headers
        WHERE ${dateCondition} ${outletFilter} AND (is_deleted IS NULL OR is_deleted = FALSE)
    `;
    // Payment modes query
    const paymentSql = `
        SELECT 
            COALESCE(payment_mode, 'UNSPECIFIED') as mode,
            COUNT(*) as order_count,
            COALESCE(SUM(net_amount), 0) as total_amount
        FROM sales_headers
        WHERE ${dateCondition} ${outletFilter} AND (is_deleted IS NULL OR is_deleted = FALSE)
        GROUP BY payment_mode
        ORDER BY total_amount DESC
    `;
    // Top selling items query
    const topItemsSql = `
        SELECT 
            si.item_name,
            COALESCE(si.item_code, '') as item_code,
            COALESCE(SUM(si.qty), 0) as total_qty,
            COALESCE(SUM(si.net_amount), 0) as total_amount
        FROM sales_items si
        JOIN sales_headers sh ON si.sale_id = sh.id
        WHERE ${dateCondition.replace(/sale_date/g, 'sh.sale_date')} 
          ${outletFilter.replace(/outlet_id/g, 'sh.outlet_id')}
          AND (sh.is_deleted IS NULL OR sh.is_deleted = FALSE)
        GROUP BY si.item_name, si.item_code
        ORDER BY total_qty DESC
        LIMIT 5
    `;
    let summaryRow = {};
    let paymentRows = [];
    let topItemsRows = [];
    if (rawDb) {
        try {
            const sRes = await rawDb.query(summarySql);
            summaryRow = sRes[0]?.[0] || {};
            const pRes = await rawDb.query(paymentSql);
            paymentRows = pRes[0] || [];
            const tRes = await rawDb.query(topItemsSql);
            topItemsRows = tRes[0] || [];
        }
        catch (dbErr) {
            console.error('[MCP ANALYZE SALES DB ERROR]:', dbErr.message);
        }
    }
    const totalOrders = Number(summaryRow.total_orders || 0);
    const totalRevenue = Number(summaryRow.total_revenue || 0);
    const totalDiscounts = Number(summaryRow.total_discounts || 0);
    const avgOrderValue = Math.round(Number(summaryRow.avg_order_value || 0) * 100) / 100;
    const totalUnits = Number(summaryRow.total_units_sold || 0);
    const paymentBreakdown = paymentRows.map((p) => ({
        mode: p.mode,
        count: Number(p.order_count || 0),
        amount: Number(p.total_amount || 0),
        percent: totalRevenue > 0 ? Math.round((Number(p.total_amount || 0) / totalRevenue) * 100) : 0
    }));
    const topItems = topItemsRows.map((it) => ({
        name: it.item_name,
        code: it.item_code,
        quantity: Number(it.total_qty || 0),
        revenue: Number(it.total_amount || 0)
    }));
    const scopeLabel = effectiveOutletIds.length === 1
        ? `Outlet #${effectiveOutletIds[0]}`
        : `Linked Cluster [${effectiveOutletIds.map(id => `#${id}`).join(', ')}]`;
    const topItemSummary = topItems.length > 0
        ? topItems.map((i, idx) => `${idx + 1}. ${i.name} (${i.quantity} units, ₹${i.revenue.toFixed(2)})`).join('\n')
        : 'No line item details recorded for this period.';
    const paymentSummary = paymentBreakdown.length > 0
        ? paymentBreakdown.map(p => `• ${p.mode}: ₹${p.amount.toFixed(2)} (${p.percent}%, ${p.count} bills)`).join('\n')
        : 'No payments recorded.';
    const narrative = `📊 SALES REPORT [${periodName.toUpperCase()} - ${scopeLabel}]
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Total Revenue: ₹${totalRevenue.toFixed(2)}
• Total Orders: ${totalOrders}
• Average Bill Value: ₹${avgOrderValue.toFixed(2)}
• Total Units Sold: ${totalUnits}
• Total Discounts Given: ₹${totalDiscounts.toFixed(2)}
• Scoped Outlets: ${scopeLabel}

💳 PAYMENT BREAKDOWN:
${paymentSummary}

🏆 TOP PERFORMING ITEMS:
${topItemSummary}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━`;
    return {
        period: periodName,
        timeframe,
        scopedOutlets: effectiveOutletIds,
        isMultiOutletCluster: effectiveOutletIds.length > 1,
        totalRevenue,
        totalOrders,
        averageOrderValue: avgOrderValue,
        totalUnitsSold: totalUnits,
        totalDiscounts,
        paymentBreakdown,
        topItems,
        narrative
    };
}
/**
 * 2. Tool Implementation: create_order_bill
 * Strictly creates bill on authorized target outlet only.
 */
async function toolCreateOrderBill(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    // Validate target outlet against authorized linked outlets
    let targetOutlet = scope.primaryOutletId;
    if (args.outletId !== undefined && args.outletId !== null && args.outletId !== '') {
        const requestedId = Number(args.outletId);
        if (!scope.allowedOutletIds.includes(requestedId)) {
            throw new Error(`Security Access Denied: Cannot create bill for Outlet #${requestedId}. Your credentials are strictly limited to your designated outlet and linked cluster: [${scope.allowedOutletIds.join(', ')}].`);
        }
        targetOutlet = requestedId;
    }
    const customerName = (args.customerName || 'Walk-in Customer').trim();
    const customerPhone = (args.customerPhone || '').trim();
    const paymentMode = (args.paymentMode || 'CASH').toUpperCase();
    const discountAmount = Number(args.discountAmount || 0);
    const notes = (args.notes || 'Created via MCP AI Tool (ChatGPT/Gemini)').trim();
    const inputItems = Array.isArray(args.items) ? args.items : [];
    if (inputItems.length === 0) {
        throw new Error('At least one item is required to create a bill.');
    }
    // Generate unique sequential / timestamped sale number
    const billTimestamp = Date.now().toString().slice(-6);
    const saleNo = `AI-BILL-${billTimestamp}`;
    const saleDate = new Date();
    // Process line items & match catalog if needed (strictly scoped to linked outlets)
    const processedItems = [];
    let grossSubTotal = 0;
    let totalQty = 0;
    for (const item of inputItems) {
        const qty = Number(item.quantity || 1);
        if (qty <= 0)
            continue;
        let unitPrice = Number(item.unitPrice || 0);
        let itemName = (item.name || 'Product').trim();
        let itemCode = (item.itemCode || '').trim();
        let barcode = (item.barcode || '').trim();
        let unit = 'PCS';
        let matchedItemId = Number(item.itemId || 0);
        // Try catalog lookup within authorized outlets
        if (rawDb && (unitPrice === 0 || matchedItemId === 0)) {
            try {
                let matchQuery = '';
                let matchBind = [];
                if (barcode) {
                    matchQuery = `SELECT id, item_code, item_name, rate, unit FROM item_master WHERE barcode = $1 AND outlet_id IN (${scope.allowedOutletIds.join(',')}) ORDER BY CASE WHEN outlet_id = ${targetOutlet} THEN 1 ELSE 2 END LIMIT 1`;
                    matchBind = [barcode];
                }
                else if (itemCode) {
                    matchQuery = `SELECT id, item_code, item_name, rate, unit FROM item_master WHERE item_code = $1 AND outlet_id IN (${scope.allowedOutletIds.join(',')}) ORDER BY CASE WHEN outlet_id = ${targetOutlet} THEN 1 ELSE 2 END LIMIT 1`;
                    matchBind = [itemCode];
                }
                else if (itemName) {
                    matchQuery = `SELECT id, item_code, item_name, rate, unit FROM item_master WHERE item_name ILIKE $1 AND outlet_id IN (${scope.allowedOutletIds.join(',')}) ORDER BY CASE WHEN outlet_id = ${targetOutlet} THEN 1 ELSE 2 END, LENGTH(item_name) ASC LIMIT 1`;
                    matchBind = [`%${itemName}%`];
                }
                if (matchQuery) {
                    const matchRes = await rawDb.query(matchQuery, { bind: matchBind });
                    if (matchRes[0] && matchRes[0].length > 0) {
                        const found = matchRes[0][0];
                        matchedItemId = Number(found.id);
                        itemName = found.item_name || itemName;
                        itemCode = found.item_code || itemCode;
                        unit = found.unit || unit;
                        if (unitPrice === 0) {
                            unitPrice = Number(found.rate || 0);
                        }
                    }
                }
            }
            catch (err) {
                console.warn('[MCP CATALOG LOOKUP WARNING]:', err.message);
            }
        }
        const lineTotal = Math.round(qty * unitPrice * 100) / 100;
        grossSubTotal += lineTotal;
        totalQty += qty;
        processedItems.push({
            itemId: matchedItemId || 1,
            itemName,
            itemCode: itemCode || 'ITEM_AI',
            barcode,
            unit,
            quantity: qty,
            unitPrice,
            lineTotal
        });
    }
    const netAmount = Math.max(0, grossSubTotal - discountAmount);
    let createdSaleId = 0;
    if (rawDb) {
        // Insert Header strictly with authorized targetOutlet
        const insertHeaderSql = `
            INSERT INTO sales_headers (
                outlet_id, sale_no, sale_date, customer_name, customer_phone,
                payment_mode, total_qty, sub_total, total_discount, net_amount,
                status, sale_source, notes, is_latest, is_deleted, created_at, updated_at
            ) VALUES (
                $1, $2, CURRENT_TIMESTAMP, $3, $4,
                $5, $6, $7, $8, $9,
                'COMPLETED', 'AI_MCP', $10, TRUE, FALSE, CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
            ) RETURNING id
        `;
        const headerRes = await rawDb.query(insertHeaderSql, {
            bind: [
                targetOutlet,
                saleNo,
                customerName,
                customerPhone,
                paymentMode,
                totalQty,
                grossSubTotal,
                discountAmount,
                netAmount,
                notes
            ]
        });
        createdSaleId = Number(headerRes[0]?.[0]?.id || 0);
        // Insert Line Items
        for (const it of processedItems) {
            const insertItemSql = `
                INSERT INTO sales_items (
                    sale_id, item_id, item_code, item_name, barcode, unit,
                    qty, rate, amount, taxable_amount, net_amount, created_at
                ) VALUES (
                    $1, $2, $3, $4, $5, $6,
                    $7, $8, $9, $10, $11, CURRENT_TIMESTAMP
                )
            `;
            await rawDb.query(insertItemSql, {
                bind: [
                    createdSaleId,
                    it.itemId,
                    it.itemCode,
                    it.itemName,
                    it.barcode,
                    it.unit,
                    it.quantity,
                    it.unitPrice,
                    it.lineTotal,
                    it.lineTotal,
                    it.lineTotal
                ]
            });
            // Update item stock strictly on targetOutlet
            if (it.itemId > 1) {
                try {
                    await rawDb.query(`UPDATE item_master SET opening_balance = COALESCE(opening_balance, 0) - $1 WHERE id = $2 AND outlet_id = $3`, { bind: [it.quantity, it.itemId, targetOutlet] });
                }
                catch (_) { }
            }
        }
    }
    // Format clean ASCII receipt
    const itemsTable = processedItems.map(it => {
        return `${it.itemName.padEnd(20).slice(0, 20)} ${String(it.quantity).padStart(3)} x ₹${it.unitPrice.toFixed(2).padStart(7)} = ₹${it.lineTotal.toFixed(2).padStart(8)}`;
    }).join('\n');
    const formattedReceipt = `🧾 ══════════════════════════════════════════
          FAMALTH LYNX RETAIL POS          
             AI ORDER & TAX INVOICE        
══════════════════════════════════════════
Invoice No : ${saleNo}
Date & Time: ${saleDate.toLocaleString()}
Customer   : ${customerName} ${customerPhone ? `(${customerPhone})` : ''}
Payment    : ${paymentMode}
Outlet     : #${targetOutlet} (${scope.primaryOutletName || 'Store'})
Security   : Verified Linked Outlet Cluster
──────────────────────────────────────────
ITEM DESCRIPTION     QTY     RATE     TOTAL
──────────────────────────────────────────
${itemsTable}
──────────────────────────────────────────
Subtotal (${totalQty} items)        : ₹${grossSubTotal.toFixed(2)}
Discount Applied           : ₹${discountAmount.toFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
GRAND TOTAL (NET PAYABLE)  : ₹${netAmount.toFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Notes: ${notes}
   Thank you for your business! Have a great day!
══════════════════════════════════════════`;
    return {
        success: true,
        orderId: createdSaleId,
        billNumber: saleNo,
        outletId: targetOutlet,
        authorizedCluster: scope.allowedOutletIds,
        saleDate: saleDate.toISOString(),
        customer: {
            name: customerName,
            phone: customerPhone
        },
        paymentMode,
        totalItems: processedItems.length,
        totalQuantity: totalQty,
        subTotal: grossSubTotal,
        discount: discountAmount,
        grandTotal: netAmount,
        status: 'COMPLETED',
        items: processedItems,
        formattedReceipt
    };
}
/**
 * 3. Tool Implementation: get_inventory_status
 * Strictly restricted to authorized outlet cluster.
 */
async function toolGetInventoryStatus(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    const filter = args.filter || 'all';
    const threshold = Number(args.threshold || 10);
    const limit = Math.min(Number(args.limit || 50), 200);
    const search = (args.search || '').trim();
    // Determine target outlets
    let targetIds = scope.allowedOutletIds;
    if (args.outletId !== undefined && args.outletId !== null && args.outletId !== '') {
        const reqId = Number(args.outletId);
        if (!scope.allowedOutletIds.includes(reqId)) {
            throw new Error(`Security Access Denied: Outlet #${reqId} is outside your authorized cluster [${scope.allowedOutletIds.join(', ')}].`);
        }
        targetIds = [reqId];
    }
    let whereClause = `is_active = TRUE AND outlet_id IN (${targetIds.join(',')})`;
    const binds = [];
    if (filter === 'low_stock') {
        binds.push(threshold);
        whereClause += ` AND COALESCE(opening_balance, 0) <= $${binds.length} AND COALESCE(opening_balance, 0) > 0`;
    }
    else if (filter === 'out_of_stock') {
        whereClause += ` AND COALESCE(opening_balance, 0) <= 0`;
    }
    if (search) {
        binds.push(`%${search}%`);
        whereClause += ` AND (item_name ILIKE $${binds.length} OR item_code ILIKE $${binds.length} OR barcode ILIKE $${binds.length})`;
    }
    const itemsSql = `
        SELECT id, item_code, item_name, barcode, item_group, sub_category, unit, rate, opening_balance, outlet_id
        FROM item_master
        WHERE ${whereClause}
        ORDER BY opening_balance ASC, item_name ASC
        LIMIT ${limit}
    `;
    // Overview statistics for authorized outlets only
    const statsSql = `
        SELECT 
            COUNT(*) as total_items,
            COUNT(*) FILTER (WHERE COALESCE(opening_balance, 0) <= ${threshold} AND COALESCE(opening_balance, 0) > 0) as low_stock_count,
            COUNT(*) FILTER (WHERE COALESCE(opening_balance, 0) <= 0) as out_of_stock_count,
            COALESCE(SUM(COALESCE(opening_balance, 0) * COALESCE(rate, 0)), 0) as total_valuation
        FROM item_master
        WHERE is_active = TRUE AND outlet_id IN (${targetIds.join(',')})
    `;
    let items = [];
    let stats = {};
    if (rawDb) {
        try {
            const itemRes = await rawDb.query(itemsSql, { bind: binds });
            items = itemRes[0] || [];
            const statsRes = await rawDb.query(statsSql);
            stats = statsRes[0]?.[0] || {};
        }
        catch (err) {
            console.error('[MCP INVENTORY DB ERROR]:', err.message);
        }
    }
    const totalItems = Number(stats.total_items || items.length);
    const lowStockCount = Number(stats.low_stock_count || 0);
    const outOfStockCount = Number(stats.out_of_stock_count || 0);
    const totalValuation = Number(stats.total_valuation || 0);
    const mappedItems = items.map((it) => ({
        id: it.id,
        outletId: it.outlet_id,
        code: it.item_code,
        name: it.item_name,
        barcode: it.barcode || '',
        category: it.item_group || it.sub_category || 'General',
        unit: it.unit || 'PCS',
        sellingPrice: Number(it.rate || 0),
        currentStock: Number(it.opening_balance || 0),
        status: Number(it.opening_balance || 0) <= 0 ? 'OUT_OF_STOCK' : (Number(it.opening_balance || 0) <= threshold ? 'LOW_STOCK' : 'IN_STOCK')
    }));
    const summaryText = `📦 INVENTORY HEALTH SNAPSHOT (Outlets: ${targetIds.map(i => `#${i}`).join(', ')})
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
• Total Active Catalog SKUs: ${totalItems}
• Low Stock Alert (<= ${threshold} units): ${lowStockCount} items
• Out of Stock (0 stock): ${outOfStockCount} items
• Total Inventory Value: ₹${totalValuation.toFixed(2)}
━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━
Showing ${mappedItems.length} items (Filter: ${filter}):
${mappedItems.slice(0, 10).map(i => `• [${i.status}] ${i.name} — Stock: ${i.currentStock} ${i.unit} (Price: ₹${i.sellingPrice}, Outlet #${i.outletId})`).join('\n')}${mappedItems.length > 10 ? `\n...and ${mappedItems.length - 10} more items.` : ''}`;
    return {
        scopedOutlets: targetIds,
        summary: {
            totalItems,
            lowStockCount,
            outOfStockCount,
            totalValuation
        },
        count: mappedItems.length,
        items: mappedItems,
        narrative: summaryText
    };
}
/**
 * 4. Tool Implementation: search_products
 * Strictly restricted to authorized outlet cluster.
 */
async function toolSearchProducts(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    const query = (args.query || '').trim();
    const limit = Math.min(Number(args.limit || 20), 50);
    if (!query) {
        throw new Error('Search query is required.');
    }
    let targetIds = scope.allowedOutletIds;
    if (args.outletId !== undefined && args.outletId !== null && args.outletId !== '') {
        const reqId = Number(args.outletId);
        if (!scope.allowedOutletIds.includes(reqId)) {
            throw new Error(`Security Access Denied: Outlet #${reqId} is outside your authorized cluster [${scope.allowedOutletIds.join(', ')}].`);
        }
        targetIds = [reqId];
    }
    const searchSql = `
        SELECT id, item_code, item_name, barcode, item_group, sub_category, unit, rate, opening_balance, outlet_id
        FROM item_master
        WHERE is_active = TRUE
          AND outlet_id IN (${targetIds.join(',')})
          AND (item_name ILIKE $1 OR item_code ILIKE $1 OR barcode ILIKE $1 OR item_group ILIKE $1)
        ORDER BY 
          CASE WHEN item_name ILIKE $1 THEN 1 ELSE 2 END,
          item_name ASC
        LIMIT ${limit}
    `;
    let rows = [];
    if (rawDb) {
        try {
            const res = await rawDb.query(searchSql, { bind: [`%${query}%`] });
            rows = res[0] || [];
        }
        catch (err) {
            console.error('[MCP SEARCH PRODUCTS ERROR]:', err.message);
        }
    }
    const results = rows.map((r) => ({
        id: r.id,
        outletId: r.outlet_id,
        code: r.item_code,
        name: r.item_name,
        barcode: r.barcode || '',
        category: r.item_group || r.sub_category || 'General',
        unit: r.unit || 'PCS',
        sellingPrice: Number(r.rate || 0),
        availableStock: Number(r.opening_balance || 0)
    }));
    const textOutput = results.length > 0
        ? results.map(r => `• ID #${r.id} | ${r.name} (${r.code}) | ₹${r.sellingPrice.toFixed(2)} / ${r.unit} | In Stock: ${r.availableStock} (Outlet #${r.outletId})`).join('\n')
        : `No products found matching '${query}' in authorized outlets [${targetIds.join(', ')}].`;
    return {
        query,
        scopedOutlets: targetIds,
        count: results.length,
        products: results,
        formattedList: textOutput
    };
}
/**
 * 5. Tool Implementation: get_order_details
 * Strictly restricted to authorized outlet cluster.
 */
async function toolGetOrderDetails(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    const billNumber = args.billNumber;
    const orderId = Number(args.orderId);
    if (!billNumber && !orderId) {
        throw new Error('Either billNumber or orderId must be provided.');
    }
    let querySql = `SELECT * FROM sales_headers WHERE `;
    const binds = [];
    if (billNumber) {
        binds.push(billNumber);
        querySql += `sale_no = $1`;
    }
    else {
        binds.push(orderId);
        querySql += `id = $1`;
    }
    querySql += ` AND outlet_id IN (${scope.allowedOutletIds.join(',')})`;
    let header = null;
    let items = [];
    if (rawDb) {
        const headerRes = await rawDb.query(querySql, { bind: binds });
        if (headerRes[0] && headerRes[0].length > 0) {
            header = headerRes[0][0];
            const itemsRes = await rawDb.query(`SELECT * FROM sales_items WHERE sale_id = $1 ORDER BY id ASC`, { bind: [header.id] });
            items = itemsRes[0] || [];
        }
    }
    if (!header) {
        throw new Error(`Order not found or not accessible within your authorized outlets [${scope.allowedOutletIds.join(', ')}].`);
    }
    return {
        orderId: header.id,
        billNumber: header.sale_no,
        outletId: header.outlet_id,
        date: header.sale_date,
        customerName: header.customer_name || 'Walk-in',
        customerPhone: header.customer_phone || '',
        paymentMode: header.payment_mode,
        totalQuantity: Number(header.total_qty || 0),
        subTotal: Number(header.sub_total || 0),
        discount: Number(header.total_discount || 0),
        grandTotal: Number(header.net_amount || 0),
        status: header.status,
        notes: header.notes,
        items: items.map((it) => ({
            itemId: it.item_id,
            name: it.item_name,
            code: it.item_code,
            quantity: Number(it.qty || 0),
            unitPrice: Number(it.rate || 0),
            totalPrice: Number(it.net_amount || 0)
        }))
    };
}
/**
 * 6. Tool Implementation: get_customer_insights
 * Strictly restricted to authorized outlet cluster.
 */
async function toolGetCustomerInsights(db, outletContext = 1, args = {}) {
    const rawDb = resolveDb(db);
    const scope = normalizeOutletScope(outletContext);
    const phone = (args.phone || '').trim();
    const name = (args.name || '').trim();
    if (!phone && !name) {
        throw new Error('Please provide customer phone number or customer name.');
    }
    let whereClause = phone ? `customer_phone = $1` : `customer_name ILIKE $1`;
    const bindVal = phone ? phone : `%${name}%`;
    const summarySql = `
        SELECT 
            COUNT(*) as visit_count,
            COALESCE(SUM(net_amount), 0) as lifetime_spend,
            COALESCE(AVG(net_amount), 0) as avg_bill_value,
            MAX(sale_date) as last_visit,
            customer_name,
            customer_phone
        FROM sales_headers
        WHERE ${whereClause} 
          AND outlet_id IN (${scope.allowedOutletIds.join(',')})
          AND (is_deleted IS NULL OR is_deleted = FALSE)
        GROUP BY customer_name, customer_phone
        ORDER BY visit_count DESC
        LIMIT 1
    `;
    let customerRow = null;
    let recentOrders = [];
    if (rawDb) {
        try {
            const res = await rawDb.query(summarySql, { bind: [bindVal] });
            if (res[0] && res[0].length > 0) {
                customerRow = res[0][0];
                const ordersRes = await rawDb.query(`SELECT id, sale_no, sale_date, net_amount, payment_mode, outlet_id 
                     FROM sales_headers 
                     WHERE ${whereClause} AND outlet_id IN (${scope.allowedOutletIds.join(',')})
                     ORDER BY sale_date DESC LIMIT 5`, { bind: [bindVal] });
                recentOrders = ordersRes[0] || [];
            }
        }
        catch (err) {
            console.error('[MCP CUSTOMER INSIGHTS ERROR]:', err.message);
        }
    }
    if (!customerRow) {
        return {
            found: false,
            scopedOutlets: scope.allowedOutletIds,
            message: `No purchase records found for customer '${phone || name}' within authorized outlets [${scope.allowedOutletIds.join(', ')}].`
        };
    }
    return {
        found: true,
        scopedOutlets: scope.allowedOutletIds,
        customerName: customerRow.customer_name,
        customerPhone: customerRow.customer_phone,
        totalVisits: Number(customerRow.visit_count || 0),
        lifetimeSpend: Number(customerRow.lifetime_spend || 0),
        averageSpendPerVisit: Math.round(Number(customerRow.avg_bill_value || 0) * 100) / 100,
        lastVisitDate: customerRow.last_visit,
        recentOrders: recentOrders.map((o) => ({
            billNo: o.sale_no,
            outletId: o.outlet_id,
            date: o.sale_date,
            amount: Number(o.net_amount || 0),
            paymentMode: o.payment_mode
        }))
    };
}
/**
 * Unified Tool Dispatcher with Strict Outlet Scoping
 */
async function executeTool(db, outletContext = 1, toolName, args = {}) {
    switch (toolName) {
        case 'analyze_sales':
            return await toolAnalyzeSales(db, outletContext, args);
        case 'create_order_bill':
            return await toolCreateOrderBill(db, outletContext, args);
        case 'get_inventory_status':
            return await toolGetInventoryStatus(db, outletContext, args);
        case 'search_products':
            return await toolSearchProducts(db, outletContext, args);
        case 'get_order_details':
            return await toolGetOrderDetails(db, outletContext, args);
        case 'get_customer_insights':
            return await toolGetCustomerInsights(db, outletContext, args);
        default:
            throw new Error(`Unknown MCP Tool: '${toolName}'. Available tools: ${exports.MCP_TOOLS.map(t => t.name).join(', ')}`);
    }
}
/**
 * Standard MCP JSON-RPC 2.0 Protocol Handler with Multi-Tenant Enforcement
 */
async function handleJsonRpc(db, outletContext = 1, request) {
    const { jsonrpc, id, method, params } = request;
    if (jsonrpc !== '2.0') {
        return {
            jsonrpc: '2.0',
            id: id || null,
            error: { code: -32600, message: 'Invalid Request: jsonrpc must be "2.0"' }
        };
    }
    const scope = normalizeOutletScope(outletContext);
    switch (method) {
        case 'initialize':
            return {
                jsonrpc: '2.0',
                id,
                result: {
                    protocolVersion: '2024-11-05',
                    capabilities: {
                        tools: { listChanged: true },
                        resources: { subscribe: false, listChanged: true },
                        prompts: { listChanged: true }
                    },
                    serverInfo: {
                        name: 'famalth-lynx-mcp-server',
                        version: '2.0.0-ENTERPRISE',
                        description: `Model Context Protocol server for Famalth Lynx POS (Outlet #${scope.primaryOutletId}: ${scope.primaryOutletName}, Linked: [${scope.allowedOutletIds.join(', ')}])`
                    }
                }
            };
        case 'ping':
            return { jsonrpc: '2.0', id, result: {} };
        case 'tools/list':
            return {
                jsonrpc: '2.0',
                id,
                result: {
                    tools: exports.MCP_TOOLS
                }
            };
        case 'tools/call': {
            const toolName = params?.name;
            const args = params?.arguments || {};
            try {
                const result = await executeTool(db, scope, toolName, args);
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        content: [
                            {
                                type: 'text',
                                text: typeof result === 'string' ? result : JSON.stringify(result, null, 2)
                            }
                        ]
                    }
                };
            }
            catch (toolErr) {
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        isError: true,
                        content: [
                            {
                                type: 'text',
                                text: `Error executing tool '${toolName}': ${toolErr.message}`
                            }
                        ]
                    }
                };
            }
        }
        case 'resources/list':
            return {
                jsonrpc: '2.0',
                id,
                result: {
                    resources: exports.MCP_RESOURCES
                }
            };
        case 'resources/read': {
            const uri = params?.uri;
            if (uri === 'inventory://catalog') {
                const data = await toolGetInventoryStatus(db, scope, { filter: 'all', limit: 100 });
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        contents: [
                            {
                                uri,
                                mimeType: 'application/json',
                                text: JSON.stringify(data, null, 2)
                            }
                        ]
                    }
                };
            }
            else if (uri === 'reports://daily_summary') {
                const data = await toolAnalyzeSales(db, scope, { timeframe: 'today' });
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        contents: [
                            {
                                uri,
                                mimeType: 'application/json',
                                text: JSON.stringify(data, null, 2)
                            }
                        ]
                    }
                };
            }
            return {
                jsonrpc: '2.0',
                id,
                error: { code: -32602, message: `Resource not found: ${uri}` }
            };
        }
        case 'prompts/list':
            return {
                jsonrpc: '2.0',
                id,
                result: {
                    prompts: exports.MCP_PROMPTS
                }
            };
        case 'prompts/get': {
            const promptName = params?.name;
            if (promptName === 'retail_analyst') {
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        description: `Retail Business Analyst Persona (Authorized Outlets: ${scope.allowedOutletIds.join(', ')})`,
                        messages: [
                            {
                                role: 'user',
                                content: {
                                    type: 'text',
                                    text: `You are an expert retail analyst for outlet #${scope.primaryOutletId} (${scope.primaryOutletName}) and its linked branches [${scope.allowedOutletIds.join(', ')}]. Always use \`analyze_sales\` to examine sales and provide actionable summaries with revenue, top-selling items, and margin recommendations.`
                                }
                            }
                        ]
                    }
                };
            }
            else if (promptName === 'pos_cashier') {
                return {
                    jsonrpc: '2.0',
                    id,
                    result: {
                        description: `Smart POS Cashier Persona (Outlet #${scope.primaryOutletId})`,
                        messages: [
                            {
                                role: 'user',
                                content: {
                                    type: 'text',
                                    text: `You are an automated POS cashier for outlet #${scope.primaryOutletId}. When creating an order, first check stock with \`search_products\`, then issue the bill using \`create_order_bill\` and show the formatted receipt.`
                                }
                            }
                        ]
                    }
                };
            }
            return {
                jsonrpc: '2.0',
                id,
                error: { code: -32602, message: `Prompt not found: ${promptName}` }
            };
        }
        default:
            return {
                jsonrpc: '2.0',
                id,
                error: { code: -32601, message: `Method not found: ${method}` }
            };
    }
}
/**
 * Generate ChatGPT Custom GPT Action OpenAPI 3.0.1 Specification
 */
function getChatGptOpenApiSpec(baseUrl) {
    return {
        openapi: '3.0.1',
        info: {
            title: 'FAMALTH LYNX POS & Retail ERP - AI Agent Gateway',
            description: 'Action OpenAPI Specification enabling ChatGPT Custom GPTs to perform deep retail data analysis, stock inquiries, product search, and live sales order/billing invoice creation with strict outlet tenant isolation.',
            version: '2.0.0'
        },
        servers: [
            {
                url: baseUrl,
                description: 'Famalth Lynx Store Server'
            }
        ],
        paths: {
            '/api/v1/developer/mcp/tools/execute': {
                post: {
                    operationId: 'executeMcpTool',
                    summary: 'Execute any retail business tool (Sales Analysis, Bill Creation, Inventory Check)',
                    description: 'Unified action endpoint for AI models to invoke analyze_sales, create_order_bill, get_inventory_status, search_products, get_order_details, or get_customer_insights.',
                    requestBody: {
                        required: true,
                        content: {
                            'application/json': {
                                schema: {
                                    type: 'object',
                                    required: ['tool', 'arguments'],
                                    properties: {
                                        tool: {
                                            type: 'string',
                                            enum: ['analyze_sales', 'create_order_bill', 'get_inventory_status', 'search_products', 'get_order_details', 'get_customer_insights'],
                                            description: 'Name of the tool to execute'
                                        },
                                        arguments: {
                                            type: 'object',
                                            description: 'Tool input parameters'
                                        }
                                    }
                                }
                            }
                        }
                    },
                    responses: {
                        '200': {
                            description: 'Tool executed successfully',
                            content: {
                                'application/json': {
                                    schema: {
                                        type: 'object',
                                        properties: {
                                            success: { type: 'boolean' },
                                            tool: { type: 'string' },
                                            result: { type: 'object' }
                                        }
                                    }
                                }
                            }
                        }
                    }
                }
            },
            '/api/v1/developer/mcp/tools/analyze-sales': {
                post: {
                    operationId: 'analyzeSales',
                    summary: 'Analyze Store Revenue & Sales Performance',
                    description: 'Get deep revenue analytics, payment method breakdowns, top 5 selling items, and order volume for today, yesterday, this week, or custom date range.',
                    requestBody: {
                        content: {
                            'application/json': {
                                schema: exports.MCP_TOOLS.find(t => t.name === 'analyze_sales')?.inputSchema
                            }
                        }
                    },
                    responses: {
                        '200': { description: 'Sales analytics report' }
                    }
                }
            },
            '/api/v1/developer/mcp/tools/create-order-bill': {
                post: {
                    operationId: 'createOrderBill',
                    summary: 'Create POS Order & Generate Bill/Invoice',
                    description: 'Issue a live retail sales bill directly in the POS with item lines, customer info, payment method, tax, and discount. Returns generated bill number and printable receipt text.',
                    requestBody: {
                        required: true,
                        content: {
                            'application/json': {
                                schema: exports.MCP_TOOLS.find(t => t.name === 'create_order_bill')?.inputSchema
                            }
                        }
                    },
                    responses: {
                        '200': { description: 'Invoice created successfully' }
                    }
                }
            },
            '/api/v1/developer/mcp/tools/inventory-status': {
                post: {
                    operationId: 'getInventoryStatus',
                    summary: 'Check Stock Levels & Low Stock Alerts',
                    description: 'Query store inventory valuation, low stock warnings, and out-of-stock products.',
                    requestBody: {
                        content: {
                            'application/json': {
                                schema: exports.MCP_TOOLS.find(t => t.name === 'get_inventory_status')?.inputSchema
                            }
                        }
                    },
                    responses: {
                        '200': { description: 'Inventory stock report' }
                    }
                }
            },
            '/api/v1/developer/mcp/tools/search-products': {
                post: {
                    operationId: 'searchProducts',
                    summary: 'Search Products & Catalog Pricing',
                    description: 'Search catalog items by name, barcode, or code to check unit price and live stock before billing.',
                    requestBody: {
                        required: true,
                        content: {
                            'application/json': {
                                schema: exports.MCP_TOOLS.find(t => t.name === 'search_products')?.inputSchema
                            }
                        }
                    },
                    responses: {
                        '200': { description: 'Matching products list' }
                    }
                }
            }
        },
        components: {
            securitySchemes: {
                ApiKeyAuth: {
                    type: 'apiKey',
                    in: 'header',
                    name: 'X-API-Key'
                }
            }
        },
        security: [
            {
                ApiKeyAuth: []
            }
        ]
    };
}
/**
 * Generate Google Gemini Function Declarations Spec
 */
function getGeminiToolsSpec() {
    return {
        tools: [
            {
                function_declarations: exports.MCP_TOOLS.map(t => ({
                    name: t.name,
                    description: t.description,
                    parameters: t.inputSchema
                }))
            }
        ]
    };
}
/**
 * Generate Claude Desktop / Cursor mcpServers JSON snippet
 */
function getClaudeConfigSnippet(baseUrl, apiKey = 'YOUR_API_KEY_HERE') {
    return {
        mcpServers: {
            'famalth-lynx': {
                command: 'node',
                args: ['backend/mcp/server.js'],
                env: {
                    LYNX_API_URL: baseUrl,
                    LYNX_API_KEY: apiKey
                }
            }
        }
    };
}
module.exports = {
    MCP_TOOLS: exports.MCP_TOOLS,
    MCP_RESOURCES: exports.MCP_RESOURCES,
    MCP_PROMPTS: exports.MCP_PROMPTS,
    normalizeOutletScope,
    toolAnalyzeSales,
    toolCreateOrderBill,
    toolGetInventoryStatus,
    toolSearchProducts,
    toolGetOrderDetails,
    toolGetCustomerInsights,
    executeTool,
    handleJsonRpc,
    getChatGptOpenApiSpec,
    getGeminiToolsSpec,
    getClaudeConfigSnippet
};
exports.default = module.exports;
