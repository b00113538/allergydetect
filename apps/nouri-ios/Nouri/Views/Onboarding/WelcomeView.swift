import SwiftUI

struct WelcomeView: View {
    @EnvironmentObject private var app: AppState
    @State private var mode: Mode = .signUp
    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var isWorking = false

    enum Mode: String, CaseIterable { case signUp = "Create account", signIn = "Sign in" }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 28) {
                VStack(alignment: .leading, spacing: 10) {
                    Image(systemName: "leaf.circle.fill")
                        .font(.system(size: 54))
                        .foregroundStyle(Color.nouriPrimary, Color.nouriAccent.opacity(0.3))
                    Text("Nouri").font(NouriFont.display).foregroundStyle(Color.nouriTextPrimary)
                    Text("Snap your meals, log how you feel, and let Nouri find the ingredients your body doesn't agree with.")
                        .foregroundStyle(Color.nouriTextSecondary)
                }
                .padding(.top, 40)

                if app.isDemoMode {
                    demoCard
                } else {
                    accountCard
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("Nouri shows patterns in what you log — it isn't a medical device and doesn't diagnose allergies.")
                    Link("Privacy policy", destination: AppEnvironment.webPage("privacy"))
                }
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
            }
            .padding(24)
        }
        .nouriScreenBackground()
    }

    private var accountCard: some View {
        NouriCard {
            Picker("Mode", selection: $mode) {
                ForEach(Mode.allCases, id: \.self) { Text($0.rawValue) }
            }
            .pickerStyle(.segmented)

            if mode == .signUp {
                TextField("Your name", text: $name)
                    .textContentType(.name)
                    .nouriField()
            }
            TextField("Email", text: $email)
                .textContentType(.emailAddress)
                .keyboardType(.emailAddress)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .nouriField()
            SecureField("Password (6+ characters)", text: $password)
                .textContentType(mode == .signUp ? .newPassword : .password)
                .nouriField()

            Button {
                Task {
                    isWorking = true
                    defer { isWorking = false }
                    if mode == .signUp {
                        await app.signUp(name: name.trimmingCharacters(in: .whitespaces), email: email, password: password)
                    } else {
                        await app.signIn(email: email, password: password)
                    }
                }
            } label: {
                if isWorking { ProgressView().tint(Color.nouriOnPrimary) } else { Text(mode.rawValue) }
            }
            .buttonStyle(.nouriPrimary)
            .disabled(!isValid || isWorking)
        }
    }

    private var demoCard: some View {
        NouriCard {
            Label("Demo mode", systemImage: "sparkles").font(NouriFont.label).foregroundStyle(Color.nouriAccentText)
            Text("Firebase isn't configured in this build, so your data stays on this device and meal photos return a sample analysis.")
                .font(.footnote)
                .foregroundStyle(Color.nouriTextSecondary)
            TextField("Your name", text: $name).nouriField()
            Button("Get started") { app.startDemoAccount(name: name.trimmingCharacters(in: .whitespaces)) }
                .buttonStyle(.nouriPrimary)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
        }
    }

    private var isValid: Bool {
        email.contains("@") && password.count >= 6 && (mode == .signIn || !name.trimmingCharacters(in: .whitespaces).isEmpty)
    }
}

extension View {
    func nouriField() -> some View {
        padding(14)
            .background(Color.nouriBackground, in: RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 12, style: .continuous).stroke(Color.nouriBorder))
    }
}
