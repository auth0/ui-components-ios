import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

// Constants
export const MY_ACCOUNT_API_SCOPES = [
  "read:me:authentication_methods",
  "create:me:authentication_methods",
  "delete:me:authentication_methods",
  "update:me:authentication_methods",
  "read:me:connected_accounts",
  "create:me:connected_accounts",
  "delete:me:connected_accounts",
  "read:me:factors",
]

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export function checkMyAccountResourceServerChanges(
  existingResourceServers,
  domain
) {
  const identifier = `https://${domain}/me/`
  const existing = existingResourceServers.find(
    (rs) => rs.identifier === identifier
  )

  if (!existing) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "My Account API",
      identifier,
    })
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "My Account API",
    identifier,
    existing,
  })
}

// ============================================================================
// APPLY FUNCTIONS
// ============================================================================

export async function applyMyAccountResourceServerChanges(changePlan, domain) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({
      text: `My Account API is up to date`,
    }).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora({
      text: `Creating My Account API`,
    }).start()

    try {
      const createMyAccountResourceServerArgs = [
        "api",
        "post",
        "resource-servers",
        "--data",
        JSON.stringify({
          identifier: `https://${domain}/me/`,
          name: "Auth0 My Account API",
          skip_consent_for_verifiable_first_party_clients: true,
          token_dialect: "rfc9068_profile",
        }),
      ]

      const { stdout } = await $`auth0 ${createMyAccountResourceServerArgs}`
      const result = JSON.parse(stdout)
      spinner.succeed("Created My Account API")
      return result
    } catch (e) {
      spinner.fail(`Failed to create My Account API`)
      throw e
    }
  }
}
