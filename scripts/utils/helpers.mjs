import readline from "node:readline/promises"
import { select } from "@inquirer/prompts"

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
 * Wait for user input
 */
export async function getInputFromUser(message) {
  const rl = readline.createInterface({
    input: process.stdin,
    output: process.stdout,
  })

  const answer = await rl.question(`${message} `)
  rl.close()

  return answer.toLowerCase()
}

/**
 * Prompt the user to select one option from a list
 */
export async function selectOptionFromList(message, options) {
  const answer = await select({ message: message, choices: options })
  return answer
}
