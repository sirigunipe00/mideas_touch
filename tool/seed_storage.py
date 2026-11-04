#!/usr/bin/env python3
"""Upload the 28 Diwali template pictures to the Supabase `app-assets` bucket.

Run AFTER supabase/backend/01_schema.sql (it creates the bucket).

    export SUPABASE_URL="https://<project>.supabase.co"
    export SUPABASE_SERVICE_ROLE_KEY="<secret key (sb_secret_...) or legacy service_role key>"
    python3 tool/seed_storage.py            # upload (existing files are replaced)
    python3 tool/seed_storage.py --verify   # only check the public URLs

The key bypasses every security rule. Keep it in your shell only: never put it
in config/supabase.json, the Flutter app or git.

Uses the system `curl` (so macOS' own certificate store is used) and, when an
ISP returns a wrong address for supabase.co, resolves the host name over HTTPS
(Cloudflare) and connects to that address instead. The TLS certificate is still
checked against the real host name.

(Alternative without any key: Supabase dashboard > Storage > app-assets >
create the folder `templates` and drag in supabase/seed/images/*.jpg.)
"""
import json
import os
import subprocess
import sys
import time
import urllib.parse
from pathlib import Path

BUCKET = "app-assets"
FOLDER = "templates"
IMAGES = Path(__file__).resolve().parent.parent / "supabase" / "seed" / "images"


def curl(args: list[str], timeout: int = 90) -> tuple[int, str]:
    """Returns (exit code, stdout). stdout ends with the HTTP status code."""
    p = subprocess.run(
        ["curl", "-sS", "-m", str(timeout), "-w", "\n%{http_code}", *args],
        capture_output=True,
        text=True,
    )
    return p.returncode, p.stdout


def resolve_over_https(host: str) -> list[str]:
    code, out = curl(
        ["-H", "accept: application/dns-json",
         f"https://cloudflare-dns.com/dns-query?name={host}&type=A"],
        timeout=20,
    )
    if code != 0:
        return []
    try:
        data = json.loads(out.rsplit("\n", 1)[0])
    except ValueError:
        return []
    return [a["data"] for a in data.get("Answer", []) if a.get("type") == 1]


def main() -> int:
    verify_only = "--verify" in sys.argv
    url = os.environ.get("SUPABASE_URL", "").rstrip("/")
    key = os.environ.get("SUPABASE_SERVICE_ROLE_KEY", "")
    if not url or (not key and not verify_only):
        print("Set SUPABASE_URL and SUPABASE_SERVICE_ROLE_KEY first (see the file header).")
        return 2
    files = sorted(IMAGES.glob("*.jpg"))
    if not files:
        print(f"No pictures found in {IMAGES}")
        return 2

    host = urllib.parse.urlparse(url).hostname
    ips = resolve_over_https(host)
    resolve = ["--resolve", f"{host}:443:{ips[0]}"] if ips else []
    print(f"{host} -> {ips[0]} (resolved over HTTPS)" if ips
          else "(could not resolve over HTTPS; using system DNS)")

    failed = 0
    for path in files:
        object_path = f"{FOLDER}/{path.name}"
        if not verify_only:
            headers = ["-H", f"apikey: {key}", "-H", "Content-Type: image/jpeg",
                       "-H", "x-upsert: true"]
            # New-style secret keys (sb_secret_...) are not JWTs and must only
            # go in `apikey`; legacy service_role keys are JWTs and need Bearer.
            if not key.startswith("sb_secret_"):
                headers += ["-H", f"Authorization: Bearer {key}"]
            status, body = "", ""
            for _ in range(4):  # the connection can be flaky
                code, out = curl(
                    [*resolve, *headers, "-X", "POST", "--data-binary", f"@{path}",
                     f"{url}/storage/v1/object/{BUCKET}/{object_path}"])
                body, _, status = out.rpartition("\n")
                if code == 0 and status == "200":
                    break
                time.sleep(2)
            if status != "200":
                print(f"FAILED  {object_path}: HTTP {status} {body[:200]}")
                failed += 1
                continue
        code, out = curl(
            [*resolve, "-o", os.devnull, "-I",
             f"{url}/storage/v1/object/public/{BUCKET}/{object_path}"], timeout=30)
        if code == 0 and out.strip().endswith("200"):
            print(f"ok      {object_path}")
        else:
            print(f"MISSING {object_path}: HTTP {out.strip()[-3:]}")
            failed += 1
    print(f"\n{len(files) - failed}/{len(files)} pictures available in bucket '{BUCKET}'.")
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
