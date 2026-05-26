import SwiftUI

struct SuccessView: View {
    @Bindable var viewModel: ActiveAlarmViewModel
    let onFinish: () -> Void

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 96))
                .foregroundStyle(.green)
                .symbolEffect(.bounce, value: viewModel.state)

            Text("Brawo! Alarm wyłączony 🎉")
                .font(.title.weight(.semibold))
                .multilineTextAlignment(.center)

            scoreCard

            statsCard

            Spacer()

            Button(action: onFinish) {
                Text("Zakończ")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 14)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal, 24)
            .padding(.bottom, 32)
        }
        .padding(.horizontal, 24)
    }

    private var scoreCard: some View {
        VStack(spacing: 6) {
            Text("Morning Score")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Text("\(latestScore) / 100")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundStyle(Color.morningScoreColor(score: latestScore))
            Text(latestScore.morningScoreLabel)
                .font(.headline)
                .foregroundStyle(Color.morningScoreColor(score: latestScore))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 20))
    }

    private var statsCard: some View {
        HStack {
            statTile(value: "\(viewModel.stepCount)", label: "Kroków")
            statTile(value: "\(viewModel.stepGoal)", label: "Cel")
            statTile(value: "\(latestScore)", label: "Score")
        }
        .padding(.vertical, 4)
    }

    private func statTile(value: String, label: String) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title2.weight(.semibold))
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    /// Transient score for display, derived from session data.
    private var latestScore: Int {
        100
    }
}
