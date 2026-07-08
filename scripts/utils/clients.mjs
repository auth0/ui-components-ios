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
export const CLIENT_NAME = "iOS UI Components Demo"

/**
 * Build the allowed callback / logout URLs for the native iOS client.
 *
 * Auth0.swift derives its redirect URL from the app's bundle identifier. Both
 * forms below must be registered so login/logout resolve whether or not the app
 * has associated-domains (universal links) configured:
 *   - HTTPS universal link: https://{domain}/ios/{bundleId}/callback
 *   - Custom scheme:        {bundleId}://{domain}/ios/{bundleId}/callback
 *
 * @param {string} domain - Auth0 tenant domain
 * @param {string} bundleIdentifier - iOS app bundle identifier
 * @returns {string[]} Redirect URLs (used for both callbacks and logout URLs)
 */
export function buildRedirectUrls(domain, bundleIdentifier) {
  return [
    `https://${domain}/ios/${bundleIdentifier}/callback`,
    `${bundleIdentifier}://${domain}/ios/${bundleIdentifier}/callback`,
  ]
}

/**
 * Detect a stale iOS callback URL: any `<scheme>://{domain}/ios/{bundleId}/callback`
 * whose scheme is neither `https` nor the bundle identifier. These are leftovers
 * from earlier runs (e.g. the old hardcoded `demo://…` scheme) and should be
 * removed so the client ends up with exactly the two correct redirect URLs.
 *
 * @param {string} url - An existing callback/logout URL
 * @param {string} domain - Auth0 tenant domain
 * @param {string} bundleIdentifier - iOS app bundle identifier
 * @returns {boolean} True if the URL is a stale iOS callback for this app
 */
function isStaleIosCallback(url, domain, bundleIdentifier) {
  const suffix = `://${domain}/ios/${bundleIdentifier}/callback`
  if (!url.endsWith(suffix)) return false
  const scheme = url.slice(0, url.length - suffix.length)
  return scheme !== "https" && scheme !== bundleIdentifier
}

/**
 * Reconcile an existing URL list to the desired end state: drop any stale iOS
 * callback URLs for this app, preserve everything else, and ensure both desired
 * redirect URLs are present (de-duplicated, order-stable).
 *
 * @param {string[]} existing - Current callback/logout URLs on the client
 * @param {string[]} desired - The two correct redirect URLs
 * @param {string} domain - Auth0 tenant domain
 * @param {string} bundleIdentifier - iOS app bundle identifier
 * @returns {string[]} The reconciled URL list
 */
function reconcileRedirectUrls(existing, desired, domain, bundleIdentifier) {
  const kept = existing.filter(
    (url) =>
      !isStaleIosCallback(url, domain, bundleIdentifier) &&
      !desired.includes(url)
  )
  return [...kept, ...desired]
}

// ============================================================================
// CHECK FUNCTIONS
// ============================================================================

