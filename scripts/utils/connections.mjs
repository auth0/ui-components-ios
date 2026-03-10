import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

// Constants
export const DEFAULT_CONNECTION_NAME = "Username-Password-Authentication"

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

  if (missingClients.length > 0) {
    return createChangeItem(ChangeAction.UPDATE, {
      resource: "Database Connection",
      name: DEFAULT_CONNECTION_NAME,
      existing,
      updates: {
        missingClients,
      },
      summary: `Add ${missingClients.length} enabled client(s)`,
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
      text: `Adding missing enabled clients to ${DEFAULT_CONNECTION_NAME} connection`,
    }).start()

    try {
      const { existing } = changePlan
      const existingEnabledClients = existing.enabled_clients || []

      // Use the actual client IDs instead of the ones from the change plan
      const clientsToAdd = []
      if (!existingEnabledClients.includes(dashboardClientId)) {
        clientsToAdd.push(dashboardClientId)
      }

      if (clientsToAdd.length === 0) {
        spinner.succeed(
          `${DEFAULT_CONNECTION_NAME} connection already has all clients enabled`
        )
        return existing
      }

      const updatedClients = [...existingEnabledClients, ...clientsToAdd]

      await auth0ApiCall("patch", `connections/${existing.id}`, {
        enabled_clients: updatedClients,
      })
      spinner.succeed(
        `Updated ${DEFAULT_CONNECTION_NAME} connection with ${clientsToAdd.length} new enabled client(s)`
      )

      // Fetch updated connection
      const updated = await auth0ApiCall("get", `connections/${existing.id}`)
      return updated || existing
    } catch (e) {
      spinner.fail(`Failed to update ${DEFAULT_CONNECTION_NAME} connection`)
      throw e
    }
  }
}
