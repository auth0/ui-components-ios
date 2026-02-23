/**
 * Action types for change plans
 */
export const ChangeAction = {
  CREATE: "create",
  UPDATE: "update",
  SKIP: "skip",
}

/**
 * Create a change plan item
 */
export function createChangeItem(action, details = {}) {
  return {
    action, // 'create', 'update', or 'skip'
    ...details,
  }
}
