import Foundation

/// Common allergen groups (EU "Big 14", which covers the FDA Big 9).
enum AllergenGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case peanuts, treeNuts, dairy, gluten, eggs, soy, fish, shellfish, molluscs, sesame, mustard, celery, sulphites, lupin

    var id: String { rawValue }

    var label: String {
        switch self {
        case .peanuts: "Peanuts"
        case .treeNuts: "Tree nuts"
        case .dairy: "Dairy"
        case .gluten: "Gluten"
        case .eggs: "Eggs"
        case .soy: "Soy"
        case .fish: "Fish"
        case .shellfish: "Shellfish"
        case .molluscs: "Molluscs"
        case .sesame: "Sesame"
        case .mustard: "Mustard"
        case .celery: "Celery"
        case .sulphites: "Sulphites"
        case .lupin: "Lupin"
        }
    }
}

/// Small curated ingredient → allergen lookup. Runs fully offline so high-risk items are flagged
/// the moment the AI returns its ingredient list, before any pattern detection has data.
enum AllergenDatabase {
    struct Entry {
        let group: AllergenGroup
        /// Words/phrases that indicate the group. Matched on word boundaries; plurals are tolerated.
        let keywords: [String]
        /// Phrases that look like a keyword but are not this allergen ("peanut butter" is not dairy).
        let exclusions: [String]
    }

    static let entries: [Entry] = [
        Entry(group: .peanuts,
              keywords: ["peanut", "groundnut", "arachis", "satay", "monkey nut"],
              exclusions: []),
        Entry(group: .treeNuts,
              keywords: ["almond", "cashew", "walnut", "pecan", "pistachio", "hazelnut", "macadamia",
                         "brazil nut", "pine nut", "praline", "marzipan", "frangipane", "nutella",
                         "pesto", "tree nut", "nut"],
              exclusions: ["nutmeg", "water chestnut", "coconut", "butternut", "peanut", "doughnut",
                           "donut", "groundnut", "monkey nut", "nutritional yeast"]),
        Entry(group: .dairy,
              keywords: ["milk", "cheese", "butter", "cream", "yogurt", "yoghurt", "ghee", "whey", "casein",
                         "lactose", "paneer", "mozzarella", "parmesan", "cheddar", "feta", "ricotta",
                         "mascarpone", "labneh", "halloumi", "brie", "custard", "ice cream", "bechamel",
                         "alfredo", "tzatziki", "buttermilk", "kefir", "curd", "caesar dressing"],
              exclusions: ["peanut butter", "almond butter", "nut butter", "cashew butter", "cocoa butter",
                           "apple butter", "shea butter", "coconut milk", "coconut cream", "almond milk",
                           "oat milk", "soy milk", "soya milk", "rice milk", "cashew milk", "cream of tartar",
                           "bean curd", "dairy free", "dairy-free", "vegan cheese"]),
        Entry(group: .gluten,
              keywords: ["wheat", "flour", "bread", "pasta", "noodle", "spaghetti", "couscous", "bulgur",
                         "barley", "rye", "malt", "semolina", "spelt", "seitan", "farro", "pita", "naan",
                         "tortilla", "crouton", "breadcrumb", "panko", "batter", "cracker", "biscuit",
                         "cake", "pastry", "pizza", "bun", "bagel", "croissant", "soy sauce", "beer",
                         "freekeh", "orzo", "udon", "ramen", "dumpling", "fettuccine", "linguine", "penne",
                         "macaroni", "lasagna", "lasagne", "vermicelli", "muffin", "pancake", "waffle"],
              exclusions: ["buckwheat", "gluten free", "gluten-free", "rice noodle", "rice flour",
                           "corn tortilla", "almond flour", "coconut flour", "chickpea flour", "rice cracker",
                           "tamari", "rice vermicelli"]),
        Entry(group: .eggs,
              keywords: ["egg", "mayonnaise", "mayo", "aioli", "meringue", "albumin", "omelette", "omelet",
                         "hollandaise", "frittata", "quiche", "custard", "brioche", "caesar dressing"],
              exclusions: ["eggplant", "egg-free", "egg free", "vegan mayo"]),
        Entry(group: .soy,
              keywords: ["soy", "soya", "soybean", "tofu", "edamame", "miso", "tempeh", "tamari", "natto"],
              exclusions: []),
        Entry(group: .fish,
              keywords: ["fish", "salmon", "tuna", "cod", "haddock", "anchovy", "sardine", "mackerel",
                         "trout", "tilapia", "halibut", "sea bass", "hammour", "snapper", "worcestershire",
                         "caesar dressing", "fish sauce", "bonito"],
              exclusions: ["shellfish"]),
        Entry(group: .shellfish,
              keywords: ["shrimp", "prawn", "crab", "lobster", "crayfish", "langoustine", "shellfish",
                         "crustacean", "krill"],
              exclusions: []),
        Entry(group: .molluscs,
              keywords: ["mussel", "oyster", "clam", "scallop", "squid", "calamari", "octopus", "snail",
                         "escargot", "cuttlefish", "oyster sauce"],
              exclusions: []),
        Entry(group: .sesame,
              keywords: ["sesame", "tahini", "tahina", "hummus", "halva", "halwa", "za atar", "zaatar", "gomashio"],
              exclusions: []),
        Entry(group: .mustard,
              keywords: ["mustard", "dijon"],
              exclusions: []),
        Entry(group: .celery,
              keywords: ["celery", "celeriac"],
              exclusions: []),
        Entry(group: .sulphites,
              keywords: ["wine", "sulphite", "sulfite", "dried apricot", "vinegar"],
              exclusions: []),
        Entry(group: .lupin,
              keywords: ["lupin", "lupine"],
              exclusions: []),
    ]

