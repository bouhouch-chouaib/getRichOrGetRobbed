"""Tapis de course, modèle Sport (un des 10 modèles, du plus simple au plus spectaculaire), en briques sans lueur : voir _station.py."""

import _station as ST


def build(name: str) -> dict:
    return ST.treadmill(name, ST.TIERS["Sport"])
