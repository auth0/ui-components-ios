import { $, execaSync } from "execa"
import ora from "ora"
import fs from "node:fs"
import path from "node:path"

import { auth0ApiCall, isSessionValid, isTokenCorrupted } from "./auth0-api.mjs"
import { confirmWithUser } from "./helpers.mjs"
import { MY_ACCOUNT_API_SCOPES } from "./resource-servers.mjs"

// Timeout for CLI commands (15 seconds)
const CLI_TIMEOUT = 15000

// All scopes needed for the iOS bootstrap operations.
//
// Each entry carries a one-line `reason` (surfaced in `--help` usage details)
// and an `important` flag. "Important" scopes are the write permissions that
// gate a user-visible feature or the self-grant capability — the ones most
// likely to be missing on an M2M app and to silently block setup. They are
// highlighted in the pre-login summary so you know why they are requested.
//
// NOTE: Organization-only scopes (create:organization_*) are intentionally
// omitted — the iOS sample app configures the My Account feature only.
const BOOTSTRAP_SCOPE_METADATA = [
  { scope: "read:connection_profiles", reason: "Read connection profiles" },
  { scope: "create:connection_profiles", reason: "Create the connection profile" },
  { scope: "read:user_attribute_profiles", reason: "Read user attribute profiles" },
  { scope: "create:user_attribute_profiles", reason: "Create the user attribute profile" },
  { scope: "read:client_grants", reason: "Read existing client grants" },
  { scope: "create:client_grants", reason: "Grant the app access to the My Account API" },
  {
    scope: "update:client_grants",
    reason:
      "Lets the M2M app grant itself any future scopes — without it, scope changes need the Dashboard (chicken-and-egg).",
    important: true,
  },
  { scope: "read:connections", reason: "Read database connections" },
  { scope: "create:connections", reason: "Create the database connection" },
  {
    scope: "update:connections",
    reason: "Enable the native app as a client of the connection (username/password login).",
    important: true,
  },
  { scope: "read:connections_options", reason: "Read connection options (auth methods)" },
  {
    scope: "update:connections_options",
    reason: "Enable passkeys on the connection so the Passkey option shows in Universal Login.",
    important: true,
  },
  { scope: "read:clients", reason: "Read existing applications" },
  {
    scope: "create:clients",
    reason: "Create the native iOS application the sample app authenticates with.",
    important: true,
  },
  {
    scope: "update:clients",
    reason: "Set the app's callback + logout URLs so login/logout redirects resolve.",
    important: true,
  },
  { scope: "read:resource_servers", reason: "Read existing APIs" },
  { scope: "create:resource_servers", reason: "Register the My Account API resource server" },
  { scope: "update:resource_servers", reason: "Keep the My Account API scopes in sync" },
  {
    scope: "update:tenant_settings",
    reason: "Enable MFA customization in the post-login action for the MFA components.",
    important: true,
  },
  {
    scope: "update:prompts",
    reason: "Turn on identifier-first login, required for the Passkey prompt.",
    important: true,
  },
  { scope: "read:guardian_factors", reason: "Read enabled MFA factors" },
  {
    scope: "update:guardian_factors",
    reason: "Enable WebAuthn MFA factors so the MFA components have something to enroll.",
    important: true,
  },
]

// Flat scope-name list for `auth0 login --scopes` and any join operations.
const BOOTSTRAP_SCOPES = BOOTSTRAP_SCOPE_METADATA.map((s) => s.scope)

/**
 * Print the full per-scope rationale. Used by `--help` so a user who wants to
 * know why each permission is requested can expand the usage details. Important
 * scopes are marked with a star.
 */
export function printScopeUsageDetails() {
  console.log(
    `\nManagement API scopes requested at login (${BOOTSTRAP_SCOPES.length} total, ★ = key permission):\n`
  )
  for (const { scope, reason, important } of BOOTSTRAP_SCOPE_METADATA) {
    const marker = important ? "★" : " "
    console.log(`  ${marker} ${scope.padEnd(30)} ${reason}`)
  }
  console.log("")
}

/**
 * Print a summary of the scopes the bootstrap will request, shown right before
 * an interactive login prompts for consent. Important scopes are flagged with a
 * one-line reason so you know why elevated permissions are being requested; the
 * full per-scope rationale is available via `npm run auth0:bootstrap --help`.
 */
