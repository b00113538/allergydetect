import SwiftUI

/// "Coming soon": at partner restaurants, scan the table's QR code when ordering and your allergens
/// travel with the order to the waiter and the kitchen ticket. Teaser only — nothing is sent yet.
struct PartnerOrderingTeaser: View {
    @State private var showInfo = false

    var body: some View {
        Button { showInfo = true } label: {
            NouriCard {
                HStack(alignment: .top, spacing: 14) {
                    Image(systemName: "fork.knife.circle")
                        .font(.system(size: 30))
                        .foregroundStyle(Color.nouriPrimaryText)
                        .accessibilityHidden(true)
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Order with Nouri").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                            Spacer()
                            Tag(text: "Coming soon")
                        }
                        Text("At partner restaurants, scan the QR code on your table when you order — your waiter and the kitchen get your allergens with the order.")
                            .font(.footnote)
                            .multilineTextAlignment(.leading)
                            .foregroundStyle(Color.nouriTextSecondary)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityHint("Shows how ordering at partner restaurants will work")
        .sheet(isPresented: $showInfo) { PartnerOrderingInfoView() }
    }
}

struct PartnerOrderingInfoView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nouri.partnerOrdering.notify") private var notifyWhenLive = false

    private let steps: [(symbol: String, title: String, detail: String)] = [
        ("qrcode.viewfinder", "Scan at the table",
         "Partner restaurants have a Nouri code on the table or menu. Scan it with Nouri when you're ready to order."),
        ("checkmark.shield", "You choose what to share",
         "Review your allergies and likely triggers and confirm before anything is sent. Nothing leaves your phone without your tap."),
        ("person.badge.shield.checkmark", "Your waiter is told",
         "Your server sees an allergy alert for your seat, so they can flag dishes and answer questions."),
        ("frying.pan", "The kitchen ticket carries it",
         "Your allergens are printed on the order ticket for the kitchen, so the people cooking your food know too."),
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    VStack(alignment: .leading, spacing: 8) {
                        Tag(text: "Coming soon")
                        Text("Order with Nouri").nouriHeading(.title)
                        Text("No more repeating your allergies to every new person — or hoping the message made it to the kitchen.")
                            .foregroundStyle(Color.nouriTextSecondary)
                    }

                    NouriCard {
                        ForEach(Array(steps.enumerated()), id: \.offset) { index, step in
                            HStack(alignment: .top, spacing: 14) {
                                Image(systemName: step.symbol)
                                    .font(.title3)
                                    .frame(width: 30)
                                    .foregroundStyle(Color.nouriPrimaryText)
                                    .accessibilityHidden(true)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("\(index + 1). \(step.title)").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                                    Text(step.detail).font(.footnote).foregroundStyle(Color.nouriTextSecondary)
                                }
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }

                    NouriCard {
                        Toggle(isOn: $notifyWhenLive) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Tell me when it launches").font(.headline).foregroundStyle(Color.nouriTextPrimary)
                                Text("We'll let you know when partner restaurants are live near you.")
                                    .font(.footnote)
                                    .foregroundStyle(Color.nouriTextSecondary)
                            }
                        }
                        .tint(Color.nouriPrimary)
                    }

                    Text("Until then, your Dine Code works anywhere: show it to staff and they can scan it with their phone camera.")
                        .font(.footnote)
                        .foregroundStyle(Color.nouriTextSecondary)
                }
                .padding(20)
            }
            .nouriScreenBackground()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }
}

#Preview {
    PartnerOrderingInfoView()
}
