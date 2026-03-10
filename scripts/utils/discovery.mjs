import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import {
  checkConnectionProfileChanges,
  checkUserAttributeProfileChanges,
} from "./profiles.mjs"
import {
  checkDashboardClientChanges,
  checkMyAccountClientGrantChanges,
} from "./clients.mjs"
import { checkDatabaseConnectionChanges } from "./connections.mjs"
import {
  checkMyAccountResourceServerChanges,
  MY_ACCOUNT_API_SCOPES,
} from "./resource-servers.mjs"
import { checkAdminRoleChanges } from "./roles.mjs"
import {
  checkTenantSettingsChanges,
  checkPromptSettingsChanges,
} from "./tenant-config.mjs"
import { ChangeAction } from "./change-plan.mjs"

// ============================================================================
// Resource Discovery
// ============================================================================

export async function discoverExistingResources(domain) {
  const spinner = ora({
    text: `Discovering existing resources in tenant`,
  }).start()

  try {
    // Query all resources
    let clients = []
    try {
      const clientsArgs = ["apps", "list", "--json", "--no-input"]
      const { stdout } = await $`auth0 ${clientsArgs}`
      clients = stdout ? JSON.parse(stdout) : []
    } catch {
      clients = []
    }

    let roles = []
    try {
      const rolesArgs = ["roles", "list", "--json", "--no-input"]
      const { stdout } = await $`auth0 ${rolesArgs}`
      roles = stdout ? JSON.parse(stdout) : []
    } catch {
      roles = []
    }

    let connections = []
    try {
      connections = (await auth0ApiCall("get", "connections")) || []
    } catch {
      connections = []
    }

    let resourceServers = []
    try {
      const rsArgs = ["apis", "list", "--json", "--no-input"]
      const { stdout } = await $`auth0 ${rsArgs}`
      resourceServers = stdout ? JSON.parse(stdout) : []
    } catch {
      resourceServers = []
    }

    let clientGrants = []
    try {
      clientGrants = (await auth0ApiCall("get", "client-grants")) || []
    } catch {
      clientGrants = []
    }

    let connectionProfiles = []
    try {
      const cpResult = await auth0ApiCall("get", "connection-profiles")
      connectionProfiles = cpResult?.connection_profiles || []
    } catch {
      connectionProfiles = []
    }

    let userAttributeProfiles = []
    try {
      const uapResult = await auth0ApiCall("get", "user-attribute-profiles")
      userAttributeProfiles = uapResult?.user_attribute_profiles || []
    } catch {
      userAttributeProfiles = []
    }

    spinner.succeed("Discovered existing resources")

    return {
      clients,
      roles,
      connections,
      resourceServers,
      clientGrants,
      connectionProfiles,
      userAttributeProfiles,
    }
  } catch (e) {
    spinner.fail("Failed to discover existing resources")
    throw e
  }
}

// ============================================================================
// Build Change Plan
// ============================================================================

export async function buildChangePlan(resources, domain, iosConfig) {
  const plan = {
    connectionProfile: null,
    userAttributeProfile: null,
    clients: { dashboard: null },
    clientGrants: { myAccount: null },
    connection: null,
    resourceServer: null,
    roles: { admin: null },
    tenantConfig: {
      settings: null,
      prompts: null,
    },
  }

  // Profiles
  plan.connectionProfile = checkConnectionProfileChanges(
    resources.connectionProfiles
  )
  plan.userAttributeProfile = checkUserAttributeProfileChanges(
    resources.userAttributeProfiles
  )

  // Client
  plan.clients.dashboard = await checkDashboardClientChanges(
    resources.clients,
    domain,
    iosConfig,
    MY_ACCOUNT_API_SCOPES
  )

  // Resource Server
  plan.resourceServer = checkMyAccountResourceServerChanges(
    resources.resourceServers,
    domain
  )

  // Get client IDs (either existing or will be created)
  const dashboardClientId =
    plan.clients.dashboard.existing?.client_id || "TO_BE_CREATED"
  plan.clientGrants.myAccount = checkMyAccountClientGrantChanges(
    dashboardClientId,
    resources.clientGrants,
    domain,
    MY_ACCOUNT_API_SCOPES
  )

  // Connection
  plan.connection = checkDatabaseConnectionChanges(
    resources.connections,
    dashboardClientId
  )

  // Roles
  plan.roles.admin = await checkAdminRoleChanges(
    resources.roles,
    domain,
    MY_ACCOUNT_API_SCOPES
  )

  // Tenant Config
  plan.tenantConfig.settings = await checkTenantSettingsChanges()
  plan.tenantConfig.prompts = await checkPromptSettingsChanges()

  return plan
}

// ============================================================================
// Display Change Plan
// ============================================================================

export function displayChangePlan(plan) {
  console.log("📋 Change Plan Summary:\n")

  const items = [
    { name: "Tenant Settings", ...plan.tenantConfig.settings },
    { name: "Prompt Settings", ...plan.tenantConfig.prompts },
    { name: "Connection Profile", ...plan.connectionProfile },
    { name: "User Attribute Profile", ...plan.userAttributeProfile },
    { name: "My Account API", ...plan.resourceServer },
    { name: "Native Client", ...plan.clients.dashboard },
    { name: "Client Grant (My Account)", ...plan.clientGrants.myAccount },
    { name: "Database Connection", ...plan.connection },
    { name: "Admin Role", ...plan.roles.admin },
  ]

  for (const item of items) {
    const icon =
      item.action === ChangeAction.CREATE
        ? "🆕"
        : item.action === ChangeAction.UPDATE
          ? "🔄"
          : "✅"
    const label =
      item.action === ChangeAction.CREATE
        ? "CREATE"
        : item.action === ChangeAction.UPDATE
          ? "UPDATE"
          : "SKIP  "

    let detail = ""
    if (item.summary) {
      detail = ` (${item.summary})`
    } else if (item.callbackUrl) {
      detail = ` (callback: ${item.callbackUrl})`
    }

    console.log(`  ${icon} [${label}] ${item.name || item.resource}${detail}`)
  }
  console.log("")
}
