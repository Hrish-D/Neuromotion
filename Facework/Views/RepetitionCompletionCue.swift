import AudioToolbox

nonisolated protocol RepetitionCompletionCuePlaying {
    func play() throws
}

nonisolated struct SystemRepetitionCompletionCuePlayer: RepetitionCompletionCuePlaying {
    func play() throws {
        AudioServicesPlaySystemSound(1057)
    }
}

nonisolated final class RepetitionCompletionCueTrigger {
    private let player: any RepetitionCompletionCuePlaying
    private var handledRepetitionIDs: Set<UUID> = []

    init(player: any RepetitionCompletionCuePlaying = SystemRepetitionCompletionCuePlayer()) {
        self.player = player
    }

    func handle(_ result: RepetitionResult) {
        guard result.valid, handledRepetitionIDs.insert(result.id).inserted else { return }
        try? player.play()
    }
}
