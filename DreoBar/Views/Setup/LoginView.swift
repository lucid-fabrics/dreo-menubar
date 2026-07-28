import SwiftUI

struct LoginView: View {
    let appModel: AppModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: Theme.Space.roomy + 4) {
            ZStack {
                Circle()
                    .fill(Theme.accent.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "fan.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Theme.accent)
            }
            .padding(.top, 4)

            VStack(spacing: 3) {
                Text("Sign in to Dreo")
                    .font(.system(size: 14.5, weight: .semibold))
                Text("Control your fans without opening the Dreo app")
                    .font(Theme.Font.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: Theme.Space.tight) {
                TextField("Email", text: $email)
                    .textContentType(.username)
                SecureField("Password", text: $password)
                    .textContentType(.password)
            }
            .textFieldStyle(.roundedBorder)
            .onSubmit(submit)

            if let errorMessage = appModel.errorMessage {
                InlineErrorBanner(message: errorMessage)
            }

            Button(action: submit) {
                if isSubmitting {
                    ProgressView()
                        .controlSize(.small)
                        .frame(maxWidth: .infinity)
                } else {
                    Text("Sign In")
                        .frame(maxWidth: .infinity)
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(email.isEmpty || password.isEmpty || isSubmitting)
        }
        .padding(Theme.Space.loose + 2)
        .frame(width: Theme.Metric.popoverWidth)
    }

    private func submit() {
        guard !isSubmitting else { return }
        isSubmitting = true
        Task {
            await appModel.login(email: email, password: password)
            isSubmitting = false
        }
    }
}