function printScopeSummary() {
  const important = BOOTSTRAP_SCOPE_METADATA.filter((s) => s.important)

  console.log(
    `\n📋 This login requests ${BOOTSTRAP_SCOPES.length} Management API scopes to configure your tenant.`
  )
  console.log(
    `   ${important.length} are key permissions that gate a user-visible feature or self-service setup:\n`
  )
  for (const { scope, reason } of important) {
    console.log(`   • ${scope}`)
    console.log(`       ↳ ${reason}`)
  }
  console.log(
    "\n   Run with --help to see the reason for every requested scope.\n"
  )
}

/**
 * Check Node.js version
 */
export function checkNodeVersion() {
  if (process.version.replace("v", "").split(".")[0] < 20) {
    console.error(
      "❌ Node.js version 20 or later is required to run this script."
    )
    process.exit(1)
  }
}

/**
 * Check Auth0 CLI is installed
 */
export async function checkAuth0CLI() {
  const cliCheck = ora({
    text: `Checking that the Auth0 CLI has been installed`,
  }).start()

  try {
    await $({ timeout: CLI_TIMEOUT })`auth0 --version`
    cliCheck.succeed()
  } catch {
    cliCheck.fail(
      "The Auth0 CLI must be installed: https://github.com/auth0/auth0-cli"
    )
    process.exit(1)
  }
}

/**
 * Read machine-to-machine (client-credentials) login parameters from the
 * environment. When all three are present the script can authenticate the CLI
 * non-interactively — no browser, no device code — which makes the bootstrap
 * fully standalone (works in CI / headless shells) and sidesteps any tenant
 * post-login Actions that only run on interactive logins.
 *
 * @param {string} domain - The tenant domain being configured (fallback for AUTH0_DOMAIN)
 * @returns {{ domain: string, clientId: string, clientSecret: string } | null}
 */
/**
 * Whether M2M client-credentials are configured (env or .env). Used by the
 * bootstrap to decide if it can safely auto-confirm in a non-interactive run.
 * @param {string} domain - The tenant domain being configured
 * @returns {boolean}
 */
export function hasMachineCredentials(domain = null) {
  return readMachineCredentials(domain) !== null
}

function readMachineCredentials(domain = null) {
  // Merge process env with an optional .env file in the scripts directory.
  // Shell `export`s often do not survive into `npm run` child processes, so a
  // local .env is the reliable channel for non-interactive credentials.
  const fileEnv = readDotEnvFile()

  const clientId = (process.env.AUTH0_CLIENT_ID || fileEnv.AUTH0_CLIENT_ID)?.trim()
  const clientSecret = (
    process.env.AUTH0_CLIENT_SECRET || fileEnv.AUTH0_CLIENT_SECRET
  )?.trim()
  const envDomain =
    (process.env.AUTH0_DOMAIN || fileEnv.AUTH0_DOMAIN)?.trim() || domain

  if (clientId && clientSecret && envDomain) {
    return { domain: envDomain, clientId, clientSecret }
  }

  return null
}

/**
 * Read a minimal KEY=VALUE .env file from the scripts directory, if present.
 * Only used to source M2M credentials; values already in process.env win.
 * Supports optional surrounding quotes and ignores comments/blank lines.
 * @returns {Record<string,string>}
 */
function readDotEnvFile() {
  try {
    const envPath = path.resolve(process.cwd(), ".env")
    if (!fs.existsSync(envPath)) return {}

    const out = {}
    for (const rawLine of fs.readFileSync(envPath, "utf-8").split("\n")) {
      const line = rawLine.trim()
      if (!line || line.startsWith("#")) continue
      const eq = line.indexOf("=")
      if (eq === -1) continue
      const key = line.slice(0, eq).trim()
      let value = line.slice(eq + 1).trim()
      // Strip a single pair of surrounding quotes.
      if (
        (value.startsWith('"') && value.endsWith('"')) ||
        (value.startsWith("'") && value.endsWith("'"))
      ) {
        value = value.slice(1, -1)
      }
      out[key] = value
    }
    return out
  } catch {
    return {}
  }
}

