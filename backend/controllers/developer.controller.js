"use strict";
Object.defineProperty(exports, "__esModule", { value: true });
exports.issueOAuthToken = exports.deleteApiKey = exports.generateApiKey = exports.getApiKeys = exports.testWebhook = exports.deleteWebhook = exports.registerWebhook = exports.getWebhooks = exports.getEcosystemInfo = void 0;
const developerService = require('../services/developer.service');
const defaultDb = require('../db/models');
function getDb(req) {
    return req.propertyDb || defaultDb;
}
function resolveOutletId(req) {
    const fromUser = Number(req?.user?.outlet_id || req?.user?.outletId);
    if (fromUser)
        return fromUser;
    const fromHeader = Number(req?.headers?.['x-outlet-id'] || req?.headers?.['outlet_id']);
    if (fromHeader)
        return fromHeader;
    const fromQueryOrBody = Number(req?.query?.outletId || req?.query?.outlet_id || req?.body?.outletId || req?.body?.outlet_id);
    if (fromQueryOrBody)
        return fromQueryOrBody;
    // Decode token if req.user was not populated by upstream middleware
    try {
        const token = req?.headers?.authorization?.split(' ')[1];
        if (token) {
            const jwt = require('../utils/jwt.util');
            const data = jwt.verify(token);
            if (data?.outlet_id || data?.outletId)
                return Number(data.outlet_id || data.outletId);
        }
    }
    catch (_) { }
    return 0;
}
const getEcosystemInfo = async (req, res) => {
    try {
        const data = await developerService.getEcosystemInfo();
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER ECOSYSTEM CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch ecosystem information'
        });
    }
};
exports.getEcosystemInfo = getEcosystemInfo;
const getWebhooks = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getWebhooks(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER WEBHOOKS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch webhooks'
        });
    }
};
exports.getWebhooks = getWebhooks;
const registerWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { topic, targetUrl } = req.body;
        const data = await developerService.registerWebhook(getDb(req), outletId, topic, targetUrl);
        return res.json({
            success: true,
            data,
            message: 'Webhook registered successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER REGISTER WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to register webhook'
        });
    }
};
exports.registerWebhook = registerWebhook;
const deleteWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'Webhook deleted successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER DELETE WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to delete webhook'
        });
    }
};
exports.deleteWebhook = deleteWebhook;
const testWebhook = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        const data = await developerService.testWebhook(getDb(req), outletId, id);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER TEST WEBHOOK ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to test webhook'
        });
    }
};
exports.testWebhook = testWebhook;
const getApiKeys = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const data = await developerService.getApiKeys(getDb(req), outletId);
        return res.json({
            success: true,
            data
        });
    }
    catch (error) {
        console.error('[DEVELOPER API KEYS CONTROLLER ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: 'Failed to fetch API keys'
        });
    }
};
exports.getApiKeys = getApiKeys;
const generateApiKey = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { keyName, scopes } = req.body;
        const data = await developerService.generateApiKey(getDb(req), outletId, keyName, scopes);
        return res.json({
            success: true,
            data,
            message: 'API Key & OAuth credentials generated successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER GENERATE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to generate API key'
        });
    }
};
exports.generateApiKey = generateApiKey;
const deleteApiKey = async (req, res) => {
    try {
        const outletId = resolveOutletId(req);
        const { id } = req.params;
        await developerService.deleteApiKey(getDb(req), outletId, id);
        return res.json({
            success: true,
            message: 'API Key revoked successfully'
        });
    }
    catch (error) {
        console.error('[DEVELOPER DELETE API KEY ERROR]:', error.message);
        return res.status(500).json({
            success: false,
            message: error.message || 'Failed to revoke API key'
        });
    }
};
exports.deleteApiKey = deleteApiKey;
const authorizeOAuth = async (req, res) => {
    try {
        const clientId = req.query?.client_id || req.body?.client_id || req.query?.clientId || req.body?.clientId;
        const redirectUri = req.query?.redirect_uri || req.body?.redirect_uri || req.query?.redirectUri || req.body?.redirectUri;
        const state = req.query?.state || req.body?.state || '';
        const scopeParam = req.query?.scope || req.body?.scope;
        const codeChallenge = req.query?.code_challenge || req.body?.code_challenge;
        const codeChallengeMethod = req.query?.code_challenge_method || req.body?.code_challenge_method || 'S256';

        if (!clientId) {
            return res.status(400).send(`
                <html>
                <body style="font-family:sans-serif;padding:40px;background:#0f172a;color:#fff;">
                    <h2 style="color:#ef4444;">OAuth 2.0 Error: Missing client_id</h2>
                    <p>No client_id was specified in the authorization request from ChatGPT.</p>
                </body>
                </html>
            `);
        }

        const scopes = scopeParam ? String(scopeParam).split(/[,\s]+/).filter(Boolean) : undefined;

        const { code, keyRecord } = await developerService.createAuthorizationCode(getDb(req), {
            clientId: String(clientId).trim(),
            redirectUri: redirectUri ? String(redirectUri).trim() : undefined,
            scopes,
            codeChallenge: codeChallenge ? String(codeChallenge).trim() : undefined,
            codeChallengeMethod: codeChallengeMethod ? String(codeChallengeMethod).trim() : 'S256'
        });

        // If redirect_uri provided (standard ChatGPT OAuth flow), redirect back with code and state
        if (redirectUri) {
            const redirectUrl = new (require('url').URL)(String(redirectUri).trim());
            redirectUrl.searchParams.set('code', code);
            if (state) {
                redirectUrl.searchParams.set('state', String(state));
            }
            return res.redirect(redirectUrl.toString());
        }

        // Otherwise render confirmation HTML
        return res.send(`
            <html>
            <head><title>FAMALTH LYNX - Authorize AI Assistant</title></head>
            <body style="font-family:system-ui,-apple-system,sans-serif;padding:40px;background:#0f172a;color:#f8fafc;max-width:550px;margin:auto;">
                <div style="background:#1e293b;border-radius:16px;padding:32px;box-shadow:0 10px 25px rgba(0,0,0,0.5);border:1px solid #334155;">
                    <h2 style="color:#10b981;margin-top:0;">Connected to FAMALTH LYNX POS</h2>
                    <p style="color:#94a3b8;font-size:14px;">Client Authorized: <strong>${keyRecord.keyName}</strong> (Outlet #${keyRecord.outletId})</p>
                    <div style="background:#0f172a;padding:12px 16px;border-radius:8px;font-family:monospace;font-size:13px;word-break:break-all;color:#38bdf8;margin:20px 0;">
                        ${code}
                    </div>
                    <p style="color:#64748b;font-size:12px;">You can return to ChatGPT. The authorization code has been issued.</p>
                </div>
            </body>
            </html>
        `);
    } catch (error) {
        console.error('[DEVELOPER OAUTH AUTHORIZE ERROR]:', error.message);
        return res.status(400).send(`
            <html>
            <body style="font-family:sans-serif;padding:40px;background:#0f172a;color:#fff;">
                <h2 style="color:#ef4444;">Authorization Failed</h2>
                <p style="color:#cbd5e1;">${error.message}</p>
            </body>
            </html>
        `);
    }
};
exports.authorizeOAuth = authorizeOAuth;

