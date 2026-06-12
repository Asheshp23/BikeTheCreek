import SwiftUI

struct OnboardingView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding: Bool = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Spacer(minLength: 20)
                Image(systemName: "bicycle")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 88, height: 88)
                    .foregroundStyle(.white)
                    .padding(12)
                    .background(Color.creek.opacity(0.2))
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                Text("Welcome to Bike the Creek")
                    .font(.system(size: 22, weight: .bold))
                    .foregroundStyle(.white)
                Text("Pick a route, preview it, or record your ride. Allow Location to show your position on the map and Health permissions to import workouts.")
                    .multilineTextAlignment(.center)
                    .font(.system(size: 15))
                    .foregroundStyle(Color.white.opacity(0.8))
                    .padding(.horizontal)

                VStack(alignment: .leading, spacing: 10) {
                    Label("Location: to show your position and fit the route.", systemImage: "location")
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                    Label("Health: to import cycling workouts.", systemImage: "heart.fill")
                        .foregroundStyle(.white)
                        .font(.system(size: 14))
                }
                .padding()
                .background(Color.surface.background(.ultraThinMaterial))
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(RoundedRectangle(cornerRadius: 16, style: .continuous).strokeBorder(Color.white.opacity(0.08), lineWidth: 1))

                Spacer()
                Button {
                    hasCompletedOnboarding = true
                    dismiss()
                } label: {
                    Text("Get Started")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(maxWidth: .infinity)
                        .frame(height: 48)
                        .background(LinearGradient(colors: [.creek, .creekDeep], startPoint: .leading, endPoint: .trailing))
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .accessibilityLabel("Get Started")
                .accessibilityHint("Dismiss onboarding and use the app")
            }
            .padding()
            .navigationTitle("Getting Started")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    OnboardingView()
        .background(Color.black)
}
