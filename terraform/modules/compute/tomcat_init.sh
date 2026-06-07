#!/bin/bash
# =============================================================================
# VProfile Tomcat — Runtime Startup Script
#
# Architecture: Runtime Artifact Pulling
#
# What the Packer Base Image already contains (baked in):
#   ✅  OpenJDK 17
#   ✅  Tomcat 10 (systemd service installed, NOT enabled — this script starts it)
#   ✅  tomcat system user + /usr/local/tomcat directory
#
# What THIS script does on every boot:
#   1. Install runtime deps (mysql-client, unzip) — not part of the base image
#   2. Fetch DB password from Secret Manager
#   3. Check if WAR exists on GCS (Fail-Safe Guard)
#   4. Download vprofile-latest.war from GCS artifacts bucket
#   5. Extract db_backup.sql from the WAR (it is a ZIP archive)
#   6. Acquire a MySQL distributed lock (GET_LOCK) to serialize DB seeding
#      across multiple instances that may boot simultaneously
#   7. Seed the DB if not already seeded (idempotent table-existence check)
#   8. Release the lock
#   9. Patch db.password into application.properties inside the WAR
#  10. Deploy the patched WAR to Tomcat webapps/
#  11. Start Tomcat
# =============================================================================
set -euo pipefail

# ── Constants ────────────────────────────────────────────────────────────────
GCS_WAR="gs://vprofile-build-artifacts/vprofile-latest.war"
TMP_WAR="/tmp/vprofile-latest.war"
TMP_SQL="/tmp/db_backup.sql"
WEBAPPS="/usr/local/tomcat/webapps"
PROPS_PATH="WEB-INF/classes/application.properties"
WORK_DIR=$(mktemp -d)

# Cloud SQL is reachable via the private DNS record created by the dns module.
# Using DNS avoids hardcoding the private IP in the template.
DB_HOST="vprodb.vprofile.internal"
DB_USER="root"
DB_NAME="accounts"
LOCK_NAME="vprofile_db_init_lock"
LOCK_TIMEOUT=60   # seconds to wait for the distributed lock

log() { echo "[startup] $*"; }

# ── Step 1: Install runtime dependencies ─────────────────────────────────────
# mysql-client: needed for GET_LOCK + DB seeding
# unzip: needed to extract db_backup.sql from the WAR (WAR = ZIP archive)
# These are NOT baked into the Packer base image to keep it lean.
log "Installing runtime dependencies..."
apt-get update -y -qq
apt-get install -y mysql-client unzip
log "Dependencies installed."

# ── Step 2: Fetch DB password from Secret Manager ────────────────────────────
# The tomcat SA (vprofile-tomcat-sa) holds roles/secretmanager.secretAccessor.
# gcloud authenticates automatically via the GCE metadata server — no key file.
log "Fetching DB password from Secret Manager..."
DB_PASSWORD=$(gcloud secrets versions access latest \
  --secret="vprofile-db-password" \
  --format="get(payload.data)" | base64 --decode)
log "DB password fetched."

# Helper: run a MySQL command with standard auth
run_mysql() {
  mysql \
    -h "${DB_HOST}" \
    -u "${DB_USER}" \
    -p"${DB_PASSWORD}" \
    --connect-timeout=10 \
    --silent \
    "$@" 2>/dev/null
}

# ── Step 3: Fail-Safe Check & Download ───────────────────────────────────────
log "Checking if application code exists on GCS: ${GCS_WAR}..."

