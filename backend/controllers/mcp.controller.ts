/**
 * FAMALTH LYNX - MCP & AI Gateway Controller
 * Handles JSON-RPC 2.0, SSE Transport, ChatGPT OpenAPI specs, and Gemini Tool calls
 * with strict particular outlet & linked outlet cluster security.
 */

const mcpService = require('../services/mcp.service');
const defaultDb = require('../db/models');

function getDb(req: any) {
    return req.propertyDb || defaultDb;
}

export interface McpOutletContext {
    primaryOutletId: number;
    primaryOutletName: string;
    isMaster: boolean;
    allowedOutletIds: number[];
    linkedOutlets: { id: number; code: string; name: string; role: string }[];
    authMethod: string;
    keyName?: string;
}

/**
 * Resolves caller identity, primary outlet ID, and the authorized linked outlets cluster.
 * Ensures an AI model can ONLY access its designated outlet and linked branches, NEVER all outlets.
 */
export async function resolveMcpOutletContext(db: any, req: any): Promise<McpOutletContext> {
    const rawDb = db?.query ? db : (req.propertyDb || defaultDb);
    let sessionOutletId = 0;
    let authMethod = 'ANONYMOUS';
    let keyName = '';

    // Check 1: X-API-Key Header or Query Param
    const apiKeyHeader = req.headers['x-api-key'] || req.query.api_key;
    if (apiKeyHeader) {
        authMethod = 'API_KEY';
        try {
            const keyRows = await rawDb.query(
                `SELECT outlet_id, key_name, is_active FROM developer_api_keys WHERE api_key = $1`,
                { bind: [String(apiKeyHeader).trim()] }
            );
            if (keyRows[0] && keyRows[0].length > 0) {
                const k = keyRows[0][0];
                if (!k.is_active) {
                    throw new Error('API Key has been revoked or deactivated.');
                }
                sessionOutletId = Number(k.outlet_id) || 0;
                keyName = k.key_name || 'API Key Client';
            }
        } catch (e: any) {
            console.warn('[MCP OUTLET RESOLVE KEY ERROR]:', e.message);
        }
    }

    // Check 2: Bearer Token
    if (!sessionOutletId) {
        const authHeader = req.headers['authorization'];
        if (authHeader && authHeader.startsWith('Bearer ')) {
            authMethod = 'BEARER_TOKEN';
            try {
                const token = authHeader.substring(7).trim();
                const jwt = require('../utils/jwt.util');
                const decoded: any = jwt.verify(token);
                if (decoded?.outlet_id || decoded?.outletId) {
                    sessionOutletId = Number(decoded.outlet_id || decoded.outletId);
                }
            } catch (_) {}
        }
    }

    // Check 3: Logged-in session user / outlet
    if (!sessionOutletId) {
        sessionOutletId = Number(req?.user?.outlet_id || req?.user?.outletId || req?.outlet?.id || 0);
        if (sessionOutletId) authMethod = 'SESSION';
    }

    // Check 4: Header x-outlet-id
    if (!sessionOutletId) {
        const fromHeader = Number(req?.headers?.['x-outlet-id'] || req?.headers?.['outlet_id']);
        if (fromHeader) {
            sessionOutletId = fromHeader;
            authMethod = 'HEADER';
        }
    }

    // Check 5: Query or Body outletId (from developer UI testing)
    if (!sessionOutletId) {
        const fromBodyOrQuery = Number(req?.body?.outletId || req?.query?.outletId || req?.body?.outlet_id || req?.query?.outlet_id);
        if (fromBodyOrQuery) {
            sessionOutletId = fromBodyOrQuery;
            authMethod = 'UI_TESTER';
        }
    }

    // Query active outlets to determine master/branch relationships
    let allOutlets: any[] = [];
    try {
        const oRows = await rawDb.query(
            `SELECT id, outlet_code, outlet_name, parent_outlet_id, is_master, outlet_role FROM outlets WHERE is_active = TRUE ORDER BY id ASC`
        );
        allOutlets = oRows[0] || [];
    } catch (_) {}

    // If still 0, default strictly to the primary registered outlet, NEVER 0
    if (!sessionOutletId || sessionOutletId <= 0) {
        if (allOutlets.length > 0) {
            const master = allOutlets.find(o => o.is_master || o.outlet_role === 'MASTER');
            sessionOutletId = Number(master ? master.id : allOutlets[0].id);
        } else {
            sessionOutletId = 1;
        }
    }

    const currentOutlet = allOutlets.find(o => Number(o.id) === sessionOutletId);
    const primaryName = currentOutlet ? currentOutlet.outlet_name : `Outlet #${sessionOutletId}`;
    const isMaster = currentOutlet ? Boolean(currentOutlet.is_master || currentOutlet.outlet_role === 'MASTER') : false;

    // Resolve Linked Outlets Cluster
    const linkedSet = new Set<number>();
    linkedSet.add(sessionOutletId);

    if (currentOutlet) {
        if (isMaster) {
            // Master can access all its child branch outlets
            allOutlets.forEach(o => {
                if (Number(o.parent_outlet_id) === sessionOutletId) {
                    linkedSet.add(Number(o.id));
                }
            });
        } else if (currentOutlet.parent_outlet_id) {
            // Branch can access itself and its parent cluster
            const parentId = Number(currentOutlet.parent_outlet_id);
            linkedSet.add(parentId);
            allOutlets.forEach(o => {
                if (Number(o.parent_outlet_id) === parentId || Number(o.id) === parentId) {
                    linkedSet.add(Number(o.id));
                }
            });
        }
    }

    const allowedOutletIds = Array.from(linkedSet);
    const linkedOutlets = allOutlets
        .filter(o => allowedOutletIds.includes(Number(o.id)))
        .map(o => ({
            id: Number(o.id),
            code: o.outlet_code || '',
            name: o.outlet_name || `Outlet #${o.id}`,
            role: o.outlet_role || (o.is_master ? 'MASTER' : 'BRANCH')
        }));

    return {
        primaryOutletId: sessionOutletId,
        primaryOutletName: primaryName,
        isMaster,
        allowedOutletIds,
        linkedOutlets,
        authMethod,
        keyName
    };
}

