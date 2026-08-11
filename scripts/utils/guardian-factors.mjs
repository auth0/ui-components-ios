import ora from "ora"

import { auth0ApiCall } from "./auth0-api.mjs"
import { ChangeAction, createChangeItem } from "./change-plan.mjs"
import {
  extractMissingScope,
  isPermissionError,
  recordManualAction,
} from "./manual-actions.mjs"

// The WebAuthn Guardian factors back the Passkeys / device-biometric MFA
// components in the sample app. `webauthn-platform` = device-bound passkeys
// (Face ID / Touch ID), `webauthn-roaming` = security keys. Enabling them makes
// those MFA options selectable during step-up / enrollment in Universal Login.
const DESIRED_FACTORS = ["webauthn-platform", "webauthn-roaming"]

// ============================================================================
// CHECK
// ============================================================================

/**
 * Determine which WebAuthn MFA factors still need to be enabled.
 * @param {Array<{name:string,enabled:boolean}>} existingFactors
 * @returns {object} change item
 */
export function checkGuardianFactorChanges(existingFactors) {
  const byName = new Map(
    (existingFactors || []).map((f) => [f.name, f])
  )

  const toEnable = DESIRED_FACTORS.filter((name) => {
    const factor = byName.get(name)
    // If the factor isn't present at all we still attempt to enable it; the API
    // will tell us if it is unavailable on this tenant.
    return !factor || factor.enabled !== true
  })

  if (toEnable.length === 0) {
    return createChangeItem(ChangeAction.SKIP, {
      resource: "MFA Factors (WebAuthn/Passkey)",
    })
  }

  return createChangeItem(ChangeAction.UPDATE, {
    resource: "MFA Factors (WebAuthn/Passkey)",
    updates: { toEnable },
    summary: `Enable ${toEnable.join(", ")}`,
  })
}

// ============================================================================
// APPLY
// ============================================================================

/**
 * Enable the WebAuthn MFA factors. Each factor is toggled independently so a
 * missing entitlement on one does not block the other. Missing-scope failures
 * are recorded as manual actions rather than aborting the bootstrap.
 * @param {object} changePlan
 */
export async function applyGuardianFactorChanges(changePlan) {
  if (changePlan.action === ChangeAction.SKIP) {
    const spinner = ora({ text: `MFA factors are up to date` }).start()
    spinner.succeed()
    return
  }

  for (const factor of changePlan.updates.toEnable) {
    const spinner = ora({ text: `Enabling MFA factor: ${factor}` }).start()
    try {
      await auth0ApiCall("put", `guardian/factors/${factor}`, {
        enabled: true,
      })

      // auth0ApiCall swallows missing-scope errors (returns null), so verify.
      // NOTE: the per-factor GET (guardian/factors/:name) is not supported and
      // returns 404 — only the list endpoint reflects state, so re-list here.
      const factors = (await auth0ApiCall("get", "guardian/factors")) || []
      const current = factors.find((f) => f.name === factor)
      if (current?.enabled === true) {
        spinner.succeed(`Enabled MFA factor: ${factor}`)
      } else {
        spinner.warn(
          `Could not enable ${factor} — likely missing scope: update:guardian_factors`
        )
        recordManualAction({
          resource: `MFA Factor: ${factor}`,
          scope: "update:guardian_factors",
          reason:
            "Enables the WebAuthn/Passkey MFA option in Universal Login step-up and enrollment.",
          manualStep:
            "Dashboard → Security → Multi-factor Auth → enable WebAuthn, OR grant update:guardian_factors and re-run.",
        })
      }
    } catch (e) {
      if (isPermissionError(e)) {
        const scope = extractMissingScope(e) || "update:guardian_factors"
        spinner.warn(`Skipped ${factor} — M2M app lacks scope: ${scope}`)
        recordManualAction({
          resource: `MFA Factor: ${factor}`,
          scope,
          reason:
            "Enables the WebAuthn/Passkey MFA option in Universal Login step-up and enrollment.",
          manualStep:
            "Dashboard → Security → Multi-factor Auth → enable WebAuthn, OR grant the scope above and re-run.",
        })
        continue
      }
      spinner.fail(`Failed to enable MFA factor: ${factor}`)
      throw e
    }
  }
}
