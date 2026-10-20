# Test-only command doubles: never enter/build the real ROM or write a build log.
cd() { return 0; }
source() { return 0; }
lunch() { return 0; }
m() { return "${MOCK_M_EXIT:-0}"; }
tee() { command cat; return "${MOCK_TEE_EXIT:-0}"; }
