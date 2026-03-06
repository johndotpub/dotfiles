#!/usr/bin/env bats

# BATS wrapper suite:
# keeps CI output grouped while each underlying shell test
# still owns its isolated fixture setup.
setup() {
  REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "repo root configs: no duplicates" {
  run bash "${REPO_DIR}/test/check-no-root-config-duplicates.sh"
  [ "$status" -eq 0 ]
}

@test "installer: idempotency" {
  run bash "${REPO_DIR}/test/test-installer-idempotency.sh"
  [ "$status" -eq 0 ]
}

@test "installer: backup collisions" {
  run bash "${REPO_DIR}/test/test-backup-collision.sh"
  [ "$status" -eq 0 ]
}

@test "skel: merge behavior" {
  run bash "${REPO_DIR}/test/test-skel-merge-behavior.sh"
  [ "$status" -eq 0 ]
}

@test "ssh: config migration" {
  run bash "${REPO_DIR}/test/test-ssh-config-migration.sh"
  [ "$status" -eq 0 ]
}

@test "tmux: oh-my-tmux behavior" {
  run bash "${REPO_DIR}/test/test-oh-my-tmux.sh"
  [ "$status" -eq 0 ]
}

@test "installer: lock handling" {
  run bash "${REPO_DIR}/test/test-install-lock.sh"
  [ "$status" -eq 0 ]
}

@test "report: json output" {
  run bash "${REPO_DIR}/test/test-report-json.sh"
  [ "$status" -eq 0 ]
}

@test "release: reproducible archive" {
  run bash "${REPO_DIR}/test/verify-release-reproducible.sh" "${RELEASE_TAG:-v0.0.0-test}"
  [ "$status" -eq 0 ]
}

@test "inference: opt-in behavior" {
  run bash "${REPO_DIR}/test/test-inference-opt-in.sh"
  [ "$status" -eq 0 ]
}

@test "nano: optional clone failure" {
  run bash "${REPO_DIR}/test/test-nanorc-optional-failure.sh"
  [ "$status" -eq 0 ]
}

@test "brew env: HOMEBREW_PREFIX path" {
  run bash "${REPO_DIR}/test/test-brew-env-linux-prefix.sh"
  [ "$status" -eq 0 ]
}

@test "brew env: shell function" {
  run bash "${REPO_DIR}/test/test-brew-env-shell-function.sh"
  [ "$status" -eq 0 ]
}

@test "brew env: function shellenv failure" {
  run bash "${REPO_DIR}/test/test-brew-env-shellenv-failure-function.sh"
  [ "$status" -eq 0 ]
}

@test "brew env: binary shellenv failure" {
  run bash "${REPO_DIR}/test/test-brew-env-shellenv-failure-binary.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap e2e: curl PR payload" {
  run bash "${REPO_DIR}/test/test-bootstrap-e2e-curl-pr-commit.sh"
  [ "$status" -eq 0 ]
}
