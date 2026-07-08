#!/usr/bin/env node
import {
  applyDashboardClientChanges,
  applyMyAccountClientGrantChanges,
} from "./utils/clients.mjs"
import { applyDatabaseConnectionChanges } from "./utils/connections.mjs"
import {
  buildChangePlan,
  discoverExistingResources,
  displayChangePlan,
} from "./utils/discovery.mjs"
import { writeAuth0Plist } from "./utils/plist-writer.mjs"
import { writeInfoPlistUrlScheme } from "./utils/info-plist-writer.mjs"
import { confirmWithUser } from "./utils/helpers.mjs"
import { getManualActions } from "./utils/manual-actions.mjs"
import {
  applyConnectionProfileChanges,
  applyUserAttributeProfileChanges,
} from "./utils/profiles.mjs"
import {
  applyMyAccountResourceServerChanges,
  MY_ACCOUNT_API_SCOPES,
} from "./utils/resource-servers.mjs"
import { applyAdminRoleChanges } from "./utils/roles.mjs"
import {
  applyPromptSettingsChanges,
  applyTenantSettingsChanges,
} from "./utils/tenant-config.mjs"
import { applyGuardianFactorChanges } from "./utils/guardian-factors.mjs"
import {
  checkAuth0CLI,
  checkNodeVersion,
  hasMachineCredentials,
  printScopeUsageDetails,
  validateAuth0Session,
  validateIOSProject,
  validateMyAccountScopes,
  validateTenant,
} from "./utils/validation.mjs"
import { ChangeAction } from "./utils/change-plan.mjs"

// ============================================================================
// Main Bootstrap Flow
// ============================================================================

