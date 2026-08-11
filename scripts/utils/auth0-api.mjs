import { $ } from "execa"

// Default timeout for API calls (30 seconds)
const DEFAULT_API_TIMEOUT = 30000

/**
 * Check if an error indicates an authentication/authorization issue
 * @param {Error} e - The error to check
 * @returns {boolean} True if it's an auth error
 */
function isAuthError(e) {
  const stderr = e.stderr?.toLowerCase() || ""

  // Check for clear authentication failures
  if (stderr.includes("unauthorized") || stderr.includes("401")) {
    return true
  }

  // Check for token expiration messages
  if (stderr.includes("token") && (stderr.includes("expired") || stderr.includes("invalid"))) {
    return true
  }

  // Check for "please login" type messages (but not "during login" which is scope advice)
  if (stderr.includes("please login") || stderr.includes("not logged in")) {
    return true
  }

  return false
}

/**
 * Make a generic API call using auth0 CLI
 * @param {string} method - HTTP method (get, post, patch, delete)
 * @param {string} endpoint - API endpoint
 * @param {object} data - Optional data payload
 * @param {number} timeout - Optional timeout in ms (default 30s)
 */
export async function auth0ApiCall(method, endpoint, data = null, timeout = DEFAULT_API_TIMEOUT) {
  const args = ["api", method, endpoint, "--no-input"]

  if (data) {
    args.push("--data", JSON.stringify(data))
  }

  try {
    const { stdout } = await $({ timeout })`auth0 ${args}`
    const result = stdout ? JSON.parse(stdout) : null

    // The Auth0 CLI exits 0 even when the Management API returns an HTTP error
    // (e.g. 400/403), printing the error body as JSON on stdout. Detect that
    // shape and surface it as a real failure instead of a silent success.
    if (
      result &&
      typeof result === "object" &&
      !Array.isArray(result) &&
      typeof result.statusCode === "number" &&
      result.statusCode >= 400
    ) {
      const detail = result.message || result.error || "Unknown error"
      throw new Error(
        `Auth0 API ${method.toUpperCase()} ${endpoint} failed (${result.statusCode}): ${detail}`
      )
    }

    return result
  } catch (e) {
    // Check if it's a timeout error
    if (e.timedOut) {
      throw new Error(
        `API call timed out after ${timeout}ms. Your Auth0 session may have expired.`
      )
    }
    // Check for authentication errors
    if (isAuthError(e)) {
      throw new Error(`Authentication failed. Your Auth0 session may have expired.`)
    }
    // For scope errors, return null gracefully (the feature may not be available)
    if (e.stderr?.includes("lacks scope") || e.stderr?.includes("insufficient_scope")) {
      console.warn(
        `⚠️  Warning: Missing required scope for ${endpoint}. Some features may not be available.`
      )
      return null
    }
    console.warn(`⚠️  Warning: API Call failed: ${e.message}`)
    throw e
  }
}

/**
 * Check if the Auth0 CLI session is valid by making a simple API call
 * @param {number} timeout - Timeout in ms (default 10s for quick check)
 * @returns {Promise<boolean>} True if session is valid
 */
export async function isSessionValid(timeout = 10000) {
  try {
    // Probe with an endpoint whose scope is part of the bootstrap set
    // (read:client_grants). Using `get users` would require read:users, which
    // the bootstrap never requests — so a correctly-scoped M2M app would look
    // "invalid" here even though its session is fine.
    await $({ timeout })`auth0 api get client-grants --no-input`
    return true
  } catch (e) {
    return false
  }
}

/**
 * Detect the Auth0 CLI "corrupted token" state. The CLI can persist a malformed
 * token (a known issue) that no refresh can fix — it must be cleared with
 * `auth0 logout` before logging in again. A plain expiry does NOT report this,
 * so we treat it distinctly to trigger an automatic logout+relogin.
 * @param {number} timeout
 * @returns {Promise<boolean>} True if the stored token is corrupted
 */
export async function isTokenCorrupted(timeout = 10000) {
  try {
    // Same in-set probe as isSessionValid (read:client_grants) — see note there.
    await $({ timeout })`auth0 api get client-grants --no-input`
    return false
  } catch (e) {
    const text = `${e.stderr || ""} ${e.stdout || ""} ${e.message || ""}`.toLowerCase()
    return (
      text.includes("token is corrupted") ||
      text.includes("malformed token") ||
      text.includes("auth0 logout")
    )
  }
}