/**
 * Authenticate the Auth0 CLI using client credentials (machine-to-machine).
 * This is non-interactive: it runs `auth0 login --no-input --domain ...
 * --client-id ... --client-secret ...`. Requires an M2M application on the
 * tenant that is authorized for the Auth0 Management API with the bootstrap
 * scopes.
 *
 * @param {{ domain: string, clientId: string, clientSecret: string }} creds
 * @returns {Promise<boolean>} True if login was successful
 */
async function runAuth0MachineLogin(creds) {
  const spinner = ora({
    text: `Authenticating with client credentials (${creds.domain})`,
  }).start()

  try {
    const args = [
      "login",
      "--no-input",
      "--domain",
      creds.domain,
      "--client-id",
      creds.clientId,
      "--client-secret",
      creds.clientSecret,
    ]

    // Machine login is a quick token exchange; give it a generous timeout but
    // it should return in a second or two. stdio is captured (not inherited)
    // so the client secret is never echoed to the terminal.
    await execaSync("auth0", args, { timeout: 30000 })
    spinner.succeed(`Authenticated with client credentials (${creds.domain})`)
    return true
  } catch (e) {
    spinner.fail("Client-credentials login failed")
    if (e.timedOut) {
      console.error("\n❌ Machine login timed out. Please try again.")
    } else {
      // The CLI prints the useful detail (bad client-id/secret/domain) on
      // stderr; surface it without leaking the secret we passed in.
      const detail = (e.stderr || e.shortMessage || e.message || "")
        .split("\n")
        .filter((l) => !l.includes(creds.clientSecret))
        .join("\n")
        .trim()
      console.error(`\n❌ Login failed: ${detail}`)
      console.error(
        "   Verify AUTH0_CLIENT_ID / AUTH0_CLIENT_SECRET / AUTH0_DOMAIN belong"
      )
      console.error(
        "   to an M2M app authorized for the Management API on this tenant.\n"
      )
    }
    return false
  }
}

/**
 * Ensure the M2M app's Management API client grant holds every bootstrap scope,
 * self-granting the missing ones when possible.
 *
 * The chicken-and-egg: an M2M app can only add scopes to a client grant (its
 * own included) if its token already carries `update:client_grants`. Once that
 * one scope is granted in the Dashboard, the app can grant itself all the
 * others — so this closes the gap automatically on every subsequent run and no
 * further Dashboard visits are needed.
 *
 * Because the CLI's cached access token predates the PATCH, the caller must
 * re-authenticate afterwards for the new scopes to take effect — this function
 * only performs the grant and reports whether one happened.
 *
 * @param {{ domain: string, clientId: string }} creds - M2M credentials
 * @returns {Promise<boolean>} True if scopes were added (a re-login is needed)
 */
async function ensureManagementScopes(creds) {
  const audience = `https://${creds.domain}/api/v2/`

  // Find this app's Management API client grant.
  let grants
  try {
    grants = await auth0ApiCall(
      "get",
      `client-grants?client_id=${encodeURIComponent(creds.clientId)}`
    )
  } catch {
    // Reading grants itself needs read:client_grants; if we can't, stay silent
    // and let the individual apply steps report their own missing scopes.
    return false
  }

  const list = Array.isArray(grants) ? grants : grants?.client_grants || []
  const grant = list
    .filter((g) => g.audience === audience)
    .sort((a, b) => (b.scope?.length || 0) - (a.scope?.length || 0))[0]

  if (!grant) return false

  const current = new Set(grant.scope || [])
  const missing = BOOTSTRAP_SCOPES.filter((s) => !current.has(s))
  if (missing.length === 0) return false

  // We can only patch the grant if the token can write client grants.
  if (!current.has("update:client_grants")) {
    const spinner = ora({
      text: "Checking M2M Management API scopes",
    }).start()
    spinner.warn(
      `M2M app is missing ${missing.length} scope(s), including the self-grant ` +
        `permission (update:client_grants) needed to add them automatically.`
    )
    console.log(
      "\n   Grant update:client_grants once in the Dashboard and the script will\n" +
        "   self-grant the rest on the next run. Missing scopes:\n"
    )
    for (const s of missing) console.log(`     • ${s}`)
    console.log("")
    return false
  }

  const spinner = ora({
    text: `Self-granting ${missing.length} missing Management API scope(s)`,
  }).start()

  try {
    const updatedScopes = [...(grant.scope || []), ...missing]
    await auth0ApiCall("patch", `client-grants/${grant.id}`, {
      scope: updatedScopes,
    })

    // Verify the grant actually holds the new scopes before claiming success.
    const verify = await auth0ApiCall("get", `client-grants/${grant.id}`)
    const now = new Set(verify?.scope || [])
    const stillMissing = missing.filter((s) => !now.has(s))

    if (stillMissing.length > 0) {
      spinner.warn(
        `Could not self-grant: ${stillMissing.join(", ")} — grant them manually.`
      )
      return false
    }

    spinner.succeed(
      `Self-granted ${missing.length} scope(s): ${missing.join(", ")}`
    )
    return true
  } catch (e) {
    spinner.warn(`Could not self-grant missing scopes: ${e.message}`)
    return false
  }
}

