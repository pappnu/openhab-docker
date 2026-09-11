#!/usr/bin/env python3

import json
import shutil
from pathlib import Path
from typing import NotRequired, TypedDict
from urllib.request import Request, urlopen

ADDONS_DIR = Path("/openhab/addons")
API_URL = (
    "https://api.github.com/repos/pappnu/openhab-heating-optimizer/releases/latest"
)
USER_AGENT = "openhab-heating-optimizer-installer"


class GitHubReleaseAsset(TypedDict):
    name: NotRequired[str]
    browser_download_url: NotRequired[str]


class GitHubRelease(TypedDict):
    assets: NotRequired[list[GitHubReleaseAsset]]


def _latest_jar_asset() -> tuple[str, str]:
    request = Request(
        API_URL,
        headers={
            "Accept": "application/vnd.github+json",
            "User-Agent": USER_AGENT,
        },
    )

    with urlopen(request, timeout=30) as response:
        release: GitHubRelease = json.load(response)

    assets = release.get("assets", [])
    for asset in assets:
        name = asset.get("name")
        download_url = asset.get("browser_download_url")

        if (
            isinstance(name, str)
            and name.endswith(".jar")
            and isinstance(download_url, str)
        ):
            return name, download_url

    raise RuntimeError("No JAR asset found in the latest GitHub release")


def _download(url: str, destination: Path) -> None:
    request = Request(url, headers={"User-Agent": USER_AGENT})

    with urlopen(request, timeout=30) as response, destination.open("wb") as output:
        shutil.copyfileobj(response, output)


def main() -> None:
    ADDONS_DIR.mkdir(parents=True, exist_ok=True)

    jar_name, download_url = _latest_jar_asset()
    jar_path = ADDONS_DIR / jar_name

    if jar_path.exists():
        print(
            f"Latest release of openhab-heating-optimizer is already installed: {jar_name}"
        )
        return

    for existing_jar in ADDONS_DIR.glob("openhab-heating-optimizer-*.jar"):
        existing_jar.unlink()

    temporary_path = ADDONS_DIR / f".{jar_name}.tmp"
    try:
        _download(download_url, temporary_path)
        temporary_path.replace(jar_path)
        print(f"Downloaded the latest release of openhab-heating-optimizer: {jar_name}")
    finally:
        temporary_path.unlink(missing_ok=True)


if __name__ == "__main__":
    main()
