import { Parser } from 'node-sql-parser';
import propertyDb from '../db/propertyDb';
import initMasterModels from '../models/master';
import { extractSchemaFromMigrations } from '../utils/migrationSchemaExtractor';

export interface QueryDoctorValidationResult {
  isAllowed: boolean;
  operationType: 'SELECT' | 'UPDATE' | 'DELETE' | 'OTHER';
  sanitizedSql?: string;
  rejectionReason?: string;
  whereClauseText?: string;
}

export class DataDoctorService {
  private static parser = new Parser();

  /**
   * Validates and enforces security rules on support queries:
   * 1. Only SELECT, UPDATE, DELETE allowed.
   * 2. UPDATE and DELETE MUST have a valid, non-trivial WHERE clause.
   * 3. Automatically scopes query to target outlet_id to prevent cross-outlet data leakage.
   */
  public static validateAndScopeQuery(rawSql: string, targetOutletId: number): QueryDoctorValidationResult {
    const trimmed = rawSql.trim();
    if (!trimmed) {
      return {
        isAllowed: false,
        operationType: 'OTHER',
        rejectionReason: 'Query cannot be empty.',
      };
    }

    // Reject dangerous DDL / admin commands immediately
    const forbiddenPatterns = [
      /\b(DROP|TRUNCATE|ALTER|CREATE|GRANT|REVOKE|VACUUM|REINDEX)\b/i,
      /;\s*(DROP|TRUNCATE|ALTER|DELETE|UPDATE)/i, // Prevent multi-statement injection
    ];

    for (const pattern of forbiddenPatterns) {
      if (pattern.test(trimmed)) {
        return {
          isAllowed: false,
          operationType: 'OTHER',
          rejectionReason: 'Security Alert: Schema-altering or multi-statement DDL queries are forbidden in Data Doctor.',
        };
      }
    }

    let ast: any;
    try {
      ast = this.parser.astify(trimmed, { database: 'PostgreSQL' });
    } catch (parseErr: any) {
      return {
        isAllowed: false,
        operationType: 'OTHER',
        rejectionReason: `SQL Syntax Error: ${parseErr.message}`,
      };
    }

    const stmt = Array.isArray(ast) ? ast[0] : ast;
    const opType = (stmt.type || '').toUpperCase() as 'SELECT' | 'UPDATE' | 'DELETE';

    if (opType === 'DELETE' || /\bDELETE\b/i.test(trimmed)) {
      return {
        isAllowed: false,
        operationType: 'DELETE',
        rejectionReason: 'Delete not allowed. Delete is restricted in Data Doctor.',
      };
    }

    if (!['SELECT', 'UPDATE'].includes(opType)) {
      return {
        isAllowed: false,
        operationType: 'OTHER',
        rejectionReason: `Operation '${opType}' is not supported. Data Doctor only allows SELECT and UPDATE.`,
      };
    }

    // Determine target table and whether it possesses an outlet_id column
    const tableMatch = trimmed.match(/(?:FROM|UPDATE|DELETE\s+FROM|INTO)\s+([a-zA-Z0-9_]+)/i);
    let tableHasOutletId = true;
    if (tableMatch && tableMatch[1]) {
      try {
        const schema = extractSchemaFromMigrations();
        const found = schema.tables.find(
          (t) => t.tableName.toLowerCase() === tableMatch[1].toLowerCase()
        );
        if (found) {
          tableHasOutletId = found.columns.some((c) => c.name.toLowerCase() === 'outlet_id');
        }
      } catch (_) {}
    }

    // Enforce non-trivial WHERE clause for UPDATE
    if (opType === 'UPDATE') {
      if (!stmt.where) {
        return {
          isAllowed: false,
          operationType: opType,
          rejectionReason: `GUARD ENFORCEMENT: ${opType} statement without a WHERE clause is strictly prohibited to prevent data loss!`,
        };
      }

      const whereMatch = trimmed.match(/\bWHERE\b\s+(.*)/is);
      const whereStr = whereMatch ? whereMatch[1].replace(/;.*$/, '').trim() : '';

      // Check for trivial / tautological WHERE clauses like WHERE 1=1 or WHERE true or WHERE 'a'='a'
      const trivialPatterns = [
        /^\s*1\s*=\s*1\s*$/i,
        /^\s*true\s*$/i,
        /^\s*'1'\s*=\s*'1'\s*$/i,
        /^\s*0\s*=\s*0\s*$/i,
      ];

      for (const tp of trivialPatterns) {
        if (tp.test(whereStr)) {
          return {
            isAllowed: false,
            operationType: opType,
            rejectionReason: `GUARD ENFORCEMENT: Trivial WHERE clause ('${whereStr}') is rejected. Specify exact targeted conditions.`,
          };
        }
      }

      // Check if outlet_id is already referenced or needs injection
      let sanitizedSql = trimmed.replace(/;+$/, '');
      if (tableHasOutletId && !/outlet_id/i.test(whereStr) && targetOutletId > 0) {
        const trailingRegex = /\b(RETURNING)\b/i;
        const match = sanitizedSql.match(trailingRegex);
        if (match && match.index !== undefined) {
          const mainPart = sanitizedSql.substring(0, match.index).trim();
          const trailingPart = sanitizedSql.substring(match.index).trim();
          sanitizedSql = `${mainPart} AND outlet_id = ${targetOutletId} ${trailingPart}`;
        } else {
          sanitizedSql = `${sanitizedSql} AND outlet_id = ${targetOutletId}`;
        }
      }

      return {
        isAllowed: true,
        operationType: opType,
        sanitizedSql,
        whereClauseText: whereStr,
      };
    }

    // For SELECT queries:
    const whereMatch = trimmed.match(/\bWHERE\b\s+(.*)/is);
    const whereStr = whereMatch ? whereMatch[1].replace(/;.*$/, '').trim() : '';
    let sanitizedSql = trimmed.replace(/;+$/, '');

    if (tableHasOutletId && !/outlet_id/i.test(sanitizedSql) && targetOutletId > 0) {
      const trailingRegex = /\b(GROUP\s+BY|HAVING|ORDER\s+BY|LIMIT|OFFSET|FETCH|FOR\s+UPDATE)\b/i;
      const match = sanitizedSql.match(trailingRegex);

      if (match && match.index !== undefined) {
        const mainPart = sanitizedSql.substring(0, match.index).trim();
        const trailingPart = sanitizedSql.substring(match.index).trim();

        if (/\bWHERE\b/i.test(mainPart)) {
          sanitizedSql = `${mainPart} AND outlet_id = ${targetOutletId} ${trailingPart}`;
        } else {
          sanitizedSql = `${mainPart} WHERE outlet_id = ${targetOutletId} ${trailingPart}`;
        }
      } else {
        if (/\bWHERE\b/i.test(sanitizedSql)) {
          sanitizedSql = `${sanitizedSql} AND outlet_id = ${targetOutletId}`;
        } else {
          sanitizedSql = `${sanitizedSql} WHERE outlet_id = ${targetOutletId}`;
        }
      }
    }

    return {
      isAllowed: true,
      operationType: 'SELECT',
      sanitizedSql,
      whereClauseText: whereStr || (tableHasOutletId ? `outlet_id = ${targetOutletId}` : 'ALL_GLOBAL_RECORDS'),
    };
  }