/**
 * Run Auth0 CLI login interactively with the required scopes
 * @param {string} domain - Optional tenant domain to login to
 * @returns {Promise<boolean>} True if login was successful
 */
async function runAuth0Login(domain = null) {
  // Explain what is being requested before the browser consent screen appears.
  printScopeSummary()

  console.log("🔐 Starting Auth0 CLI login...\n")
  console.log("   A browser window will open for authentication.")
  console.log("   Please complete the login process.\n")

  try {
    // Build login args with required scopes
    const scopesArg = BOOTSTRAP_SCOPES.join(",")
    const args = ["login", "--scopes", scopesArg]

    // Add domain if specified
    if (domain) {
      args.push("--domain", domain)
    }

    // Run login in interactive mode (no --no-input flag).
    // Use stdio: 'inherit' to allow interactive browser-based login.
    execaSync("auth0", args, {
      stdio: "inherit",
      timeout: 120000, // 2 minute timeout for login process
    })
    return true
  } catch (e) {
    if (e.timedOut) {
      console.error("\n❌ Login timed out. Please try again.")
    } else {
      console.error(`\n❌ Login failed: ${e.message}`)
    }
    return false
  }
}

/**
 * Clear a corrupted CLI token by running `auth0 logout`. A malformed token can
 * only be fixed by logging out first; a subsequent login then succeeds.
 * @param {string} domain - Tenant to log out of (falls back to a plain logout)
 * @returns {Promise<void>}
 */
async function clearCorruptedToken(domain = null) {
  const spinner = ora({
    text: `Clearing corrupted Auth0 CLI token`,
  }).start()
  try {
    const args = domain ? ["logout", domain] : ["logout"]
    execaSync("auth0", args, { timeout: CLI_TIMEOUT })
    spinner.succeed("Cleared corrupted token — a fresh login is required")
  } catch {
    // A logout failure is non-fatal; the subsequent login attempt may still fix it.
    spinner.warn("Could not run 'auth0 logout' automatically — continuing")
  }
}

/**
 * Validate the Auth0 CLI session and, if it is expired, restore it.
 *
 * Login strategy (in priority order):
 *   1. If a valid session already exists, do nothing.
 *   2. If the stored token is corrupted, clear it with `auth0 logout` first.
 *   3. If M2M credentials are present (env or scripts/.env), authenticate
 *      non-interactively via client credentials. This keeps the bootstrap
 *      standalone (headless / CI) and avoids interactive-only post-login
 *      Actions on the tenant.
 *   4. Otherwise fall back to an interactive browser login (device code).
 *
 * @param {string} domain - Optional tenant domain (fallback for AUTH0_DOMAIN)
 * @returns {Promise<void>}
 */
