"""Planche récap d'un lot : la rangée « repos » (face, 3/4, profil, gros plan) de chaque familier, l'une sous l'autre.

    python dataset_and_pipeline/tools/make_lot_sheet.py Lot01 ChienSaucisse HamsterJoufflu ...

Sortie : qa_renders/pets/<Lot>_sheet.png (à montrer à Chouaib), plus une version large par 4 familiers si le lot est
long (<Lot>_sheet_1.png, _2...).
"""

from __future__ import annotations

import sys
from pathlib import Path

from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parents[1]


def main() -> None:
    lot, pets = sys.argv[1], sys.argv[2:]
    rows = []
    for pet in pets:
        board = Image.open(ROOT / "qa_renders" / "pets" / f"{pet}_board.png").convert("RGB")
        row = board.crop((0, 0, board.width, board.height // 2))
        ImageDraw.Draw(row).text((14, 18), pet, fill=(255, 255, 255))
        rows.append(row)
    for k in range(0, len(rows), 4):
        chunk = rows[k:k + 4]
        sheet = Image.new("RGB", (chunk[0].width, sum(r.height for r in chunk)), (20, 20, 24))
        y = 0
        for row in chunk:
            sheet.paste(row, (0, y))
            y += row.height
        sheet.thumbnail((1700, 1700))
        suffix = "" if len(rows) <= 4 else f"_{k // 4 + 1}"
        out = ROOT / "qa_renders" / "pets" / f"{lot}_sheet{suffix}.png"
        sheet.save(out)
        print(out)


if __name__ == "__main__":
    main()
