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
