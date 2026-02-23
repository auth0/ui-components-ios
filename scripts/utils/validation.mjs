import { $ } from "execa"
import ora from "ora"
import fs from "node:fs"
import path from "node:path"

/**
 * Check Node.js version
 */
export function checkNodeVersion() {
  if (process.version.replace("v", "").split(".")[0] < 20) {
    console.error(
      "❌ Node.js version 20 or later is required to run this script."
    )
    process.exit(1)
  }
}

/**
 * Check Auth0 CLI is installed
 */
export async function checkAuth0CLI() {
  const cliCheck = ora({
    text: `Checking that the Auth0 CLI has been installed`,
  }).start()

  try {
    await $`auth0 --version`
    cliCheck.succeed()
  } catch {
    cliCheck.fail(
      "The Auth0 CLI must be installed: https://github.com/auth0/auth0-cli"
    )
    process.exit(1)
  }
}

/**
 * Validate tenant configuration
 * @param {string} tenantName - Required tenant name from command line argument
 */
export async function validateTenant(tenantName) {
  if (!tenantName) {
    console.error("\n❌ Error: Tenant name is required")
    console.error("\nUsage: npm run auth0:bootstrap <tenant-domain>")
    console.error("\nExample:")
    console.error("  npm run auth0:bootstrap my-tenant.us.auth0.com")
    console.error(
      "\nThis is a safety measure to prevent accidentally configuring the wrong tenant."
    )
    process.exit(1)
  }

  const spinner = ora({
    text: `Validating tenant: ${tenantName}`,
  }).start()

  try {
    const tenantSettingsArgs = ["tenants", "list", "--csv"]
    const { stdout } = await $`auth0 ${tenantSettingsArgs}`

    const cliDomain = stdout
      .split("\n")
      .slice(1)
      .find((line) => line.includes("→"))
      ?.split(",")[1]
      ?.trim()

    if (!cliDomain) {
      spinner.fail("No active tenant found in Auth0 CLI")
      console.error("\n❌ Please login to Auth0 CLI first:")
      console.error("  1. Run: auth0 login")
      console.error(
        "  2. If you have multiple tenants, run: auth0 tenants use <tenant-domain>"
      )
      process.exit(1)
    }

    if (tenantName !== cliDomain) {
      spinner.fail("Tenant mismatch detected")
      console.error(`\n❌ Tenant mismatch:`)
      console.error(`  Requested tenant: ${tenantName}`)
      console.error(`  CLI is using:     ${cliDomain}`)
      console.error("\nPlease ensure you're using the correct tenant:")
      console.error(`  Run: auth0 tenants use ${tenantName}`)
      console.error(
        "\nThis is a safety measure to prevent accidentally configuring the wrong tenant."
      )
      process.exit(1)
    }

    spinner.succeed(`Validated tenant: ${cliDomain}`)
    return cliDomain
  } catch (e) {
    spinner.fail("Failed to validate tenant")
    console.error(e)
    process.exit(1)
  }
}

/**
 * Validate iOS project structure and extract configuration
 * @returns {{ bundleIdentifier: string, auth0PlistPath: string }}
 */
export function validateIOSProject() {
  const spinner = ora({
    text: "Validating iOS project structure",
  }).start()

  const projectRoot = path.resolve(process.cwd(), "..")
  const xcodeProjectPath = path.join(projectRoot, "Auth0UIComponents.xcodeproj")
  const pbxprojPath = path.join(xcodeProjectPath, "project.pbxproj")
  const auth0PlistPath = path.join(projectRoot, "AppUIComponents", "Auth0.plist")

  // Check Xcode project exists
  if (!fs.existsSync(xcodeProjectPath)) {
    spinner.fail("Could not find Auth0UIComponents.xcodeproj")
    console.error(
      "\n❌ This script must be run from the scripts/ directory inside the iOS project."
    )
    process.exit(1)
  }

  // Check project.pbxproj exists
  if (!fs.existsSync(pbxprojPath)) {
    spinner.fail("Could not find project.pbxproj")
    process.exit(1)
  }

  // Extract bundle identifier from project.pbxproj
  const pbxprojContent = fs.readFileSync(pbxprojPath, "utf-8")
  const bundleIdMatch = pbxprojContent.match(
    /PRODUCT_BUNDLE_IDENTIFIER = ([^;]+);/
  )

  if (!bundleIdMatch) {
    spinner.fail("Could not extract PRODUCT_BUNDLE_IDENTIFIER from project.pbxproj")
    process.exit(1)
  }

  // Extract the AppUIComponents bundle ID (the sample app)
  const appBundleIdMatch = pbxprojContent.match(
    /PRODUCT_BUNDLE_IDENTIFIER = com\.auth0\.AppUIComponents/
  )

  const bundleIdentifier = appBundleIdMatch
    ? "com.auth0.AppUIComponents"
    : bundleIdMatch[1].trim()

  spinner.succeed(
    `Validated iOS project (bundle: ${bundleIdentifier})`
  )

  return { bundleIdentifier, auth0PlistPath }
}
