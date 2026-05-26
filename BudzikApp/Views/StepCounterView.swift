import SwiftUI

struct StepCounterView: View {
    @Bindable var viewModel: ActiveAlarmViewModel

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()
            VStack(spacing: 28) {
                Spacer()

                ZStack {
                    Circle()
                        .stroke(Color.secondary.opacity(0.2), lineWidth: 16)
                    Circle()
                        .trim(from: 0, to: viewModel.progress)
                        .stroke(
                            AngularGradient(colors: [.green, .mint, .green], center: .center),
                            style: StrokeStyle(lineWidth: 16, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.easeOut(duration: 0.25), value: viewModel.progress)

                    VStack(spacing: 6) {
                        Text("\(viewModel.stepCount)")
                            .font(.system(size: 84, weight: .bold, design: .rounded))
                            .contentTransition(.numericText())
                        Text("/ \(viewModel.stepGoal)")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 260, height: 260)
                .padding(.top)

                Text(motivationMessage)
                    .font(.title3.weight(.medium))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .accessibilityLabel(motivationMessage)

                Spacer()

                if viewModel.motionPermissionDenied {
                    Button("Potwierdź \(viewModel.stepGoal) kroków") { viewModel.confirmManualGoal() }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                }
            }
        }
        .alert(
            "Ups!",
            isPresented: Binding(
                get: { viewModel.cheatWarning != nil },
                set: { if !$0 { viewModel.dismissCheatWarning() } }
            ),
            presenting: viewModel.cheatWarning
        ) { _ in
            Button("OK") { viewModel.dismissCheatWarning() }
        } message: { warning in
            Text(warning)
        }
    }

    private var motivationMessage: String {
        let remaining = viewModel.stepsRemaining
        if remaining > 70 {
            return "Idziemy! Każdy krok się liczy."
        }
        if remaining > 30 {
            return "Zostało Ci \(remaining) kroków — daj radę!"
        }
        if remaining > 10 {
            return "Już blisko! Jeszcze \(remaining) kroków"
        }
        if remaining > 0 {
            return "\(remaining) kroków! Prawie jesteś!"
        }
        return "Brawo! Alarm wyłączony 🎉"
    }
}