async function main() {
  console.log("\n🚀 Auth0 iOS UI Components - Bootstrap Script\n")

  // Parse command-line arguments
  const args = process.argv.slice(2)

  if (args.includes("--help") || args.includes("-h")) {
    console.log("Usage: npm run auth0:bootstrap <tenant-domain> [--yes]")
    console.log("\nArguments:")
    console.log(
      "  tenant-domain  Required. The Auth0 tenant domain to configure."
    )
    console.log("                 Must match your Auth0 CLI active tenant.")
    console.log("\nOptions:")
    console.log(
      "  --yes, -y      Skip the confirmation prompt and apply changes."
    )
    console.log(
      "                 Auto-enabled when M2M credentials are set and stdin is"
    )
    console.log("                 not a TTY (headless/CI). Env: AUTH0_BOOTSTRAP_YES=1")
    console.log("\nExample:")
    console.log("  npm run auth0:bootstrap my-tenant.us.auth0.com")
    console.log("\nPrerequisites:")
    console.log("  1. Install Auth0 CLI: https://github.com/auth0/auth0-cli")
    console.log(
      "\nNote: The script checks your Auth0 CLI session and, if needed, logs you"
    )
    console.log(
      "  in and switches to the requested tenant automatically."
    )
    console.log("\nNon-interactive (standalone / CI) login:")
    console.log(
      "  Set these environment variables for a Management-API M2M app and the"
    )
    console.log(
      "  script authenticates via client credentials — no browser required:"
    )
    console.log("    AUTH0_CLIENT_ID      Client ID of the M2M application")
    console.log("    AUTH0_CLIENT_SECRET  Client secret of the M2M application")
    console.log(
      "    AUTH0_DOMAIN         Tenant domain (optional; defaults to the arg)"
    )
    console.log(
      "\nNote: Tenant name is required as a safety measure to prevent accidentally"
    )
    console.log("  configuring the wrong tenant.")
    // Expand the full per-scope rationale for users who want to know why each
    // Management API permission is requested at login.
    printScopeUsageDetails()
    process.exit(0)
  }

  // Flags: --yes/-y (or AUTH0_BOOTSTRAP_YES) skip the confirm prompt. The first
  // non-flag argument is the tenant domain.
  const flags = args.filter((a) => a.startsWith("-"))
  const tenantName = args.find((a) => !a.startsWith("-"))
  const yesFlag =
    flags.includes("--yes") ||
    flags.includes("-y") ||
    process.env.AUTH0_BOOTSTRAP_YES === "1"

  // Consistent step numbering across the run. TOTAL is the count of top-level
  // steps below; bump it if you add/remove one.
  const TOTAL_STEPS = 6
  let stepNo = 0
  const step = (emoji, title) =>
    console.log(`\n${emoji} Step ${++stepNo}/${TOTAL_STEPS}: ${title}`)

  // Step 1: Validation
  step("📋", "Pre-flight Checks")
  checkNodeVersion()
  await checkAuth0CLI()
  await validateAuth0Session(tenantName)
  const domain = await validateTenant(tenantName)
  const iosConfig = validateIOSProject()
  // Auth0.swift builds the custom-scheme callback ({bundleId}://.../callback)
  // from the bundle identifier, so the Info.plist URL scheme must be the bundle
  // identifier for the OAuth redirect to reach the app.
  const scheme = iosConfig.bundleIdentifier
  iosConfig.scheme = scheme

  // Step 2: Discovery
  step("🔍", "Resource Discovery")
  const resources = await discoverExistingResources(domain)
  validateMyAccountScopes(resources, domain)

  // Step 3: Build Change Plan
  step("📝", "Analyzing Changes")
  const plan = await buildChangePlan(resources, domain, iosConfig)
  console.log("")

  // Step 4: Display Plan
  displayChangePlan(plan)

  // Flatten the plan into a single list so change detection and the end-of-run
  // summary work off the same source of truth.
  const planItems = [
    plan.tenantConfig.settings,
    plan.tenantConfig.prompts,
    plan.connectionProfile,
    plan.userAttributeProfile,
    plan.resourceServer,
    plan.clients.dashboard,
    plan.clientGrants.myAccount,
    plan.connection,
    plan.roles.admin,
    plan.guardianFactors,
  ]
  const countByAction = (action) =>
    planItems.filter((i) => i.action === action).length
  const hasChanges = planItems.some((i) => i.action !== ChangeAction.SKIP)

  if (!hasChanges) {
    console.log(
      "✅ Bootstrap complete! Tenant is already properly configured.\n"
    )
    const confirmed = await confirmWithUser(
      "Do you want to regenerate the Auth0.plist file?"
    )
    if (confirmed) {
      await writeAuth0Plist(
        domain,
        plan.clients.dashboard.existing?.client_id,
        iosConfig.auth0PlistPath
      )
      await writeInfoPlistUrlScheme(iosConfig.infoPlistPath, scheme)
      console.log("\n✅ Auth0.plist updated!\n")
    }

    process.exit(0)
  }

  // User Confirmation. Skip the prompt when --yes is set, or automatically in a
  // non-interactive M2M run (no TTY) so the "standalone/CI" path doesn't hang.
  const autoConfirm =
    yesFlag || (hasMachineCredentials(tenantName) && !process.stdin.isTTY)

  if (autoConfirm) {
    console.log(
      `\n▶️  Proceeding with ${countByAction(ChangeAction.CREATE)} create, ` +
        `${countByAction(ChangeAction.UPDATE)} update ` +
        `(auto-confirmed${yesFlag ? " via --yes" : " — non-interactive M2M run"}).`
    )
  } else {
    const confirmed = await confirmWithUser(
      "Do you want to proceed with these changes? "
    )
    if (!confirmed) {
      console.log("\n❌ Bootstrap cancelled by user.\n")
      process.exit(0)
    }
  }
  console.log("")

  // Step 4: Apply Changes
  step("⚙️ ", "Applying Changes")
  console.log("")

  // 4a. Tenant Configuration
  console.log("Configuring Tenant...")
  await applyTenantSettingsChanges(plan.tenantConfig.settings)
  await applyPromptSettingsChanges(plan.tenantConfig.prompts)
  console.log("")

  // 4b. Profiles
  console.log("Configuring Profiles...")
  const connectionProfile = await applyConnectionProfileChanges(
    plan.connectionProfile
  )
  const userAttributeProfile = await applyUserAttributeProfileChanges(
    plan.userAttributeProfile
  )
  console.log("")

  // 4c. Resource Server (My Account API)
  console.log("Configuring My Account API...")
  await applyMyAccountResourceServerChanges(plan.resourceServer, domain)
  console.log("")

  // 4d. Native Client
  console.log("Configuring Native Client...")
  const dashboardClient = await applyDashboardClientChanges(
    plan.clients.dashboard,
    connectionProfile?.id,
    userAttributeProfile?.id,
    domain,
    MY_ACCOUNT_API_SCOPES
  )
  console.log("")

  // 4e. Client Grants
  console.log("Configuring Client Grants...")
  await applyMyAccountClientGrantChanges(
    plan.clientGrants.myAccount,
    domain,
    dashboardClient.client_id
  )
  console.log("")

  // 4f. Database Connection
  console.log("Configuring Database Connection...")
  const connection = await applyDatabaseConnectionChanges(
    plan.connection,
    dashboardClient.client_id
  )
  console.log("")

  // 4g. Roles
  console.log("Configuring Roles...")
  await applyAdminRoleChanges(plan.roles.admin)
  console.log("")

  // 4h. MFA Factors (WebAuthn / Passkey)
  console.log("Configuring MFA Factors...")
  await applyGuardianFactorChanges(plan.guardianFactors)
  console.log("")

  // Step 5: Generate Auth0.plist
  step("📝", "Generating Auth0.plist")
  console.log("")
  await writeAuth0Plist(
    domain,
    dashboardClient.client_id,
    iosConfig.auth0PlistPath
  )

  // Step 6: Configure the callback URL scheme in the sample app's Info.plist
  step("📝", "Configuring URL scheme")
  console.log("")
  await writeInfoPlistUrlScheme(iosConfig.infoPlistPath, scheme)

  // Done!
  console.log("\n✅ Bootstrap complete!\n")

  // Summary of what the plan intended, plus anything that needs manual follow-up.
  const manualCount = getManualActions().length
  console.log(
    `Summary: ${countByAction(ChangeAction.CREATE)} created, ` +
      `${countByAction(ChangeAction.UPDATE)} updated, ` +
      `${countByAction(ChangeAction.SKIP)} already up to date` +
      (manualCount > 0 ? `, ${manualCount} need manual attention` : "") +
      ".\n"
  )

  reportManualActions()

  console.log("Next steps:")
  console.log("  1. Open Auth0UniversalComponents.xcodeproj in Xcode")
  console.log("  2. Select the AppUIComponents target")
  console.log(
    "  3. Build and run the sample app (Auth0.plist and the callback URL"
  )
  console.log("     scheme have already been configured for you)")
  console.log("  4. Login and explore the UI components\n")
}

/**
 * Print a consolidated list of operations that were skipped because the
 * authenticated identity lacked the required Management API scope. Each entry
 * names the scope to grant (or the dashboard step to perform) so the tenant
 * can be finished without re-running everything blindly.
 */
function reportManualActions() {
  const actions = getManualActions()
  if (actions.length === 0) return

  console.log(
    "⚠️  Some steps need manual attention (the login identity lacked the scope):\n"
  )
  actions.forEach((a, i) => {
    console.log(`  ${i + 1}. ${a.resource}`)
    if (a.scope) console.log(`     Missing scope: ${a.scope}`)
    if (a.reason) console.log(`     Why it matters: ${a.reason}`)
    if (a.manualStep) console.log(`     Fix: ${a.manualStep}`)
    console.log("")
  })
  console.log(
    "  Tip: grant the scope(s) above to your M2M app (Dashboard → Applications →"
  )
  console.log(
    "  APIs → Auth0 Management API → Machine to Machine Applications), then re-run"
  )
  console.log(
    "  the bootstrap. It is idempotent — completed resources will be skipped.\n"
  )
}

// Run the main function
main().catch((error) => {
  console.error("\n❌ Bootstrap failed:", error.message)
  process.exit(1)
})
