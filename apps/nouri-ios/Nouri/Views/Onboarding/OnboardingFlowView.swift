import SwiftUI

/// Sign-up follow-up: about you → symptom history → known allergies.
struct OnboardingFlowView: View {
    @EnvironmentObject private var app: AppState
    @State private var step = 0
    @State private var name = ""
    @State private var hasDOB = false
    @State private var dateOfBirth = Calendar.current.date(byAdding: .year, value: -30, to: .now) ?? .now
    @State private var usualSymptoms: Set<SymptomType> = []
    @State private var frequency: SymptomHistory.Frequency = .weekly
    @State private var suspectsFood = true
    @State private var suspectsSkin = false
    @State private var knownGroups: Set<AllergenGroup> = []
    @State private var otherConditions = ""
    @State private var isSaving = false

    private let stepCount = 3

    var body: some View {
        VStack(spacing: 0) {
            ProgressView(value: Double(step + 1), total: Double(stepCount))
                .tint(Color.nouriPrimaryText)
                .padding(.horizontal, 24)
                .padding(.top, 16)

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    switch step {
                    case 0: aboutYou
                    case 1: symptomHistory
                    default: knownAllergies
                    }
                }
                .padding(24)
            }

            HStack(spacing: 12) {
                if step > 0 {
                    Button("Back") { withAnimation { step -= 1 } }
                        .buttonStyle(.nouriSecondary)
                }
                Button(step == stepCount - 1 ? "Finish" : "Continue") {
                    if step == stepCount - 1 { finish() } else { withAnimation { step += 1 } }
                }
                .buttonStyle(.nouriPrimary)
                .disabled(!canContinue || isSaving)
            }
            .padding(24)
        }
        .nouriScreenBackground()
        .onAppear { if name.isEmpty { name = app.pendingAccount?.name ?? "" } }
    }

    private var aboutYou: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Welcome to Nouri").nouriHeading(.largeTitle)
            Text("A few quick questions so we can tailor your insights.").foregroundStyle(Color.nouriTextSecondary)
            NouriCard {
                Text("Name").font(NouriFont.label)
                TextField("Your name", text: $name).nouriField()
                Toggle("Add date of birth", isOn: $hasDOB.animation())
                if hasDOB {
                    DatePicker("Date of birth", selection: $dateOfBirth, in: ...Date.now, displayedComponents: .date)
                }
            }
        }
    }

    private var symptomHistory: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Your symptoms").nouriHeading(.largeTitle)
            NouriCard {
                Text("Which of these do you get?").font(NouriFont.label)
                FlowLayout {
                    ForEach(SymptomType.allCases.filter { $0 != .none }) { symptom in
                        Chip(title: symptom.label, systemImage: symptom.symbol, isSelected: usualSymptoms.contains(symptom)) {
                            usualSymptoms.formSymmetricDifference([symptom])
                        }
                    }
                }
            }
            NouriCard {
                Text("How often?").font(NouriFont.label)
                Picker("Frequency", selection: $frequency) {
                    ForEach(SymptomHistory.Frequency.allCases) { Text($0.label).tag($0) }
                }
                .pickerStyle(.inline)
                .labelsHidden()
            }
            NouriCard {
                Toggle("I think food is involved", isOn: $suspectsFood)
                Toggle("I react to skincare or fabrics", isOn: $suspectsSkin)
            }
        }
    }

    private var knownAllergies: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("Known allergies").nouriHeading(.largeTitle)
            Text("Anything a doctor has confirmed, or you already avoid. Nouri will flag these the moment they appear in a meal. Skip if none.")
                .foregroundStyle(Color.nouriTextSecondary)
            NouriCard {
                FlowLayout {
                    ForEach(AllergenGroup.allCases) { group in
                        Chip(title: group.label, isSelected: knownGroups.contains(group), tint: .nouriDanger) {
                            knownGroups.formSymmetricDifference([group])
                        }
                    }
                }
                TextField("Other (comma separated), e.g. kiwi, latex", text: $otherConditions).nouriField()
            }
        }
    }

    private var canContinue: Bool {
        step != 0 || !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func finish() {
        isSaving = true
        let others = otherConditions.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces).lowercased() }.filter { !$0.isEmpty }
        let conditions = AllergenGroup.allCases.filter(knownGroups.contains).map(\.rawValue) + others
        let history = SymptomHistory(usualSymptoms: SymptomType.allCases.filter(usualSymptoms.contains),
                                     frequency: frequency, suspectsFood: suspectsFood, suspectsSkinOrFabric: suspectsSkin)
        Task {
            await app.completeOnboarding(name: name.trimmingCharacters(in: .whitespaces),
                                         dateOfBirth: hasDOB ? dateOfBirth : nil,
                                         history: history, knownConditions: conditions)
            isSaving = false
        }
    }
}
