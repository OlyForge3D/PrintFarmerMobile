import SwiftUI

struct LoginView: View {
    @Environment(AuthViewModel.self) private var authViewModel
    @State private var viewModel = LoginViewModel()
    @FocusState private var focusedField: LoginField?

    private enum LoginField: Hashable {
        case serverURL, username, password
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                Spacer(minLength: 40)

                // MARK: - Branding
                brandingSection

                // MARK: - Server URL
                serverSection

                // MARK: - Credentials
                credentialFields

                // MARK: - Error
                errorBanner

                // MARK: - Sign In
                signInButton

                Spacer(minLength: 60)
            }
            .padding(.horizontal, 32)
        }
        .scrollDismissesKeyboard(.interactively)
        .contentShape(Rectangle())
        .onTapGesture { focusedField = nil }
        .animation(.easeInOut(duration: 0.2), value: authViewModel.errorMessage)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isServerURLExpanded)
    }

    // MARK: - Branding

    private var brandingSection: some View {
        VStack(spacing: 12) {
            Image(systemName: "printer.fill")
                .font(.system(size: 56))
                .foregroundStyle(.tint)

            Text("PrintFarmer")
                .font(.largeTitle.bold())

            Text("3D Print Farm Management")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.bottom, 8)
    }

    // MARK: - Server

    private var serverSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation { viewModel.isServerURLExpanded.toggle() }
            } label: {
                HStack {
                    Label("Server", systemImage: "server.rack")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                    if !viewModel.serverURL.isEmpty && !viewModel.isServerURLExpanded {
                        Text(viewModel.serverURL)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                    Image(systemName: "chevron.right")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .rotationEffect(.degrees(viewModel.isServerURLExpanded ? 90 : 0))
                }
            }
            .buttonStyle(.plain)

            if viewModel.isServerURLExpanded {
                TextField("https://print.example.com", text: $viewModel.serverURL)
                    .textContentType(.URL)
                    .autocorrectionDisabled()
                    #if os(iOS)
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    #endif
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .serverURL)
                    .submitLabel(.next)
                    .onSubmit { focusedField = .username }
            }
        }
        .padding(12)
        .background(.quaternary.opacity(0.5), in: RoundedRectangle(cornerRadius: 10))
    }

    // MARK: - Credentials

    private var credentialFields: some View {
        VStack(spacing: 14) {
            TextField("Username or Email", text: $viewModel.usernameOrEmail)
                .textContentType(.username)
                .autocorrectionDisabled()
                #if os(iOS)
                .textInputAutocapitalization(.never)
                #endif
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .username)
                .submitLabel(.next)
                .onSubmit { focusedField = .password }

            SecureField("Password", text: $viewModel.password)
                .textContentType(.password)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .password)
                .submitLabel(.go)
                .onSubmit { attemptLogin() }
        }
    }

    // MARK: - Error

    @ViewBuilder
    private var errorBanner: some View {
        if let error = authViewModel.errorMessage {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.red)
                Text(error)
                    .font(.callout)
            }
            .foregroundStyle(.red)
            .padding(12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.red.opacity(0.1), in: RoundedRectangle(cornerRadius: 8))
            .transition(.opacity.combined(with: .move(edge: .top)))
        }
    }

    // MARK: - Sign In Button

    private var signInButton: some View {
        Button(action: attemptLogin) {
            Group {
                if authViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    Text("Sign In")
                        .fontWeight(.semibold)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 22)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!viewModel.isFormValid || authViewModel.isLoading)
    }

    // MARK: - Actions

    private func attemptLogin() {
        guard viewModel.isFormValid, !authViewModel.isLoading else { return }
        focusedField = nil
        Task {
            await viewModel.login(using: authViewModel)
        }
    }
}
