import AVFoundation

enum VoiceCatalog {
    static var available: [AVSpeechSynthesisVoice] { AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix("de") }.sorted { $0.name < $1.name } }
    static func voices(_ gender: Gender) -> [AVSpeechSynthesisVoice] {
        available.filter { gender == .male ? $0.gender == .male : gender == .female ? $0.gender == .female : true }
    }
    static let pitches: [Float] = [1, 0.8, 1.2]
    static let tempos: [Float] = [1, 0.85, 1.15]
    static func variants(_ gender: Gender) -> [VoiceChoice] {
        voices(gender).flatMap { voice in pitches.flatMap { pitch in tempos.map { VoiceChoice(identifier: voice.identifier, pitch: pitch, tempo: $0) } } }
    }
    static func suggest(_ book: inout Novel) {
        var used = Set(book.characters.filter { !$0.isMinor }.compactMap(\.voice))
        for index in book.characters.indices {
            let role = book.characters[index]
            guard role.voice == nil, role.gender != .unknown, !role.isMinor else { continue }
            let pool = role.isNarrator ? variants(role.gender).filter { $0.identifier == voices(role.gender).first?.identifier } : variants(role.gender)
            if let voice = pool.first(where: { !used.contains($0) }) ?? pool.first { book.characters[index].voice = voice; used.insert(voice) }
        }
        guard let narrator = book.characters.first(where: \.isNarrator), let narratorVoice = narrator.voice else { return }
        var minorUsed = Set<VoiceChoice>()
        for index in book.characters.indices where book.characters[index].isMinor {
            let gender = book.characters[index].gender
            guard gender != .unknown else { continue }
            let base = gender == narrator.gender ? narratorVoice.identifier : voices(gender).first?.identifier
            guard let base else { continue }
            let pool = pitches.flatMap { pitch in tempos.map { VoiceChoice(identifier: base, pitch: pitch, tempo: $0) } }
            if let existing = book.characters[index].voice, existing != narratorVoice { minorUsed.insert(existing); continue }
            let allowed = pool.filter { $0 != narratorVoice }
            let preferred = VoiceChoice(identifier: base)
            let choice = gender != narrator.gender && !minorUsed.contains(preferred) ? preferred : allowed.first(where: { !minorUsed.contains($0) }) ?? allowed.first
            book.characters[index].voice = choice
            if let choice { minorUsed.insert(choice) }
        }
    }
    static func allowed(_ choice: VoiceChoice, role: CharacterRole, book: Novel) -> Bool {
        if role.isMinor { return choice != book.characters.first(where: \.isNarrator)?.voice }
        let occupied = Set(book.characters.filter { $0.id != role.id && !$0.isMinor }.compactMap(\.voice))
        return !occupied.contains(choice) || !variants(role.gender).contains(where: { !occupied.contains($0) })
    }
    static func utterance(_ text: String, choice: VoiceChoice) throws -> AVSpeechUtterance {
        guard let voice = AVSpeechSynthesisVoice(identifier: choice.identifier) else { throw RomanError.message("Die zugewiesene Stimme ist nicht mehr installiert.") }
        let value = AVSpeechUtterance(string: text)
        value.voice = voice; value.pitchMultiplier = choice.pitch; value.rate = AVSpeechUtteranceDefaultSpeechRate * choice.tempo
        return value
    }
}
