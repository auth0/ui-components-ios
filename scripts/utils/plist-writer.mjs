import fs from "node:fs"
import path from "node:path"
import ora from "ora"

/**
 * Write Auth0 configuration to iOS Auth0.plist
 *
 * Creates or updates the Auth0.plist file with the required
 * configuration for the Auth0 iOS SDK.
 */
export async function writeAuth0Plist(domain, clientId, auth0PlistPath) {
  const spinner = ora({
    text: "Generating Auth0.plist",
  }).start()

  try {
    // Build plist XML content
    const plistContent = `<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>ClientId</key>
	<string>${clientId}</string>
	<key>Domain</key>
	<string>${domain}</string>
</dict>
</plist>
`

    // Ensure the directory exists
    const dir = path.dirname(auth0PlistPath)
    if (!fs.existsSync(dir)) {
      fs.mkdirSync(dir, { recursive: true })
    }

    // Write file
    fs.writeFileSync(auth0PlistPath, plistContent, "utf-8")

    spinner.succeed(`Updated ${path.relative(process.cwd(), auth0PlistPath)}`)
  } catch (e) {
    spinner.fail("Failed to generate Auth0.plist")
    throw e
  }
}
