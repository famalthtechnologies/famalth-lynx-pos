"use strict";
var __importDefault = (this && this.__importDefault) || function (mod) {
    return (mod && mod.__esModule) ? mod : { "default": mod };
};
Object.defineProperty(exports, "__esModule", { value: true });
exports.request = request;
const https_1 = __importDefault(require("https"));
/**
 * Standard https request wrapper
 * @param method HTTP method (GET, POST, etc.)
 * @param url Meta API url path/query (e.g. /v20.0/messages)
 * @param headers Request headers
 * @param body Payload object
 */
function request(method, url, headers = {}, body = null) {
    return new Promise((resolve, reject) => {
        const parsedUrl = new URL(url);
        const options = {
            method: method.toUpperCase(),
            hostname: parsedUrl.hostname,
            port: parsedUrl.port || 443,
            path: parsedUrl.pathname + parsedUrl.search,
            headers: {
                'Content-Type': 'application/json',
                ...headers
            }
        };
        const req = https_1.default.request(options, (res) => {
            let data = '';
            res.on('data', (chunk) => {
                data += chunk;
            });
            res.on('end', () => {
                try {
                    const parsed = JSON.parse(data);
                    resolve({ statusCode: res.statusCode, body: parsed });
                }
                catch (e) {
                    resolve({ statusCode: res.statusCode, body: data });
                }
            });
        });
        req.on('error', (err) => {
            reject(err);
        });
        if (body && (method === 'POST' || method === 'PUT')) {
            req.write(JSON.stringify(body));
        }
        req.end();
    });
}
exports.default = {
    request
};
