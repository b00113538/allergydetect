import Foundation

/// Common causes of contact dermatitis and skin irritation, grouped the way patch-test series and
/// dermatologists talk about them. Used to roll individual label ingredients ("Linalool",
/// "Methylchloroisothiazolinone") and product/fabric names ("Wool jumper") up into something a
/// pattern can emerge from across *different* products.
enum ContactAllergenGroup: String, Codable, CaseIterable, Identifiable, Hashable {
    case fragrance, isothiazolinones, formaldehydeReleasers, parabens, lanolin, surfactants
    case hairDye, propyleneGlycol, essentialOils, colophony, wool, syntheticFibres, latex, nickel

    var id: String { rawValue }

    var label: String {
        switch self {
        case .fragrance: "Fragrance"
        case .isothiazolinones: "Isothiazolinone preservatives"
        case .formaldehydeReleasers: "Formaldehyde releasers"
        case .parabens: "Parabens"
        case .lanolin: "Lanolin"
        case .surfactants: "Harsh surfactants (SLS)"
        case .hairDye: "Hair dye (PPD)"
        case .propyleneGlycol: "Propylene glycol"
        case .essentialOils: "Essential oils"
        case .colophony: "Colophony (rosin)"
        case .wool: "Wool"
        case .syntheticFibres: "Synthetic fibres"
        case .latex: "Latex"
        case .nickel: "Nickel"
        }
    }

    /// Materials and fibres roll up to the fabric domain; chemicals in products to skin.
    var domain: TriggerDomain {
        switch self {
        case .wool, .syntheticFibres, .latex, .nickel: .fabric
        default: .skin
        }
    }
}

enum ContactAllergenDatabase {
    struct Entry {
        let group: ContactAllergenGroup
        /// Whole-word matches (plurals tolerated), for short or common words.
        let words: [String]
        /// Substring matches, for chemical names that appear inside longer INCI names.
        let fragments: [String]
        /// Phrases removed before matching ("fragrance free" is not fragrance).
        let exclusions: [String]
    }

    static let entries: [Entry] = [
        Entry(group: .fragrance,
              words: ["parfum", "fragrance", "perfume", "aroma", "citral", "eugenol", "isoeugenol", "coumarin", "farnesol"],
              fragments: ["linalool", "limonene", "citronellol", "geraniol", "cinnamal", "cinnamyl alcohol",
                          "hydroxycitronellal", "benzyl benzoate", "benzyl salicylate", "benzyl cinnamate",
                          "anise alcohol", "evernia", "lyral", "hydroxyisohexyl"],
              exclusions: ["fragrance free", "fragrance-free", "parfum free", "unscented", "no fragrance", "without fragrance"]),
        Entry(group: .isothiazolinones,
              words: ["mci", "mit"],
              fragments: ["isothiazolinone", "kathon"],
              exclusions: []),
        Entry(group: .formaldehydeReleasers,
              words: ["formaldehyde", "formalin", "bronopol"],
              fragments: ["dmdm hydantoin", "imidazolidinyl urea", "diazolidinyl urea", "quaternium 15",
                          "bromo 2 nitropropane", "sodium hydroxymethylglycinate", "methenamine"],
              exclusions: ["formaldehyde free", "formaldehyde-free"]),
        Entry(group: .parabens,
              words: [],
              fragments: ["paraben"],
              exclusions: ["paraben free", "paraben-free", "parabens free", "no parabens"]),
        Entry(group: .lanolin,
              words: ["lanolin", "adeps lanae", "wool alcohol", "wool wax", "wool fat"],
              fragments: ["lanolin"],
              exclusions: ["lanolin free", "lanolin-free"]),
        Entry(group: .surfactants,
              words: ["sls", "sles"],
              fragments: ["sodium lauryl sulfate", "sodium laureth sulfate", "ammonium lauryl sulfate",
                          "sodium lauryl sulphate", "sodium laureth sulphate", "cocamidopropyl betaine"],
              exclusions: ["sls free", "sulfate free", "sulphate free"]),
        Entry(group: .hairDye,
              words: ["ppd", "hair dye", "hair colour", "hair color"],
              fragments: ["phenylenediamine", "toluene 2 5 diamine", "aminophenol"],
              exclusions: ["ppd free", "ppd-free"]),
        Entry(group: .propyleneGlycol,
              words: [],
              fragments: ["propylene glycol"],
              exclusions: []),
        Entry(group: .essentialOils,
              words: ["essential oil", "tea tree", "eucalyptus", "lavender oil", "peppermint oil", "ylang ylang"],
              fragments: ["melaleuca", "lavandula", "mentha piperita", "rosmarinus", "citrus aurantium", "cananga odorata"],
              exclusions: []),
        Entry(group: .colophony,
              words: ["rosin", "colophony", "colophonium", "abietic acid"],
              fragments: ["colophon"],
              exclusions: []),
        Entry(group: .wool,
              words: ["wool", "merino", "cashmere", "angora", "mohair", "alpaca", "lambswool"],
              fragments: [],
              exclusions: ["wool alcohol", "wool wax", "wool fat", "cotton wool", "steel wool", "wool free"]),
        Entry(group: .syntheticFibres,
              words: ["polyester", "nylon", "polyamide", "acrylic", "elastane", "spandex", "lycra", "polypropylene", "synthetic"],
              fragments: [],
              exclusions: []),
        Entry(group: .latex,
              words: ["latex", "natural rubber", "rubber glove"],
              fragments: [],
              exclusions: ["latex free", "latex-free"]),
        Entry(group: .nickel,
              words: ["nickel"],
              fragments: [],
              exclusions: ["nickel free", "nickel-free"]),
    ]

    /// Groups a single name belongs to (an INCI ingredient, a fibre, or a product/fabric name).
    static func groups(for text: String) -> [ContactAllergenGroup] {
        let normalized = IngredientNormalizer.normalize(text)
        guard !normalized.isEmpty else { return [] }
        return entries.compactMap { entry in
            var padded = " \(normalized) "
            for exclusion in entry.exclusions {
                padded = padded.replacingOccurrences(of: " \(IngredientNormalizer.normalize(exclusion)) ", with: " ")
            }
            let hit = entry.words.contains { word in
                let w = IngredientNormalizer.normalize(word)
                return padded.contains(" \(w) ") || padded.contains(" \(w)s ")
            } || entry.fragments.contains { padded.contains(IngredientNormalizer.normalize($0)) }
            return hit ? entry.group : nil
        }
    }

    /// Everything an exposure brings: its own name ("Wool jumper") plus every label ingredient.
    static func groups(for exposure: SkinExposure) -> Set<ContactAllergenGroup> {
        Set(([exposure.name] + (exposure.ingredients ?? [])).flatMap(groups(for:)))
    }
}
