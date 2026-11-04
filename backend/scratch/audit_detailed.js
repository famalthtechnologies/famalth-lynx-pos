"use strict";
const fs = require('fs');
const path = require('path');
const { extractSchemaFromMigrations } = require('../utils/migrationSchemaExtractor');
const migSchema = extractSchemaFromMigrations();
const migTables = new Map();
for (const t of migSchema.tables) {
    migTables.set(t.tableName.toLowerCase(), new Set(t.columns.map(c => c.name.toLowerCase())));
}
const modelDirs = [
    path.join(__dirname, '../models/master'),
    path.join(__dirname, '../models/property')
];
const missingTables = [];
const missingColumnsByTable = {};
for (const dir of modelDirs) {
    if (!fs.existsSync(dir))
        continue;
    const files = fs.readdirSync(dir).filter(f => f.endsWith('.model.ts') || (f.endsWith('.model.js') && !fs.existsSync(path.join(dir, f.replace('.js', '.ts')))));
    for (const file of files) {
        const fullPath = path.join(dir, file);
        const content = fs.readFileSync(fullPath, 'utf8');
        let tableNameMatch = content.match(/tableName:\s*['"]([^'"]+)['"]/);
        if (!tableNameMatch) {
            tableNameMatch = content.match(/sequelize\.define\(\s*['"]([^'"]+)['"]/);
        }
        if (!tableNameMatch)
            continue;
        const tableName = tableNameMatch[1].toLowerCase();
        const migCols = migTables.get(tableName);
        if (!migCols) {
            missingTables.push({ table: tableName, file: file });
            continue;
        }
        // Now extract attributes:
        // Look for lines like:
        //   column_name: { type: ... }
        //   column_name: DataTypes...
        //   declare public column_name: ...
        const lines = content.split('\n');
        const colsInModel = new Set();
        let insideDefine = false;
        let braceDepth = 0;
        for (let i = 0; i < lines.length; i++) {
            const line = lines[i];
            if (line.includes('.init(') || line.includes('sequelize.define(')) {
                insideDefine = true;
            }
            if (insideDefine) {
                // Attribute pattern: key: { ... } or key: DataTypes.
                const match = line.match(/^\s*([a-zA-Z0-9_]+)\s*:\s*(?:\{|DataTypes\.)/);
                if (match) {
                    const col = match[1];
                    if (!['sequelize', 'tableName', 'timestamps', 'createdAt', 'updatedAt', 'indexes', 'hooks', 'type', 'defaultValue', 'allowNull', 'primaryKey', 'unique', 'autoIncrement', 'references', 'onDelete', 'onUpdate', 'comment', 'validate'].includes(col)) {
                        colsInModel.add(col.toLowerCase());
                    }
                }
                if (line.includes('}, {') || line.includes('},{')) {
                    insideDefine = false;
                }
            }
        }
        for (const c of colsInModel) {
            if (!migCols.has(c)) {
                if (!missingColumnsByTable[tableName]) {
                    missingColumnsByTable[tableName] = [];
                }
                missingColumnsByTable[tableName].push(c);
            }
        }
    }
}
console.log('--- MISSING TABLES ---');
console.log(JSON.stringify(missingTables, null, 2));
console.log('\n--- MISSING COLUMNS IN EXISTING TABLES ---');
console.log(JSON.stringify(missingColumnsByTable, null, 2));
