import SwiftUI

struct LoginView: View {
    let appModel: AppModel

    @State private var email = ""
    @State private var password = ""
    @State private var isSubmitting = false

    var body: some View {
        VStack(spacing: 18) {
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.14))
                    .frame(width: 52, height: 52)
                Image(systemName: "fan.fill")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(Color.accentColor)
            }
            .padding(.top, 4)

            VStack(spacing: 3) {
                Text("Sign in to Dreo")
                    .font(.system(size: 14, weight: .semibold))
                Text("Control your fan without opening the Dreo app")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 8) {
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
        .padding(22)
        .frame(width: 300)
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
