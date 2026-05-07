import SwiftUI

// MARK: - Bolt Glass Surface
/// 玻璃态基底 — 多层半透明叠加 + 渐变描边 + 三级阴影
struct BoltGlassSurface<Content: View>: View {
    let content: Content
    let padding: CGFloat
    let cornerRadius: CGFloat

    init(padding: CGFloat = 0, cornerRadius: CGFloat = BoltTheme.radiusLg,
         @ViewBuilder content: () -> Content) {
        self.padding = padding; self.cornerRadius = cornerRadius
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(BoltTheme.surfaceGlass)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(LinearGradient(
                                colors: [.white.opacity(0.25), .white.opacity(0.06), .white.opacity(0.12)],
                                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7)
                    )
            )
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .shadow(color: BoltTheme.shadowNear, radius: 4, x: 0, y: 2)
            .shadow(color: BoltTheme.shadowMid,  radius: 12, x: 0, y: 8)
            .shadow(color: BoltTheme.shadowFar,  radius: 30, x: 0, y: 20)
    }
}

// MARK: - Bolt Elevated Card
/// 悬浮卡片 — 带顶部光源渐变描边
struct BoltElevatedCard<Content: View>: View {
    let content: Content
    let glowColor: Color
    let padding: CGFloat

    init(glowColor: Color = BoltTheme.gold.opacity(0.3), padding: CGFloat = BoltTheme.spacingMd,
         @ViewBuilder content: () -> Content) {
        self.glowColor = glowColor; self.padding = padding
        self.content = content()
    }

    var body: some View {
        content
            .padding(padding)
            .background(RoundedRectangle(cornerRadius: BoltTheme.radiusLg, style: .continuous)
                .fill(BoltTheme.surfaceGlass))
            .overlay(RoundedRectangle(cornerRadius: BoltTheme.radiusLg, style: .continuous)
                .stroke(RadialGradient(colors: [glowColor, .clear],
                    center: .topLeading, startRadius: 0, endRadius: 200), lineWidth: 0.8))
            .clipShape(RoundedRectangle(cornerRadius: BoltTheme.radiusLg, style: .continuous))
            .shadow(color: glowColor.opacity(0.2), radius: 20, x: 0, y: 0)
            .shadow(color: BoltTheme.shadowNear, radius: 6, x: 0, y: 4)
    }
}

// MARK: - Bolt Section Header
struct BoltSectionHeader: View {
    let title: String; let icon: String?

    init(_ title: String, icon: String? = nil) { self.title = title; self.icon = icon }

    var body: some View {
        HStack(spacing: 6) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(BoltTheme.gold)
            }
            Text(title.uppercased())
                .font(BoltTheme.captionFont(11).bold())
                .foregroundColor(BoltTheme.gold)
                .tracking(1.2)
            Rectangle().fill(BoltTheme.gold.opacity(0.2)).frame(height: 1).frame(maxWidth: .infinity)
        }
    }
}

// MARK: - Bolt Detail Row
struct BoltDetailRow: View {
    let label: String; let value: String; let icon: String?

    init(_ label: String, value: String, icon: String? = nil) {
        self.label = label; self.value = value; self.icon = icon
    }

    var body: some View {
        HStack(spacing: 8) {
            if let icon {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(BoltTheme.gold.opacity(0.7))
                    .frame(width: 18)
            }
            Text(label)
                .font(BoltTheme.bodyFont(12))
                .foregroundColor(BoltTheme.textSecondary)
            Spacer()
            Text(value)
                .font(BoltTheme.headingFont(13))
                .foregroundColor(BoltTheme.textPrimary)
        }
    }
}

// MARK: - Bolt Badge
struct BoltBadge: View {
    enum Style { case success, info, premium, gold }

    let text: String; let style: Style

    var config: (bg: Color, fg: Color) {
        switch style {
        case .success:  return (BoltTheme.forest.opacity(0.18),   BoltTheme.forest)
        case .info:     return (BoltTheme.skyBlue.opacity(0.18),  BoltTheme.skyBlue)
        case .premium:  return (BoltTheme.lavender.opacity(0.18), BoltTheme.lavender)
        case .gold:     return (BoltTheme.gold.opacity(0.18),     BoltTheme.gold)
        }
    }

    var body: some View {
        Text(text)
            .font(BoltTheme.captionFont(10).bold())
            .foregroundColor(config.fg)
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(config.bg)
                .overlay(Capsule().stroke(config.fg.opacity(0.2), lineWidth: 0.5)))
    }
}

// MARK: - Bolt Glow Button
struct BoltGlowButton: View {
    let title: String; let icon: String?; let gradient: [Color]; let action: () -> Void

    init(_ title: String, icon: String? = nil,
         gradient: [Color] = [Color(hex: 0xF5A623), Color(hex: 0xE8735A)],
         action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.gradient = gradient; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(BoltTheme.headingFont(13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(LinearGradient(colors: gradient, startPoint: .leading, endPoint: .trailing)))
            .foregroundColor(.white)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Bolt Ghost Button
struct BoltGhostButton: View {
    let title: String; let icon: String?; let action: () -> Void

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title; self.icon = icon; self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                if let icon { Image(systemName: icon).font(.system(size: 13, weight: .semibold)) }
                Text(title).font(BoltTheme.headingFont(13))
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .background(Capsule().fill(BoltTheme.surfaceGlass))
            .overlay(Capsule().stroke(LinearGradient(
                colors: [.white.opacity(0.3), .white.opacity(0.08)],
                startPoint: .topLeading, endPoint: .bottomTrailing), lineWidth: 0.7))
            .foregroundColor(BoltTheme.textPrimary)
        }
        .buttonStyle(PlainButtonStyle())
    }
}
