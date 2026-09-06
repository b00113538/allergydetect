"""Shared domain constants: allergens, cross-reactivity families, symptoms."""

# EU Big-14 + common synonyms (FDA Big-9 is a subset of these).
BIG_14_ALLERGENS = [
    "gluten",
    "crustaceans",
    "eggs",
    "fish",
    "peanuts",
    "soybeans",
    "milk",
    "nuts",
    "celery",
    "mustard",
    "sesame",
    "sulphites",
    "lupin",
    "molluscs",
]

# Cross-reactivity / allergen family expansion used by the correlation engine.
# If a key ingredient is implicated, its related terms get a boosted candidate score.
ALLERGEN_FAMILIES: dict[str, list[str]] = {
    "shrimp": ["lobster", "crab", "crayfish", "prawn", "crustacean"],
    "crab": ["lobster", "shrimp", "crayfish", "prawn", "crustacean"],
    "lobster": ["crab", "shrimp", "crayfish", "prawn", "crustacean"],
    "milk": ["casein", "whey", "lactose", "butter", "cream", "cheese", "yogurt"],
    "gluten": ["wheat", "barley", "rye", "malt", "spelt", "couscous", "semolina"],
    "wheat": ["gluten", "barley", "rye", "malt", "spelt"],
    "peanut": ["groundnut", "arachis"],
    "soy": ["soybean", "edamame", "tofu", "miso", "tempeh"],
    "egg": ["albumin", "mayonnaise", "meringue"],
    # Latex-fruit syndrome
    "latex": ["banana", "avocado", "kiwi", "chestnut", "papaya"],
    # Oral allergy syndrome (birch-pollen related)
    "birch": ["apple", "pear", "cherry", "carrot", "celery", "hazelnut"],
}

# Oral allergy syndrome cross-reactivities (pollen -> foods)
ORAL_ALLERGY_SYNDROME: dict[str, list[str]] = {
    "ragweed": ["banana", "melon", "cucumber", "zucchini"],
    "grass": ["tomato", "potato", "peach", "watermelon"],
    "mugwort": ["celery", "carrot", "parsley", "fennel"],
}

SYMPTOM_OPTIONS = [
    "rash_hives",
    "sneezing",
    "itchy_eyes",
    "headache",
    "brain_fog",
    "bloating",
    "cramping",
    "nausea",
    "fatigue",
    "palpitations",
    "swollen_lips",
    "difficulty_breathing",
    "skin_flushing",
    "diarrhoea",
]

# Symptoms that, alone, indicate a possible anaphylactic emergency.
ANAPHYLAXIS_SYMPTOMS = {"difficulty_breathing", "anaphylaxis", "swollen_lips"}

GRADE_VALUES = {"A": 95, "B": 80, "C": 60, "D": 40, "F": 20}

ACTIVITY_MULTIPLIERS = {
    "sedentary": 1.2,
    "light": 1.375,
    "moderate": 1.55,
    "active": 1.725,
    "very_active": 1.9,
}

MACRO_SPLITS = {
    "lose_fat": {"protein": 0.35, "fat": 0.30, "carbs": 0.35, "deficit": -500},
    "maintain": {"protein": 0.30, "fat": 0.30, "carbs": 0.40, "deficit": 0},
    "gain_muscle": {"protein": 0.35, "fat": 0.25, "carbs": 0.40, "deficit": 300},
    "manage_allergies": {"protein": 0.30, "fat": 0.30, "carbs": 0.40, "deficit": 0},
    "general_wellness": {"protein": 0.25, "fat": 0.30, "carbs": 0.45, "deficit": 0},
}

MEAL_TARGET_PCT = {"breakfast": 0.25, "lunch": 0.35, "dinner": 0.30, "snack": 0.10}

# 40 supported translation languages (code -> English name)
SUPPORTED_LANGUAGES = {
    "es": "Spanish", "fr": "French", "de": "German", "it": "Italian",
    "pt": "Portuguese", "nl": "Dutch", "pl": "Polish", "ru": "Russian",
    "ja": "Japanese", "zh": "Chinese (Simplified)", "zh-TW": "Chinese (Traditional)",
    "ko": "Korean", "ar": "Arabic", "hi": "Hindi", "th": "Thai", "vi": "Vietnamese",
    "id": "Indonesian", "ms": "Malay", "tr": "Turkish", "el": "Greek",
    "he": "Hebrew", "sv": "Swedish", "da": "Danish", "no": "Norwegian",
    "fi": "Finnish", "cs": "Czech", "hu": "Hungarian", "ro": "Romanian",
    "uk": "Ukrainian", "bg": "Bulgarian", "hr": "Croatian", "sk": "Slovak",
    "sl": "Slovenian", "et": "Estonian", "lv": "Latvian", "lt": "Lithuanian",
    "fa": "Persian", "ur": "Urdu", "bn": "Bengali", "ta": "Tamil",
}
