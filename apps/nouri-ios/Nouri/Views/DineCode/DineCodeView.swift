import SwiftUI

/// One tap → a QR restaurant staff can scan (no app needed) to see what to avoid.
struct DineCodeView: View {
    @EnvironmentObject private var app: AppState
    @State private var isWorking = false
    @State private var confirmRegenerate = false

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                if let code = app.dineCode {
                    codeCard(code)
                    avoidList
                    actions
                } else {
                    emptyState
                }
            }
            .padding(20)
        }
        .nouriScreenBackground()
        .navigationTitle("Dine Code")
        .confirmationDialog("Create a new code?", isPresented: $confirmRegenerate, titleVisibility: .visible) {
            Button("Create new code", role: .destructive) { run { await app.generateDineCode() } }
        } message: {
            Text("Your current QR will stop working. Use this if you shared it somewhere you no longer want it.")
        }
    }

    private var snapshot: DineCodeSnapshot? {
        app.user.map { DineCodeService.snapshot(user: $0, profile: app.profile) }
    }

    private func codeCard(_ code: DineCode) -> some View {
        NouriCard(padding: 22) {
            VStack(spacing: 14) {
                Text(app.user?.firstName ?? "").nouriHeading(.title)
                Text("Show this to restaurant staff").font(.subheadline).foregroundStyle(Color.nouriTextSecondary)
                if let image = QRCodeService.image(for: code.qrPayload) {
                    Image(uiImage: image)
                        .interpolation(.none)
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: 260)
                        .padding(14)
                        .background(Color.white, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                        .accessibilityLabel("Dine Code QR")
                }
                Text(app.isDemoMode
                     ? "Demo mode: this code contains your profile directly. Regenerate after your profile changes."
                     : "Stays up to date automatically as your profile changes.")
                    .font(.caption)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Color.nouriTextSecondary)
            }
            .frame(maxWidth: .infinity)
        }
    }

    private var avoidList: some View {
        NouriCard {
            Text("On your card").font(NouriFont.section).foregroundStyle(Color.nouriTextPrimary)
            let items = snapshot?.avoid ?? []
            if items.isEmpty {
                Text("Nothing yet — add known allergies in your profile, or keep logging until triggers are detected.")
                    .font(.footnote)
                    .foregroundStyle(Color.nouriTextSecondary)
            }
            ForEach(items, id: \.name) { item in
                HStack {
                    Text(item.name).foregroundStyle(Color.nouriTextPrimary)
                    Spacer()
                    Tag(text: item.level, color: color(for: item.level))
                }
            }
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let code = app.dineCode, let url = URL(string: code.qrPayload) {
                ShareLink(item: url, subject: Text("My Nouri Dine Code"), message: Text("What I need to avoid when eating out")) {
                    Label("Share link", systemImage: "square.and.arrow.up")
                }
                .buttonStyle(.nouriPrimary)
            }
            Button { confirmRegenerate = true } label: { Label("Create new code", systemImage: "arrow.clockwise") }
                .buttonStyle(.nouriSecondary)
            Button("Turn off Dine Code", role: .destructive) { run { await app.deactivateDineCode() } }
                .font(.footnote)
        }
        .disabled(isWorking)
    }

    private var emptyState: some View {
        VStack(spacing: 18) {
            Image(systemName: "qrcode")
                .font(.system(size: 72))
                .foregroundStyle(Color.nouriPrimary)
                .padding(.top, 40)
            Text("Eat out with confidence").nouriHeading(.title)
            Text("Generate a QR code that shows restaurant staff your allergies and likely triggers in plain language. They just scan it with their phone camera — no app needed.")
                .multilineTextAlignment(.center)
                .foregroundStyle(Color.nouriTextSecondary)
            Button {
                run { await app.generateDineCode() }
            } label: {
                if isWorking { ProgressView().tint(Color.nouriOnPrimary) } else { Text("Generate my Dine Code") }
            }
            .buttonStyle(.nouriPrimary)
            .disabled(isWorking)
        }
    }

    private func color(for level: String) -> Color {
        switch level {
        case "Confirmed allergy": .nouriDanger
        case "Likely trigger": .nouriWarning
        default: .nouriAccent
        }
    }

    private func run(_ work: @escaping () async -> Void) {
        Task {
            isWorking = true
            await work()
            isWorking = false
        }
    }
}
