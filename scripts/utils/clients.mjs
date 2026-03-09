import { $ } from "execa"
import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"

// Constants
export const CLIENT_NAME = "iOS UI Components Demo"

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export async function checkDashboardClientChanges(
  existingClients,
  domain,
  iosConfig,
  myAccountApiScopes
) {
  const { bundleIdentifier, scheme } = iosConfig
  const callbackUrl = `${scheme}://${domain}/ios/${bundleIdentifier}/callback`

  const existingClient = existingClients.find(
    (c) => c.name === CLIENT_NAME && c.app_type === "native"
  )

  if (!existingClient) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Native Client",
      name: CLIENT_NAME,
      callbackUrl,
    })
  }

  // Check if callback URL needs updating
  const existingCallbacks = existingClient.callbacks || []
  const hasCorrectCallback = existingCallbacks.includes(callbackUrl)

  // Check if My Account API refresh token policy exists with correct scopes
  const hasMyAccountPolicy = existingClient.refresh_token?.policies?.some(
    (policy) =>
      policy.audience === `https://${domain}/me/` &&
      policy.scope?.slice().sort().toString() ===
        myAccountApiScopes.slice().sort().toString()
  )

  const refreshTokenPoliciesNeedUpdate = !hasMyAccountPolicy

  if (!hasCorrectCallback || refreshTokenPoliciesNeedUpdate) {
    const updates = {}
    if (!hasCorrectCallback) {
      updates.callbacks = [...existingCallbacks, callbackUrl]
    }
    updates.refreshTokenNeedsUpdate = refreshTokenPoliciesNeedUpdate

    const changes = []
    if (!hasCorrectCallback) changes.push("Update callback URL")
    if (refreshTokenPoliciesNeedUpdate) changes.push("Update refresh token policies")

    return createChangeItem(ChangeAction.UPDATE, {
      resource: "Native Client",
      name: CLIENT_NAME,
      existing: existingClient,
      callbackUrl,
      updates,
      summary: changes.join(", "),
    })
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "Native Client",
    name: CLIENT_NAME,
    existing: existingClient,
  })
}

// ============================================================================
// APPLY FUNCTIONS
// ============================================================================

export async function applyDashboardClientChanges(
  changePlan,
  connectionProfileId,
  userAttributeProfileId,
  domain,
  myAccountApiScopes
) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({
      text: `Native Client is up to date: ${changePlan.name}`,
    }).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora({
      text: `Creating Native Client: ${CLIENT_NAME}`,
    }).start()

    try {
      const clientData = {
        name: CLIENT_NAME,
        description:
          "Native client for Auth0 iOS UI Components sample app",
        app_type: "native",
        oidc_conformant: true,
        is_first_party: true,
        callbacks: [changePlan.callbackUrl],
        allowed_logout_urls: [changePlan.callbackUrl],
        grant_types: ["authorization_code", "refresh_token"],
        token_endpoint_auth_method: "none",
        jwt_configuration: {
          alg: "RS256",
          lifetime_in_seconds: 36000,
        },
        refresh_token: {
          rotation_type: "rotating",
          expiration_type: "expiring",
          token_lifetime: 2592000,
          idle_token_lifetime: 1296000,
          policies: [
            {
              audience: `https://${domain}/me/`,
              scope: myAccountApiScopes,
            },
          ],
        },
      }

      const createClientArgs = [
        "api",
        "post",
        "clients",
        "--data",
        JSON.stringify(clientData),
      ]

      const { stdout } = await $`auth0 ${createClientArgs}`
      const client = JSON.parse(stdout)

      spinner.succeed(`Created Native Client: ${CLIENT_NAME}`)
      return client
    } catch (e) {
      spinner.fail(`Failed to create Native Client`)
      throw e
    }
  }

  if (changePlan.action === ChangeAction.UPDATE) {
    const spinner = ora({
      text: `Updating Native Client: ${CLIENT_NAME}`,
    }).start()

    try {
      const { existing, updates } = changePlan
      const updateData = {}

      if (updates.callbacks) {
        updateData.callbacks = updates.callbacks
      }

      if (updates.refreshTokenNeedsUpdate) {
        const desiredMyAccountPolicy = {
          audience: `https://${domain}/me/`,
          scope: myAccountApiScopes,
        }

        const existingPolicies = existing.refresh_token?.policies || []

        const hasMyAccountPolicy = existingPolicies.some(
          (policy) =>
            policy.audience === desiredMyAccountPolicy.audience &&
            policy.scope?.slice().sort().toString() ===
              myAccountApiScopes.slice().sort().toString()
        )

        let newPolicies = [...existingPolicies]
        if (!hasMyAccountPolicy) {
          // Remove any existing My Account policy with wrong scopes
          newPolicies = newPolicies.filter(
            (p) => p.audience !== desiredMyAccountPolicy.audience
          )
          newPolicies.push(desiredMyAccountPolicy)
        }

        updateData.refresh_token = {
          ...(existing.refresh_token || {}),
          policies: newPolicies,
        }
      }

      const updateArgs = [
        "api",
        "patch",
        `clients/${existing.client_id}`,
        "--data",
        JSON.stringify(updateData),
      ]

      await $`auth0 ${updateArgs}`

      // Fetch updated client
      const getArgs = [
        "api",
        "get",
        `clients/${existing.client_id}`,
      ]
      const { stdout } = await $`auth0 ${getArgs}`
      const client = JSON.parse(stdout)

      spinner.succeed(`Updated Native Client: ${CLIENT_NAME}`)
      return client
    } catch (e) {
      spinner.fail(`Failed to update Native Client`)
      throw e
    }
  }
}