const issueOAuthToken = async (req, res) => {
    try {
        let clientId = req.body?.client_id || req.body?.clientId;
        let clientSecret = req.body?.client_secret || req.body?.clientSecret;
        const grantType = req.body?.grant_type || req.body?.grantType || 'client_credentials';

        // Check HTTP Basic Auth header: Authorization: Basic base64(client_id:client_secret)
        // Standard in ChatGPT client_secret_basic mode
        const authHeader = req.headers?.authorization;
        if (authHeader && authHeader.toLowerCase().startsWith('basic ')) {
            try {
                const credentials = Buffer.from(authHeader.substring(6).trim(), 'base64').toString('utf8');
                const sepIndex = credentials.indexOf(':');
                if (sepIndex !== -1) {
                    clientId = credentials.substring(0, sepIndex);
                    clientSecret = credentials.substring(sepIndex + 1);
                }
            } catch (_) {}
        }

        if (grantType === 'authorization_code') {
            const code = req.body?.code;
            const redirectUri = req.body?.redirect_uri || req.body?.redirectUri;
            const codeVerifier = req.body?.code_verifier || req.body?.codeVerifier;

            const data = await developerService.exchangeAuthCode(getDb(req), {
                code,
                clientId,
                clientSecret,
                redirectUri,
                codeVerifier
            });
            return res.json(data);
        }

        if (grantType === 'refresh_token') {
            const refreshToken = req.body?.refresh_token || req.body?.refreshToken;
            if (!refreshToken) {
                return res.status(400).json({
                    error: 'invalid_request',
                    error_description: 'refresh_token parameter is required for grant_type=refresh_token.'
                });
            }
            const data = await developerService.refreshOAuthToken(getDb(req), refreshToken);
            return res.json(data);
        }

        if (grantType !== 'client_credentials') {
            return res.status(400).json({
                error: 'unsupported_grant_type',
                error_description: 'Supported grant_type values: authorization_code, client_credentials, refresh_token.'
            });
        }

        const data = await developerService.issueOAuthToken(getDb(req), clientId, clientSecret);
        return res.json(data);
    }
    catch (error) {
        console.error('[DEVELOPER OAUTH TOKEN ERROR]:', error.message);
        return res.status(401).json({
            error: 'invalid_grant',
            error_description: error.message || 'Authentication failed'
        });
    }
};
exports.issueOAuthToken = issueOAuthToken;

