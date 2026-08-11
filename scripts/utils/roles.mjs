import ora from "ora"

import { ChangeAction, createChangeItem } from "./change-plan.mjs"

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

/**
 * In the iOS (My Account only) flow the admin role is always a no-op.
 *
 * My Account is a System API (identifier `https://{domain}/me/`, scopes like
 * `read:me:factors`). The Management API refuses to attach System-API scopes to
 * a role — `POST roles/:id/permissions` returns
 * `400 operation_not_supported: "System APIs may not be used"`. Since every
 * scope this bootstrap manages is a `:me:` System-API scope, there is nothing
 * assignable to a role, and the sample app never uses one (My Account access is
 * granted via the client grant, not a role).
 *
 * The check therefore always returns SKIP. It is kept in the plan so the change
 * summary and idempotency logic remain uniform across resources; the earlier
 * CREATE/UPDATE code paths were dead and have been removed.
 */
export async function checkAdminRoleChanges(existingRoles) {
  const existingRole = existingRoles.find((r) => r.name === "admin")

  return createChangeItem(ChangeAction.SKIP, {
    resource: "Admin Role",
    name: "admin",
    existing: existingRole,
    reason:
      "My Account is a System API; its scopes cannot be assigned to a role",
  })
}

// ============================================================================
// APPLY FUNCTIONS
// ============================================================================

export async function applyAdminRoleChanges(changePlan) {
  // Only SKIP is ever produced by checkAdminRoleChanges (see note above).
  const spinner = ora({ text: `Admin Role is up to date` }).start()
  spinner.succeed()
  return changePlan.existing
}
