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
NEXTCLOUD_BROWSER_OIDC_PROVIDER_ID="${NEXTCLOUD_BROWSER_OIDC_PROVIDER_ID:-1}"

if [[ -z "$NEXTCLOUD_BROWSER_PASSWORD" || "$NEXTCLOUD_BROWSER_PASSWORD" == change-me* ]]; then
  die "set NEXTCLOUD_BROWSER_PASSWORD or DEMO_PASSWORD before running browser smoke"
fi
export NEXTCLOUD_BROWSER_PASSWORD

tmp_dir="$(mktemp -d)"
trap 'rm -rf "$tmp_dir"' EXIT

cat >"$tmp_dir/nextcloud-smoke.mjs" <<'JS'
import { chromium } from "playwright";

const nextcloudUrl = process.env.NEXTCLOUD_URL.replace(/\/$/, "");
const username = process.env.NEXTCLOUD_BROWSER_USERNAME;
const password = process.env.NEXTCLOUD_BROWSER_PASSWORD;
const target = process.env.NEXTCLOUD_BROWSER_TARGET || "files";
const providerId = process.env.NEXTCLOUD_BROWSER_OIDC_PROVIDER_ID || "1";

async function fillFirstVisible(locator, value) {
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    const candidate = locator.nth(i);
    if (await candidate.isVisible({ timeout: 1000 }).catch(() => false)) {
      await candidate.fill(value);
      return true;
    }
  }
  return false;
}

async function clickFirst(locator) {
  const count = await locator.count();
  for (let i = 0; i < count; i += 1) {
    const candidate = locator.nth(i);
    if (await candidate.isVisible({ timeout: 1000 }).catch(() => false)) {
      await candidate.click({ timeout: 15000 }).catch((error) => {
        if (error.name !== "TimeoutError") {
          throw error;
        }
      });
      return true;
    }
  }
  return false;
}

async function safePageLabel(page) {
  const parsed = new URL(page.url());
  const title = await page.title().catch(() => "");
  return `${parsed.origin}${parsed.pathname}${title ? ` (${title})` : ""}`;
}

function isNextcloudLanding(url) {
  const parsed = new URL(url);
  return parsed.origin === nextcloudUrl && !/\/login|\/apps\/user_oidc\//.test(parsed.pathname);
}

async function completeAuthentikLogin(page) {
  for (let attempt = 0; attempt < 8; attempt += 1) {
    await page.waitForLoadState("domcontentloaded", { timeout: 30000 }).catch(() => {});
    if (isNextcloudLanding(page.url())) {
      return;
    }

    const userFilled = await fillFirstVisible(
      page.locator('input[name="uidField"], input[name="identifier"], input[type="email"], input[type="text"], input[name="username"]'),
      username,
    );
    const passwordFilled = await fillFirstVisible(
      page.locator('input[name="password"], input[type="password"]'),
      password,
    );
    let clicked = false;
    if (userFilled || passwordFilled) {
      clicked = await clickFirst(page.getByRole("button", { name: /log in|sign in|continue|next|authorize|allow|approve/i }));
    } else {
      clicked = await clickFirst(page.getByRole("link", { name: /authentik|openid|single sign-on/i }));
      if (!clicked) {
        clicked = await clickFirst(page.getByRole("button", { name: /authorize|allow|approve|continue|next/i }));
      }
    }

    if (!userFilled && !passwordFilled && !clicked) {
      await page.waitForTimeout(1000);
      continue;
    }
    await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
  }
}

const browser = await chromium.launch({ headless: true });
const context = await browser.newContext({ ignoreHTTPSErrors: true });
const page = await context.newPage();

try {
  const landingPath = target === "collectives" ? "/apps/collectives/" : "/apps/files/";
  const redirectUrl = encodeURIComponent(landingPath);
  await page.goto(`${nextcloudUrl}/apps/user_oidc/login/${providerId}?redirectUrl=${redirectUrl}`, {
    waitUntil: "domcontentloaded",
    timeout: 60000,
  });

  await completeAuthentikLogin(page);

  await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});
  if (target === "collectives") {
    await page.goto(`${nextcloudUrl}/apps/collectives/`, { waitUntil: "domcontentloaded", timeout: 60000 });
  } else {
    await page.goto(`${nextcloudUrl}/apps/files/`, { waitUntil: "domcontentloaded", timeout: 60000 });
  }
  await page.waitForLoadState("networkidle", { timeout: 60000 }).catch(() => {});

  const body = await page.locator("body").innerText({ timeout: 30000 });
  if (/login|sign in|authentik/i.test(body) && !/Lab Demo Documents|Lab Knowledge Base|Files|Collectives/i.test(body)) {
    throw new Error(`browser smoke still appears to be on a login page at ${await safePageLabel(page)}`);
  }
  if (!/Lab Demo Documents|Lab Knowledge Base|Files|Collectives|All files/i.test(body)) {
    throw new Error(`browser smoke did not find a Nextcloud Files or Collectives landing signal at ${await safePageLabel(page)}`);
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
  -e NEXTCLOUD_BROWSER_PASSWORD \
  -e "NEXTCLOUD_BROWSER_TARGET=$NEXTCLOUD_BROWSER_TARGET" \
  -e "NEXTCLOUD_BROWSER_OIDC_PROVIDER_ID=$NEXTCLOUD_BROWSER_OIDC_PROVIDER_ID" \
  -e PLAYWRIGHT_SKIP_BROWSER_DOWNLOAD=1 \
  "$NEXTCLOUD_BROWSER_IMAGE" \
  sh -c 'set -e; workdir="$(mktemp -d)"; cp /work/nextcloud-smoke.mjs "$workdir/"; cd "$workdir"; npm init -y >/dev/null; npm install --silent playwright@1.52.0 >/dev/null; node nextcloud-smoke.mjs'
