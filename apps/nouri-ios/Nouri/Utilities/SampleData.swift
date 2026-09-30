import Foundation

/// Deterministic demo history for pitches: a user who reacts to dairy (and mildly to shrimp).
enum SampleData {
    static func history(userId: String, days: Int = 21, now: Date = .now) -> ([MealEntry], [SymptomLog]) {
        var rng = SeededGenerator(seed: 42)
        let menu: [(MealType, String, [String])] = [
            (.breakfast, "Greek yogurt bowl", ["Greek yogurt", "Honey", "Blueberries", "Granola"]),
            (.breakfast, "Shakshuka", ["Eggs", "Tomato", "Onion", "Bell pepper", "Cumin"]),
            (.breakfast, "Avocado toast", ["Sourdough bread", "Avocado", "Lemon", "Chili flakes"]),
            (.breakfast, "Oat porridge", ["Oats", "Oat milk", "Banana", "Cinnamon"]),
            (.lunch, "Chicken shawarma plate", ["Chicken", "Garlic sauce", "Rice", "Pickles", "Tahini"]),
            (.lunch, "Margherita pizza", ["Pizza dough", "Mozzarella", "Tomato sauce", "Basil"]),
            (.lunch, "Lentil soup", ["Lentils", "Carrot", "Onion", "Cumin", "Lemon"]),
            (.lunch, "Garlic prawn noodles", ["Prawns", "Rice noodles", "Garlic", "Spring onion", "Tamari"]),
            (.dinner, "Grilled hammour", ["Hammour", "Rice", "Lemon", "Parsley"]),
            (.dinner, "Chicken alfredo", ["Chicken", "Fettuccine", "Cream", "Parmesan cheese", "Garlic"]),
            (.dinner, "Beef stir-fry", ["Beef", "Broccoli", "Rice", "Ginger", "Garlic"]),
            (.dinner, "Paneer tikka", ["Paneer", "Yogurt", "Bell pepper", "Onion", "Garam masala"]),
            (.snack, "Hummus & veg", ["Hummus", "Carrot", "Cucumber"]),
            (.snack, "Cheese & crackers", ["Cheddar cheese", "Crackers", "Grapes"]),
        ]
        let hours: [MealType: Int] = [.breakfast: 8, .lunch: 13, .dinner: 19, .snack: 16]

        var meals: [MealEntry] = []
        var logs: [SymptomLog] = []
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        for dayOffset in stride(from: days, through: 1, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            for type in [MealType.breakfast, .lunch, .dinner] + (rng.next() % 3 == 0 ? [.snack] : []) {
                let options = menu.filter { $0.0 == type }
                let pick = options[Int(rng.next() % UInt64(options.count))]
                let minute = Int(rng.next() % 50)
                guard let time = calendar.date(bySettingHour: hours[type]!, minute: minute, second: 0, of: day) else { continue }
                let ingredients = pick.2.map { AllergenDatabase.annotate(Ingredient(name: $0, confidence: 0.85, source: .ai)) }
                let meal = MealEntry(userId: userId, timestamp: time, ingredients: ingredients, mealType: type,
                                     dishName: pick.1, needsSync: true)
                meals.append(meal)

                let groups = Set(ingredients.flatMap(\.allergenGroups))
                let roll = rng.next() % 100
                let reaction: (types: [SymptomType], severity: Int)?
                if groups.contains(.dairy) && roll < 85 {
                    reaction = ([.mucus, .cough], 3 + Int(rng.next() % 2))
                } else if groups.contains(.shellfish) && roll < 70 {
                    reaction = ([.rash, .irritation], 2 + Int(rng.next() % 2))
                } else if roll < 6 {
                    reaction = ([.drowsiness], 1)
                } else {
                    reaction = nil
                }
                if let reaction {
                    let delay = TimeInterval(2 * 3600 + Int(rng.next() % 10_800))
                    logs.append(SymptomLog(userId: userId, mealEntryId: rng.next() % 2 == 0 ? meal.id : nil,
                                           timestamp: time.addingTimeInterval(delay), symptomTypes: reaction.types,
                                           severity: reaction.severity, notes: ""))
                } else if roll % 4 == 0 {
                    logs.append(SymptomLog(userId: userId, mealEntryId: meal.id, timestamp: time.addingTimeInterval(3 * 3600),
                                           symptomTypes: [.none], severity: 1))
                }
            }
        }
        return (meals, logs)
    }

    /// Skin diary for the same period: wool reliably causes itching; everything else is noise.
    static func skinHistory(userId: String, days: Int = 21, now: Date = .now) -> [SkinLog] {
        var rng = SeededGenerator(seed: 7)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        var logs: [SkinLog] = []
        for dayOffset in stride(from: days, through: 1, by: -1) where rng.next() % 3 != 0 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today),
                  let time = calendar.date(bySettingHour: 20, minute: Int(rng.next() % 50), second: 0, of: day) else { continue }
            var exposures = [SkinExposure(name: "Moisturiser", kind: .product)]
            exposures.append(rng.next() % 2 == 0
                             ? SkinExposure(name: "Wool jumper", kind: .fabric)
                             : SkinExposure(name: "Cotton t-shirt", kind: .fabric))
            if rng.next() % 3 == 0 { exposures.append(SkinExposure(name: "Sunscreen", kind: .product)) }

            let wool = exposures.contains { $0.name == "Wool jumper" }
            let roll = rng.next() % 100
            if (wool && roll < 80) || roll < 5 {
                logs.append(SkinLog(userId: userId, timestamp: time, exposures: exposures, reactions: [.itching, .redness],
                                    bodyAreas: [.arms, .torso], severity: 2 + Int(rng.next() % 2)))
            } else {
                logs.append(SkinLog(userId: userId, timestamp: time, exposures: exposures, reactions: [.none], severity: 1))
            }
        }
        return logs
    }

    /// A plausible specific-IgE panel that agrees with the sample history (dairy, shellfish) and adds
    /// an inhalant (dust mite) the food logs can't see.
    static let bloodworkPanel: [BloodworkRecord.PanelResult] = [
        .init(allergen: "Cow's milk", igeLevel: 8.2, igeClass: 3),
        .init(allergen: "Shrimp", igeLevel: 1.4, igeClass: 2),
        .init(allergen: "Dermatophagoides pteronyssinus (dust mite)", igeLevel: 2.1, igeClass: 2),
        .init(allergen: "Egg white", igeLevel: 0.12, igeClass: 0),
        .init(allergen: "Wheat", igeLevel: 0.21, igeClass: 0),
        .init(allergen: "Peanut", igeLevel: 0.1, igeClass: 0, comparator: .lessThan),
        .init(allergen: "Sesame", igeLevel: 0.1, igeClass: 0, comparator: .lessThan),
    ]

    static func bloodworkRecord(userId: String, now: Date = .now) -> BloodworkRecord {
        BloodworkRecord(userId: userId, testDate: Calendar.current.date(byAdding: .day, value: -10, to: now) ?? now,
                        labName: "Demo Diagnostics", panelResults: bloodworkPanel)
    }

    /// SplitMix64 — tiny, deterministic, good enough for demo data.
    struct SeededGenerator {
        private var state: UInt64
        init(seed: UInt64) { state = seed }
        mutating func next() -> UInt64 {
            state &+= 0x9E37_79B9_7F4A_7C15
            var z = state
            z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
            z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
            return z ^ (z >> 31)
        }
    }
}
