import readline from "node:readline/promises"

/**
 * Wait for user confirmation before proceeding
 */
export async function confirmWithUser(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })

  const answer = await rl.question(`${message} (y/N): `)
  rl.close()

  return answer.toLowerCase() === "y" || answer.toLowerCase() === "yes"
}

/**
 * Prompt for a free-text value, using `defaultValue` when the user just presses
 * Enter. In a non-interactive context (stdin is not a TTY, e.g. CI or a piped
 * run) there is nobody to answer, so the default is returned immediately rather
 * than blocking on input.
 *
 * @param {string} message - Prompt label (without the trailing default hint)
 * @param {string} [defaultValue=""] - Value used on empty input or when no TTY
 * @returns {Promise<string>} The trimmed answer, or the default
 */
export async function promptWithUser(message, defaultValue = "") {
  if (!process.stdin.isTTY) {
    return defaultValue
  }

  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })

  const suffix = defaultValue ? ` [${defaultValue}]` : ""
  const answer = await rl.question(`${message}${suffix}: `)
  rl.close()

  return answer.trim() || defaultValue
}
