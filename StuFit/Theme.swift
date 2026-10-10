//
//  Theme.swift
//  StuFit
//
//  Design tokens and shared components, ported from the Glimmer Health
//  design system (guidelines/type-app.html + tokens/*.css). Dark mode only:
//  five surfaces, four accents, San Francisco at system weights, tabular
//  numerals for every figure, cards that separate by surface value alone.
//

import SwiftUI

// MARK: - Colour tokens

enum GLM {
    // Surfaces (Dracula PRO, desaturated ~45%)
    static let deep = Color(hex: 0x16151D)
    static let appBg = Color(hex: 0x22212C)
    static let surface = Color(hex: 0x2A2938)
    static let surfaceRaised = Color(hex: 0x322F47)
    static let sectionBg = Color(hex: 0x1B1A24)

    // Lines
    static let border = Color(hex: 0x454158)
    static let borderQuiet = Color(hex: 0x3A3750)

    // Ink
    static let ink = Color(hex: 0xF8F8F2)
    static let inkMuted = Color(hex: 0x7970A9)
    static let inkBody = Color(hex: 0xB8B4C8)
    static let inkFaint = Color(hex: 0x5A5478)
    static let onAccent = Color(hex: 0x22212C)

    // Accents
    static let purple = Color(hex: 0xA296DC)
    static let purpleLight = Color(hex: 0xC7BEF0)
    static let purpleLighter = Color(hex: 0xE0D8FF)
    static let purpleDeep = Color(hex: 0x7970A9)
    static let cyan = Color(hex: 0xA3E9DD)
    static let green = Color(hex: 0x9ADA95)
    static let caution = Color(hex: 0xE4C69E)
    static let attention = Color(hex: 0xDCA296)

    // Semantic aliases
    static let accent = purple
    static let success = green
    static let atRisk = caution
    static let shortfall = attention
    static let scrim = Color(red: 13 / 255, green: 12 / 255, blue: 19 / 255).opacity(0.82)

    /// Soft purple glow reserved for earned badges / record moments.
    static let badgeShadow = purple.opacity(0.35)

    enum Radius {
        static let bar: CGFloat = 6
        static let icon: CGFloat = 12
        static let button: CGFloat = 15
        static let field: CGFloat = 14
        static let cardSm: CGFloat = 16
        static let card: CGFloat = 20
        static let tile: CGFloat = 22
    }

    enum Space {
        static let gutter: CGFloat = 24
        static let gutterTight: CGFloat = 18
        static let cardPadY: CGFloat = 18
        static let cardPadX: CGFloat = 20
        static let cardGap: CGFloat = 14
        static let listGap: CGFloat = 10
    }
}

extension Color {
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }
}

// MARK: - Type scale

/// The app type scale from guidelines/type-app.html. Sizes are points on
/// San Francisco; tracking is expressed in em and converted to points.
enum GLMTextStyle {
    case display        // 38 / 700 / -0.02em
    case greeting       // 27 / 700 / -0.01em
    case screenTitle    // 16 / 700
    case rowTitle       // 15 / 600
    case cardTitle      // 14 / 600
    case body           // 13 / 400 · muted
    case caption        // 12 / 400 · muted
    case label          // 11 / 600 · muted
    case eyebrow        // 11 / 600 · muted · 0.09em caps
    case metricLarge    // 30 / 700 · tabular
    case metric         // 25 / 700 · tabular
    case statValue      // 20 / 700 · tabular
    case rowValue       // 14 / 600 · tabular
    case readout        // 12 / 400 · muted · tabular
    case unit           // 11 / 500 · muted

    var size: CGFloat {
        switch self {
        case .display: return 38
        case .greeting: return 27
        case .screenTitle: return 16
        case .rowTitle: return 15
        case .cardTitle: return 14
        case .body: return 13
        case .caption: return 12
        case .label, .eyebrow, .unit: return 11
        case .metricLarge: return 30
        case .metric: return 25
        case .statValue: return 20
        case .rowValue: return 14
        case .readout: return 12
        }
    }

    var weight: Font.Weight {
        switch self {
        case .display, .greeting, .screenTitle, .metricLarge, .metric, .statValue: return .bold
        case .rowTitle, .cardTitle, .label, .eyebrow, .rowValue: return .semibold
        case .unit: return .medium
        case .body, .caption, .readout: return .regular
        }
    }

    var trackingEm: CGFloat {
        switch self {
        case .display: return -0.02
        case .greeting: return -0.01
        case .eyebrow: return 0.09
        default: return 0
        }
    }