export async function validateAuth0Session(domain = null) {
  const spinner = ora({
    text: `Validating Auth0 CLI session`,
  }).start()

  // When M2M credentials are available for the requested domain, authenticate
  // that specific tenant non-interactively regardless of whatever session may
  // currently be active. A valid session for a *different* tenant must not let
  // the run proceed against the wrong tenant, and re-authenticating is cheap.
  const machineCreds = readMachineCredentials(domain)
  if (machineCreds) {
    spinner.info("Using M2M client-credentials login for the requested tenant")

    // A corrupted token blocks even a fresh login until it is cleared.
    if (await isTokenCorrupted()) {
      console.log(
        "\n⚠️  The stored Auth0 CLI token is corrupted; clearing it before re-login.\n"
      )
      await clearCorruptedToken(machineCreds.domain)
    }

    console.log(
      "\n🔐 Authenticating with M2M client credentials (no browser required).\n"
    )
    const loginSuccess = await runAuth0MachineLogin(machineCreds)

    if (loginSuccess) {
      // A fresh login (or a prior logout) can leave a different tenant active.
      // Make the requested tenant active so discovery targets the right one.
      await switchToTenant(machineCreds.domain)

      const postLoginValid = await isSessionValid()
      if (postLoginValid) {
        // If the app can self-grant, top up any missing bootstrap scopes now.
        // The freshly issued token predates the grant change, so re-authenticate
        // (and re-select the tenant) for the new scopes to take effect.
        const grantedMore = await ensureManagementScopes(machineCreds)
        if (grantedMore) {
          console.log(
            "\n🔄 Re-authenticating so the newly granted scopes take effect.\n"
          )
          if (await runAuth0MachineLogin(machineCreds)) {
            await switchToTenant(machineCreds.domain)
          }
        }
        console.log("\n✅ Successfully authenticated the Auth0 CLI\n")
        return
      }
      console.error("\n❌ Session validation failed after machine login.")
      console.error(
        "   The M2M app may lack the required Management API scopes.\n"
      )
      process.exit(1)
    }

    // Machine login was attempted but failed — do not silently fall back to an
    // interactive prompt in what is meant to be a non-interactive environment.
    console.error(
      "\n❌ Client-credentials login failed. Fix the credentials/scopes and retry,"
    )
    console.error(
      "   or unset AUTH0_CLIENT_ID/SECRET to use interactive browser login.\n"
    )
    process.exit(1)
  }

  // No M2M credentials available — fall back to the interactive path. If a
  // session is already valid, nothing to do (tenant matching is verified later
  // in validateTenant).
  const sessionValid = await isSessionValid()
  if (sessionValid) {
    spinner.succeed("Auth0 CLI session is valid")
    return
  }

  spinner.warn("Auth0 CLI session appears to be expired or invalid")

  // A corrupted token cannot be refreshed — clear it before an interactive login.
  if (await isTokenCorrupted()) {
    console.log(
      "\n⚠️  The stored Auth0 CLI token is corrupted; clearing it before re-login.\n"
    )
    await clearCorruptedToken(domain)
  }

  const shouldLogin = await confirmWithUser(
    "Would you like to login to Auth0 CLI now?"
  )

  if (!shouldLogin) {
    console.error("\n❌ Cannot proceed without a valid Auth0 CLI session.")
    console.error("   Please run 'auth0 login' manually and try again.\n")
    process.exit(1)
  }

  const loginSuccess = await runAuth0Login(domain)

  if (!loginSuccess) {
    console.error("\n❌ Login was not successful. Please try again.\n")
    process.exit(1)
  }

  // Verify the session is now valid
  const postLoginValid = await isSessionValid()
  if (!postLoginValid) {
    console.error("\n❌ Session validation failed after login.")
    console.error(
      "   Please check your Auth0 CLI configuration and try again.\n"
    )
    process.exit(1)
  }

  console.log("\n✅ Successfully logged in to Auth0 CLI\n")
}

/**
 * Switch to a different tenant using `auth0 tenants use`
 * @param {string} tenantName - Tenant domain to switch to
 * @returns {Promise<boolean>} True if the switch was successful
 */
async function switchToTenant(tenantName) {
  const spinner = ora({
    text: `Switching to tenant: ${tenantName}`,
  }).start()

  try {
    await $({ timeout: CLI_TIMEOUT })`auth0 tenants use ${tenantName} --no-input`
    spinner.succeed(`Switched to tenant: ${tenantName}`)
    return true
  } catch {
    spinner.fail(`Failed to switch to tenant: ${tenantName}`)
    return false
  }
}

/**
 * Validate tenant configuration. If the requested tenant does not match the
 * active CLI tenant, the script offers to switch to it (or login to it) and
 * then retries — instead of hard-failing.
 * @param {string} tenantName - Required tenant name from command line argument
 */
