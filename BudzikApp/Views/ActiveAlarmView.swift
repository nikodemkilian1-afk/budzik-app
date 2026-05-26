import SwiftUI

struct ActiveAlarmView: View {
    @Bindable var viewModel: ActiveAlarmViewModel
    let alarm: AlarmModel
    let onFinish: () -> Void

    @State private var currentTime = Date()
    @State private var pulse: Bool = false

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        Group {
            switch viewModel.state {
            case .ringing:
                ringingView
            case .walking:
                StepCounterView(viewModel: viewModel)
            case .dismissed:
                SuccessView(viewModel: viewModel, onFinish: onFinish)
            case .idle:
                Color.clear.onAppear(perform: onFinish)
            }
        }
        .onReceive(timer) { _ in currentTime = Date() }
    }

    private var ringingView: some View {
        ZStack {
            LinearGradient(
                colors: [.orange, .red],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: "alarm.waves.left.and.right.fill")
                    .font(.system(size: 120))
                    .foregroundStyle(.white)
                    .scaleEffect(pulse ? 1.08 : 0.96)
                    .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: pulse)
                    .onAppear { pulse = true }

                Text(currentTime.timeString)
                    .font(.system(size: 80, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("Alarm: \(alarm.timeString)")
                    .font(.title3)
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                VStack(spacing: 16) {
                    Button(action: viewModel.beginWalking) {
                        Text("WSTAŃ I IDŹ")
                            .font(.title2.weight(.bold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 18)
                            .background(.white)
                            .foregroundStyle(.red)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .sensoryFeedback(.impact(weight: .heavy), trigger: viewModel.state)

                    Text("Aby wyłączyć alarm, przejdź \(viewModel.stepGoal) kroków.")
                        .font(.footnote)
                        .foregroundStyle(.white.opacity(0.85))
                        .multilineTextAlignment(.center)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 32)
            }
        }
    }
}
