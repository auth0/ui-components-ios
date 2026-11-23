import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"
import {
  extractMissingScope,
  isPermissionError,
  recordManualAction,
} from "./manual-actions.mjs"

// Constants
export const DEFAULT_CONNECTION_NAME = "Username-Password-Authentication"

// Passkeys are a first-class authentication method for the sample app's MFA /
// Passkeys UI components. Enabling them on the database connection is what makes
// the "Passkey" option appear in Universal Login (alongside identifier-first).
// `passkey_options` mirror Auth0's recommended progressive-enrollment defaults.
const PASSKEY_CONNECTION_OPTIONS = {
  authentication_methods: {
    password: { enabled: true },
    passkey: { enabled: true },
  },
  passkey_options: {
    challenge_ui: "both",
    local_enrollment_enabled: true,
    progressive_enrollment_enabled: true,
  },
}


/**
 * Read every client enabled on a connection, following the opaque checkpoint
 * cursor (`next` is omitted on the last page).
 *
 * @param {string} connectionId
 * @returns {Promise<Array<{client_id: string, status?: boolean}>|null>} The
 *   enabled-client entries, or `null` when the read is unauthorized (missing
 *   scope). `null` means "unknown" — NOT "none enabled" — so callers must not
 *   treat it as an empty list.
 */
async function getConnectionEnabledClients(connectionId) {
  const all = []
  let from

  // Bounded loop: a safety cap so a malformed/looping cursor can never hang.
  for (let page = 0; page < 100; page++) {
    const params = new URLSearchParams({ take: "100" })
    if (from) params.set("from", from)

    const result = await auth0ApiCall(
      "get",
      `connections/${connectionId}/clients?${params}`
    )

    // Missing scope → unknown, not empty.
    if (result === null) return null

    // Newer API returns { clients, next }; tolerate a bare array too.
    if (Array.isArray(result)) {
      all.push(...result)
      break
    }
    all.push(...(result.clients || []))
    from = result.next
    if (!from) break
  }

  return all
}

/**
 * Enable a client on a connection via the additive connections/{id}/clients
 * sub-resource, then verify by re-reading (the PATCH returns 204 with no body,
 * so there is nothing to inspect). Additive: other enabled clients keep their
 * state. Records a manual action and returns false when the change cannot be
 * confirmed rather than reporting a false success.
 *
 * @param {string} connectionId
 * @param {string} clientId
 * @returns {Promise<boolean>} Whether the client is confirmed enabled
 */
async function ensureClientEnabledOnConnection(connectionId, clientId) {
  await auth0ApiCall("patch", `connections/${connectionId}/clients`, [
    { client_id: clientId, status: true },
  ])

  const enabledClients = await getConnectionEnabledClients(connectionId)
  const applied =
    enabledClients !== null &&
    enabledClients.some((c) => c.client_id === clientId && c.status !== false)

  if (!applied) {
    recordManualAction({
      resource: `Connection: ${DEFAULT_CONNECTION_NAME} (enable app)`,
      scope: "update:connections",
      reason:
        "The native app must be an enabled client of this database connection for username/password login to work.",
      manualStep:
        "Dashboard → Authentication → Database → Applications → enable the app, OR grant update:connections and re-run.",
    })
  }

  return applied
}

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export async function checkDatabaseConnectionChanges(
  existingConnections,
  dashboardClientId
) {
  const existing = existingConnections.find(
    (c) => c.name === DEFAULT_CONNECTION_NAME
  )

  if (!existing) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      enabledClients: [dashboardClientId],
    })
  }

  // Whether the native app is enabled on the connection is read from the
  // connections/{id}/clients sub-resource, NOT the deprecated `enabled_clients`
  // field (see §3.2). When the native client does not exist yet the id is the
  // "TO_BE_CREATED" placeholder, so its enablement verdict here is meaningless:
  // force the connection into the apply path and let apply re-resolve it with
  // the real client id (§3.3).
  let clientEnabled
  if (dashboardClientId === "TO_BE_CREATED") {
    clientEnabled = false
  } else {
    const enabledClients = await getConnectionEnabledClients(existing.id)
    // `null` means "unknown" (missing scope), not "none enabled" — don't plan a
    // change we can neither justify nor verify.
    clientEnabled =
      enabledClients === null ||
      enabledClients.some(
        (c) => c.client_id === dashboardClientId && c.status !== false
      )
  }

  // Check whether passkeys are enabled on the connection. If not, the sample
  // app's Passkeys UI component has nothing to surface in Universal Login.
  const passkeyEnabled =
    existing.options?.authentication_methods?.passkey?.enabled === true

  const changes = []
  if (!clientEnabled) {
    changes.push("Enable native app on connection")
  }
  if (!passkeyEnabled) {
    changes.push("Enable passkey authentication method")
  }

  if (changes.length > 0) {
    return createChangeItem(ChangeAction.UPDATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      existing,
      updates: {
        enableClient: !clientEnabled,
        enablePasskey: !passkeyEnabled,
      },
      summary: changes.join(", "),
    })
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "Database Connection",
    name: DEFAULT_CONNECTION_NAME,
    existing,
  })
}

// ============================================================================
// APPLY FUNCTIONS
// ============================================================================