export async function checkDashboardClientChanges(
  existingClients,
  domain,
  iosConfig,
  myAccountApiScopes
) {
  const { bundleIdentifier } = iosConfig

  // Auth0.swift's WebAuthentication builds its redirect URL from the bundle
  // identifier, not an arbitrary scheme. The two supported forms are the
  // custom-scheme callback (scheme == bundle id) and the HTTPS universal-link
  // callback. Register BOTH as allowed callback and logout URLs so login works
  // whether or not associated domains are configured.
  const redirectUrls = buildRedirectUrls(domain, bundleIdentifier)

  const existingClient = existingClients.find(
    (c) => c.name === CLIENT_NAME && c.app_type === "native"
  )

  if (!existingClient) {
    return createChangeItem(ChangeAction.CREATE, {
      resource: "Native Client",
      name: CLIENT_NAME,
      redirectUrls,
    })
  }

  // Reconcile callback and logout URLs to the desired end state: add the two
  // correct redirects and strip stale iOS callbacks (e.g. old `demo://…`),
  // while preserving any unrelated URLs already on the client.
  const existingCallbacks = existingClient.callbacks || []
  const existingLogoutUrls = existingClient.allowed_logout_urls || []
  const desiredCallbacks = reconcileRedirectUrls(
    existingCallbacks,
    redirectUrls,
    domain,
    bundleIdentifier
  )
  const desiredLogoutUrls = reconcileRedirectUrls(
    existingLogoutUrls,
    redirectUrls,
    domain,
    bundleIdentifier
  )

  // Order-independent comparison so both additions and removals are detected.
  const sameSet = (a, b) =>
    a.length === b.length &&
    a.slice().sort().toString() === b.slice().sort().toString()
  const callbacksNeedUpdate = !sameSet(existingCallbacks, desiredCallbacks)
  const logoutUrlsNeedUpdate = !sameSet(existingLogoutUrls, desiredLogoutUrls)

  // Check if My Account API refresh token policy exists with correct scopes
  const hasMyAccountPolicy = existingClient.refresh_token?.policies?.some(
    (policy) =>
      policy.audience === `https://${domain}/me/` &&
      policy.scope?.slice().sort().toString() ===
        myAccountApiScopes.slice().sort().toString()
  )

  const refreshTokenPoliciesNeedUpdate = !hasMyAccountPolicy

  if (
    callbacksNeedUpdate ||
    logoutUrlsNeedUpdate ||
    refreshTokenPoliciesNeedUpdate
  ) {
    const updates = {}
    if (callbacksNeedUpdate) {
      updates.callbacks = desiredCallbacks
    }
    if (logoutUrlsNeedUpdate) {
      updates.allowedLogoutUrls = desiredLogoutUrls
    }
    updates.refreshTokenNeedsUpdate = refreshTokenPoliciesNeedUpdate

    const changes = []
    if (callbacksNeedUpdate) changes.push("Update callback URLs")
    if (logoutUrlsNeedUpdate) changes.push("Update logout URLs")
    if (refreshTokenPoliciesNeedUpdate) changes.push("Update refresh token policies")

    return createChangeItem(ChangeAction.UPDATE, {
      resource: "Native Client",
      name: CLIENT_NAME,
      existing: existingClient,
      redirectUrls,
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
        callbacks: changePlan.redirectUrls,
        allowed_logout_urls: changePlan.redirectUrls,
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
      // The native client is the anchor for everything downstream (client
      // grant, connection enablement, Auth0.plist). If we lack create:clients
      // we cannot continue meaningfully, so surface a clear manual action and
      // re-throw rather than pretending success.
      if (isPermissionError(e)) {
        const scope = extractMissingScope(e) || "create:clients"
        spinner.fail(`Cannot create Native Client — M2M app lacks scope: ${scope}`)
        recordManualAction({
          resource: `Native Client: ${CLIENT_NAME}`,
          scope,
          reason:
            "The native client is required for the sample app to authenticate; the rest of the bootstrap depends on it.",
          manualStep:
            "Grant create:clients to the M2M app and re-run, OR create a Native application manually in the Dashboard.",
        })
      } else {
        spinner.fail(`Failed to create Native Client`)
      }
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

      if (updates.allowedLogoutUrls) {
        updateData.allowed_logout_urls = updates.allowedLogoutUrls
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
      // A missing scope (e.g. update:clients on the M2M app) should not abort
      // the whole bootstrap. Record it as a manual action and continue with the
      // existing client so the rest of the setup still runs.
      if (isPermissionError(e)) {
        const scope = extractMissingScope(e) || "update:clients"
        spinner.warn(
          `Skipped updating Native Client — M2M app lacks scope: ${scope}`
        )
        recordManualAction({
          resource: `Native Client: ${CLIENT_NAME}`,
          scope,
          reason:
            "The native client's callback/logout URLs (and My Account refresh-token policy) must be set for the app's login/logout redirects to resolve.",
          manualStep:
            "Grant update:clients to the M2M app and re-run, OR Dashboard → Applications → <app> → Settings → set Allowed Callback URLs and Allowed Logout URLs to the two iOS redirect URLs.",
        })
        return changePlan.existing
      }
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


