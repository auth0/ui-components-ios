import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export async function checkAdminRoleChanges(
  existingRoles,
  domain,
  myAccountApiScopes
) {
  const existingRole = existingRoles.find((r) => r.name === "admin")

  if (!existingRole) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Admin Role",
      name: "admin",
      permissions: myAccountApiScopes,
      domain,
    })
  }

  // Check if permissions are correct
  try {
    const permissions = await auth0ApiCall(
      "get",
      `roles/${existingRole.id}/permissions`
    )
    const existingPermissions = (permissions || []).map(
      (p) => p.permission_name
    )
    const missingPermissions = myAccountApiScopes.filter(
      (s) => !existingPermissions.includes(s)
    )

    if (missingPermissions.length > 0) {
      return createChangeItem(ChangeAction.UPDATE, {
        resource: "Admin Role",
        name: "admin",
        existing: existingRole,
        permissions: missingPermissions,
        domain,
        summary: `Add ${missingPermissions.length} missing permissions`,
      })
    }
  } catch {
    // If we can't check permissions, skip
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "Admin Role",
    name: "admin",
    existing: existingRole,
  })
}

// ============================================================================
// APPLY FUNCTIONS
// ============================================================================

export async function applyAdminRoleChanges(changePlan) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({
      text: `Admin Role is up to date`,
    }).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora({
      text: `Creating admin role`,
    }).start()

    try {
      const createRoleArgs = [
        "roles",
        "create",
        "--name",
        "admin",
        "--description",
        "Manage the tenant configuration.",
        "--json",
        "--no-input",
      ]

      const { stdout } = await $`auth0 ${createRoleArgs}`
      const role = JSON.parse(stdout)

      // Add permissions
      const permissionsData = {
        permissions: changePlan.permissions.map((scope) => ({
          permission_name: scope,
          resource_server_identifier: `https://${changePlan.domain}/me/`,
        })),
      }

      await auth0ApiCall("post", `roles/${role.id}/permissions`, permissionsData)

      spinner.succeed(`Created admin role`)
      return role
    } catch (e) {
      spinner.fail(`Failed to create the admin role`)
      throw e
    }
  }

  if (changePlan.action === ChangeAction.UPDATE) {
    const spinner = ora({
      text: `Updating admin role permissions`,
    }).start()

    try {
      const permissionsData = {
        permissions: changePlan.permissions.map((scope) => ({
          permission_name: scope,
          resource_server_identifier: `https://${changePlan.domain}/me/`,
        })),
      }

      await auth0ApiCall(
        "post",
        `roles/${changePlan.existing.id}/permissions`,
        permissionsData
      )

      spinner.succeed(`Updated admin role permissions`)
      return changePlan.existing
    } catch (e) {
      spinner.fail(`Failed to update admin role permissions`)
      throw e
    }
  }
}
