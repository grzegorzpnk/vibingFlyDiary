import SwiftUI
import AuthenticationServices

struct SignInView: View {
    @Environment(AuthService.self) private var auth

    var body: some View {
        ZStack {
            Color(hex: "#0A0A0F").ignoresSafeArea()

            RadialGradient(
                colors: [Color(hex: "#1A2A4A").opacity(0.6), .clear],
                center: .init(x: 0.5, y: 0.35),
                startRadius: 0,
                endRadius: 350
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: 16) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(Color(hex: "#C9A96E"))
                        .shadow(color: Color(hex: "#C9A96E").opacity(0.4), radius: 24)

                    Text("Flygram")
                        .font(.system(size: 34, weight: .bold, design: .serif))
                        .foregroundStyle(Color(hex: "#F0EEE8"))

                    Text("Your personal journey log")
                        .font(.system(size: 15, weight: .light))
                        .foregroundStyle(Color(hex: "#F0EEE8").opacity(0.45))
                }

                Spacer()

                VStack(spacing: 14) {
                    Text("SIGN IN TO CONTINUE")
                        .font(.system(size: 11, weight: .medium))
                        .tracking(2)
                        .foregroundStyle(Color(hex: "#F0EEE8").opacity(0.35))

                    // Apple — custom styled button with invisible native button on top
                    ZStack {
                        authButton(
                            logo: Image(systemName: "apple.logo")
                                .font(.system(size: 20, weight: .semibold))
                                .foregroundStyle(.black),
                            text: "Continue with Apple"
                        )

                        SignInWithAppleButton(.continue) { request in
                            request.requestedScopes = [.fullName, .email]
                        } onCompletion: { result in
                            if case .success(let auth) = result {
                                self.auth.handleAuthorization(auth)
                            }
                        }
                        .opacity(0.001)
                    }
                    .frame(height: 50)

                    // Google — custom styled button (UI only)
                    authButton(
                        logo: GoogleGLogo(size: 22),
                        text: "Continue with Google"
                    )
                    .frame(height: 50)

                    // Facebook — custom styled button (UI only)
                    authButton(
                        logo: FacebookLogo(size: 22),
                        text: "Continue with Facebook"
                    )
                    .frame(height: 50)

                    Button {
                        auth.continueAsGuest()
                    } label: {
                        Text("Continue without account")
                            .font(.system(size: 14, weight: .light))
                            .foregroundStyle(Color(hex: "#F0EEE8").opacity(0.4))
                    }
                    .buttonStyle(.plain)
                    .padding(.top, 4)
                }
                .padding(.horizontal, 32)
                .padding(.bottom, 56)
            }
        }
    }

    @ViewBuilder
    private func authButton<Logo: View>(logo: Logo, text: String) -> some View {
        HStack(spacing: 0) {
            logo
                .frame(width: 44)
            Spacer()
            Text(text)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(.black)
            Spacer()
            Color.clear.frame(width: 44)
        }
        .frame(maxWidth: .infinity)
        .frame(height: 50)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(hex: "#DADCE0"), lineWidth: 1))
    }
}

// MARK: - Facebook Logo

private struct FacebookLogo: View {
    let size: CGFloat

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: size * 0.22)
                .fill(Color(hex: "1877F2"))
                .frame(width: size, height: size)
            Text("f")
                .font(.system(size: size * 0.72, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .offset(x: size * 0.04, y: size * 0.01)
        }
    }
}

// MARK: - Google G Logo

private struct GoogleGLogo: View {
    let size: CGFloat

    var body: some View {
        Canvas { context, sz in
            let cx = sz.width / 2, cy = sz.height / 2
            let outer = sz.width * 0.48, inner = sz.width * 0.27

            func sector(from s: Double, to e: Double, color: Color) {
                let path = Path { p in
                    p.addArc(center: .init(x: cx, y: cy), radius: outer,
                             startAngle: .degrees(s), endAngle: .degrees(e), clockwise: false)
                    p.addArc(center: .init(x: cx, y: cy), radius: inner,
                             startAngle: .degrees(e), endAngle: .degrees(s), clockwise: true)
                    p.closeSubpath()
                }
                context.fill(path, with: .color(color))
            }

            sector(from: 20,  to: 105, color: Color(hex: "4285F4"))
            sector(from: 105, to: 190, color: Color(hex: "34A853"))
            sector(from: 190, to: 255, color: Color(hex: "FBBC05"))
            sector(from: 255, to: 340, color: Color(hex: "EA4335"))

            let barH = outer - inner
            context.fill(Path(CGRect(x: cx, y: cy - barH / 2, width: outer, height: barH)),
                         with: .color(Color(hex: "4285F4")))
        }
        .frame(width: size, height: size)
    }
}
