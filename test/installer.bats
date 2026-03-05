#!/usr/bin/env bats

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
