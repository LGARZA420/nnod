#!/bin/sh

# If Heroku has set a PORT env var, forward it to n8n
if [ -z "${PORT+x}" ]; then
  echo "PORT variable not defined, leaving n8n on its default port."
else
  export N8N_PORT="$PORT"
  echo "n8n will start on port '$PORT'"
fi

# --- Parse DATABASE_URL (Heroku Postgres) -----------------------------------
parse_url() {
  eval $(echo "$1" | sed -e "s#^\(\(.*\)://\)\?\(\([^:@]*\)\(:\(.*\)\)\?@\)\?\([^/?]*\)\(/\(.*\)\)\?#${PREFIX:-URL_}SCHEME='\2' ${PREFIX:-URL_}USER='\4' ${PREFIX:-URL_}PASSWORD='\6' ${PREFIX:-URL_}HOSTPORT='\7' ${PREFIX:-URL_}DATABASE='\9'#")
}

PREFIX="N8N_DB_" parse_url "$DATABASE_URL"
echo "$N8N_DB_SCHEME://$N8N_DB_USER:*****@$N8N_DB_HOSTPORT/$N8N_DB_DATABASE"

# Split host & port
N8N_DB_HOST="$(echo "$N8N_DB_HOSTPORT" | sed -e 's,:.*,,g')"
N8N_DB_PORT="$(echo "$N8N_DB_HOSTPORT" | sed -e 's,^.*:,:,g' -e 's,.*:\([0-9]*\).*,\1,g' -e 's,[^0-9],,g')"

# Export variables n8n expects
export DB_TYPE="postgresdb"
export DB_POSTGRESDB_HOST="$N8N_DB_HOST"
export DB_POSTGRESDB_PORT="$N8N_DB_PORT"
export DB_POSTGRESDB_DATABASE="$N8N_DB_DATABASE"
export DB_POSTGRESDB_USER="$N8N_DB_USER"
export DB_POSTGRESDB_PASSWORD="$N8N_DB_PASSWORD"



# Ensure custom nodes folder is on the NODE_PATH
if [ -n "$N8N_CUSTOM_EXTENSIONS" ]; then
  export N8N_CUSTOM_EXTENSIONS="/opt/n8n-custom-nodes:${N8N_CUSTOM_EXTENSIONS}"
else
  export N8N_CUSTOM_EXTENSIONS="/opt/n8n-custom-nodes"
fi

print_banner() {
  echo "----------------------------------------"
  echo " n8n Puppeteer Node - Environment Details"
  echo "----------------------------------------"
  echo "Node.js version: $(node -v)"
  echo "n8n version: $(n8n --version)"

  # Chromium version (if Puppeteer already set PUPPETEER_EXECUTABLE_PATH)
  CHROME_VERSION="$([ -x "$PUPPETEER_EXECUTABLE_PATH" ] && "$PUPPETEER_EXECUTABLE_PATH" --version || echo 'Chromium not found')"
  echo "Chromium version: $CHROME_VERSION"

  # n8n-nodes-puppeteer & core Puppeteer versions (if installed)
  PUPPETEER_PATH="/opt/n8n-custom-nodes/node_modules/n8n-nodes-puppeteer"
  if [ -f "$PUPPETEER_PATH/package.json" ]; then
    PUPPETEER_VERSION=$(node -p "require('$PUPPETEER_PATH/package.json').version")
    echo "n8n-nodes-puppeteer version: $PUPPETEER_VERSION"

    CORE_PUPPETEER_VERSION=$(cd "$PUPPETEER_PATH" && \
      node -e "try { console.log(require('puppeteer/package.json').version) } catch { console.log('not found') }")
    echo "Puppeteer core version: $CORE_PUPPETEER_VERSION"
  else
    echo "n8n-nodes-puppeteer: not installed"
  fi

  echo "Puppeteer executable path: ${PUPPETEER_EXECUTABLE_PATH:-unset}"
  echo "----------------------------------------"
}

print_banner


exec n8n "$@"
