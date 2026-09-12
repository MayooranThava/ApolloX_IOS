#!/usr/bin/env python3
"""Fill Void Runner App Store Connect review blockers via the ASC API.

Reads credentials from the environment only. Never commit keys.

  ASC_ISSUER_ID     UUID from App Store Connect → Users and Access → Integrations
  ASC_KEY_ID        10-character Key ID
  ASC_PRIVATE_KEY   PEM contents of AuthKey_<KEY_ID>.p8
                    (or ASC_KEY_PATH pointing at that file)

Usage:
  python3 scripts/asc_fill_review_blockers.py           # read-only status
  python3 scripts/asc_fill_review_blockers.py --apply   # write the review fields
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import time
import urllib.error
import urllib.parse
import urllib.request
from typing import Any

import jwt

BUNDLE_ID = "com.mayooran.ApolloX"
PRIVACY_URL = "https://mayooranthava.github.io/ApolloX_IOS/privacy-policy.html"
SUPPORT_URL = "https://mayooranthava.github.io/ApolloX_IOS/support.html"
COPYRIGHT = "2026 Mayooran Thavajogarasa"
DESCRIPTION = (
    "Void Runner is a portrait arcade space shooter. Drag to steer, auto-fire at "
    "asteroids, grab stars for a fire boost, dodge mines, and take down rotating bosses.\n\n"
    "Earn credits each run to unlock hulls and weapons in the Hangar. Optional Game Center "
    "ranks your high score globally — the game is fully playable signed out.\n\n"
    "No ads. No in-app purchases."
)
KEYWORDS = "space,shooter,arcade,game,ship,boss,asteroid,galaxy"
WHATS_NEW = "Initial release."

AGE_RATING_ATTRIBUTES: dict[str, Any] = {
    "alcoholTobaccoOrDrugUseOrReferences": "NONE",
    "contests": "INFREQUENT",
    "gamblingSimulated": "NONE",
    "gunsOrOtherWeapons": "FREQUENT",
    "horrorOrFearThemes": "NONE",
    "matureOrSuggestiveThemes": "NONE",
    "medicalOrTreatmentInformation": "NONE",
    "profanityOrCrudeHumor": "NONE",
    "sexualContentGraphicAndNudity": "NONE",
    "sexualContentOrNudity": "NONE",
    "violenceCartoonOrFantasy": "FREQUENT",
    "violenceRealistic": "NONE",
    "violenceRealisticProlongedGraphicOrSadistic": "NONE",
    "gambling": False,
    "lootBox": False,
    "unrestrictedWebAccess": False,
    "messagingAndChat": False,
    "ageAssurance": False,
    "advertising": False,
    "parentalControls": False,
    "userGeneratedContent": False,
    "healthOrWellnessTopics": False,
    "ageRatingOverrideV2": "NONE",
}

API = "https://api.appstoreconnect.apple.com/v1"


class AscError(RuntimeError):
    def __init__(self, status: int, body: str) -> None:
        self.status = status
        self.body = body
        super().__init__(f"ASC HTTP {status}: {body[:2000]}")


def _private_key() -> str:
    pem = os.environ.get("ASC_PRIVATE_KEY", "").strip()
    if pem:
        return pem.replace("\\n", "\n")
    path = os.environ.get("ASC_KEY_PATH", "").strip()
    if path:
        return open(os.path.expanduser(path), encoding="utf-8").read()
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    fallback = os.path.expanduser(f"~/.private_keys/AuthKey_{key_id}.p8") if key_id else ""
    if fallback and os.path.isfile(fallback):
        return open(fallback, encoding="utf-8").read()
    raise SystemExit(
        "Missing App Store Connect credentials. Set ASC_ISSUER_ID, ASC_KEY_ID, "
        "and ASC_PRIVATE_KEY (or ASC_KEY_PATH)."
    )


def generate_token() -> str:
    key_id = os.environ.get("ASC_KEY_ID", "").strip()
    issuer = os.environ.get("ASC_ISSUER_ID", "").strip()
    if not key_id or not issuer:
        raise SystemExit("Set ASC_KEY_ID and ASC_ISSUER_ID.")
    now = int(time.time())
    return jwt.encode(
        {"iss": issuer, "iat": now, "exp": now + 18 * 60, "aud": "appstoreconnect-v1"},
        _private_key(),
        algorithm="ES256",
        headers={"kid": key_id, "typ": "JWT"},
    )


def api_request(method: str, path: str, data: dict[str, Any] | None = None) -> Any:
    token = generate_token()
    url = path if path.startswith("http") else f"{API}/{path.lstrip('/')}"
    body = json.dumps(data).encode() if data is not None else None
    req = urllib.request.Request(
        url,
        data=body,
        method=method,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
    )
    try:
        with urllib.request.urlopen(req) as resp:
            raw = resp.read()
            if not raw or resp.status == 204:
                return None
            return json.loads(raw)
    except urllib.error.HTTPError as exc:
        err_body = exc.read().decode("utf-8", errors="replace")
        raise AscError(exc.code, err_body) from exc


def _attr(resource: dict[str, Any], key: str, default: Any = None) -> Any:
    return (resource.get("attributes") or {}).get(key, default)


def pick_editable_app_info(app_infos: list[dict[str, Any]]) -> dict[str, Any]:
    preferred = {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
        "WAITING_FOR_REVIEW",
        "INVALID_BINARY",
    }
    for info in app_infos:
        if _attr(info, "appStoreState") in preferred or _attr(info, "state") in preferred:
            return info
    for info in app_infos:
        state = str(_attr(info, "appStoreState") or _attr(info, "state") or "")
        if state and state not in {"READY_FOR_SALE", "REPLACED_WITH_NEW_INFO"}:
            return info
    return app_infos[0]


def pick_version(versions: list[dict[str, Any]]) -> dict[str, Any]:
    preferred = {
        "PREPARE_FOR_SUBMISSION",
        "DEVELOPER_REJECTED",
        "REJECTED",
        "METADATA_REJECTED",
        "WAITING_FOR_REVIEW",
        "INVALID_BINARY",
    }
    for ver in versions:
        if _attr(ver, "appStoreState") in preferred:
            return ver
    return versions[0]


def summarize() -> dict[str, Any]:
    apps = api_request("GET", f"apps?filter[bundleId]={urllib.parse.quote(BUNDLE_ID)}")
    if not apps or not apps.get("data"):
        raise SystemExit(f"No app found for bundle id {BUNDLE_ID}")
    app = apps["data"][0]
    app_id = app["id"]
    infos = api_request("GET", f"apps/{app_id}/appInfos?include=primaryCategory,primarySubcategoryOne,primarySubcategoryTwo,secondaryCategory,appInfoLocalizations")
    app_info = pick_editable_app_info(infos["data"])

    def rel_id(name: str) -> str | None:
        data = ((app_info.get("relationships") or {}).get(name) or {}).get("data")
        if isinstance(data, dict):
            return data.get("id")
        return None

    versions = api_request("GET", f"apps/{app_id}/appStoreVersions?limit=20")
    version = pick_version(versions["data"])
    version_id = version["id"]
    locs = api_request("GET", f"appStoreVersions/{version_id}/appStoreVersionLocalizations")
    info_locs = api_request("GET", f"appInfos/{app_info['id']}/appInfoLocalizations")

    age_id = None
    age_attrs: dict[str, Any] = {}
    try:
        age = api_request("GET", f"appInfos/{app_info['id']}/ageRatingDeclaration")
        if age and age.get("data"):
            age_id = age["data"]["id"]
            age_attrs = age["data"].get("attributes") or {}
    except AscError:
        try:
            age = api_request("GET", f"appStoreVersions/{version_id}/ageRatingDeclaration")
            if age and age.get("data"):
                age_id = age["data"]["id"]
                age_attrs = age["data"].get("attributes") or {}
        except AscError:
            pass

    return {
        "app": app,
        "app_id": app_id,
        "app_info": app_info,
        "app_info_id": app_info["id"],
        "categories": {
            "primary": rel_id("primaryCategory"),
            "primarySubOne": rel_id("primarySubcategoryOne"),
            "primarySubTwo": rel_id("primarySubcategoryTwo"),
            "secondary": rel_id("secondaryCategory"),
        },
        "version": version,
        "version_id": version_id,
        "version_locs": locs["data"],
        "info_locs": info_locs["data"],
        "age_id": age_id,
        "age_attrs": age_attrs,
        "content_rights": _attr(app, "contentRightsDeclaration"),
    }


def print_status(state: dict[str, Any]) -> None:
    app = state["app"]
    ver = state["version"]
    print(f"App: {_attr(app, 'name')}  id={state['app_id']}")
    print(f"Bundle: {_attr(app, 'bundleId')}")
    print(f"Content rights: {state['content_rights'] or '(missing)'}")
    print(
        f"Version: {_attr(ver, 'versionString')}  "
        f"state={_attr(ver, 'appStoreState')}  platform={_attr(ver, 'platform')}  "
        f"copyright={_attr(ver, 'copyright') or '(missing)'}"
    )
    print(f"Categories: {state['categories']}")
    print(f"Age rating declaration: {state['age_id'] or '(missing)'}")
    if state["age_attrs"]:
        interesting = {
            k: state["age_attrs"].get(k)
            for k in (
                "violenceCartoonOrFantasy",
                "gunsOrOtherWeapons",
                "contests",
                "advertising",
                "unrestrictedWebAccess",
            )
        }
        print(f"  {interesting}")
    print("App-info privacy URLs:")
    for loc in state["info_locs"]:
        print(f"  {_attr(loc, 'locale')}: {_attr(loc, 'privacyPolicyUrl') or '(missing)'}")
    print("Version support URLs:")
    for loc in state["version_locs"]:
        print(
            f"  {_attr(loc, 'locale')}: support={_attr(loc, 'supportUrl') or '(missing)'}  "
            f"desc={'set' if _attr(loc, 'description') else 'missing'}"
        )
    print(
        "\nNote: App Privacy nutrition labels cannot be published via the API. "
        "An Admin still has to complete App Privacy → data types → Publish in the web UI."
    )


def patch_ignore_unknown(path: str, payload: dict[str, Any], attrs: dict[str, Any]) -> None:
    """PATCH, dropping attributes Apple rejects as unknown or illegal."""
    remaining = dict(attrs)
    for _ in range(12):
        payload["data"]["attributes"] = remaining
        try:
            api_request("PATCH", path, payload)
            return
        except AscError as exc:
            dropped = []
            try:
                parsed = json.loads(exc.body)
            except json.JSONDecodeError:
                raise
            for err in parsed.get("errors") or []:
                pointer = ((err.get("source") or {}).get("pointer") or "")
                # /data/attributes/foo
                parts = [p for p in pointer.split("/") if p]
                if len(parts) >= 3 and parts[0] == "data" and parts[1] == "attributes":
                    key = parts[2]
                    if key in remaining:
                        dropped.append(key)
                        remaining.pop(key, None)
            if not dropped:
                raise
            print(f"  retry without {dropped}")
    raise RuntimeError(f"Could not PATCH {path} after dropping unknown fields")


def apply(state: dict[str, Any]) -> None:
    app_id = state["app_id"]
    app_info_id = state["app_info_id"]
    version_id = state["version_id"]

    print("Setting content rights…")
    api_request(
        "PATCH",
        f"apps/{app_id}",
        {
            "data": {
                "type": "apps",
                "id": app_id,
                "attributes": {"contentRightsDeclaration": "USES_THIRD_PARTY_CONTENT"},
            }
        },
    )

    print("Setting Games → Action (+ Arcade)…")
    api_request(
        "PATCH",
        f"appInfos/{app_info_id}",
        {
            "data": {
                "type": "appInfos",
                "id": app_info_id,
                "relationships": {
                    "primaryCategory": {"data": {"type": "appCategories", "id": "GAMES"}},
                    "primarySubcategoryOne": {
                        "data": {"type": "appCategories", "id": "GAMES_ACTION"}
                    },
                    "primarySubcategoryTwo": {
                        "data": {"type": "appCategories", "id": "GAMES_ARCADE"}
                    },
                },
            }
        },
    )

    print("Setting privacy policy URL on app-info localizations…")
    for loc in state["info_locs"]:
        api_request(
            "PATCH",
            f"appInfoLocalizations/{loc['id']}",
            {
                "data": {
                    "type": "appInfoLocalizations",
                    "id": loc["id"],
                    "attributes": {"privacyPolicyUrl": PRIVACY_URL},
                }
            },
        )
        print(f"  {_attr(loc, 'locale')}")

    print("Setting support URL / listing copy on version localizations…")
    for loc in state["version_locs"]:
        attrs: dict[str, Any] = {"supportUrl": SUPPORT_URL}
        if not (_attr(loc, "description") or "").strip():
            attrs["description"] = DESCRIPTION
        if not (_attr(loc, "keywords") or "").strip():
            attrs["keywords"] = KEYWORDS
        if not (_attr(loc, "whatsNew") or "").strip():
            attrs["whatsNew"] = WHATS_NEW
        api_request(
            "PATCH",
            f"appStoreVersionLocalizations/{loc['id']}",
            {"data": {"type": "appStoreVersionLocalizations", "id": loc["id"], "attributes": attrs}},
        )
        print(f"  {_attr(loc, 'locale')}")

    if not (_attr(state["version"], "copyright") or "").strip():
        print("Setting copyright…")
        api_request(
            "PATCH",
            f"appStoreVersions/{version_id}",
            {
                "data": {
                    "type": "appStoreVersions",
                    "id": version_id,
                    "attributes": {"copyright": COPYRIGHT},
                }
            },
        )

    age_id = state["age_id"]
    if not age_id:
        raise SystemExit("No ageRatingDeclaration id — open App Information once in the web UI, then rerun.")
    print(f"Setting age rating questionnaire ({age_id})…")
    patch_ignore_unknown(
        f"ageRatingDeclarations/{age_id}",
        {"data": {"type": "ageRatingDeclarations", "id": age_id, "attributes": {}}},
        AGE_RATING_ATTRIBUTES,
    )

    print("Done. Re-fetching status…")
    print_status(summarize())


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--apply", action="store_true", help="Write the review-blocker fields")
    args = parser.parse_args()
    try:
        state = summarize()
    except AscError as exc:
        print(exc, file=sys.stderr)
        if exc.status in {401, 403}:
            print(
                "Auth failed. The key needs App Manager or Admin access, and "
                "Issuer ID / Key ID / .p8 must match.",
                file=sys.stderr,
            )
        return 1
    print_status(state)
    if args.apply:
        print("\nApplying…")
        apply(state)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
