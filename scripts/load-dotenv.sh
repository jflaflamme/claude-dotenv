#!/usr/bin/env bash
# claude-dotenv: Load .env files into Claude Code sessions via CLAUDE_ENV_FILE
set -euo pipefail

# Require CLAUDE_ENV_FILE — this is where Claude reads env vars from
if [[ -z "${CLAUDE_ENV_FILE:-}" ]]; then
    echo "CLAUDE_ENV_FILE not set — not running inside Claude Code?"
    exit 0
fi

# Use CLAUDE_PROJECT_DIR if set, otherwise fall back to current directory
PROJECT_DIR="${CLAUDE_PROJECT_DIR:-.}"

# Cascade order: base → local → environment-specific
ENV_FILES=(
    ".env"
    ".env.local"
)

# Add environment-specific files if NODE_ENV or similar is set
if [[ -n "${NODE_ENV:-}" ]]; then
    ENV_FILES+=(".env.${NODE_ENV}" ".env.${NODE_ENV}.local")
elif [[ -n "${APP_ENV:-}" ]]; then
    ENV_FILES+=(".env.${APP_ENV}" ".env.${APP_ENV}.local")
fi

# Associative array for variable interpolation
declare -A env_vars
loaded_files=()
total_vars=0

# Parse a single .env file and append exports to CLAUDE_ENV_FILE
parse_env_file() {
    local file="$1"
    local count=0

    while IFS= read -r line || [[ -n "$line" ]]; do
        # Strip leading/trailing whitespace
        line="${line#"${line%%[![:space:]]*}"}"
        line="${line%"${line##*[![:space:]]}"}"

        # Skip empty lines and comments
        [[ -z "$line" || "$line" == \#* ]] && continue

        # Strip 'export ' prefix
        if [[ "$line" == export\ * ]]; then
            line="${line#export }"
            line="${line#"${line%%[![:space:]]*}"}"
        fi

        # Split on first '='
        local key="${line%%=*}"
        local value="${line#*=}"

        # Validate key: must be alphanumeric or underscore
        if [[ ! "$key" =~ ^[a-zA-Z_][a-zA-Z0-9_]*$ ]]; then
            continue
        fi

        # Handle quoting
        if [[ "$value" == \"*\" ]]; then
            # Double-quoted: remove quotes, expand ${VAR} references
            value="${value#\"}"
            value="${value%\"}"
            # Strip inline comment after closing quote (already stripped)
            # Expand ${VAR} and $VAR references
            value=$(expand_vars "$value")
        elif [[ "$value" == \'*\' ]]; then
            # Single-quoted: remove quotes, no interpolation
            value="${value#\'}"
            value="${value%\'}"
        else
            # Unquoted: strip inline comments (space + #)
            if [[ "$value" == *" #"* ]]; then
                value="${value%% \#*}"
            fi
            # Trim trailing whitespace
            value="${value%"${value##*[![:space:]]}"}"
            # Expand variables in unquoted values too
            value=$(expand_vars "$value")
        fi

        # Store in associative array for interpolation
        env_vars["$key"]="$value"

        # Write to CLAUDE_ENV_FILE
        printf 'export %s="%s"\n' "$key" "$value" >> "$CLAUDE_ENV_FILE"
        ((count++))
    done < "$file"

    echo "$count"
}

# Expand ${VAR} and $VAR references using already-parsed variables
expand_vars() {
    local input="$1"
    local result="$input"

    # Expand ${VAR} syntax
    while [[ "$result" =~ \$\{([a-zA-Z_][a-zA-Z0-9_]*)\} ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${env_vars[$var_name]:-${!var_name:-}}"
        result="${result/\$\{${var_name}\}/${var_value}}"
    done

    # Expand $VAR syntax (word boundary: followed by non-alnum/underscore or end)
    while [[ "$result" =~ \$([a-zA-Z_][a-zA-Z0-9_]*) ]]; do
        local var_name="${BASH_REMATCH[1]}"
        local var_value="${env_vars[$var_name]:-${!var_name:-}}"
        result="${result/\$${var_name}/${var_value}}"
    done

    echo "$result"
}

# Process each .env file in cascade order
for env_file in "${ENV_FILES[@]}"; do
    local_path="${PROJECT_DIR}/${env_file}"
    if [[ -f "$local_path" ]]; then
        count=$(parse_env_file "$local_path")
        loaded_files+=("$env_file")
        total_vars=$((total_vars + count))
    fi
done

# Output summary for Claude context
if [[ ${#loaded_files[@]} -gt 0 ]]; then
    echo "claude-dotenv: Loaded ${total_vars} variable(s) from: ${loaded_files[*]}"
else
    echo "claude-dotenv: No .env files found in ${PROJECT_DIR}"
fi
