#!/usr/bin/env bats

# BATS wrapper suite:
# keeps CI output grouped while each underlying shell test
# still owns its isolated fixture setup.
setup() {
  REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/.." && pwd)"
}

@test "repo root configs: no duplicates" {
  run bash "${REPO_DIR}/test/root-configs.sh"
  [ "$status" -eq 0 ]
}

@test "installer: idempotency" {
  run bash "${REPO_DIR}/test/installer-idempotency.sh"
  [ "$status" -eq 0 ]
}

@test "installer: backup collisions" {
  run bash "${REPO_DIR}/test/backup-collision.sh"
  [ "$status" -eq 0 ]
}

@test "installer: backup accumulation" {
  run bash "${REPO_DIR}/test/backup-accumulation.sh"
  [ "$status" -eq 0 ]
}

@test "installer: backup semantics" {
  run bash "${REPO_DIR}/test/backup-semantics.sh"
  [ "$status" -eq 0 ]
}

@test "skel: merge behavior" {
  run bash "${REPO_DIR}/test/skel-merge.sh"
  [ "$status" -eq 0 ]
}

@test "ssh: config migration" {
  run bash "${REPO_DIR}/test/ssh-config-migration.sh"
  [ "$status" -eq 0 ]
}

@test "tmux: oh-my-tmux behavior" {
  run bash "${REPO_DIR}/test/tmux-oh-my.sh"
  [ "$status" -eq 0 ]
}

@test "installer: lock handling" {
  run bash "${REPO_DIR}/test/installer-lock.sh"
  [ "$status" -eq 0 ]
}

@test "report: json output" {
  run bash "${REPO_DIR}/test/report-json.sh"
  [ "$status" -eq 0 ]
}

@test "release: reproducible archive" {
  run bash "${REPO_DIR}/test/release-reproducible.sh" "${RELEASE_TAG:-v0.0.0-test}"
  [ "$status" -eq 0 ]
}

@test "inference: opt-in behavior" {
  run bash "${REPO_DIR}/test/inference-opt-in.sh"
  [ "$status" -eq 0 ]
}

@test "nano: optional clone failure" {
  run bash "${REPO_DIR}/test/nanorc-optional-failure.sh"
  [ "$status" -eq 0 ]
}

@test "shell templates: brew bootstrap compatibility" {
  run bash "${REPO_DIR}/test/shell-templates.sh"
  [ "$status" -eq 0 ]
}

@test "brew env: all scenarios" {
  run bash "${REPO_DIR}/test/brew-env.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap e2e: readme curl flow" {
  run bash "${REPO_DIR}/test/bootstrap-e2e.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap: main branch fallback (no --ref)" {
  run bash "${REPO_DIR}/test/bootstrap-main-fallback.sh"
  [ "$status" -eq 0 ]
}

@test "bootstrap: branch ref resolves to archive" {
  run bash "${REPO_DIR}/test/bootstrap-ref-branch.sh"
  [ "$status" -eq 0 ]
}

@test "installer: preserve flag" {
  run bash "${REPO_DIR}/test/preserve-flag.sh"
  [ "$status" -eq 0 ]
}
