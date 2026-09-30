import SwiftUI

/// Every extracted value is shown for the user to check against the report before saving —
/// numbers from a lab report shouldn't be stored unreviewed.
struct BloodworkReviewView: View {
    @Binding var draft: BloodworkDraft
    var hasDocument: Bool
    var onSave: () -> Void

    var body: some View {
        Form {
            if hasDocument {
                Section {
                    Label("Check each value against your report before saving.", systemImage: "checkmark.shield")
                        .font(.footnote)
                    if !draft.readerNotes.isEmpty {
                        Text(draft.readerNotes).font(.footnote).foregroundStyle(Color.nouriTextSecondary)
                    }
                }
            }
            Section("Test") {
                DatePicker("Test date", selection: $draft.testDate, in: ...Date.now, displayedComponents: .date)
                TextField("Lab or clinic (optional)", text: $draft.labName)
            }
            Section {
                ForEach($draft.rows) { $row in
                    ResultRowEditor(row: $row)
                }
                .onDelete { draft.rows.remove(atOffsets: $0) }
                Button {
                    draft.rows.append(.init())
                } label: {
                    Label("Add result", systemImage: "plus")
                }
            } header: {
                Text("Results (kU/L)")
            } footer: {
                Text("Type bounds as printed, e.g. <0.10 or >100. Leave class on Auto unless the report states one. Class 1 and above (≥ 0.35 kU/L) means sensitised.")
            }
            Section("Notes") {
                TextField("Anything else from your clinician (optional)", text: $draft.notes, axis: .vertical)
                    .lineLimit(2...5)
            }
            Section {
                Button("Save results", action: onSave)
                    .buttonStyle(.nouriPrimary)
                    .disabled(draft.panelResults.isEmpty || draft.invalidRowCount > 0)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets())
            } footer: {
                if draft.invalidRowCount > 0 {
                    Text("\(draft.invalidRowCount) row\(draft.invalidRowCount == 1 ? " needs" : "s need") a name and a number.")
                        .foregroundStyle(Color.nouriDanger)
                }
            }
        }
        .scrollContentBackground(.hidden)
    }
}

private struct ResultRowEditor: View {
    @Binding var row: BloodworkDraft.Row

    private var derivedClass: Int? { row.panelResult?.effectiveClass }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Allergen (e.g. Cow's milk)", text: $row.allergen)
                .font(.headline)
            HStack {
                TextField("Level", text: $row.level)
                    .keyboardType(.numbersAndPunctuation)
                    .frame(maxWidth: 110)
                    .textFieldStyle(.roundedBorder)
                Spacer()
                Picker("Class", selection: $row.igeClass) {
                    Text(derivedClass.map { "Auto (\($0))" } ?? "Auto").tag(Int?.none)
                    ForEach(0...6, id: \.self) { Text("Class \($0)").tag(Optional($0)) }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }
            if let result = row.panelResult {
                Tag(text: IgEScale.label(forClass: result.effectiveClass), color: result.effectiveClass.igeClassColor)
            }
        }
        .padding(.vertical, 4)
    }
}

extension Int {
    /// IgE class 0–6 → colour.
    var igeClassColor: Color {
        switch self {
        case ...0: .nouriSuccess
        case 1...2: .nouriWarning
        default: .nouriDanger
        }
    }
}
