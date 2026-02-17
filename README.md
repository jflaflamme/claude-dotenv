# claude-dotenv

A [Claude Code](https://docs.anthropic.com/en/docs/claude-code) plugin that automatically loads `.env` files into your session. No more manually setting environment variables — just drop your `.env` and go.

## Why?

Claude Code doesn't natively load `.env` files. You'd have to either:
- Add each variable to `settings.json`'s `env` key
- Export them in your shell before launching Claude

**claude-dotenv** fixes this with a `SessionStart` hook that parses your `.env` files and injects them via `CLAUDE_ENV_FILE`, making every variable available in all Bash commands Claude runs.

## Install

### From marketplace (recommended)

```
/plugin marketplace add innolabsdev/innolabs-plugins
/plugin install claude-dotenv@innolabs-plugins
```

### Manual

```bash
git clone https://github.com/jflaflamme/claude-dotenv.git ~/.claude/plugins/claude-dotenv
```

Then add it to your Claude Code settings (`~/.claude/settings.json`):

```json
{
  "plugins": ["~/.claude/plugins/claude-dotenv"]
}
```

Or run with the flag:

```bash
claude --plugin-dir ~/.claude/plugins/claude-dotenv
```

## How It Works

On session startup, the plugin:

1. Reads `.env` files from your project directory in cascade order
2. Parses each file (handling quotes, comments, interpolation)
3. Writes `export` statements to `CLAUDE_ENV_FILE`
4. Prints a summary so Claude knows what was loaded

That's it. Your variables are available in every Bash tool call for the session.

## .env File Cascade

Files are loaded in order, with later files overriding earlier ones:

| Priority | File | Purpose |
|----------|------|---------|
| 1 | `.env` | Base defaults |
| 2 | `.env.local` | Local overrides (gitignored) |
| 3 | `.env.{NODE_ENV}` | Environment-specific |
| 4 | `.env.{NODE_ENV}.local` | Environment-specific local overrides |

`APP_ENV` is also supported as a fallback when `NODE_ENV` is not set.

## Supported .env Syntax

```bash
# Comments are ignored
KEY=value

# Quoted values
DOUBLE="hello world"
SINGLE='hello world'

# export prefix
export API_KEY=sk-12345

# Variable interpolation (double-quoted and unquoted)
DB_URL="postgresql://${DB_USER}:${DB_PASS}@${DB_HOST}:5432/mydb"

# Single-quoted values are NOT interpolated (POSIX behavior)
LITERAL='${NOT_EXPANDED}'

# Inline comments (unquoted values only)
DEBUG=true # this part is stripped
```

## Verify It Works

Start Claude with debug output:

```bash
claude --debug --plugin-dir ./path/to/claude-dotenv
```

You should see:

```
[DEBUG] Hook command completed with status 0: claude-dotenv: Loaded 5 variable(s) from: .env .env.local
```

Then inside the session, run:

```bash
echo $YOUR_VAR
```

## Project Structure

```
claude-dotenv/
├── .claude-plugin/
│   └── plugin.json        # Plugin manifest
├── hooks/
│   └── hooks.json         # SessionStart hook config
├── scripts/
│   └── load-dotenv.sh     # .env parser
├── LICENSE
└── README.md
```

## Security Note

The plugin only reads `.env` files from the project directory (`CLAUDE_PROJECT_DIR`). It does not send your variables anywhere — they stay local in the Claude Code process. As always, avoid committing `.env` files with secrets to version control.

## License

MIT
