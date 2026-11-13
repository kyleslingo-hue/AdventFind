import SwiftUI

// A shared visual language: ink, paper, warm sunlight and generous typography.
enum AdventDesign {
    static let ink = Color(red: 0.055, green: 0.09, blue: 0.16)
    static let muted = Color(red: 0.60, green: 0.66, blue: 0.75)
    static let orange = Color(red: 1, green: 0.64, blue: 0.39)
    static let paper = Color(red: 0.98, green: 0.96, blue: 0.92)
    static let panel = Color(red: 0.095, green: 0.14, blue: 0.22)
}

struct Eyebrow: View {
    let text: String
    var body: some View {
        Text(text.uppercased()).font(.caption2.weight(.bold)).tracking(2.6)
            .foregroundStyle(AdventDesign.muted)
    }
}

/// Vector landscape, drawn at the current view size rather than cropped artwork.
struct SabbathLandscape: View {
    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack {
                LinearGradient(colors: [Color(red: 0.19, green: 0.24, blue: 0.39),
                                        Color(red: 0.65, green: 0.40, blue: 0.40),
                                        AdventDesign.orange], startPoint: .top, endPoint: .bottom)
                Circle().fill(Color(red: 1, green: 0.83, blue: 0.56))
                    .frame(width: h * 0.44, height: h * 0.44)
                    .position(x: w * 0.73, y: h * 0.53)
                ForEach(0..<3) { layer in
                    Path { path in
                        let base = h * (0.64 + Double(layer) * 0.12)
                        path.move(to: CGPoint(x: 0, y: base))
                        path.addCurve(to: CGPoint(x: w, y: base - h * 0.04),
                                      control1: CGPoint(x: w * 0.3, y: base - h * 0.4),
                                      control2: CGPoint(x: w * 0.65, y: base + h * 0.2))
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill([Color(red: 0.35, green: 0.32, blue: 0.43), Color(red: 0.18, green: 0.23, blue: 0.33), AdventDesign.ink][layer])
                }
                // A quiet steeple in the landscape.
                Path { p in
                    let x = w * 0.77
                    let y = h * 0.76
                    p.move(to: CGPoint(x: x - 11, y: y + 35))
                    p.addLine(to: CGPoint(x: x - 11, y: y))
                    p.addLine(to: CGPoint(x: x, y: y - 19))
                    p.addLine(to: CGPoint(x: x + 11, y: y))
                    p.addLine(to: CGPoint(x: x + 11, y: y + 35))
                    p.closeSubpath()
                    p.move(to: CGPoint(x: x, y: y - 19))
                    p.addLine(to: CGPoint(x: x, y: y - 33))
                    p.move(to: CGPoint(x: x - 5, y: y - 28))
                    p.addLine(to: CGPoint(x: x + 5, y: y - 28))
                }.stroke(AdventDesign.paper.opacity(0.8), lineWidth: 1.5)
            }
        }
        .accessibilityHidden(true)
    }
}

struct AdventEmptyState: View {
    let symbol: String
    let title: String
    let message: String
    var body: some View {
        VStack(spacing: 14) {
            Image(systemName: symbol).font(.system(size: 32, weight: .light))
                .foregroundStyle(AdventDesign.orange).padding(22)
                .background(AdventDesign.orange.opacity(0.08), in: Circle())
            Text(title).font(.title2.weight(.semibold)).foregroundStyle(AdventDesign.paper)
            Text(message).font(.subheadline).foregroundStyle(AdventDesign.muted)
                .multilineTextAlignment(.center).frame(maxWidth: 320)
        }.padding(28).frame(maxWidth: .infinity)
    }
}

extension View {
    func adventPanel() -> some View {
        self.padding(20).background(AdventDesign.panel, in: RoundedRectangle(cornerRadius: 24))
    }
}
