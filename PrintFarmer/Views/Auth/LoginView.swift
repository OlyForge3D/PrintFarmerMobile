import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var usernameOrEmail = ""
    @State private var password = ""

    var body: some View {
        @Bindable var authViewModel = authViewModel

        NavigationStack {
            VStack(spacing: 24) {
                Spacer()

                Image(systemName: "printer.fill")
                    .font(.system(size: 64))
                    .foregroundStyle(.tint)

                Text("PrintFarmer")
                    .font(.largeTitle.bold())

                VStack(spacing: 16) {
                    TextField("Username or Email", text: $usernameOrEmail)
                        .textContentType(.username)
                        .autocorrectionDisabled()
                        #if os(iOS)
                        .textInputAutocapitalization(.never)
                        #endif
                        .textFieldStyle(RoundedBorderTextFieldStyle())

                    SecureField("Password", text: $password)
                        .textContentType(.password)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                }
                .padding(.horizontal, 32)

                if let error = authViewModel.errorMessage {
                    Text(error)
                        .foregroundStyle(.red)
                        .font(.caption)
                }

                Button {
                    Task {
                        await authViewModel.login(
                            usernameOrEmail: usernameOrEmail,
                            password: password
                        )
                    }
                } label: {
                    if authViewModel.isLoading {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text("Sign In")
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.horizontal, 32)
                .disabled(usernameOrEmail.isEmpty || password.isEmpty || authViewModel.isLoading)

                Spacer()
                Spacer()
            }
        }
    }
}