export async function validateTenant(tenantName) {
  if (!tenantName) {
    console.error("\n❌ Error: Tenant name is required")
    console.error("\nUsage: npm run auth0:bootstrap <tenant-domain>")
    console.error("\nExample:")
    console.error("  npm run auth0:bootstrap my-tenant.us.auth0.com")
    console.error(
      "\nThis is a safety measure to prevent accidentally configuring the wrong tenant."
    )
    process.exit(1)
  }

  const spinner = ora({
    text: `Validating tenant: ${tenantName}`,
  }).start()

  try {
    // Get current tenant from CLI
    // NOTE: we output CSV here due to a bug in the Auth0 CLI that doesn't
    // respect the --json flag: https://github.com/auth0/auth0-cli/pull/1002
    const tenantSettingsArgs = ["tenants", "list", "--csv", "--no-input"]
    const { stdout } = await $({ timeout: CLI_TIMEOUT })`auth0 ${tenantSettingsArgs}`

    // Parse all available tenants and find the active one
    const tenantLines = stdout
      .split("\n")
      .slice(1)
      .filter((line) => line.trim())
    const availableTenants = tenantLines
      .map((line) => line.split(",")[1]?.trim())
      .filter(Boolean)

    // Get the active tenant (marked with →)
    const cliDomain = tenantLines
      .find((line) => line.includes("→"))
      ?.split(",")[1]
      ?.trim()

    if (!cliDomain) {
      spinner.fail("No active tenant found in Auth0 CLI")
      console.error("\n❌ No active tenant configured.")

      const shouldLogin = await confirmWithUser(
        `Would you like to login to ${tenantName}?`
      )

      if (shouldLogin) {
        const loginSuccess = await runAuth0Login(tenantName)
        if (loginSuccess) {
          // Retry tenant validation after login
          return validateTenant(tenantName)
        }
      }

      console.error("\n❌ Cannot proceed without an active tenant.")
      console.error("   Please run 'auth0 login' and try again.\n")
      process.exit(1)
    }

    // Verify the provided tenant name matches the CLI active tenant
    if (tenantName !== cliDomain) {
      spinner.fail("Tenant mismatch detected")
      console.error(`\n❌ Tenant mismatch:`)
      console.error(`   Requested tenant: ${tenantName}`)
      console.error(`   CLI is using:     ${cliDomain}`)

      // Check if the requested tenant is in the list of available tenants
      const tenantAvailable = availableTenants.includes(tenantName)

      if (tenantAvailable) {
        // Tenant exists, offer to switch
        console.error(`\n   The tenant "${tenantName}" is available in your CLI.`)
        const shouldSwitch = await confirmWithUser(
          `Would you like to switch to ${tenantName}?`
        )

        if (shouldSwitch) {
          const switchSuccess = await switchToTenant(tenantName)
          if (switchSuccess) {
            // Retry tenant validation after switching
            return validateTenant(tenantName)
          }
        }
      } else {
        // Tenant not in list, offer to login
        console.error(
          `\n   The tenant "${tenantName}" is not in your CLI's tenant list.`
        )
        console.error(`   You may need to login to this tenant.`)
        const shouldLogin = await confirmWithUser(
          `Would you like to login to ${tenantName}?`
        )

        if (shouldLogin) {
          const loginSuccess = await runAuth0Login(tenantName)
          if (loginSuccess) {
            // Retry tenant validation after login
            return validateTenant(tenantName)
          }
        }
      }

      console.error("\n❌ Cannot proceed with mismatched tenant.")
      console.error(
        "\nThis is a safety measure to prevent accidentally configuring the wrong tenant."
      )
      process.exit(1)
    }

    spinner.succeed(`Validated tenant: ${cliDomain}`)
    return cliDomain
  } catch (e) {
    // Handle timeout errors specifically
    if (e.timedOut) {
      spinner.fail("Auth0 CLI command timed out")
      console.error("\n❌ The Auth0 CLI is not responding.")
      console.error("   This usually means your session has expired.\n")

      const shouldLogin = await confirmWithUser(
        `Would you like to login to ${tenantName}?`
      )

      if (shouldLogin) {
        const loginSuccess = await runAuth0Login(tenantName)
        if (loginSuccess) {
          // Retry tenant validation after login
          return validateTenant(tenantName)
        }
      }

      console.error("\n❌ Cannot proceed without a valid session.")
      console.error("   Please run 'auth0 login' and try again.\n")
      process.exit(1)
    }

    spinner.fail("Failed to validate tenant")
    console.error(e)
    process.exit(1)
  }
}