if gcloud storage objects describe "${GCS_WAR}" &>/dev/null; then
  log "✅ WAR file found! Proceeding with standard deployment..."

  # Download the WAR from GCS
  log "Downloading WAR from GCS..."
  gcloud storage cp "${GCS_WAR}" "${TMP_WAR}"
  log "WAR downloaded ($(du -sh ${TMP_WAR} | cut -f1))."

  # ── Step 4: Extract db_backup.sql from WAR ───────────────────────────────────
  log "Extracting db_backup.sql from WAR..."
  if unzip -p "${TMP_WAR}" WEB-INF/classes/db_backup.sql > "${TMP_SQL}" 2>/dev/null; then
    log "db_backup.sql extracted ($(wc -l < ${TMP_SQL}) lines)."
  else
    log "WARNING: db_backup.sql not found in WAR. Skipping DB seeding."
    TMP_SQL=""
  fi

  # ── Step 5–7: Distributed lock + idempotent DB seeding ───────────────────────
  if [ -n "${TMP_SQL}" ]; then
    log "Attempting to acquire distributed DB lock '${LOCK_NAME}' (timeout: ${LOCK_TIMEOUT}s)..."

    LOCK_RESULT=$(run_mysql -e \
      "SELECT GET_LOCK('${LOCK_NAME}', ${LOCK_TIMEOUT});" "${DB_NAME}" | tail -1)

    if [ "${LOCK_RESULT}" = "1" ]; then
      log "Lock acquired. Checking if schema is already seeded..."

      # Check for the 'role' table in the accounts database
      TABLE_COUNT=$(run_mysql -e \
        "SELECT COUNT(*) FROM information_schema.tables \
         WHERE table_schema='${DB_NAME}' AND table_name='role';" | tail -1)

      if [ "${TABLE_COUNT:-0}" = "0" ]; then
        log "Schema not found. Seeding database from db_backup.sql..."
        run_mysql "${DB_NAME}" < "${TMP_SQL}"
        log "Database seeded successfully."
      else
        log "Schema already present (table count: ${TABLE_COUNT}). Skipping seeding."
      fi

      # Release the distributed lock — always, whether seeding was skipped or not
      run_mysql -e "SELECT RELEASE_LOCK('${LOCK_NAME}');" "${DB_NAME}"
      log "Lock released."

    elif [ "${LOCK_RESULT}" = "0" ]; then
      log "Lock timed out (another instance is seeding). Proceeding without seeding."
    else
      log "WARNING: Could not connect to DB to acquire lock (result=${LOCK_RESULT:-NULL}). Skipping seeding."
    fi
  fi

  # ── Step 8: Patch db.password into the WAR ───────────────────────────────────
  log "Patching db.password into WAR..."
  cd "${WORK_DIR}"
  jar xf "${TMP_WAR}" "${PROPS_PATH}"
  sed -i "s|^db\.password=.*|db.password=${DB_PASSWORD}|" "${PROPS_PATH}"
  jar uf "${TMP_WAR}" "${PROPS_PATH}"
  cd /
  rm -rf "${WORK_DIR}"
  log "Password patched."

  # ── Step 9: Deploy WAR to Tomcat ─────────────────────────────────────────────
  log "Deploying WAR to Tomcat webapps/..."
  rm -rf "${WEBAPPS}/ROOT" "${WEBAPPS}/ROOT.war"
  cp "${TMP_WAR}" "${WEBAPPS}/ROOT.war"
  chown tomcat:tomcat "${WEBAPPS}/ROOT.war"
  rm -f "${TMP_WAR}" "${TMP_SQL}"
  log "WAR deployed."

else
  # ── Fail-Safe Mode (triggered when Terraform runs before the app pipeline has uploaded a WAR) ─────
  log "⚠️ WARNING: vprofile-latest.war NOT found on GCS bucket!"
  log "Activating Fail-Safe mode: Creating a temporary landing page..."
  
  rm -rf "${WEBAPPS}/ROOT" "${WEBAPPS}/ROOT.war"
  mkdir -p "${WEBAPPS}/ROOT"
  
  # Create a temporary landing page — gives the health check something to respond to
  # while the development team runs their first deployment.
  cat <<'EOF' > "${WEBAPPS}/ROOT/index.jsp"