const getOAuthMetadata = (req, res) => {
    const proto = req.headers['x-forwarded-proto'] || req.protocol || 'http';
    const host = req.headers['x-forwarded-host'] || req.headers['host'] || 'localhost:3000';
    const baseUrl = `${proto}://${host}`;

    res.setHeader('Access-Control-Allow-Origin', '*');
    res.setHeader('Access-Control-Allow-Methods', 'GET, OPTIONS');
    res.setHeader('Access-Control-Allow-Headers', '*');

    return res.json({
        issuer: baseUrl,
        authorization_endpoint: `${baseUrl}/api/v1/developer/oauth/authorize`,
        token_endpoint: `${baseUrl}/api/v1/developer/oauth/token`,
        token_endpoint_auth_methods_supported: ['client_secret_basic', 'client_secret_post'],
        response_types_supported: ['code'],
        grant_types_supported: ['authorization_code', 'client_credentials', 'refresh_token'],
        code_challenge_methods_supported: ['S256', 'plain'],
        scopes_supported: [
            'orders:read',
            'orders:write',
            'billing:read',
            'reports:read',
            'inventory:read'
        ],
        service_documentation: `${baseUrl}/api/v1/developer/ecosystem/info`,
        ui_locales_supported: ['en']
    });
};
exports.getOAuthMetadata = getOAuthMetadata;

module.exports = {
    getEcosystemInfo: exports.getEcosystemInfo,
    getWebhooks: exports.getWebhooks,
    registerWebhook: exports.registerWebhook,
    deleteWebhook: exports.deleteWebhook,
    testWebhook: exports.testWebhook,
    getApiKeys: exports.getApiKeys,
    generateApiKey: exports.generateApiKey,
    deleteApiKey: exports.deleteApiKey,
    authorizeOAuth: exports.authorizeOAuth,
    issueOAuthToken: exports.issueOAuthToken,
    getOAuthMetadata: exports.getOAuthMetadata
};
exports.default = module.exports;