function getBaseUrl(req: any) {
    const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers['host'] || 'localhost:3000';
    return `${proto}://${host}`;
}

/**
 * POST /api/v1/developer/mcp
 * Standard MCP JSON-RPC 2.0 endpoint (initialize, tools/list, tools/call, etc.)
 */
export const handleJsonRpc = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const response = await mcpService.handleJsonRpc(db, outletContext, req.body);
        return res.json(response);
    } catch (err: any) {
        console.error('[MCP JSON-RPC ERROR]:', err.message);
        return res.status(500).json({
            jsonrpc: '2.0',
            id: req.body?.id || null,
            error: {
                code: -32603,
                message: `Internal server error: ${err.message}`
            }
        });
    }
};

/**
 * GET /api/v1/developer/mcp/sse
 * MCP Server-Sent Events (SSE) Transport for remote MCP clients
 */
const sseClients = new Map<string, any>();

export const handleSse = (req: any, res: any) => {
    res.setHeader('Content-Type', 'text/event-stream');
    res.setHeader('Cache-Control', 'no-cache');
    res.setHeader('Connection', 'keep-alive');
    res.setHeader('Access-Control-Allow-Origin', '*');
    res.flushHeaders?.();

    const sessionId = `mcp_sess_${Date.now()}_${Math.random().toString(36).substring(2, 9)}`;
    sseClients.set(sessionId, res);

    const baseUrl = getBaseUrl(req);
    res.write(`event: endpoint\ndata: ${baseUrl}/api/v1/developer/mcp/messages?sessionId=${sessionId}\n\n`);

    req.on('close', () => {
        sseClients.delete(sessionId);
    });
};

/**
 * POST /api/v1/developer/mcp/messages
 * Post endpoint for SSE session messages
 */
export const handleMessages = async (req: any, res: any) => {
    const sessionId = req.query.sessionId as string;
    const clientRes = sseClients.get(sessionId);

    const db = getDb(req);

    try {
        const outletContext = await resolveMcpOutletContext(db, req);
        const response = await mcpService.handleJsonRpc(db, outletContext, req.body);
        if (clientRes) {
            clientRes.write(`event: message\ndata: ${JSON.stringify(response)}\n\n`);
        }
        return res.status(202).json({ success: true, delivered: Boolean(clientRes) });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * GET /api/v1/developer/mcp/tools
 * List all available AI MCP tools
 */
export const getMcpTools = (req: any, res: any) => {
    return res.json({
        success: true,
        count: mcpService.MCP_TOOLS.length,
        tools: mcpService.MCP_TOOLS,
        resources: mcpService.MCP_RESOURCES,
        prompts: mcpService.MCP_PROMPTS
    });
};

/**
 * POST /api/v1/developer/mcp/tools/execute
 * Direct tool execution endpoint (used by ChatGPT Actions, Gemini scripts, or UI tester)
 */
export const executeToolDirect = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const { tool, arguments: args = {} } = req.body;

        if (!tool) {
            return res.status(400).json({
                success: false,
                message: "Missing 'tool' parameter in request body."
            });
        }

        const result = await mcpService.executeTool(db, outletContext, tool, args);
        return res.json({
            success: true,
            tool,
            outletContext: {
                primaryOutletId: outletContext.primaryOutletId,
                primaryOutletName: outletContext.primaryOutletName,
                allowedOutletIds: outletContext.allowedOutletIds,
                securityPolicy: 'STRICT_PARTICULAR_OR_LINKED_CLUSTER_ONLY'
            },
            result
        });
    } catch (err: any) {
        console.error('[MCP EXECUTE TOOL ERROR]:', err.message);
        return res.status(500).json({
            success: false,
            message: err.message
        });
    }
};

