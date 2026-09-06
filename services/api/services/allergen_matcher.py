from typing import Any

from constants import ALLERGEN_FAMILIES


def _norm(s: str) -> str:
    return (s or "").strip().lower()


def expand_terms(allergen: str) -> set[str]:
    a = _norm(allergen)
    return {a, *(_norm(t) for t in ALLERGEN_FAMILIES.get(a, []))}


def cross_reference(flags: list[str], user_allergies: list[Any]) -> list[dict]:
    """Match a list of allergen flags against the user's profile.

    Returns one entry per matched user allergy:
      { allergen, severity, confirmed_by_doctor, matched_flag, status }
    status is 'confirmed' (user has this allergy) — used to colour badges red.
    """
    norm_flags = [_norm(f) for f in (flags or [])]
    matches: list[dict] = []
    for allergy in user_allergies:
        name = _norm(getattr(allergy, "allergen_name", allergy) if not isinstance(allergy, str) else allergy)
        terms = expand_terms(name)
        for flag in norm_flags:
            if any(term and (term in flag or flag in term) for term in terms):
                matches.append(
                    {
                        "allergen": name,
                        "severity": getattr(allergy, "severity", "moderate") if not isinstance(allergy, str) else "moderate",
                        "confirmed_by_doctor": getattr(allergy, "confirmed_by_doctor", False) if not isinstance(allergy, str) else False,
                        "matched_flag": flag,
                        "status": "confirmed",
                    }
                )
                break
    return matches
