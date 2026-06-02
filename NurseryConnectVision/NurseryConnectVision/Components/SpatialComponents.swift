// Components/SpatialComponents.swift — NurseryConnectVision
// Reusable spatial glass UI components for visionOS.
// Ported and adapted from the NurseryCare reference design.

import SwiftUI

// MARK: - GlassCard

struct GlassCard<Content: View>: View {
    let content: Content
    var padding: CGFloat = 20
    var cornerRadius: CGFloat = 20
    @State private var isHovered = false

    init(padding: CGFloat = 20, cornerRadius: CGFloat = 20, @ViewBuilder content: () -> Content) {
        self.content = content()
        self.padding = padding
        self.cornerRadius = cornerRadius
    }

    var body: some View {
        content
            .padding(padding)
            .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: cornerRadius))
            .hoverEffect(.highlight)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
            .onHover { isHovered = $0 }
    }
}

// MARK: - FloatingMetricCard

struct FloatingMetricCard: View {
    let title: String
    let value: String
    let subtitle: String
    let iconName: String
    let accentColor: Color
    var trend: String? = nil
    var trendUp: Bool = true
    var isAlert: Bool = false

    @State private var isHovered = false
    @State private var appeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundStyle(accentColor)
                    .symbolEffect(.pulse, options: .repeating, isActive: isAlert)
                Spacer()
                if let trend {
                    HStack(spacing: 4) {
                        Image(systemName: trendUp ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption)
                        Text(trend)
                            .font(.caption)
                    }
                    .foregroundStyle(trendUp ? .green : .red)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.ultraThinMaterial, in: Capsule())
                }
            }

            Text(value)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())

            Text(title)
                .font(.headline)
                .foregroundStyle(.primary)

            Text(subtitle)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(minWidth: 180)
        .padding(20)
        .glassBackgroundEffect(in: RoundedRectangle(cornerRadius: 20))
        .hoverEffect(.highlight)
        .scaleEffect(isHovered ? 1.03 : 1.0)
        .opacity(appeared ? 1 : 0)
        .offset(y: appeared ? 0 : 20)
        .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isHovered)
        .animation(.easeOut(duration: 0.6), value: appeared)
        .onHover { isHovered = $0 }
        .onAppear { appeared = true }
    }
}

// MARK: - SpatialSectionHeader

struct SpatialSectionHeader: View {
    let title: String
    let iconName: String
    let accentColor: Color

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .font(.title2)
                .foregroundStyle(accentColor)
            Text(title)
                .font(.title2.bold())
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding(.bottom, 4)
    }
}

// MARK: - AlertBadge

struct AlertBadge: View {
    let count: Int
    var color: Color = .red

    var body: some View {
        if count > 0 {
            Text("\(count)")
                .font(.caption2.bold())
                .foregroundStyle(.white)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color, in: Capsule())
                .transition(.scale.combined(with: .opacity))
        }
    }
}

// MARK: - StatusIndicator

struct StatusIndicator: View {
    let color: Color
    var isPulsing: Bool = false
    var size: CGFloat = 10

    @State private var pulsing = false

    var body: some View {
        ZStack {
            if isPulsing {
                Circle()
                    .fill(color.opacity(0.3))
                    .frame(width: size * 2.2, height: size * 2.2)
                    .scaleEffect(pulsing ? 1.4 : 1.0)
                    .opacity(pulsing ? 0 : 0.6)
                    .animation(
                        isPulsing
                            ? .easeOut(duration: 1.2).repeatForever(autoreverses: false)
                            : .default,
                        value: pulsing
                    )
                    .onAppear { if isPulsing { pulsing = true } }
            }
            Circle()
                .fill(color)
                .frame(width: size, height: size)
        }
    }
}

// MARK: - ChildAvatar

struct ChildAvatar: View {
    let child: Child
    var size: CGFloat = 50

    private var backgroundColor: Color {
        switch child.ageBand {
        case .underTwo:    return .pink
        case .twoYears:    return .cyan
        case .threeToFive: return .indigo
        }
    }

    var body: some View {
        ZStack {
            Circle()
                .fill(backgroundColor.gradient)
                .frame(width: size, height: size)
            Text(child.initials)
                .font(.system(size: size * 0.35, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
        }
        .overlay(alignment: .bottomTrailing) {
            if child.hasSevereAllergy {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: size * 0.26))
                    .foregroundStyle(.red)
                    .background(.ultraThickMaterial, in: Circle())
            }
        }
    }
}

// MARK: - ProgressRing

struct ProgressRing: View {
    let progress: Double
    let color: Color
    var lineWidth: CGFloat = 6
    var size: CGFloat = 60

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
            Text("\(Int(progress * 100))%")
                .font(.system(size: size * 0.22, weight: .bold, design: .rounded))
                .foregroundStyle(color)
        }
        .frame(width: size, height: size)
    }
}

// MARK: - StatusBadge

struct StatusBadge: View {
    let text: String
    let color: Color
    var filled: Bool = false

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(filled ? color : color.opacity(0.15), in: Capsule())
            .foregroundStyle(filled ? .white : color)
    }
}
