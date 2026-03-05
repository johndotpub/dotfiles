#!/usr/bin/env bats

# BATS wrapper suite:
# keeps CI output grouped while each underlying shell test
# still owns its isolated fixture setup.
setup() {
  REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "installer idempotency script passes" {
  run bash "${REPO_DIR}/test/test-installer-idempotency.sh"
  [ "$status" -eq 0 ]
}

@test "backup collision script passes" {
  run bash "${REPO_DIR}/test/test-backup-collision.sh"
  [ "$status" -eq 0 ]
}

@test "skel merge behavior script passes" {
  run bash "${REPO_DIR}/test/test-skel-merge-behavior.sh"
  [ "$status" -eq 0 ]
}

@test "oh-my-tmux behavior script passes" {
  run bash "${REPO_DIR}/test/test-oh-my-tmux.sh"
  [ "$status" -eq 0 ]
}

@test "installer lock script passes" {
  run bash "${REPO_DIR}/test/test-install-lock.sh"
  [ "$status" -eq 0 ]
}

@test "report JSON script passes" {
  run bash "${REPO_DIR}/test/test-report-json.sh"
  [ "$status" -eq 0 ]
}