/**
 * Check if My Account API Client Grant needs changes
 */
export function checkMyAccountClientGrantChanges(
  clientId,
  existingClientGrants,
  domain,
  myAccountApiScopes
) {
  const existingGrant = existingClientGrants.find(
    (g) =>
      g.client_id === clientId && g.audience === `https://${domain}/me/`
  )

  if (!existingGrant) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "My Account API Client Grant",
      clientId,
      scopes: myAccountApiScopes,
    })
  }

  // Check if we need to add any missing scopes
  const existingScopes = existingGrant.scope || []
  const missingScopes = myAccountApiScopes.filter(
    (scope) => !existingScopes.includes(scope)
  )

  if (missingScopes.length > 0) {
    return createChangeItem(ChangeAction.UPDATE, {
      resource: "My Account API Client Grant",
      existing: existingGrant,
      updates: {
        missingScopes,
      },
      summary: `Add ${missingScopes.length} scope(s)`,
    })
  }

  return createChangeItem(ChangeAction.SKIP, {
    resource: "My Account API Client Grant",
    existing: existingGrant,
  })
}

/**
 * Apply client grant changes for My Account API
 */
export async function applyMyAccountClientGrantChanges(
  changePlan,
  domain,
  clientId
) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({
      text: `My Account API Client Grant is up to date`,
    }).start()
    spinner.succeed()
    return changePlan.existing
  }

  if (changePlan.action === ChangeAction.CREATE) {
    const spinner = ora({
      text: `Creating ${CLIENT_NAME} client grants for My Account API`,
    }).start()

    try {
      // prettier-ignore
      const createClientGrantArgs = [
        "api", "post", "client-grants",
        "--data", JSON.stringify({
          client_id: clientId,
          audience: `https://${domain}/me/`,
          scope: changePlan.scopes,
          subject_type: "user"
        }),
      ];

      await $`auth0 ${createClientGrantArgs}`
      spinner.succeed(`Created My Account API Client Grant`)
    } catch (e) {
      spinner.fail(
        `Failed to create the ${CLIENT_NAME} client grants for My Account API`
      )
      throw e
    }
  }

  if (changePlan.action === ChangeAction.UPDATE) {
    const spinner = ora({
      text: `Adding missing scopes to My Account API Client Grant`,
    }).start()

    try {
      const { existing, updates } = changePlan
      const existingScopes = existing.scope || []
      const updatedScopes = [...existingScopes, ...updates.missingScopes]

      await auth0ApiCall("patch", `client-grants/${existing.id}`, {
        scope: updatedScopes,
      })
      spinner.succeed(
        `Updated My Account API Client Grant with ${updates.missingScopes.length} new scope(s)`
      )
      return existing
    } catch (e) {
      spinner.fail(`Failed to update My Account API Client Grant`)
      throw e
    }
  }
}