    var defaultColor: Color {
        switch self {
        case .body, .caption, .label, .eyebrow, .readout, .unit: return GLM.inkMuted
        default: return GLM.ink
        }
    }

    var isTabular: Bool {
        switch self {
        case .metricLarge, .metric, .statValue, .rowValue, .readout: return true
        default: return false
        }
    }

    var lineSpacing: CGFloat {
        switch self {
        case .body: return size * 0.5      // 1.5 leading
        case .caption: return size * 0.4   // 1.4 leading
        default: return 0
        }
    }

    var font: Font { .system(size: size, weight: weight) }
}

private struct GLMTextModifier: ViewModifier {
    let style: GLMTextStyle
    let color: Color?

    func body(content: Content) -> some View {
        let base = content
            .font(style.font)
            .tracking(style.trackingEm * style.size)
            .foregroundColor(color ?? style.defaultColor)
            .lineSpacing(style.lineSpacing)
        if style.isTabular {
            base.monospacedDigit()
        } else {
            base
        }
    }
}

extension View {
    /// Apply one of the app type roles. Pass `color` to override the role's ink.
    func glmText(_ style: GLMTextStyle, color: Color? = nil) -> some View {
        modifier(GLMTextModifier(style: style, color: color))
    }
}

extension Text {
    /// Small tracked uppercase eyebrow ("SPLITS", "HOW FAR").
    func glmEyebrow(color: Color = GLM.inkMuted) -> some View {
        self.textCase(.uppercase).glmText(.eyebrow, color: color)
    }
}

// MARK: - Cards

enum GLMCardVariant {
    case surface     // default module
    case featured    // 160° surface → raised wash, 1px border
    case inset       // app-bg inside a card
    case outline     // transparent, 1px border
}

private struct GLMCardModifier: ViewModifier {
    var variant: GLMCardVariant
    var radius: CGFloat
    var padding: EdgeInsets?

    func body(content: Content) -> some View {
        content
            .padding(padding ?? EdgeInsets(top: GLM.Space.cardPadY, leading: GLM.Space.cardPadX,
                                           bottom: GLM.Space.cardPadY, trailing: GLM.Space.cardPadX))
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(background)
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: radius, style: .continuous)
                        .strokeBorder(GLM.border, lineWidth: 1)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
    }

    private var showsBorder: Bool {
        switch variant {
        case .featured, .outline: return true
        default: return false
        }
    }

    @ViewBuilder
    private var background: some View {
        switch variant {
        case .surface:
            GLM.surface
        case .featured:
            LinearGradient(colors: [GLM.surface, GLM.surfaceRaised],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
        case .inset:
            GLM.appBg
        case .outline:
            Color.clear
        }
    }
}

extension View {
    /// 20px dashboard card with 18/20 padding.
    func glmCard(_ variant: GLMCardVariant = .surface, padding: EdgeInsets? = nil) -> some View {
        modifier(GLMCardModifier(variant: variant, radius: GLM.Radius.card, padding: padding))
    }

    /// 16px list row / compact module.
    func glmRow(_ variant: GLMCardVariant = .surface,
                padding: EdgeInsets = EdgeInsets(top: 14, leading: 16, bottom: 14, trailing: 16)) -> some View {
        modifier(GLMCardModifier(variant: variant, radius: GLM.Radius.cardSm, padding: padding))
    }

    /// Uniform padding shorthand for cards.
    func glmCard(_ variant: GLMCardVariant = .surface, padding: CGFloat) -> some View {
        glmCard(variant, padding: EdgeInsets(top: padding, leading: padding, bottom: padding, trailing: padding))
    }
}

// MARK: - Buttons

struct GLMButtonStyle: ButtonStyle {
    enum Variant { case primary, light, soft, outline, quiet, attention }
    enum Size { case sm, md, lg }

