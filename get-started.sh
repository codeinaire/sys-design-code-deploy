#!/usr/bin/env bash
set -euo pipefail

# Absolute path to repo root (directory of this script)
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

BOOTSTRAP_DIR="$SCRIPT_DIR/terraform/bootstrap"
INFRA_DIR="$SCRIPT_DIR/terraform/infra"

log() { printf "[get-started] %s\n" "$*"; }

# Ensure docker compose is brought down if script exits with code 1
docker_compose_down() {
  log "Bringing down docker compose stack..."
  if command -v docker-compose >/dev/null 2>&1; then
    (cd "$SCRIPT_DIR" && docker-compose down -v || true)
  else
    (cd "$SCRIPT_DIR" && docker compose down -v || true)
  fi
}

on_exit() {
  ec=$?
  if [ "$ec" -eq 1 ]; then
    log "Exit code 1 detected. Running docker compose down."
    docker_compose_down
  fi
}

trap 'on_exit' EXIT

run_compose_and_capture() {
  if command -v docker-compose >/dev/null 2>&1; then
    COMPOSE_OUTPUT=$(cd "$SCRIPT_DIR" && docker-compose up -d 2>&1)
  else
    COMPOSE_OUTPUT=$(cd "$SCRIPT_DIR" && docker compose up -d 2>&1)
  fi
  printf "%s\n" "$COMPOSE_OUTPUT"
}

exit_if_already_running() {
  if echo "$COMPOSE_OUTPUT" | grep -q "Running"; then
    log "Docker compose reports services are already Running. Exiting."
    exit 0
  fi
}

ensure_started_or_exit() {
  if echo "$COMPOSE_OUTPUT" | grep -q "Started"; then
    log "Detected 'Started' from docker compose output. Proceeding."
  else
    log "Did not detect 'Started' in docker compose output. Exiting."
    exit 1
  fi
}

package_lambdas() {
  log "Packaging Lambda functions into zip archives..."
  mkdir -p "$SCRIPT_DIR/src"

  zip -j -q "$SCRIPT_DIR/src/lambda_build_worker.zip"        "$SCRIPT_DIR/src/lambda_build_worker/index.js"
  zip -j -q "$SCRIPT_DIR/src/lambda_replication_worker.zip"  "$SCRIPT_DIR/src/lambda_replication_worker/index.js"
  zip -j -q "$SCRIPT_DIR/src/lambda_regional_sync.zip"       "$SCRIPT_DIR/src/lambda_regional_sync/index.js"
  zip -j -q "$SCRIPT_DIR/src/lambda_step_function_invoker.zip" "$SCRIPT_DIR/src/lambda_step_function_invoker/index.js"

  log "Lambda packages ready under $SCRIPT_DIR/src"
}

update_backend_block() {
  local target_file="$1"
  local s3_bucket_name="$2"
  local backend_key="$3"

  if grep -q 'backend "s3"' "$target_file"; then
    log "Updating existing backend \"s3\" block in $target_file"
    awk -v bucket="$s3_bucket_name" -v backend_key="$backend_key" '
      BEGIN { in_backend = 0 }
      /backend \"s3\"[[:space:]]*\{/ && in_backend == 0 {
        print $0
        print "    bucket         = \"" bucket "\""
        print "    key            = \"" backend_key "\""
        print "    region         = \"us-east-1\""
        print "    use_lockfile   = true"
        print "    force_path_style = true"
        print "    endpoints = { s3 = \"http://localhost:4566\" }"
        print "    encrypt        = true"
        in_backend = 1
        next
      }
      in_backend == 1 {
        if ($0 ~ /^\s*}\s*$/) {
          print "  }"
          in_backend = 0
        }
        next
      }
      { print $0 }
    ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"
  else
    log "Inserting backend \"s3\" block into $target_file"
    awk -v bucket="$s3_bucket_name" -v backend_key="$backend_key" '
      BEGIN { inserted = 0 }
      /terraform[[:space:]]*\{/ && inserted == 0 {
        print $0
        print "  backend \"s3\" {"
        print "    bucket         = \"" bucket "\""
        print "    key            = \"" backend_key "\""
        print "    region         = \"us-east-1\""
        print "    use_lockfile   = true"
        print "    force_path_style = true"
        print "    endpoints = { s3 = \"http://localhost:4566\" }"
        print "    encrypt        = true"
        print "  }"
        inserted = 1
        next
      }
      { print $0 }
    ' "$target_file" > "$target_file.tmp" && mv "$target_file.tmp" "$target_file"
  fi
}

main() {
  # 0) Start LocalStack with docker-compose
  log "Starting LocalStack via docker-compose..."
  run_compose_and_capture
  exit_if_already_running
  ensure_started_or_exit

  # Ensure AWS env for LocalStack for backend/auth
  export AWS_ACCESS_KEY_ID="test"
  export AWS_SECRET_ACCESS_KEY="test"
  export AWS_DEFAULT_REGION="us-east-1"
  export AWS_ENDPOINT_URL="http://localhost:4566"

  # 1) Ensure Lambda zips exist for Terraform
  package_lambdas

  # 2) Terraform init & apply for bootstrap
  log "Running terraform init/apply for bootstrap..."
  terraform -chdir="$BOOTSTRAP_DIR" init -input=false
  terraform -chdir="$BOOTSTRAP_DIR" apply -auto-approve -input=false -lock=true

  # 3) Read S3 bucket output and inject into backend blocks in bootstrap and infra
  log "Fetching bootstrap outputs..."
  S3_BUCKET_NAME="$(terraform -chdir="$BOOTSTRAP_DIR" output -raw s3_bucket_name)"
  if [[ -z "$S3_BUCKET_NAME" ]]; then
    log "Failed to retrieve s3_bucket_name from bootstrap outputs."
    exit 1
  fi
  log "Using S3 bucket: $S3_BUCKET_NAME"
  
  # Use separate keys to avoid Infra trying to manage bootstrap state's bucket
  update_backend_block "$BOOTSTRAP_DIR/main.tf" "$S3_BUCKET_NAME" "bootstrap/terraform.tfstate"
  # Re-run terraform init in bootstrap to migrate local state into S3 backend
  log "Re-initializing bootstrap to migrate state to S3 backend..."
  terraform -chdir="$BOOTSTRAP_DIR" init -migrate-state

  # 5) Terraform init & apply for infra (configure backend to LocalStack explicitly)
  log "Running terraform init/apply for infra..."
  update_backend_block "$INFRA_DIR/main.tf" "$S3_BUCKET_NAME" "infra/terraform.tfstate"
  terraform -chdir="$INFRA_DIR" init -reconfigure

  terraform -chdir="$INFRA_DIR" apply -auto-approve -input=false

  log "All done."
}

main "$@"
