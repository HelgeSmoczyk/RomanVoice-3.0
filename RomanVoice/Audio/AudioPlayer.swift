import AVFoundation
import MediaPlayer
import Combine

@MainActor final class AudioPlayer: NSObject, ObservableObject, AVAudioPlayerDelegate {
    @Published var bookID: UUID?
    @Published var playing = false
    @Published var waiting = false
    @Published var elapsed: Double = 0
    @Published var duration: Double = 0
    @Published var error: String?
    @Published var sleepMinutes = 0
    private var player: AVAudioPlayer?
    private var segment = 0
    private var ticker: Timer?
    private var deadline: Date?
    private var endChapter = false
    private var interrupted = false
    private var transientPosition = false
    private let library: Library
    var currentTextOffset: Int? {
        guard let id = bookID, let book = library.book(id), book.segments.indices.contains(segment) else { return nil }
        return book.segments[segment].offset
    }
    init(library: Library) {
        self.library = library; super.init()
        let center = MPRemoteCommandCenter.shared()
        center.playCommand.addTarget { [weak self] _ in Task { @MainActor in self?.play() }; return .success }
        center.pauseCommand.addTarget { [weak self] _ in Task { @MainActor in self?.pause() }; return .success }
        center.skipForwardCommand.preferredIntervals = [15]
        center.skipBackwardCommand.preferredIntervals = [15]
        center.skipForwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(15) }; return .success }
        center.skipBackwardCommand.addTarget { [weak self] _ in Task { @MainActor in self?.skip(-15) }; return .success }
        center.nextTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.chapter(1) }; return .success }
        center.previousTrackCommand.addTarget { [weak self] _ in Task { @MainActor in self?.chapter(-1) }; return .success }
        center.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let event = event as? MPChangePlaybackPositionCommandEvent else { return .commandFailed }
            Task { @MainActor in self?.seek(event.positionTime) }; return .success
        }
        NotificationCenter.default.addObserver(self, selector: #selector(audioInterrupted(_:)), name: AVAudioSession.interruptionNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(routeChanged(_:)), name: AVAudioSession.routeChangeNotification, object: nil)
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in Task { @MainActor in self?.tick() } }
    }
    func open(_ id: UUID, offset: Int? = nil, autoplay: Bool = true) {
        pause(); bookID = id; error = nil; waiting = false
        transientPosition = offset != nil && !autoplay
        guard let book = library.book(id), !book.segments.isEmpty else { return }
        segment = book.segmentIndex(at: offset ?? book.listening.offset)
        load(seconds: offset == nil ? book.listening.seconds : 0, autoplay: autoplay)
    }
    private func load(seconds: Double = 0, autoplay: Bool) {
        guard let id = bookID, let book = library.book(id), book.segments.indices.contains(segment) else { return }
        player?.stop(); player = nil
        let item = book.segments[segment]
        guard let filename = item.audioFile else { playing = false; waiting = autoplay; error = item.speaker == nil ? "Diese Sprecherstelle muss zuerst geklärt werden." : "Dieser Abschnitt wird noch erstellt."; return }
        do {
            let data = try AudioVault.read(AppFiles.book(id).appendingPathComponent(filename))
            let audio = try AVAudioPlayer(data: data)
            audio.delegate = self; audio.enableRate = true; audio.rate = book.playbackRate
            audio.currentTime = min(seconds, max(0, audio.duration - 0.05))
            player = audio; waiting = false; error = nil
            duration = book.segments.reduce(0) { $0 + $1.duration }
            if autoplay { play() } else { updateNowPlaying() }
        } catch { self.error = error.localizedDescription; playing = false }
    }
    func play() {
        transientPosition = false
        guard let player else { if bookID != nil { load(autoplay: true) }; return }
        do {
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowAirPlay, .allowBluetoothA2DP])
            try AVAudioSession.sharedInstance().setActive(true)
            playing = player.play(); waiting = false
            if playing, let id = bookID { library.update(id) { $0.listening.started = true } }
            updateNowPlaying()
        } catch { self.error = error.localizedDescription }
    }
    func pause() { player?.pause(); playing = false; waiting = false; persist(); updateNowPlaying() }
    func toggle() { playing ? pause() : play() }
    func availableAudioChanged() { if waiting { load(autoplay: true) } }
    func setRate(_ rate: Float) { guard let id = bookID else { return }; library.update(id) { $0.playbackRate = rate }; player?.rate = rate; updateNowPlaying() }
    func setSleep(_ minutes: Int) { sleepMinutes = minutes; endChapter = minutes == -1; deadline = minutes > 0 ? Date().addingTimeInterval(Double(minutes * 60)) : nil }
    func skip(_ delta: Double) { seek(elapsed + delta) }
    func seek(_ time: Double) {
        transientPosition = false
        guard let id = bookID, let book = library.book(id) else { return }
        var remaining = max(0, time)
        for index in book.segments.indices {
            let item = book.segments[index]
            guard item.audioFile != nil else { break }
            if remaining < item.duration || index == book.segments.count - 1 {
                segment = index; load(seconds: remaining, autoplay: playing); persist(); tick(); return
            }
            remaining -= item.duration
        }
    }
    func chapter(_ delta: Int) {
        guard let id = bookID, let book = library.book(id), book.segments.indices.contains(segment) else { return }
        let current = book.segments[segment].chapter
        let target = max(0, current + delta)
        guard let index = book.segments.firstIndex(where: { $0.chapter == target }) else { return }
        segment = index; load(autoplay: playing); persist()
    }
    func persist() {
        guard !transientPosition else { return }
        guard let id = bookID, let book = library.book(id), book.segments.indices.contains(segment), player != nil else { return }
        let offset = book.segments[segment].offset; let seconds = player?.currentTime ?? 0
        library.update(id) { $0.listening.offset = offset; $0.listening.seconds = seconds; $0.modified = Date() }
    }
    private func tick() {
        guard let id = bookID, let book = library.book(id) else { return }
        elapsed = book.segments.prefix(segment).reduce(0) { $0 + $1.duration } + (player?.currentTime ?? 0)
        duration = book.segments.reduce(0) { $0 + $1.duration }
        if playing { persist(); updateNowPlaying() }
        if let deadline, Date() >= deadline { pause(); setSleep(0) }
    }
    private func updateNowPlaying() {
        guard let id = bookID, let book = library.book(id) else { return }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = [MPMediaItemPropertyTitle: book.title, MPMediaItemPropertyArtist: book.author, MPMediaItemPropertyPlaybackDuration: duration, MPNowPlayingInfoPropertyElapsedPlaybackTime: elapsed, MPNowPlayingInfoPropertyPlaybackRate: playing ? book.playbackRate : 0]
    }
    nonisolated func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        Task { @MainActor in self.finished(flag) }
    }
    private func finished(_ success: Bool) {
        guard let id = bookID, let book = library.book(id), book.segments.indices.contains(segment) else { return }
        guard success else { pause(); error = "Audiowiedergabe unterbrochen."; return }
        let oldChapter = book.segments[segment].chapter
        segment += 1
        if segment >= book.segments.count { pause(); library.update(id) { $0.listening.completed = true }; return }
        let stop = endChapter && book.segments[segment].chapter != oldChapter
        if stop { setSleep(0) }
        load(autoplay: !stop); persist()
    }
    @objc private func audioInterrupted(_ notification: Notification) {
        guard let type = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt else { return }
        if type == AVAudioSession.InterruptionType.began.rawValue { interrupted = playing; pause() }
        else if interrupted, let options = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt, AVAudioSession.InterruptionOptions(rawValue: options).contains(.shouldResume) { play(); interrupted = false }
    }
    @objc private func routeChanged(_ notification: Notification) {
        if let reason = notification.userInfo?[AVAudioSessionRouteChangeReasonKey] as? UInt, reason == AVAudioSession.RouteChangeReason.oldDeviceUnavailable.rawValue { pause() }
    }
}