<!DOCTYPE html>
<html>
<head>
    <title>VProfile - System Initialised</title>
    <style>
        body { font-family: 'Segoe UI', Tahoma, Geneva, Verdana, sans-serif; text-align: center; margin-top: 100px; background: #f4f6f9; color: #333; }
        .card { background: white; padding: 40px; border-radius: 8px; box-shadow: 0 4px 10px rgba(0,0,0,0.08); display: inline-block; max-width: 500px; }
        h1 { color: #28a745; margin-bottom: 20px; }
        p { font-size: 16px; line-height: 1.6; color: #666; }
        .badge { background: #e9ecef; padding: 6px 12px; border-radius: 20px; font-size: 14px; font-weight: bold; color: #495057; }
    </style>
</head>
<body>
    <div class="card">
        <h1>Infrastructure is Ready! 🚀</h1>
        <p>The virtual machine and Tomcat server have been successfully started and secured.</p>
        <p>Application code (<code>vprofile-latest.war</code>) was not found on the GCS bucket.</p>
        <div class="badge">Awaiting first deployment from the development team...</div>
    </div>
</body>
</html>
EOF
  chown -R tomcat:tomcat "${WEBAPPS}/ROOT"
  log "Fail-Safe landing page successfully created."
fi

# ── Step 10: Start Tomcat ─────────────────────────────────────────────────────
log "Starting Tomcat..."
# Clear the password from memory before starting Tomcat — security hygiene
unset DB_PASSWORD
systemctl enable tomcat
systemctl start tomcat
log "Instance ready."

# ── Step 3: Download WAR from GCS ────────────────────────────────────────────
# The CI pipeline (app repo) always publishes the latest build here.
# log "Downloading WAR from GCS: ${GCS_WAR}"
# gcloud storage cp "${GCS_WAR}" "${TMP_WAR}"
# log "WAR downloaded ($(du -sh ${TMP_WAR} | cut -f1))."

# # ── Step 4: Extract db_backup.sql from WAR ───────────────────────────────────
# # The WAR is a ZIP archive; unzip -p writes to stdout without creating dirs.
# log "Extracting db_backup.sql from WAR..."
# if unzip -p "${TMP_WAR}" WEB-INF/classes/db_backup.sql > "${TMP_SQL}" 2>/dev/null; then
#   log "db_backup.sql extracted ($(wc -l < ${TMP_SQL}) lines)."
# else
#   log "WARNING: db_backup.sql not found in WAR. Skipping DB seeding."
#   TMP_SQL=""
# fi

# # ── Step 5–7: Distributed lock + idempotent DB seeding ───────────────────────
# # Race-condition problem: multiple MIG instances may boot at the same time
# # (rolling update, autoscale). Without coordination they all try to seed the DB
# # simultaneously — causing duplicate data or foreign-key errors.
# #
# # Solution: MySQL advisory lock (GET_LOCK).
# #   • Atomic:       only one session holds the lock at a time
# #   • Self-healing: if the holder crashes, MySQL releases the lock automatically
# #   • Idempotent:   the table-existence check is the true guard; the lock only
# #                   serializes the check+run so two instances cannot both pass
# #                   the check before either has finished seeding
# if [ -n "${TMP_SQL}" ]; then
#   log "Attempting to acquire distributed DB lock '${LOCK_NAME}' (timeout: ${LOCK_TIMEOUT}s)..."

#   LOCK_RESULT=$(run_mysql -e \
#     "SELECT GET_LOCK('${LOCK_NAME}', ${LOCK_TIMEOUT});" "${DB_NAME}" | tail -1)

#   if [ "${LOCK_RESULT}" = "1" ]; then
#     log "Lock acquired. Checking if schema is already seeded..."

#     # Check for the 'role' table — it is created by db_backup.sql and
#     # will not exist in a fresh Cloud SQL instance.
#     TABLE_COUNT=$(run_mysql -e \
#       "SELECT COUNT(*) FROM information_schema.tables \
#        WHERE table_schema='${DB_NAME}' AND table_name='role';" | tail -1)

#     if [ "${TABLE_COUNT:-0}" = "0" ]; then
#       log "Schema not found. Seeding database from db_backup.sql..."
#       run_mysql "${DB_NAME}" < "${TMP_SQL}"
#       log "Database seeded successfully."
#     else
#       log "Schema already present (table count: ${TABLE_COUNT}). Skipping seeding."
#     fi

#     # Always release the lock — even if seeding was skipped
#     run_mysql -e "SELECT RELEASE_LOCK('${LOCK_NAME}');" "${DB_NAME}"
#     log "Lock released."

#   elif [ "${LOCK_RESULT}" = "0" ]; then
#     # Timeout: another instance holds the lock and is currently seeding.
#     # Safe to continue — the seeder will finish before our app needs the DB.
#     log "Lock timed out (another instance is seeding). Proceeding without seeding."
#   else
#     # NULL result: connection error. Log and continue — app will surface DB errors.
#     log "WARNING: Could not connect to DB to acquire lock (result=${LOCK_RESULT:-NULL}). Skipping seeding."
#   fi
# fi

# # ── Step 8: Patch db.password into the WAR ───────────────────────────────────
# # The WAR was built by mvn package without a plaintext password.
# # We extract application.properties, inject the password, and repack the WAR.
# # 'jar' is available because openjdk-17-jdk was installed by Ansible in the image.
# log "Patching db.password into WAR..."
# cd "${WORK_DIR}"
# jar xf "${TMP_WAR}" "${PROPS_PATH}"
# sed -i "s|^db\.password=.*|db.password=${DB_PASSWORD}|" "${PROPS_PATH}"
# jar uf "${TMP_WAR}" "${PROPS_PATH}"
# cd /
# rm -rf "${WORK_DIR}"
# log "Password patched."

# # Clear the password from memory — no longer needed after this point
# unset DB_PASSWORD

# # ── Step 9: Deploy WAR to Tomcat ─────────────────────────────────────────────
# log "Deploying WAR to Tomcat webapps/..."
# rm -rf "${WEBAPPS}/ROOT" "${WEBAPPS}/ROOT.war"
# cp "${TMP_WAR}" "${WEBAPPS}/ROOT.war"
# chown tomcat:tomcat "${WEBAPPS}/ROOT.war"
# rm -f "${TMP_WAR}" "${TMP_SQL}"
# log "WAR deployed."

# # ── Step 10: Start Tomcat ─────────────────────────────────────────────────────
# # Tomcat is installed but explicitly NOT enabled in the Packer image (by design)
# # so that it never starts before this script has injected the password.
# log "Starting Tomcat..."
# systemctl enable tomcat
# systemctl start tomcat
# log "Instance ready."