    var variant: Variant = .primary
    var size: Size = .lg
    var block: Bool = true
    var pill: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        let radius = pill ? 999 : GLM.Radius.button
        configuration.label
            .font(.system(size: fontSize, weight: .semibold))
            .foregroundColor(foreground)
            .lineLimit(1)
            .minimumScaleFactor(0.85)
            .padding(.vertical, padY)
            .padding(.horizontal, padX)
            .frame(maxWidth: block ? .infinity : nil)
            .background(background)
            .overlay {
                RoundedRectangle(cornerRadius: radius, style: .continuous)
                    .strokeBorder(borderColor, lineWidth: 1)
            }
            .clipShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .contentShape(RoundedRectangle(cornerRadius: radius, style: .continuous))
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }

    private var fontSize: CGFloat {
        switch size {
        case .sm: return 13
        case .md: return 14
        case .lg: return 15
        }
    }

    private var padY: CGFloat {
        switch size {
        case .sm: return 9
        case .md: return 13
        case .lg: return 15
        }
    }

    private var padX: CGFloat {
        switch size {
        case .sm: return 15
        case .md: return 22
        case .lg: return 26
        }
    }

    private var background: Color {
        switch variant {
        case .primary: return GLM.purple
        case .light: return GLM.ink
        case .soft: return GLM.purpleLight
        case .outline, .quiet, .attention: return .clear
        }
    }

    private var foreground: Color {
        switch variant {
        case .primary, .soft: return GLM.onAccent
        case .light: return GLM.deep
        case .outline: return GLM.ink
        case .quiet: return GLM.purple
        case .attention: return GLM.attention
        }
    }

    private var borderColor: Color {
        switch variant {
        case .outline, .attention: return GLM.border
        default: return .clear
        }
    }
}

extension ButtonStyle where Self == GLMButtonStyle {
    static var glmPrimary: GLMButtonStyle { GLMButtonStyle(variant: .primary) }
    static var glmOutline: GLMButtonStyle { GLMButtonStyle(variant: .outline) }
    static var glmSoft: GLMButtonStyle { GLMButtonStyle(variant: .soft) }
    static var glmAttention: GLMButtonStyle { GLMButtonStyle(variant: .attention) }
    static var glmQuiet: GLMButtonStyle { GLMButtonStyle(variant: .quiet, size: .md, block: false) }
}

/// Lightweight press feedback for tappable rows and tiles: opacity only,
/// nothing scales or lifts.
struct GLMPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .contentShape(Rectangle())
            .opacity(configuration.isPressed ? 0.82 : 1)
            .animation(.easeOut(duration: 0.15), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == GLMPressStyle {
    static var glmPress: GLMPressStyle { GLMPressStyle() }
}

// MARK: - Chip

struct GLMChip: View {
    let title: String
    var selected: Bool = false
    var small: Bool = false
    var action: () -> Void = {}

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(selected ? GLM.onAccent : GLM.ink)
                .lineLimit(1)
                .padding(.vertical, small ? 8 : 9)
                .padding(.horizontal, small ? 14 : 15)
                .background(selected ? GLM.purple : Color.clear)
                .overlay {
                    Capsule().strokeBorder(selected ? Color.clear : GLM.border, lineWidth: 1)
                }
                .clipShape(Capsule())
        }
        .buttonStyle(.glmPress)
    }
}

// MARK: - Icon tile

/// Emoji centred in an inset square: the product's icon system.
struct GLMIconTile: View {
    let glyph: String
    var size: CGFloat = 42
    var fill: Color = GLM.appBg
    var circular: Bool = false

    var body: some View {
        Text(glyph)
            .font(.system(size: size * 0.45))
            .frame(width: size, height: size)
            .background(fill)
            .clipShape(
                circular
                    ? AnyShape(Circle())
                    : AnyShape(RoundedRectangle(cornerRadius: GLM.Radius.icon, style: .continuous))
            )
    }
}

/// Lavender-gradient medallion for earned badges and record moments.
struct GLMBadgeTile: View {
    let glyph: String
    var size: CGFloat = 42

    var body: some View {
        Text(glyph)
            .font(.system(size: size * 0.45))
            .frame(width: size, height: size)
            .background(
                LinearGradient(colors: [GLM.purpleLight, GLM.purpleDeep],
                               startPoint: .topLeading, endPoint: .bottomTrailing)
            )
            .clipShape(Circle())
            .shadow(color: GLM.badgeShadow, radius: 7, x: 0, y: 6)
    }
}

// MARK: - Section header

struct GLMSectionHeader<Trailing: View>: View {
    let title: String
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center) {
            Text(title).glmText(.cardTitle)
            Spacer()
            trailing()
        }
    }
}

extension GLMSectionHeader where Trailing == EmptyView {
    init(_ title: String) {
        self.init(title) { EmptyView() }
    }
}

// MARK: - Stat tile

struct GLMStatTile: View {
    let value: String
    let label: String
    var tone: Color = GLM.ink

    var body: some View {
        VStack(spacing: 2) {
            Text(value).glmText(.statValue, color: tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label).glmText(.label)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
        .padding(.horizontal, 12)
        .background(GLM.surface)
        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous))
    }
}

