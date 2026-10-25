"""Génère une image avec RunComfy (API HTTP directe) : références LEGO des familiers, 25 oct. 2026.

La CLI `runcomfy` du skill ai-image-generation n'existe pas sous Windows : ce script fait les mêmes appels
(POST /v1/models/<modèle>, puis /v1/requests/<id>/status et /result) avec la bibliothèque standard de Python.

    python dataset_and_pipeline/tools/gen_image.py --name PigeonVilles --prompt "..." [--model ...] [--out ...]
    python dataset_and_pipeline/tools/gen_image.py --name ChatRuelle --prompt-file prompt.txt

Clé : variable d'environnement RUNCOMFY_TOKEN, sinon le fichier %USERPROFILE%\\.config\\runcomfy\\token.json
({"token": "..."}) ou token.txt à côté. La clé n'est jamais affichée ni écrite ailleurs. Elle se trouve sur
runcomfy.com/profile (compte RunComfy de Chouaib, payant à l'image).
Sécurité (comme le skill) : on ne télécharge que des adresses https de *.runcomfy.net / *.runcomfy.com.
"""

from __future__ import annotations

import argparse
import json
import os
import re
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path
from urllib.parse import urlparse

API = "https://model-api.runcomfy.net/v1"
DEFAULT_MODEL = "blackforestlabs/flux-2-klein/9b/text-to-image"
OUT = Path(__file__).resolve().parents[1] / "lego_refs"
ALLOWED = (".runcomfy.net", ".runcomfy.com")


def token() -> str:
    value = os.environ.get("RUNCOMFY_TOKEN", "").strip()
    if value:
        return value
    folder = Path.home() / ".config" / "runcomfy"
    # utf-8-sig : PowerShell 5.1 ajoute un BOM en tête des fichiers qu'il écrit
    if (folder / "token.json").exists():
        data = json.loads((folder / "token.json").read_text("utf-8-sig"))
        value = str(data.get("token") or data.get("access_token") or "").strip()
    elif (folder / "token.txt").exists():
        value = (folder / "token.txt").read_text("utf-8-sig").strip()
    if not value:
        sys.exit("Pas de clé RunComfy : RUNCOMFY_TOKEN ou ~/.config/runcomfy/token.json (voir runcomfy.com/profile).")
    return value


def call(method: str, url: str, body: dict | None = None) -> dict:
    data = json.dumps(body).encode("utf-8") if body is not None else None
    req = urllib.request.Request(url, data=data, method=method, headers={
        "Authorization": f"Bearer {token()}", "Content-Type": "application/json", "Accept": "application/json"})
    try:
        with urllib.request.urlopen(req, timeout=120) as resp:
            return json.loads(resp.read().decode("utf-8") or "{}")
    except urllib.error.HTTPError as err:
        detail = err.read().decode("utf-8", "replace")[:400]
        sys.exit(f"RunComfy {err.code} sur {urlparse(url).path} : {detail}")


def _urls(node) -> list[str]:
    found = []
    if isinstance(node, dict):
        for value in node.values():
            found += _urls(value)
    elif isinstance(node, list):
        for value in node:
            found += _urls(value)
    elif isinstance(node, str) and node.startswith("https://"):
        host = urlparse(node).hostname or ""
        if host.endswith(ALLOWED):
            found.append(node)
    return found


def generate(name: str, prompt: str, model: str = DEFAULT_MODEL, out: Path = OUT, extra: dict | None = None) -> list[Path]:
    out.mkdir(parents=True, exist_ok=True)
    body = {"prompt": prompt, **(extra or {})}
    sub = call("POST", f"{API}/models/{model}", body)
    request_id = sub.get("request_id") or sub.get("id")
    if not request_id:
        sys.exit(f"Réponse inattendue : {json.dumps(sub)[:300]}")
    t0 = time.time()
    while True:
        status = call("GET", f"{API}/requests/{request_id}/status")
        state = str(status.get("status", "")).lower()
        if state in ("completed", "succeeded", "success"):
            break
        if state in ("failed", "error", "cancelled", "canceled"):
            sys.exit(f"Échec RunComfy : {json.dumps(status)[:300]}")
        if time.time() - t0 > 600:
            sys.exit("RunComfy : plus de 10 minutes, abandon")
        time.sleep(2)
    result = call("GET", f"{API}/requests/{request_id}/result")
    saved = []
    for index, url in enumerate(dict.fromkeys(_urls(result))):
        ext = Path(urlparse(url).path).suffix.lower() or ".png"
        if ext not in (".png", ".jpg", ".jpeg", ".webp"):
            continue
        path = out / (f"{name}{ext}" if index == 0 else f"{name}_{index}{ext}")
        with urllib.request.urlopen(url, timeout=120) as resp:
            path.write_bytes(resp.read())
        saved.append(path)
    (out / f"{name}.json").write_text(json.dumps({"model": model, "prompt": prompt, "request_id": request_id,
                                                  "seconds": round(time.time() - t0, 1)}, ensure_ascii=False, indent=2),
                                      "utf-8")
    if not saved:
        sys.exit(f"Aucune image dans le résultat : {json.dumps(result)[:300]}")
    return saved


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__.split("\n")[0])
    parser.add_argument("--name", required=True, help="nom du fichier (Id du familier)")
    parser.add_argument("--prompt")
    parser.add_argument("--prompt-file")
    parser.add_argument("--model", default=DEFAULT_MODEL)
    parser.add_argument("--out", default=str(OUT))
    parser.add_argument("--width", type=int, default=1536)
    parser.add_argument("--height", type=int, default=864)
    parser.add_argument("--steps", type=int, default=25)
    args = parser.parse_args()
    prompt = args.prompt or Path(args.prompt_file).read_text("utf-8").strip()
    extra = {"width": args.width, "height": args.height, "steps": args.steps} if "flux-2-klein" in args.model else {}
    for path in generate(args.name, prompt, args.model, Path(args.out), extra):
        print(f"[gen_image] {path}")


if __name__ == "__main__":
    main()