  /**
   * Executes a verified query and logs complete audit trail with execution metrics.
   */
  public static async executeScopedDiagnosticQuery(params: {
    rawSql: string;
    ticketId?: string;
    agentId?: string;
    tenantId: string;
    outletId: number;
  }) {
    const { rawSql, ticketId, agentId, tenantId, outletId } = params;

    const validation = this.validateAndScopeQuery(rawSql, outletId);
    if (!validation.isAllowed) {
      return {
        success: false,
        error: validation.rejectionReason,
      };
    }

    const startTime = Date.now();
    let affectedRows = 0;
    let queryResult: any = null;
    let preChangeSnapshot: any = null;

    try {
      const finalSql = validation.sanitizedSql || rawSql;

      // If mutation (UPDATE/DELETE), capture pre-change snapshot if possible
      if (validation.operationType === 'UPDATE' || validation.operationType === 'DELETE') {
        // Best effort pre-change snapshot
        try {
          const tableNameMatch = finalSql.match(/(?:UPDATE|FROM)\s+([a-zA-Z0-9_]+)/i);
          if (tableNameMatch && tableNameMatch[1] && validation.whereClauseText) {
            const tableName = tableNameMatch[1];
            const [snapshotRows] = await propertyDb.query(
              `SELECT * FROM ${tableName} WHERE ${validation.whereClauseText} LIMIT 50`
            );
            preChangeSnapshot = snapshotRows;
          }
        } catch (_) {
          // Non-fatal if snapshot extraction fails
        }
      }

      // Execute in transactional context for safety
      const [results, metadata]: any = await propertyDb.query(finalSql);
      const durationMs = Date.now() - startTime;

      if (validation.operationType === 'SELECT') {
        queryResult = results;
        affectedRows = Array.isArray(results) ? results.length : 0;
      } else {
        if (metadata && typeof metadata.rowCount === 'number') {
          affectedRows = metadata.rowCount;
        } else if (typeof metadata === 'number') {
          affectedRows = metadata;
        } else if (results && typeof results.rowCount === 'number') {
          affectedRows = results.rowCount;
        } else {
          affectedRows = Array.isArray(results) ? results.length : 0;
        }
        queryResult = { affectedRows, status: 'SUCCESS' };
      }

      // Log into diagnostic_query_audit_logs
      const { DiagnosticQueryAuditLog } = initMasterModels(propertyDb);
      await DiagnosticQueryAuditLog.create({
        ticket_id: ticketId || null,
        agent_id: agentId || null,
        tenant_id: tenantId,
        outlet_id: outletId,
        executed_sql: finalSql,
        operation_type: validation.operationType,
        where_clause_text: validation.whereClauseText || 'N/A',
        row_count_affected: affectedRows,
        pre_change_snapshot: preChangeSnapshot,
        execution_duration_ms: durationMs,
      });

      return {
        success: true,
        operationType: validation.operationType,
        sanitizedSql: finalSql,
        rowCount: affectedRows,
        durationMs,
        data: queryResult,
        preChangeSnapshot,
      };
    } catch (execErr: any) {
      return {
        success: false,
        error: `Execution Failure: ${execErr.message}`,
        durationMs: Date.now() - startTime,
      };
    }
  }
}

export default DataDoctorService;
