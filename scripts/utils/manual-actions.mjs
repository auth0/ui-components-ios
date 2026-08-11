// ============================================================================
// Manual-action tracking + permission-error detection
//
// The bootstrap can authenticate with an M2M app that is missing some
// Management API scopes (e.g. `update:tenant_settings`). Rather than aborting
// the whole run when a single privileged operation is denied, the affected
// apply step records a "manual action" here, warns, and continues. At the end
// of the run the bootstrap prints a consolidated list of what still needs to
// be done by hand (or by granting the missing scope and re-running).
// ============================================================================

const pendingManualActions = []

/**
 * Record something the caller could not complete automatically.
 * @param {{ resource: string, reason: string, scope?: string, manualStep?: string }} action
 */
export function recordManualAction(action) {
  pendingManualActions.push(action)
}

/**
 * @returns {Array<{resource:string,reason:string,scope?:string,manualStep?:string}>}
 */
export function getManualActions() {
  return pendingManualActions
}

/**
 * Detect whether an execa/CLI error was caused by a missing Management API
 * scope or an authorization denial (as opposed to a genuine failure we should
 * surface). The Auth0 CLI reports these as
 * "Request failed because access token lacks scope: <scope>".
 * @param {Error & {stderr?: string, stdout?: string}} e
 * @returns {boolean}
 */
export function isPermissionError(e) {
  const text = `${e?.stderr || ""} ${e?.stdout || ""} ${e?.message || ""}`.toLowerCase()

  return (
    text.includes("lacks scope") ||
    text.includes("insufficient_scope") ||
    text.includes("insufficient scope") ||
    text.includes("forbidden") ||
    text.includes("access_denied") ||
    text.includes("403")
  )
}

/**
 * Try to pull the specific scope name out of a "lacks scope: <scope>" message
 * so the manual-action summary can name exactly what to grant.
 * @param {Error & {stderr?: string}} e
 * @returns {string | null}
 */
export function extractMissingScope(e) {
  const text = `${e?.stderr || ""} ${e?.message || ""}`
  const match = text.match(/lacks scope:\s*([a-z0-9_:*-]+)/i)
  return match ? match[1] : null
}
