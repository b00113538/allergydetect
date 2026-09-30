import SwiftUI

/// Insights → Blood work: uploaded panels and how they line up with the food patterns.
struct BloodworkInsightsView: View {
    @EnvironmentObject private var app: AppState
    @State private var showUpload = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Button { showUpload = true } label: { Label("Add blood work", systemImage: "testtube.2") }
                .buttonStyle(.nouriPrimary)

            if app.bloodwork.isEmpty {
                NouriCard {
                    Text("No results yet").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                    Text("If you've had an allergy blood test (specific IgE / ImmunoCAP), add it here. Nouri compares it with what your logs show — where they agree, and where they don't.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
            } else {
                comparison
                records
            }

            NouriCard {
                Label("Reading IgE results", systemImage: "info.circle").font(NouriFont.label).foregroundStyle(Color.nouriTextPrimary)
                Text("Class 0 (under 0.35 kU/L) is negative. Class 1 and above means sensitised — your immune system recognises the allergen — but many sensitised people never react, and intolerances don't show up on IgE tests at all. Moderate or higher food results (class 2+) are added to your Dine Code. Always review results with a clinician.")
                    .font(.footnote)
                    .foregroundStyle(Color.nouriTextSecondary)
            }
        }
        .sheet(isPresented: $showUpload) { BloodworkUploadFlowView() }
    }

    @ViewBuilder
    private var comparison: some View {
        let findings = app.bloodworkFindings
        if !findings.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                Text("Blood test vs. your logs").nouriHeading(.title3)
                ForEach(findings) { FindingRow(finding: $0) }
            }
        }
    }

    private var records: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Panels").nouriHeading(.title3)
            ForEach(app.bloodwork) { record in
                NavigationLink { BloodworkDetailView(record: record) } label: {
                    NouriCard {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(record.testDate.formatted(date: .abbreviated, time: .omitted))
                                    .font(.headline)
                                    .foregroundStyle(Color.nouriTextPrimary)
                                Text("\(record.panelResults.count) allergens tested · \(record.sensitisedResults.count) sensitised\(record.labName.map { " · \($0)" } ?? "")")
                                    .font(.caption)
                                    .foregroundStyle(Color.nouriTextSecondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").foregroundStyle(Color.nouriTextSecondary)
                        }
                        if !record.sensitisedResults.isEmpty {
                            FlowLayout {
                                ForEach(record.sensitisedResults.prefix(6), id: \.self) { result in
                                    Tag(text: "\(result.allergen) · \(result.effectiveClass)", color: result.effectiveClass.igeClassColor)
                                }
                            }
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }
}

private struct FindingRow: View {
    let finding: BloodworkFinding

    private var color: Color {
        switch finding.kind {
        case .agrees: .nouriDanger
        case .sensitisedOnly: .nouriWarning
        case .patternOnly: .nouriAccent
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(finding.allergen).font(.headline).foregroundStyle(Color.nouriTextPrimary)
                Spacer()
                Tag(text: finding.kind.label, color: color)
            }
            Text(finding.explanation).font(.caption).foregroundStyle(Color.nouriTextSecondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.nouriSurface, in: RoundedRectangle(cornerRadius: 14, style: .continuous))
        .overlay(RoundedRectangle(cornerRadius: 14, style: .continuous).stroke(Color.nouriBorder))
    }
}
