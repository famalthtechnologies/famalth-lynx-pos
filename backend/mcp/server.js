#!/usr/bin/env node
/**
 * FAMALTH LYNX - Model Context Protocol (MCP) Stdio Server
 * Compatible with Claude Desktop, Cursor, Gemini CLI, Antigravity, and all MCP Stdio clients.
 * 
 * Usage in claude_desktop_config.json:
 * {
 *   "mcpServers": {
 *     "famalth-lynx": {
 *       "command": "node",
 *       "args": ["<path-to-RetailSale>/backend/mcp/server.js"],
 *       "env": {
 *         "LYNX_API_URL": "http://localhost:3000",
 *         "LYNX_API_KEY": "YOUR_API_KEY"
 *       }
 *     }
 *   }
 * }
 */

const readline = require('readline');
const http = require('http');
const https = require('https');
const { URL } = require('url');

const apiUrl = process.env.LYNX_API_URL || 'http://localhost:3000';
const apiKey = process.env.LYNX_API_KEY || '';

// Try to load local service if available
let localMcpService = null;
let localDb = null;
try {
    localMcpService = require('../services/mcp.service');
    localDb = require('../db/models');
} catch (_) {}

async function forwardToHttpServer(jsonRpcMessage) {
    return new Promise((resolve, reject) => {
        try {
            const parsedUrl = new URL(`${apiUrl}/api/v1/developer/mcp`);
            const isHttps = parsedUrl.protocol === 'https:';
            const client = isHttps ? https : http;

            const postData = JSON.stringify(jsonRpcMessage);
            const headers = {
                'Content-Type': 'application/json',
                'Content-Length': Buffer.byteLength(postData)
            };

            if (apiKey) {
                headers['X-API-Key'] = apiKey;
            }

            const req = client.request(parsedUrl, {
                method: 'POST',
                headers,
                timeout: 10000
            }, (res) => {
                let data = '';
                res.on('data', chunk => { data += chunk; });
                res.on('end', () => {
                    try {
                        const parsed = JSON.parse(data);
                        resolve(parsed);
                    } catch (parseErr) {
                        reject(new Error(`Failed to parse backend response: ${data}`));
                    }
                });
            });

            req.on('error', (err) => reject(err));
            req.on('timeout', () => {
                req.destroy();
                reject(new Error('Request to Lynx backend timed out.'));
            });

            req.write(postData);
            req.end();
        } catch (e) {
            reject(e);
        }
    });
}

async function handleMessage(messageStr) {
    if (!messageStr || !messageStr.trim()) return;

    let request;
    try {
        request = JSON.parse(messageStr);
    } catch (e) {
        process.stdout.write(JSON.stringify({
            jsonrpc: '2.0',
            id: null,
            error: { code: -32700, message: 'Parse error' }
        }) + '\n');
        return;
    }

    try {
        // Attempt HTTP proxy first if backend is running
        let response = null;
        try {
            response = await forwardToHttpServer(request);
        } catch (proxyErr) {
            // Fallback to local DB handler if HTTP server isn't up
            if (localMcpService && localDb) {
                response = await localMcpService.handleJsonRpc(localDb, 0, request);
            } else {
                response = {
                    jsonrpc: '2.0',
                    id: request.id || null,
                    error: {
                        code: -32603,
                        message: `Unable to connect to Lynx Backend at ${apiUrl}: ${proxyErr.message}`
                    }
                };
            }
        }

        if (response) {
            process.stdout.write(JSON.stringify(response) + '\n');
        }
    } catch (err) {
        process.stdout.write(JSON.stringify({
            jsonrpc: '2.0',
            id: request?.id || null,
            error: { code: -32603, message: err.message }
        }) + '\n');
    }
}

function startStdioServer() {
    const rl = readline.createInterface({
        input: process.stdin,
        output: process.stdout,
        terminal: false
    });

    rl.on('line', (line) => {
        handleMessage(line);
    });

    // Handle unexpected terminations gracefully
    process.on('SIGINT', () => process.exit(0));
    process.on('SIGTERM', () => process.exit(0));
}

startStdioServer();
