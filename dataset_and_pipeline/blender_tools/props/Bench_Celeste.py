"""Banc de muscu, modèle Celeste (un des 10 modèles, du plus simple au plus spectaculaire), en briques sans lueur : voir _station.py."""

import _station as ST


def build(name: str) -> dict:
    return ST.bench(name, ST.TIERS["Celeste"])
