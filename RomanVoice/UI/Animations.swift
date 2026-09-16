import SwiftUI
import UIKit

struct AtlasSprite: View {
    let index: Int
    private static let images: [UIImage] = {
        guard let url = Bundle.main.url(forResource: "AnimationAtlas", withExtension: "png"), let source = UIImage(contentsOfFile: url.path)?.cgImage else { return [] }
        let width = source.width / 3, height = source.height / 2
        return (0..<6).compactMap { index in source.cropping(to: CGRect(x: (index % 3) * width, y: (index / 3) * height, width: width, height: height)).map { UIImage(cgImage: $0) } }
    }()
    var body: some View {
        if Self.images.indices.contains(index) { Image(uiImage: Self.images[index]).resizable().scaledToFit() }
    }
}
struct WorkAnimation: View {
    var active: Bool
    var rendering: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !active || reduceMotion)) { timeline in
            GeometryReader { geometry in
                let size = geometry.size
                let time = active && !reduceMotion ? timeline.date.timeIntervalSinceReferenceDate : 0
                ZStack {
                    AtlasSprite(index: 1).frame(width: size.width * 0.62).position(x: size.width * 0.34, y: size.height * 0.65)
                    AtlasSprite(index: 3).frame(width: size.width * 0.34).position(x: size.width * 0.81, y: size.height * 0.37)
                    if !rendering {
                        let scan = sin(time * 1.5) * 0.10
                        AtlasSprite(index: 2).frame(width: size.width * 0.22).rotationEffect(.degrees(-15)).position(x: size.width * (0.37 + scan), y: size.height * (active ? 0.48 : 0.7))
                        if active {
                            ForEach(0..<7) { i in
                                let progress = (time * 0.24 + Double(i) / 7).truncatingRemainder(dividingBy: 1)
                                Text(["A", "Wort", "R", "Text", "B", "Stimme", "Z"][i]).font(.system(size: 11, design: .serif)).foregroundStyle(RomanStyle.gold)
                                    .position(x: size.width * (0.37 + scan + progress * (0.44 - scan)), y: size.height * (0.47 - progress * 0.25))
                                    .opacity(sin(progress * .pi))
                            }
                        }
                    } else if active {
                        ForEach(0..<5) { i in
                            Image(systemName: "waveform").font(.title2).foregroundStyle(i.isMultiple(of: 2) ? RomanStyle.lightGreen : RomanStyle.gold)
                                .scaleEffect(0.8 + 0.2 * sin(time * 2 + Double(i))).position(x: size.width * (0.25 + Double(i) * 0.12), y: size.height * 0.35)
                        }
                    }
                }
            }
        }.accessibilityHidden(true)
    }
}
struct GramophoneAnimation: View {
    var playing: Bool
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var started = Date()
    @State private var accumulated: Double = 0
    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 24, paused: !playing || reduceMotion)) { timeline in
            GeometryReader { geometry in
                let size = geometry.size
                let time = playing && !reduceMotion ? max(0, timeline.date.timeIntervalSince(started)) : 0
                let winding = min(time / 1.8, 1)
                let angle = accumulated + max(0, time - 1.8) * 120
                ZStack {
                    AtlasSprite(index: 4).frame(width: 85, height: 85).rotationEffect(.degrees(angle)).scaleEffect(x: 1, y: 0.32).position(x: size.width * 0.66, y: size.height * 0.73)
                    AtlasSprite(index: 5).frame(width: 42, height: 42).rotationEffect(.degrees(winding * 1080)).position(x: size.width * 0.86, y: size.height * 0.81)
                    if playing {
                        ForEach(0..<8) { index in
                            let p = (time / 5 + Double(index) / 8).truncatingRemainder(dividingBy: 1)
                            Image(systemName: index.isMultiple(of: 2) ? "music.note" : "waveform")
                                .font(.system(size: 15 + p * 12)).foregroundStyle(index.isMultiple(of: 2) ? RomanStyle.gold : RomanStyle.lightGreen)
                                .position(x: size.width * (0.58 + (index.isMultiple(of: 2) ? -0.4 : 0.3) * p), y: size.height * (0.6 - p * 0.65))
                                .opacity((1 - p) * min(time, 1))
                        }
                        ForEach(0..<3) { index in
                            let p = (time / 4 + Double(index) / 3).truncatingRemainder(dividingBy: 1)
                            AtlasSprite(index: 1).frame(width: 52, height: 52).scaleEffect(1 - p * 0.7).position(x: size.width * 0.67, y: size.height * (1.05 - p * 0.28)).opacity(1 - p)
                        }
                    }
                }.clipped()
            }
        }
        .onChange(of: playing) { old, current in
            if old { accumulated += max(0, Date().timeIntervalSince(started) - 1.8) * 120 }
            if current { started = Date() }
        }
        .onAppear { started = Date() }
        .accessibilityHidden(true)
    }
}
