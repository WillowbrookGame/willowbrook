// Compatibility entry point: the current chat contract spans all places for eligible accounts.
// Run the canonical WebSocket suite rather than enforcing the retired Town-only contract.
await import('./test_family_chat_all_areas.mjs');