/// Inset variant for tiles that sit inside a surface card.
struct GLMInsetStatTile: View {
    let value: String
    let label: String
    var subtitle: String? = nil
    var tone: Color = GLM.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).glmText(.label)
                .lineLimit(1)
            Text(value).glmText(.statValue, color: tone)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle).glmText(.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 12)
        .padding(.horizontal, 14)
        .background(GLM.appBg)
        .clipShape(RoundedRectangle(cornerRadius: GLM.Radius.cardSm, style: .continuous))
    }
}

// MARK: - Metric bar

struct GLMMetricBar: View {
    var label: String? = nil
    var readout: String? = nil
    let fraction: Double
    var color: Color = GLM.purple
    var height: CGFloat = 10

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if label != nil || readout != nil {
                HStack(alignment: .firstTextBaseline) {
                    if let label { Text(label).glmText(.cardTitle) }
                    Spacer()
                    if let readout { Text(readout).glmText(.readout) }
                }
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: GLM.Radius.bar, style: .continuous)
                        .fill(GLM.border)
                    RoundedRectangle(cornerRadius: GLM.Radius.bar, style: .continuous)
                        .fill(color)
                        .frame(width: geo.size.width * min(max(fraction, 0), 1))
                }
            }
            .frame(height: height)
        }
    }
}

// MARK: - Tag pill

/// Small status pill on the app background ("Warmup", "Completed").
struct GLMTag: View {
    let text: String
    var color: Color = GLM.inkMuted
    var dot: Bool = false

    var body: some View {
        HStack(spacing: 5) {
            if dot {
                Circle().fill(color).frame(width: 5, height: 5)
            }
            Text(text)
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
        .padding(.vertical, 4)
        .padding(.horizontal, 9)
        .background(GLM.appBg)
        .clipShape(Capsule())
    }
}

// MARK: - Screen header

struct GLMScreenHeader<Trailing: View>: View {
    let title: String
    var subtitle: String? = nil
    var onBack: (() -> Void)? = nil
    @ViewBuilder var trailing: () -> Trailing

    init(_ title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil,
         @ViewBuilder trailing: @escaping () -> Trailing) {
        self.title = title
        self.subtitle = subtitle
        self.onBack = onBack
        self.trailing = trailing
    }

    var body: some View {
        HStack(alignment: .center, spacing: 12) {
            if let onBack {
                Button(action: onBack) {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(GLM.ink)
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.glmPress)
            }
            VStack(alignment: .leading, spacing: 1) {
                Text(title).glmText(.screenTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                if let subtitle {
                    Text(subtitle).glmText(.caption)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, GLM.Space.gutterTight)
        .padding(.top, 10)
        .padding(.bottom, 14)
        .overlay(alignment: .bottom) {
            Rectangle().fill(GLM.surface).frame(height: 1)
        }
    }
}

extension GLMScreenHeader where Trailing == EmptyView {
    init(_ title: String, subtitle: String? = nil, onBack: (() -> Void)? = nil) {
        self.init(title, subtitle: subtitle, onBack: onBack) { EmptyView() }
    }
}

// MARK: - Hairline

struct GLMHairline: View {
    var color: Color = GLM.border
    var body: some View {
        Rectangle().fill(color).frame(height: 1)
    }
}

// MARK: - Screen chrome

private struct GLMScreenModifier: ViewModifier {
    func body(content: Content) -> some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(GLM.appBg.ignoresSafeArea())
            .preferredColorScheme(.dark)
            .tint(GLM.purple)
    }
}

extension View {
    /// App background, dark scheme and purple tint for a full screen.
    func glmScreen() -> some View {
        modifier(GLMScreenModifier())
    }
}

// MARK: - Helpers

enum GLMFormat {
    /// "1,180" style thousands grouping for any count.
    static func count(_ value: Int) -> String {
        value.formatted(.number.grouping(.automatic))
    }

    /// Weight with one decimal and a lowercase unit: "60.0 kg".
    static func kg(_ value: Double) -> String {
        String(format: "%.1f kg", value)
    }

    /// Time of day greeting.
    static var greeting: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "Good morning"
        case 12..<17: return "Good afternoon"
        case 17..<21: return "Good evening"
        default: return "Good night"
        }
    }

    /// "this morning" / "this afternoon" / "this evening" / "tonight".
    static var timeOfDay: String {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 5..<12: return "this morning"
        case 12..<17: return "this afternoon"
        case 17..<21: return "this evening"
        default: return "tonight"
        }
    }
}
