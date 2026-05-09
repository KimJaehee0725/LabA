#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=deploy/scripts/lib/common.sh
. "$SCRIPT_DIR/lib/common.sh"

load_envs "$ENV_DIR/00-global.env" "$ENV_DIR/60-nextcloud.env" "$ENV_DIR/99-demo.env"

require_cmd docker
require_cmd mktemp

NEXTCLOUD_URL="${NEXTCLOUD_URL:-https://${NEXTCLOUD_DOMAIN:-files.lab.snu.ac.kr}}"
NEXTCLOUD_BROWSER_USERNAME="${NEXTCLOUD_BROWSER_USERNAME:-${DEMO_USERNAME:-demo.member}}"
NEXTCLOUD_BROWSER_PASSWORD="${NEXTCLOUD_BROWSER_PASSWORD:-${DEMO_PASSWORD:-}}"
NEXTCLOUD_BROWSER_IMAGE="${NEXTCLOUD_BROWSER_IMAGE:-mcr.microsoft.com/playwright:v1.52.0-noble}"
NEXTCLOUD_BROWSER_TARGET="${NEXTCLOUD_BROWSER_TARGET:-files}"

if [[ -z "$NEXTCLOUD_BROWSER_PASSWORD" || "$NEXTCLOUD_BROWSER_PASSWORD" == change-me* ]]; then
  die "set NEXTCLOUD_BROWSER_PASSWORD or DEMO_PASSWORD before running browser smoke"
fi

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/nextcloud-smoke.mjs" <<'JS'
import { chromium } from "playwright";

const nextcloudUrl = process.env.NEXTCLOUD_URL.replace(/\/$/, "");
const username = process.env.NEXTCLOUD_BROWSER_USERNAME;
const password = process.env.NEXTCLOUD_BROWSER_PASSWORD;
const target = process.env.NEXTCLOUD_BROWSER_TARGET || "files";

async function fillFirst(locator, value) {
  const count = await locator.count();
  if (count === 0) return false;
  await locator.first().fill(value);
  return true;
}

async function clickFirst(locator) {
  const count = await locator.count();
  if (count === 0) return false;
  await locator.first().click();
  return true;
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

try {
  await page.goto(nextcloudUrl, { waitUntil: "domcontentloaded", timeout: 60000 });

  await clickFirst(page.getByRole("link", { name: /authentik|openid|single sign-on|log in/i }));
  await clickFirst(page.getByRole("button", { name: /authentik|openid|single sign-on|log in/i }));

  await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});

  const userFilled = await fillFirst(page.locator('input[name="uidField"], input[name="username"], input[name="identifier"], input[type="email"], input[type="text"]'), username);
  if (userFilled) {
    await clickFirst(page.getByRole("button", { name: /continue|next|log in|sign in/i }));
  }

  await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
  const passwordFilled = await fillFirst(page.locator('input[name="password"], input[type="password"]'), password);
  if (passwordFilled) {
    await clickFirst(page.getByRole("button", { name: /log in|sign in|continue/i }));
  }

  await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
  if (target === "collectives") {
    await page.goto(`${nextcloudUrl}/apps/collectives/`, { waitUntil: "domcontentloaded", timeout: 60000 });
  } else {
    await page.goto(`${nextcloudUrl}/apps/files/`, { waitUntil: "domcontentloaded", timeout: 60000 });
  }
  await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});

  const body = await page.locator("body").innerText({ timeout: 30000 });
  if (/login|sign in|authentik/i.test(body) && !/Lab Demo Documents|Lab Knowledge Base|Files|Collectives/i.test(body)) {
    throw new Error("browser smoke still appears to be on a login page");
  }
  if (!/Lab Demo Documents|Lab Knowledge Base|Files|Collectives|All files/i.test(body)) {
    throw new Error("browser smoke did not find a Nextcloud Files or Collectives landing signal");
  }
  console.log(`nextcloud browser smoke reached ${target}`);
} finally {
  await browser.close();
}
JS

docker run --rm \
  --network host \
  -v "$tmp_dir:/work:ro" \
  -e "NEXTCLOUD_URL=$NEXTCLOUD_URL" \
  -e "NEXTCLOUD_BROWSER_USERNAME=$NEXTCLOUD_BROWSER_USERNAME" \
  -e "NEXTCLOUD_BROWSER_PASSWORD=$NEXTCLOUD_BROWSER_PASSWORD" \
  -e "NEXTCLOUD_BROWSER_TARGET=$NEXTCLOUD_BROWSER_TARGET" \
  "$NEXTCLOUD_BROWSER_IMAGE" \
  node /work/nextcloud-smoke.mjs
