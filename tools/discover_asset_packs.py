"""Inspect official publishers' pages and retain their license/source evidence."""
import json
from pathlib import Path
import re
import urllib.request

output = Path("build/asset-discovery")
output.mkdir(parents=True, exist_ok=True)
for publisher, url in [
    ("kenney-blaster-kit", "https://kenney.nl/assets/blaster-kit"),
    ("quaternius-guns", "https://quaternius.com/packs/ultimategunpack.html"),
]:
    try:
        with urllib.request.urlopen(url, timeout=30) as response:
            page = response.read().decode("utf-8")
        (output / (publisher + ".html")).write_text(page)
        links = re.findall(r'href=[\"\']([^\"\']+)[\"\']', page)
        evidence = {"publisher": publisher, "url": url, "links": [link for link in links if any(word in link.lower() for word in ["zip", "download", "drive.google", "license", "creativecommons", "itch.io"])],
                    "cc0_mentioned": "CC0" in page or "publicdomain/zero" in page}
        print(json.dumps(evidence), flush=True)
    except Exception as error:
        print(json.dumps({"publisher": publisher, "url": url, "error": str(error)}), flush=True)
