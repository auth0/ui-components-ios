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

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export function checkDatabaseConnectionChanges(
  existingConnections,
  dashboardClientId
) {
  const existing = existingConnections.find(
    (c) => c.name === DEFAULT_CONNECTION_NAME
  )

  const desiredEnabledClients = [dashboardClientId]

  if (!existing) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      enabledClients: desiredEnabledClients,
    })
  }

  // Check if we need to add any missing enabled clients
  const existingEnabledClients = existing.enabled_clients || []
  const missingClients = desiredEnabledClients.filter(
    (clientId) => !existingEnabledClients.includes(clientId)
  )

  // Check whether passkeys are enabled on the connection. If not, the sample
  // app's Passkeys UI component has nothing to surface in Universal Login.
  const passkeyEnabled =
    existing.options?.authentication_methods?.passkey?.enabled === true

  const changes = []
  if (missingClients.length > 0) {
    changes.push(`Add ${missingClients.length} enabled client(s)`)
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
        missingClients,
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
      const connectionData = {
        strategy: "auth0",
        name: DEFAULT_CONNECTION_NAME,
        display_name: "Universal-Components",
        enabled_clients: [dashboardClientId],
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
      const existingEnabledClients = existing.enabled_clients || []

      // Use the actual client IDs instead of the ones from the change plan
      const clientsToAdd = []
      if (!existingEnabledClients.includes(dashboardClientId)) {
        clientsToAdd.push(dashboardClientId)
      }

      // Build the patch: enable the client and/or turn on the passkey method.
      const patchData = {}

      if (clientsToAdd.length > 0) {
        patchData.enabled_clients = [...existingEnabledClients, ...clientsToAdd]
      }

      if (updates?.enablePasskey) {
        // Merge with existing options so we don't clobber other settings.
        const existingOptions = existing.options || {}
        patchData.options = {
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
        }
      }

      if (Object.keys(patchData).length === 0) {
        spinner.succeed(`${DEFAULT_CONNECTION_NAME} connection is already up to date`)
        return existing
      }

      await auth0ApiCall("patch", `connections/${existing.id}`, patchData)

      // auth0ApiCall swallows missing-scope errors (returns null instead of
      // throwing), so a "success" here is not proof the change landed. Re-read
      // the connection and verify the intended state actually applied; if not,
      // treat it as a manual action rather than reporting a false success.
      const updated =
        (await auth0ApiCall("get", `connections/${existing.id}`)) || existing

      const clientApplied =
        !patchData.enabled_clients ||
        (updated.enabled_clients || []).includes(dashboardClientId)
      const passkeyApplied =
        !patchData.options ||
        updated.options?.authentication_methods?.passkey?.enabled === true

      if (clientApplied && passkeyApplied) {
        const applied = []
        if (patchData.enabled_clients) applied.push(`${clientsToAdd.length} client(s)`)
        if (patchData.options) applied.push("passkey method")
        spinner.succeed(
          `Updated ${DEFAULT_CONNECTION_NAME} connection (${applied.join(", ")})`
        )
        return updated
      }

      spinner.warn(`Could not fully update ${DEFAULT_CONNECTION_NAME} connection`)

      if (!clientApplied) {
        recordManualAction({
          resource: `Connection: ${DEFAULT_CONNECTION_NAME} (enable app)`,
          scope: "update:connections",
          reason:
            "The native app must be an enabled client of this database connection for username/password login to work.",
          manualStep:
            "Dashboard → Authentication → Database → Applications → enable the app, OR grant update:connections and re-run.",
        })
      }
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