/**
 * Warn (softly) if the tenant's My Account API is missing MFA scopes required
 * by the sample app. This is informational only — the bootstrap can still
 * create/enable the My Account API, and the missing scopes typically require
 * Auth0 support to enable on the tenant.
 * @param {object} resources - Discovered resources from the tenant
 * @param {string} domain - The tenant domain
 */
export function validateMyAccountScopes(resources, domain) {
  const spinner = ora({
    text: `Validating My Account API scopes`,
  }).start()

  const myAccountApi = resources.resourceServers.find(
    (rs) => rs.identifier === `https://${domain}/me/`
  )

  // If the API doesn't exist yet, the bootstrap will create it — nothing to warn about.
  if (!myAccountApi) {
    spinner.info(
      "My Account API not found — it will be created during bootstrap"
    )
    return
  }

  const availableScopes = myAccountApi.scopes?.map((s) => s.value) || []
  const missingScopes = MY_ACCOUNT_API_SCOPES.filter(
    (scope) => !availableScopes.includes(scope)
  )

  if (missingScopes.length > 0) {
    spinner.warn("Some My Account API scopes are not available on this tenant")
    console.log("")
    console.log("⚠️  My Account API")
    console.log(`   Missing scope(s):`)
    missingScopes.forEach((scope) => console.log(`     - ${scope}`))
    console.log(
      "   Suggestion: Contact Auth0 support to enable these scopes on your tenant."
    )
    console.log(
      "   The bootstrap will continue with the scopes that are available.\n"
    )
    return
  }

  spinner.succeed("My Account API scopes are available")
}

/**
 * Validate iOS project structure and extract configuration.
 * The generated Auth0.plist is written into the runnable sample app target
 * (AppUIComponents), which is where the SDK loads it from the main bundle.
 * @returns {{ bundleIdentifier: string, auth0PlistPath: string, infoPlistPath: string }}
 */
export function validateIOSProject() {
  const spinner = ora({
    text: "Validating iOS project structure",
  }).start()

  const projectRoot = path.resolve(process.cwd(), "..")
  const xcodeProjectPath = path.join(
    projectRoot,
    "Auth0UniversalComponents.xcodeproj"
  )
  const pbxprojPath = path.join(xcodeProjectPath, "project.pbxproj")
  // The sample app (AppUIComponents) is the runnable target and the bundle the
  // SDK reads Auth0.plist / Info.plist from.
  const appTargetDir = path.join(projectRoot, "AppUIComponents")
  const auth0PlistPath = path.join(appTargetDir, "Auth0.plist")
  const infoPlistPath = path.join(appTargetDir, "Info.plist")

  // Check Xcode project exists
  if (!fs.existsSync(xcodeProjectPath)) {
    spinner.fail("Could not find Auth0UniversalComponents.xcodeproj")
    console.error(
      "\n❌ This script must be run from the scripts/ directory inside the iOS project."
    )
    process.exit(1)
  }

  // Check project.pbxproj exists
  if (!fs.existsSync(pbxprojPath)) {
    spinner.fail("Could not find project.pbxproj")
    process.exit(1)
  }

  // Extract bundle identifier from project.pbxproj
  const pbxprojContent = fs.readFileSync(pbxprojPath, "utf-8")
  const bundleIdMatch = pbxprojContent.match(
    /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/
  )

  if (!bundleIdMatch) {
    spinner.fail(
      "Could not extract PRODUCT_BUNDLE_IDENTIFIER from project.pbxproj"
    )
    process.exit(1)
  }

  // Extract the AppUIComponents bundle ID (the sample app)
  const appBundleIdMatch = pbxprojContent.match(
    /PRODUCT_BUNDLE_IDENTIFIER = com\.auth0\.AppUIComponents/
  )

  const bundleIdentifier = appBundleIdMatch
    ? "com.auth0.AppUIComponents"
    : bundleIdMatch[1].trim()

  spinner.succeed(`Validated iOS project (bundle: ${bundleIdentifier})`)

  return { bundleIdentifier, auth0PlistPath, infoPlistPath }
}