    /// Allergen groups an ingredient name belongs to (possibly several: "egg noodles" → eggs + gluten).
    static func groups(for ingredientName: String) -> [AllergenGroup] {
        let normalized = IngredientNormalizer.normalize(ingredientName)
        guard !normalized.isEmpty else { return [] }
        return entries.compactMap { entry in
            var text = " \(normalized) "
            for exclusion in entry.exclusions {
                let phrase = IngredientNormalizer.normalize(exclusion)
                for form in [phrase, phrase + "s", phrase + "es"] {
                    text = text.replacingOccurrences(of: " \(form) ", with: " ")
                }
            }
            return entry.keywords.contains { matches(keyword: $0, in: text) } ? entry.group : nil
        }
    }

    /// Returns a copy of `ingredient` with `allergenGroups` filled in.
    static func annotate(_ ingredient: Ingredient) -> Ingredient {
        var copy = ingredient
        copy.allergenGroups = groups(for: ingredient.name)
        return copy
    }

    /// Groups the user already told us about (from onboarding) that appear in `ingredients`.
    static func conflicts(in ingredients: [Ingredient], knownConditions: [String]) -> [AllergenGroup] {
        let known = Set(knownConditions.flatMap { condition -> [AllergenGroup] in
            if let group = AllergenGroup(rawValue: condition) { return [group] }
            return groups(for: condition)
        })
        let present = Set(ingredients.flatMap(\.allergenGroups))
        return AllergenGroup.allCases.filter { known.contains($0) && present.contains($0) }
    }

    private static func matches(keyword: String, in paddedText: String) -> Bool {
        let kw = IngredientNormalizer.normalize(keyword)
        return paddedText.contains(" \(kw) ") || paddedText.contains(" \(kw)s ") || paddedText.contains(" \(kw)es ")
    }
}

enum IngredientNormalizer {
    /// Lowercased, diacritic-folded, punctuation → spaces, single-spaced.
    static func normalize(_ raw: String) -> String {
        let folded = raw.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .init(identifier: "en_US"))
        let mapped = folded.unicodeScalars.map { CharacterSet.alphanumerics.contains($0) ? Character($0) : " " }
        return String(mapped).split(separator: " ").joined(separator: " ")
    }

    /// Key used to group the same ingredient across meals ("Tomatoes" and "tomato" → "tomato").
    static func canonicalKey(_ raw: String) -> String {
        normalize(raw).split(separator: " ").map { singular(String($0)) }.joined(separator: " ")
    }

    private static func singular(_ word: String) -> String {
        guard word.count > 3 else { return word }
        if word.hasSuffix("ies") { return String(word.dropLast(3)) + "y" }
        if word.hasSuffix("oes") { return String(word.dropLast(2)) }
        if word.hasSuffix("ss") || word.hasSuffix("us") || word.hasSuffix("is") { return word }
        if word.hasSuffix("s") { return String(word.dropLast()) }
        return word
    }
}
