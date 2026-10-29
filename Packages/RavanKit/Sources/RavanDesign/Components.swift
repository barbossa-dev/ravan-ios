import SwiftUI

/// Content card on Liquid Glass.
public struct GlassCard<Content: View>: View {
    private let tint: Color?
    private let cornerRadius: CGFloat
    private let content: Content

    public init(tint: Color? = nil, cornerRadius: CGFloat = 26, @ViewBuilder content: () -> Content) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.content = content()
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) { content }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(18)
            .glassEffect(tint.map { Glass.regular.tint($0.opacity(0.35)) } ?? .regular, in: .rect(cornerRadius: cornerRadius))
    }
}

/// Small tag such as a part of speech or a CEFR level.
public struct Pill: View {
    private let text: String
    private let systemImage: String?
    private let tint: Color

    public init(_ text: String, systemImage: String? = nil, tint: Color = .secondary) {
        self.text = text
        self.systemImage = systemImage
        self.tint = tint
    }

    public var body: some View {
        HStack(spacing: 4) {
            if let systemImage { Image(systemName: systemImage).imageScale(.small) }
            Text(text)
        }
        .font(.caption.weight(.semibold))
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(tint.opacity(0.14), in: .capsule)
    }
}

public struct SectionTitle: View {
    private let title: String
    public init(_ title: String) { self.title = title }

    public var body: some View {
        Text(title)
            .font(.headline)
            .foregroundStyle(RavanColor.brand)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, 6)
            .accessibilityAddTraits(.isHeader)
    }
}

/// English text inside the right-to-left UI. `leftAligned` lays it out like an English book.
public struct EnglishText: View {
    private let text: String
    private let font: Font
    private let leftAligned: Bool

    public init(_ text: String, font: Font = .englishSentence, leftAligned: Bool = false) {
        self.text = text
        self.font = font
        self.leftAligned = leftAligned
    }

    public var body: some View {
        if leftAligned {
            Text(verbatim: text)
                .font(font)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .environment(\.layoutDirection, .leftToRight)
        } else {
            Text(verbatim: text).font(font)
        }
    }
}

/// "US /rɪˈzɪliənt/" — a glass button that plays one accent.
public struct PronounceButton: View {
    private let label: String
    private let phonetic: String
    private let isSpeaking: Bool
    private let action: () -> Void

    public init(label: String, phonetic: String, isSpeaking: Bool, action: @escaping () -> Void) {
        self.label = label
        self.phonetic = phonetic
        self.isSpeaking = isSpeaking
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: "speaker.wave.2.fill")
                    .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                    .foregroundStyle(RavanColor.brand)
                VStack(alignment: .leading, spacing: 2) {
                    Text(label).font(.caption.weight(.bold)).foregroundStyle(RavanColor.brand)
                    if !phonetic.isEmpty {
                        Text(verbatim: phonetic).font(.phonetic).foregroundStyle(.primary)
                    }
                }
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity, minHeight: 44)
        }
        .buttonStyle(.glass)
        .accessibilityLabel("تلفظ \(label)")
    }
}

/// Small speaker button for list rows and example sentences.
public struct SpeakButton: View {
    private let isSpeaking: Bool
    private let action: () -> Void

    public init(isSpeaking: Bool, action: @escaping () -> Void) {
        self.isSpeaking = isSpeaking
        self.action = action
    }

    public var body: some View {
        Button(action: action) {
            Image(systemName: "speaker.wave.2.fill")
                .symbolEffect(.variableColor.iterative, isActive: isSpeaking)
                .frame(width: 30, height: 30)
        }
        .buttonStyle(.glass)
        .buttonBorderShape(.circle)
        .tint(RavanColor.brand)
        .accessibilityLabel("تلفظ")
    }
}

/// Five segments; the first `box` are filled. Mastered cards fill all of them in saffron.
public struct LeitnerProgressView: View {
    private let box: Int
    private let boxCount: Int

    public init(box: Int, boxCount: Int) {
        self.box = box
        self.boxCount = boxCount
    }

    public var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<boxCount, id: \.self) { index in
                Capsule()
                    .fill(color(for: index))
                    .frame(height: 8)
            }
        }
        .accessibilityElement()
        .accessibilityLabel("خانهٔ \(box) از \(boxCount)")
    }

    private func color(for index: Int) -> Color {
        if box > boxCount { return RavanColor.saffron }
        return index < box ? RavanColor.brand : Color.secondary.opacity(0.2)
    }
}

/// Wrapping horizontal layout for chips (SwiftUI has no built-in flow layout).
nonisolated public struct FlowLayout: Layout {
    private let spacing: CGFloat

    public init(spacing: CGFloat = 8) {
        self.spacing = spacing
    }

    public func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let rows = arrange(proposal: proposal, subviews: subviews)
        let height = rows.map(\.height).reduce(0, +) + spacing * CGFloat(max(rows.count - 1, 0))
        let width = rows.map(\.width).max() ?? 0
        return CGSize(width: proposal.width ?? width, height: height)
    }

    public func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var y = bounds.minY
        for row in arrange(proposal: ProposedViewSize(width: bounds.width, height: nil), subviews: subviews) {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(at: CGPoint(x: x, y: y), proposal: ProposedViewSize(size))
                x += size.width + spacing
            }
            y += row.height + spacing
        }
    }

    private struct Row {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> [Row] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [Row] = [Row()]
        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let needed = rows[rows.count - 1].indices.isEmpty ? size.width : rows[rows.count - 1].width + spacing + size.width
            if needed > maxWidth, !rows[rows.count - 1].indices.isEmpty {
                rows.append(Row())
            }
            var row = rows[rows.count - 1]
            row.width = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            row.height = max(row.height, size.height)
            row.indices.append(index)
            rows[rows.count - 1] = row
        }
        return rows
    }
}
