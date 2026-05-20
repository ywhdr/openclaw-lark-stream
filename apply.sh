#!/bin/bash
# openclaw-lark-stream-enhancer: apply exec output streaming patches to @larksuite/openclaw-lark
# 
# This script patches openclaw-lark to add `onCommandOutput` hook support,
# enabling real-time exec/command output display in Feishu streaming cards.
#
# Usage:
#   bash apply.sh [openclaw-lark-dir]
#
# Default target: $OPENCLAW_NPM_DIR/@larksuite/openclaw-lark
# or auto-detect from npm global prefix

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

# Resolve target directory
if [ $# -ge 1 ]; then
    TARGET="$1"
else
    NPM_PREFIX="${OPENCLAW_NPM_DIR:-$(npm config get prefix 2>/dev/null || echo "$HOME/.nvm/versions/node/$(node -v | cut -d. -f1 | sed 's/v//')/lib")}"
    TARGET="$NPM_PREFIX/node_modules/@larksuite/openclaw-lark"
fi

if [ ! -d "$TARGET" ]; then
    echo "ERROR: openclaw-lark not found at $TARGET"
    echo "Install it first: npm install -g @larksuite/openclaw-lark"
    exit 1
fi

echo "Target: $TARGET"
echo "Applying streaming enhancer patches..."

# Apply patches
cd "$TARGET"

if patch -p1 --dry-run < "$SCRIPT_DIR/reply-dispatcher.patch" 2>/dev/null; then
    patch -p1 < "$SCRIPT_DIR/reply-dispatcher.patch"
    echo "  ✅ reply-dispatcher.js patched"
else
    # Try fuzzy match
    echo "  ⚠️  Exact patch failed, trying inline edit..."
    node -e "
const fs = require('fs');
const path = require('path');
const file = path.join('$TARGET', 'src/card/reply-dispatcher.js');
let content = fs.readFileSync(file, 'utf8');

// Find onToolStart handler in reply-options spread
const search = \"onToolStart: (payload) => controller.onToolStart(payload),\";
const replace = search + '\n' +
    '                    onCommandOutput: (payload) => controller.onCommandOutput(payload),\n' +
    '                    onToolResult: (payload) => controller.onToolResult?.(payload),\n' +
    '                    onItemEvent: (payload) => controller.onItemEvent?.(payload),';

if (content.includes(search) && !content.includes('onCommandOutput')) {
    content = content.replace(search, replace);
    fs.writeFileSync(file, content);
    console.log('  ✅ reply-dispatcher.js patched (inline)');
} else if (content.includes('onCommandOutput')) {
    console.log('  ⏭️  reply-dispatcher.js already patched');
} else {
    console.error('  ❌ Could not find injection point in reply-dispatcher.js');
    process.exit(1);
}
" && echo "  ✅ reply-dispatcher.js patched (inline)"
fi

if patch -p1 --dry-run < "$SCRIPT_DIR/streaming-card-controller.patch" 2>/dev/null; then
    patch -p1 < "$SCRIPT_DIR/streaming-card-controller.patch"
    echo "  ✅ streaming-card-controller.js patched"
else
    echo "  ⚠️  Exact patch failed, trying inline edit..."
    node -e "
const fs = require('fs');
const path = require('path');
const file = path.join('$TARGET', 'src/card/streaming-card-controller.js');
let content = fs.readFileSync(file, 'utf8');

// Check if already patched
if (content.includes('onCommandOutput(payload)')) {
    console.log('  ⏭️  streaming-card-controller.js already patched');
    process.exit(0);
}

// Find onToolPayload method — insert onCommandOutput before it
const search = /(\s+async onToolPayload\(_payload\) \{)/;
const replacement = `
    async onCommandOutput(payload) {
        if (!this.shouldProceed('onCommandOutput'))
            return;
        if (!this.shouldDisplayToolUse)
            return;
        this.markToolUseActivity();
        if (payload.output) {
            this.commandOutput = (this.commandOutput ?? '') + payload.output;
        }
        if (payload.phase === 'complete' || payload.status === 'complete') {
            const { recordToolUseEnd } = require('./tool-use-trace-store.js');
            recordToolUseEnd({
                toolName: payload.name ?? payload.title ?? 'exec',
                result: { output: this.commandOutput, exitCode: payload.exitCode },
                durationMs: payload.durationMs,
            });
        }
        await this.ensureCardCreated();
        if (!this.shouldProceed('onCommandOutput.postCreate'))
            return;
        if (!this.cardKit.cardMessageId)
            return;
        await this.throttledCardUpdate();
    }
\$1`;

if (search.test(content)) {
    content = content.replace(search, replacement);
    fs.writeFileSync(file, content);
    console.log('  ✅ streaming-card-controller.js patched (inline)');
} else {
    console.error('  ❌ Could not find injection point');
    process.exit(1);
}
"

fi

echo ""
echo "✅ Patches applied successfully!"
echo ""
echo "Restart OpenClaw to take effect:"
echo "  openclaw gateway restart"
echo ""
echo "To use streaming exec output in Feishu, enable verbose mode:"
echo "  - Send /verbose in a DM/group to enable tool-use display"
echo "  - Or set permanently: openclaw config set agents.defaults.verboseDefault on"
