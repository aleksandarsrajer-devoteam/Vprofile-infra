#!/bin/bash
# ─────────────────────────────────────────────────────────────────────────────
# VProfile Tomcat — Runtime Startup Script
#
# What Packer + Ansible already did (baked into the image):
#   ✅ Installed OpenJDK 17
#   ✅ Installed Tomcat 10 + systemd service
#   ✅ Deployed vprofile-v2.war to /usr/local/tomcat/webapps/ROOT.war
#
# What THIS script does at every boot (runtime only):
#   1. Fetch the DB password from Secret Manager
#   2. Inject it into the WAR's application.properties
#   3. Start Tomcat
#
# Why inject into the WAR and not use an EnvironmentFile?
#   The WAR was built by Maven (mvn package) without a password.
#   The app reads db.password from application.properties inside the WAR.
#   We patch the WAR at boot — no code changes needed in the app repo.
# ─────────────────────────────────────────────────────────────────────────────
set -euo pipefail

WAR_FILE="/usr/local/tomcat/webapps/ROOT.war"
PROPS_PATH="WEB-INF/classes/application.properties"
WORK_DIR=$(mktemp -d)

# ── Step 1: Fetch DB password from Secret Manager ────────────────────────────
# The tomcat SA (vprofile-tomcat-sa) has roles/secretmanager.secretAccessor.
# gcloud authenticates automatically via the GCE metadata server — no key file.
echo "[startup] Fetching DB password from Secret Manager..."
DB_PASSWORD=$(gcloud secrets versions access latest \
  --secret="vprofile-db-password" \
  --format="get(payload.data)" | base64 --decode)
echo "[startup] DB password fetched."

# ── Step 2: Inject password into the WAR ─────────────────────────────────────
# The WAR (a ZIP file) already contains application.properties with a placeholder.
# We extract it, patch the db.password line, and repack it.
# jar is available because openjdk-17-jdk was installed by Ansible.
echo "[startup] Injecting DB password into ROOT.war..."
cd "${WORK_DIR}"
jar xf "${WAR_FILE}" "${PROPS_PATH}"
sed -i "s|^db\.password=.*|db.password=${DB_PASSWORD}|" "${PROPS_PATH}"
jar uf "${WAR_FILE}" "${PROPS_PATH}"
cd /
rm -rf "${WORK_DIR}"
unset DB_PASSWORD
echo "[startup] Password injected."

# ── Step 3: Start Tomcat ──────────────────────────────────────────────────────
# Tomcat is installed but NOT enabled for auto-start in the image (by design).
# We enable and start it here, after the WAR has the correct password.
echo "[startup] Starting Tomcat..."
systemctl enable tomcat
systemctl start tomcat
echo "[startup] Instance ready."