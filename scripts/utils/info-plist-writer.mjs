import { $ } from "execa"
import fs from "node:fs"
import path from "node:path"
import ora from "ora"

const PLIST_BUDDY = "/usr/libexec/PlistBuddy"

/**
 * Print manual fallback instructions for adding the URL scheme by hand.
 */
function printManualInstructions(scheme) {
  console.log("\n   Add the following to your app's Info.plist manually:\n")
  console.log(`     <key>CFBundleURLTypes</key>`)
  console.log(`     <array>`)
  console.log(`       <dict>`)
  console.log(`         <key>CFBundleURLSchemes</key>`)
  console.log(`         <array><string>${scheme}</string></array>`)
  console.log(`         <key>CFBundleTypeRole</key>`)
  console.log(`         <string>None</string>`)
  console.log(`       </dict>`)
  console.log(`     </array>\n`)
}

/**
 * Read and parse an Info.plist file as JSON via plutil.
 * @returns {object|null} Parsed plist, or null if it can't be read/parsed.
 */
async function readPlistAsJson(infoPlistPath) {
  try {
    const { stdout } = await $`plutil -convert json -o - ${infoPlistPath}`
    return JSON.parse(stdout)
  } catch {
    return null
  }
}

/**
 * Idempotently add the OAuth callback URL scheme to the sample app's Info.plist.
 *
 * The Auth0 iOS SDK uses a custom URL scheme to receive the login/logout
 * callback. Without a matching `CFBundleURLSchemes` entry the redirect cannot
 * return to the app, so this wires it up automatically as part of bootstrap.
 *
 * Safe to run repeatedly: if the scheme is already present it is a no-op. If
 * the Info.plist is missing or has an unexpected shape, it prints manual
 * instructions instead of corrupting the file.
 *
 * @param {string} infoPlistPath - Absolute path to the app's Info.plist
 * @param {string} scheme - URL scheme to register (the app's bundle identifier)
 * @param {string[]} staleSchemes - Legacy schemes to remove (e.g. old "demo")
 */
export async function writeInfoPlistUrlScheme(
  infoPlistPath,
  scheme,
  staleSchemes = ["demo"]
) {
  const spinner = ora({
    text: `Configuring URL scheme "${scheme}" in Info.plist`,
  }).start()

  // The file must exist — we never create an Info.plist from scratch.
  if (!fs.existsSync(infoPlistPath)) {
    spinner.warn(`Could not find Info.plist at ${infoPlistPath}`)
    printManualInstructions(scheme)
    return
  }

  const plist = await readPlistAsJson(infoPlistPath)
  if (!plist) {
    spinner.warn("Could not read Info.plist (unexpected format)")
    printManualInstructions(scheme)
    return
  }

  const hasUrlTypesKey = Array.isArray(plist.CFBundleURLTypes)
  const urlTypes = hasUrlTypesKey ? plist.CFBundleURLTypes : []

  // Remove any leftover URL-type entries from earlier runs whose schemes are
  // ALL stale (e.g. the old hardcoded "demo"). We only delete an entry when
  // every scheme in it is stale, so we never disturb a URL type that also
  // carries a scheme the app legitimately uses. Delete from the highest index
  // down so earlier indices don't shift mid-operation.
  const staleIndices = urlTypes
    .map((entry, i) => ({ entry, i }))
    .filter(({ entry }) => {
      const schemes = Array.isArray(entry?.CFBundleURLSchemes)
        ? entry.CFBundleURLSchemes
        : []
      return (
        schemes.length > 0 && schemes.every((s) => staleSchemes.includes(s))
      )
    })
    .map(({ i }) => i)

  if (staleIndices.length > 0) {
    const deleteArgs = staleIndices
      .sort((a, b) => b - a)
      .flatMap((i) => ["-c", `Delete :CFBundleURLTypes:${i}`])
    try {
      await $`${PLIST_BUDDY} ${deleteArgs} ${infoPlistPath}`
      // Reflect the removals in our in-memory view so index math below is correct.
      for (const i of staleIndices) urlTypes.splice(i, 1)
    } catch (e) {
      spinner.warn(
        `Could not remove stale URL scheme(s) [${staleSchemes.join(", ")}] — continuing`
      )
    }
  }

  // Idempotency guard: skip if any existing URL type already declares the scheme.
  const alreadyConfigured = urlTypes.some((entry) =>
    Array.isArray(entry?.CFBundleURLSchemes)
      ? entry.CFBundleURLSchemes.includes(scheme)
      : false
  )

  if (alreadyConfigured) {
    const note =
      staleIndices.length > 0
        ? ` (removed stale: ${staleSchemes.join(", ")})`
        : ""
    spinner.succeed(
      `URL scheme "${scheme}" already configured in Info.plist${note}`
    )
    return
  }

  // Build the PlistBuddy commands. Append a new URL type at the next index so
  // we never disturb existing entries.
  const index = urlTypes.length
  const commands = []
  // Only create the array if the key doesn't exist at all. If it exists but is
  // now empty (e.g. we just deleted a stale entry), re-adding it would fail.
  if (!hasUrlTypesKey) {
    commands.push("Add :CFBundleURLTypes array")
  }
  commands.push(`Add :CFBundleURLTypes:${index} dict`)
  commands.push(`Add :CFBundleURLTypes:${index}:CFBundleTypeRole string None`)
  commands.push(`Add :CFBundleURLTypes:${index}:CFBundleURLSchemes array`)
  commands.push(
    `Add :CFBundleURLTypes:${index}:CFBundleURLSchemes:0 string ${scheme}`
  )

  const args = commands.flatMap((c) => ["-c", c])

  try {
    await $`${PLIST_BUDDY} ${args} ${infoPlistPath}`

    // Verify the scheme is now present before reporting success.
    const updated = await readPlistAsJson(infoPlistPath)
    const verified = (updated?.CFBundleURLTypes || []).some((entry) =>
      Array.isArray(entry?.CFBundleURLSchemes)
        ? entry.CFBundleURLSchemes.includes(scheme)
        : false
    )

    if (!verified) {
      throw new Error("Scheme not present after write")
    }

    spinner.succeed(
      `Added URL scheme "${scheme}" to ${path.relative(process.cwd(), infoPlistPath)}`
    )
  } catch (e) {
    spinner.fail("Failed to update Info.plist")
    console.warn(`   ${e.message}`)
    printManualInstructions(scheme)
  }
}
