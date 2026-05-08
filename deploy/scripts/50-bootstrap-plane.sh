#!/usr/bin/env bash
set -euo pipefail

echo "Plane bootstrap is version-sensitive."
echo "1. Start core, MinIO bucket policy, and plane compose."
echo "2. Run Plane migrations if required by the selected release."
echo "3. Configure OIDC in God Mode if env-driven OIDC is unsupported."
echo "4. Create the first workspace and verify upload storage."