/**
 * Dedicated individual endpoints for ChatGPT OpenAPI Action mappings
 */
export const toolAnalyzeSales = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const result = await mcpService.toolAnalyzeSales(db, outletContext, req.body || {});
        return res.json({ success: true, data: result });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

export const toolCreateOrderBill = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const result = await mcpService.toolCreateOrderBill(db, outletContext, req.body || {});
        return res.status(201).json({ success: true, data: result });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

export const toolInventoryStatus = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const result = await mcpService.toolGetInventoryStatus(db, outletContext, req.body || {});
        return res.json({ success: true, data: result });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

export const toolSearchProducts = async (req: any, res: any) => {
    try {
        const db = getDb(req);
        const outletContext = await resolveMcpOutletContext(db, req);
        const result = await mcpService.toolSearchProducts(db, outletContext, req.body || {});
        return res.json({ success: true, data: result });
    } catch (err: any) {
        return res.status(500).json({ success: false, error: err.message });
    }
};

/**
 * GET /api/v1/developer/mcp/chatgpt-openapi.json
 * Dynamic OpenAPI 3.0.1 spec for direct import in ChatGPT Custom GPT Action
 */
export const getChatGptSpec = (req: any, res: any) => {
    const baseUrl = getBaseUrl(req);
    const spec = mcpService.getChatGptOpenApiSpec(baseUrl);
    return res.json(spec);
};

/**
 * GET /api/v1/developer/mcp/gemini-tools.json
 * Ready-to-use function declarations spec for Google Gemini API
 */
export const getGeminiSpec = (req: any, res: any) => {
    const spec = mcpService.getGeminiToolsSpec();
    return res.json(spec);
};

/**
 * GET /api/v1/developer/mcp/config
 * Returns all connection details, ready configurations, and active outlet security context
 */
export const getMcpConfig = async (req: any, res: any) => {
    const baseUrl = getBaseUrl(req);
    const db = getDb(req);
    const outletContext = await resolveMcpOutletContext(db, req);

    return res.json({
        success: true,
        data: {
            serverName: 'FAMALTH LYNX Model Context Protocol (MCP) Server',
            version: '2.0.0-ENTERPRISE',
            status: 'ONLINE',
            securityPolicy: 'STRICT_PARTICULAR_OR_LINKED_CLUSTER_ONLY',
            activeOutlet: {
                primaryId: outletContext.primaryOutletId,
                primaryName: outletContext.primaryOutletName,
                isMaster: outletContext.isMaster,
                allowedOutletIds: outletContext.allowedOutletIds,
                linkedOutlets: outletContext.linkedOutlets
            },
            endpoints: {
                mcpJsonRpc: `${baseUrl}/api/v1/developer/mcp`,
                mcpSse: `${baseUrl}/api/v1/developer/mcp/sse`,
                mcpMessages: `${baseUrl}/api/v1/developer/mcp/messages`,
                toolExecute: `${baseUrl}/api/v1/developer/mcp/tools/execute`,
                chatGptOpenApiSpec: `${baseUrl}/api/v1/developer/mcp/chatgpt-openapi.json`,
                geminiToolsSpec: `${baseUrl}/api/v1/developer/mcp/gemini-tools.json`,
            },
            claudeConfig: mcpService.getClaudeConfigSnippet(baseUrl, 'YOUR_API_KEY_HERE'),
            toolsCount: mcpService.MCP_TOOLS.length,
            tools: mcpService.MCP_TOOLS,
            prompts: mcpService.MCP_PROMPTS
        }
    });
};

module.exports = {
    resolveMcpOutletContext,
    handleJsonRpc,
    handleSse,
    handleMessages,
    getMcpTools,
    executeToolDirect,
    toolAnalyzeSales,
    toolCreateOrderBill,
    toolInventoryStatus,
    toolSearchProducts,
    getChatGptSpec,
    getGeminiSpec,
    getMcpConfig
};

export default module.exports;
