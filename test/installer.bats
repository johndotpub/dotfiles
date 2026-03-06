#!/usr/bin/env bats

# BATS wrapper suite:
# keeps CI output grouped while each underlying shell test
# still owns its isolated fixture setup.
setup() {
  REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "no root config duplicates check passes" {
  run bash "${REPO_DIR}/test/check-no-root-config-duplicates.sh"
  [ "$status" -eq 0 ]
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

@test "ssh config migration script passes" {
  run bash "${REPO_DIR}/test/test-ssh-config-migration.sh"
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

@test "reproducibility script passes" {
  run bash "${REPO_DIR}/test/verify-release-reproducible.sh" "${RELEASE_TAG:-v0.0.0-test}"
  [ "$status" -eq 0 ]
}

@test "inference opt-in script passes" {
  run bash "${REPO_DIR}/test/test-inference-opt-in.sh"
  [ "$status" -eq 0 ]
}

@test "nanorc optional failure script passes" {
  run bash "${REPO_DIR}/test/test-nanorc-optional-failure.sh"
  [ "$status" -eq 0 ]
}

@test "brew env helper resolves HOMEBREW_PREFIX path" {
  run bash "${REPO_DIR}/test/test-brew-env-linux-prefix.sh"
  [ "$status" -eq 0 ]
}

@test "brew env helper supports brew shell function" {
  run bash "${REPO_DIR}/test/test-brew-env-shell-function.sh"
  [ "$status" -eq 0 ]
}

@test "brew env helper fails when brew function shellenv fails" {
  run bash "${REPO_DIR}/test/test-brew-env-shellenv-failure-function.sh"
  [ "$status" -eq 0 ]
}

@test "brew env helper fails when brew binary shellenv fails" {
  run bash "${REPO_DIR}/test/test-brew-env-shellenv-failure-binary.sh"
  [ "$status" -eq 0 ]
}