export async function applyDatabaseConnectionChanges(
  changePlan,
  dashboardClientId
) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({
      text: `Database Connection is up to date: ${changePlan.name}`,
    }).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora({
      text: `Creating Database Connection: ${DEFAULT_CONNECTION_NAME}`,
    }).start()

    try {
      // `enabled_clients` in the body is deprecated and rejected by the API
      // (400 invalid_body). Create the connection, then enable the app through
      // the connections/{id}/clients sub-resource below (§3.2).
      const connectionData = {
        strategy: "auth0",
        name: DEFAULT_CONNECTION_NAME,
        display_name: "Universal-Components",
        options: PASSKEY_CONNECTION_OPTIONS,
      }

      const createArgs = [
        "api",
        "post",
        "connections",
        "--data",
        JSON.stringify(connectionData),
      ]

      const { stdout } = await $`auth0 ${createArgs}`
      const connection = JSON.parse(stdout)

      spinner.succeed(`Created Database Connection: ${DEFAULT_CONNECTION_NAME}`)

      // Enable the native app on the freshly created connection. A failure here
      // is recorded as a manual action (not fatal) — the connection exists.
      await ensureClientEnabledOnConnection(connection.id, dashboardClientId)

      return connection
    } catch (e) {
      spinner.fail(`Failed to create Database Connection`)
      throw e
    }
  }

  if (changePlan.action === ChangeAction.UPDATE) {
    const spinner = ora({
      text: `Updating ${DEFAULT_CONNECTION_NAME} connection`,
    }).start()

    try {
      const { existing, updates } = changePlan

      let clientApplied = true
      let passkeyApplied = true
      let updated = existing
      const applied = []

      // Enable the native app via the additive sub-resource — never the
      // deprecated enabled_clients body field, which the API rejects with 400
      // invalid_body (§3.2). A failed enable records its own manual action.
      if (updates?.enableClient) {
        clientApplied = await ensureClientEnabledOnConnection(
          existing.id,
          dashboardClientId
        )
        if (clientApplied) applied.push("app enabled")
      }

      // Turn on the passkey method by merging into the connection's existing
      // options so we don't clobber password policy, attributes, or MFA config.
      if (updates?.enablePasskey) {
        const existingOptions = existing.options || {}
        const patchData = {
          options: {
            ...existingOptions,
            authentication_methods: {
              ...(existingOptions.authentication_methods || {}),
              password: { enabled: true },
              passkey: { enabled: true },
            },
            passkey_options: {
              ...PASSKEY_CONNECTION_OPTIONS.passkey_options,
              ...(existingOptions.passkey_options || {}),
            },
          },
        }

        await auth0ApiCall("patch", `connections/${existing.id}`, patchData)

        // auth0ApiCall swallows missing-scope errors (returns null instead of
        // throwing), so a "success" here is not proof the change landed. Re-read
        // the connection and verify the method actually applied; if not, treat
        // it as a manual action rather than reporting a false success.
        updated =
          (await auth0ApiCall("get", `connections/${existing.id}`)) || existing
        passkeyApplied =
          updated.options?.authentication_methods?.passkey?.enabled === true
        if (passkeyApplied) applied.push("passkey method")
      }

      if (clientApplied && passkeyApplied) {
        spinner.succeed(
          `Updated ${DEFAULT_CONNECTION_NAME} connection${applied.length ? ` (${applied.join(", ")})` : ""
          }`
        )
        return updated
      }

      spinner.warn(`Could not fully update ${DEFAULT_CONNECTION_NAME} connection`)

      // The client manual action (if any) was recorded inside
      // ensureClientEnabledOnConnection; only the passkey one is handled here.
      if (!passkeyApplied) {
        // Writing the connection `options` object (which is where the passkey
        // authentication method lives) requires update:connections_options —
        // a scope distinct from update:connections. When it is missing the CLI
        // reports an empty "lacks scope: ." because it cannot render the newer
        // scope name, so we name it explicitly here.
        recordManualAction({
          resource: `Connection: ${DEFAULT_CONNECTION_NAME} (enable passkeys)`,
          scope: "update:connections_options",
          reason:
            "Passkey must be enabled on the connection for the Passkey login option to appear in Universal Login. Writing connection options requires update:connections_options (separate from update:connections).",
          manualStep:
            "Grant update:connections_options to the M2M app and re-run, OR Dashboard → Authentication → Database → <connection> → Authentication Methods → toggle Passkey on.",
        })
      }
      return updated
    } catch (e) {
      if (isPermissionError(e)) {
        const scope = extractMissingScope(e) || "update:connections"
        spinner.warn(
          `Skipped updating ${DEFAULT_CONNECTION_NAME} — M2M app lacks scope: ${scope}`
        )
        recordManualAction({
          resource: `Connection: ${DEFAULT_CONNECTION_NAME}`,
          scope,
          reason:
            "The native app must be an enabled client of this connection and passkeys enabled for the full login experience.",
          manualStep:
            "Dashboard → Authentication → Database → enable the app + toggle Passkey, OR grant the scope above and re-run.",
        })
        return changePlan.existing
      }
      spinner.fail(`Failed to update ${DEFAULT_CONNECTION_NAME} connection`)
      throw e
    }
  }
}
