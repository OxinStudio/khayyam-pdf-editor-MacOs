import SwiftUI
import AppKit

// MARK: - AboutKhayyamView

struct AboutKhayyamView: View {

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                KhayyamHeroHeader()
                KhayyamBiographyBody()
            }
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .frame(minWidth: 640, minHeight: 560)
    }
}

// MARK: - Hero Header

private struct KhayyamHeroHeader: View {
    var body: some View {
        ZStack {
            // Deep indigo background
            Rectangle()
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.10, green: 0.18, blue: 0.41),
                                 Color(red: 0.05, green: 0.09, blue: 0.22)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    )
                )

            // Decorative compass arc in background
            CompassDecoration()
                .opacity(0.18)

            // Content
            HStack(alignment: .top, spacing: 32) {
                // Medallion with compass icon
                KhayyamMedallion()

                VStack(alignment: .leading, spacing: 10) {
                    Text("Omar Khayyam")
                        .font(.system(size: 28, weight: .bold, design: .serif))
                        .foregroundColor(.white)

                    Text("عمر خیام")
                        .font(.system(size: 22, weight: .regular, design: .serif))
                        .foregroundColor(Color(red: 0.95, green: 0.84, blue: 0.35))

                    Text("1048 – 1131  ·  Nishapur, Persia")
                        .font(.system(size: 13, weight: .regular))
                        .foregroundColor(.white.opacity(0.6))
                        .padding(.top, 2)

                    HStack(spacing: 8) {
                        KhayyamPill("Mathematician")
                        KhayyamPill("Astronomer")
                        KhayyamPill("Poet")
                        KhayyamPill("Philosopher")
                    }
                    .padding(.top, 4)
                }

                Spacer()
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
        }
        .frame(maxWidth: .infinity)
    }
}

private struct KhayyamPill: View {
    let label: String
    init(_ label: String) { self.label = label }

    var body: some View {
        Text(label)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(Color(red: 0.95, green: 0.84, blue: 0.35))
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .overlay(
                Capsule()
                    .stroke(Color(red: 0.83, green: 0.66, blue: 0.13).opacity(0.6), lineWidth: 1)
            )
    }
}

private struct KhayyamMedallion: View {
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(red: 0.83, green: 0.66, blue: 0.13).opacity(0.15))
                .frame(width: 100, height: 100)
            Circle()
                .stroke(Color(red: 0.95, green: 0.84, blue: 0.35).opacity(0.5), lineWidth: 1.5)
                .frame(width: 100, height: 100)
            // Mini compass SVG-equivalent in SwiftUI
            MiniCompassIcon()
        }
    }
}

private struct MiniCompassIcon: View {
    private let gold = Color(red: 0.95, green: 0.84, blue: 0.35)

    var body: some View {
        ZStack {
            // Left arm
            Path { p in
                p.move(to:    CGPoint(x: 40, y: 12))
                p.addLine(to: CGPoint(x: 18, y: 54))
            }
            .stroke(gold, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

            // Right arm
            Path { p in
                p.move(to:    CGPoint(x: 40, y: 12))
                p.addLine(to: CGPoint(x: 62, y: 54))
            }
            .stroke(gold, style: StrokeStyle(lineWidth: 3.5, lineCap: .round))

            // Hinge
            Circle()
                .fill(gold)
                .frame(width: 10, height: 10)
                .offset(x: 0, y: -20)

            // Star at left tip (bright dot + rays)
            Circle()
                .fill(Color.white)
                .frame(width: 8, height: 8)
                .offset(x: -22, y: 14)

            // Dashed arc
            Path { p in
                p.addArc(center: CGPoint(x: 18, y: 54),
                         radius: 30,
                         startAngle: .degrees(-15),
                         endAngle:   .degrees(25),
                         clockwise: false)
            }
            .stroke(gold.opacity(0.6),
                    style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
        }
        .frame(width: 80, height: 80)
    }
}

private struct CompassDecoration: View {
    private let gold = Color(red: 0.83, green: 0.66, blue: 0.13)

    var body: some View {
        GeometryReader { geo in
            Path { p in
                p.addArc(center: CGPoint(x: geo.size.width * 0.12,
                                         y: geo.size.height * 1.15),
                         radius: geo.size.height * 1.05,
                         startAngle: .degrees(-58),
                         endAngle:   .degrees(-22),
                         clockwise: false)
            }
            .stroke(gold, style: StrokeStyle(lineWidth: 1, dash: [8, 10]))
        }
    }
}

// MARK: - Biography Body

private struct KhayyamBiographyBody: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {

            // Intro quote
            KhayyamQuoteBlock(
                text: "Come, fill the Cup, and in the fire of Spring\nYour Winter-garment of Repentance fling:\nThe Bird of Time has but a little way\nTo flutter — and the Bird is on the Wing.",
                source: "Rubaiyat of Omar Khayyam, trans. Edward FitzGerald"
            )

            Divider().padding(.horizontal, 28)

            // Sections
            KhayyamSection(
                icon: "person.fill",
                title: "Life",
                color: Color(red: 0.10, green: 0.18, blue: 0.41)
            ) {
                KhayyamParagraph("""
                Ghiyāth al-Dīn Abu'l-Fatḥ ʿUmar ibn Ibrāhīm al-Khayyām was born around 1048 in Nishapur, a major city in the Khorasan region of Persia — present-day northeastern Iran. His family name, Khayyam (خیام), means "tent maker" in Persian, likely reflecting his family's trade.

                He lived through a remarkable era — the height of the Islamic Golden Age — when Persia was one of the world's great centres of science, philosophy, and art. He studied under the scholars of Nishapur and Samarkand, and was supported by the Seljuk sultan Malik-Shah I, who commissioned his most important scientific work.

                Khayyam died in 1131, having spent over eight decades advancing human knowledge across disciplines that most scholars would spend a lifetime mastering just one.
                """)
            }

            Divider().padding(.horizontal, 28)

            KhayyamSection(
                icon: "compass.drawing",
                title: "Mathematics",
                color: Color(red: 0.15, green: 0.38, blue: 0.22)
            ) {
                KhayyamParagraph("""
                Khayyam's most significant mathematical achievement was his systematic treatment of cubic equations in his Treatise on the Proofs of Algebra and Balancing (Risāla fi l-barāhīn ʿalā masāʾil al-jabr wa-l-muqābala). He classified cubic equations into fourteen categories and solved them geometrically using conic sections — intersections of circles, parabolas, and hyperbolas — centuries before algebraic solutions were found in Europe.

                He also contributed to the theory of parallel lines, anticipating ideas that would not fully emerge in the West until the 19th century with the development of non-Euclidean geometry. His work on the binomial theorem and the arithmetical triangle predates Pascal's Triangle by five centuries.

                The drafting compass in this application's icon pays direct tribute to Khayyam's geometric method of reasoning — his tools were compass and ruler, and with them he unlocked equations the ancient Greeks had left unsolved.
                """)
            }

            Divider().padding(.horizontal, 28)

            KhayyamSection(
                icon: "moon.stars.fill",
                title: "Astronomy",
                color: Color(red: 0.10, green: 0.18, blue: 0.41)
            ) {
                KhayyamParagraph("""
                In 1073, Sultan Malik-Shah I invited Khayyam to lead a group of astronomers in building a new observatory at Isfahan and reforming the Persian calendar. The result — completed in 1079 — was the Jalali calendar, named after the Sultan's title Jalāl al-Dawla.

                The Jalali calendar is extraordinarily precise: it drifts by only one day every 3,770 years, making it more accurate than the Gregorian calendar introduced five centuries later in Europe (which drifts one day every 3,226 years). It is still the basis of the official calendar of Iran and Afghanistan today.

                Khayyam's method involved measuring the solar year with meticulous astronomical observations. The bright star in the application's icon represents this legacy — the compass tip touching a star, the astronomer-mathematician measuring the heavens with geometric precision.
                """)
            }

            Divider().padding(.horizontal, 28)

            KhayyamSection(
                icon: "text.quote",
                title: "Poetry",
                color: Color(red: 0.38, green: 0.22, blue: 0.08)
            ) {
                KhayyamParagraph("""
                Alongside his scientific work, Khayyam wrote poetry — specifically rubaiyat (رباعیات), a Persian poetic form of four-line stanzas (quatrains). He is credited with somewhere between 100 and over 1,000 quatrains, though scholars debate which were truly his.

                His poems are philosophical and often melancholy, touching on the brevity of life, the mystery of existence, and the pleasures of the present moment. They express a worldview that is sceptical of rigid religious doctrine and deeply human in its acceptance of uncertainty.

                Khayyam's poetry remained relatively obscure in the West until 1859, when the English poet Edward FitzGerald published a loose translation called The Rubaiyat of Omar Khayyam. It became one of the most widely read poems in the Victorian era, and introduced the Western world to one of Persia's greatest minds.
                """)

                KhayyamQuoteBlock(
                    text: "The Moving Finger writes; and, having writ,\nMoves on: nor all thy Piety nor Wit\nShall lure it back to cancel half a Line,\nNor all thy Tears wash out a Word of it.",
                    source: "Rubaiyat, LI"
                )
                .padding(.top, 8)
            }

            Divider().padding(.horizontal, 28)

            // Why named Khayyam
            KhayyamSection(
                icon: "doc.richtext.fill",
                title: "Why Khayyam PDF Editor?",
                color: Color(red: 0.10, green: 0.18, blue: 0.41)
            ) {
                KhayyamParagraph("""
                Omar Khayyam embodied the unity of precision and expression — the same qualities a good document editor should have. He measured the cosmos with a compass and wrote about it in verse. He was equally at home with a geometric proof and a beautifully turned quatrain.

                The name honours a scholar who understood that working with text and ideas is a serious and worthy endeavour — and that the tools we use to do it matter.
                """)
            }

            // Footer
            HStack {
                Spacer()
                VStack(spacing: 4) {
                    Link("www.oxinstudio.com", destination: URL(string: "https://www.oxinstudio.com")!)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("Khayyam PDF Editor · Oxin Studio · 2026")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Spacer()
            }
            .padding(.vertical, 24)
        }
    }
}

// MARK: - Reusable Section Components

private struct KhayyamSection<Content: View>: View {
    let icon: String
    let title: String
    let color: Color
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(color)
                Text(title)
                    .font(.system(size: 18, weight: .bold, design: .serif))
            }
            content()
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 28)
    }
}

private struct KhayyamParagraph: View {
    let text: String
    init(_ text: String) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 14, weight: .regular))
            .foregroundStyle(.primary)
            .lineSpacing(5)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct KhayyamQuoteBlock: View {
    let text: String
    let source: String

    var body: some View {
        HStack(spacing: 0) {
            Rectangle()
                .fill(Color(red: 0.83, green: 0.66, blue: 0.13).opacity(0.7))
                .frame(width: 3)

            VStack(alignment: .leading, spacing: 6) {
                Text(text)
                    .font(.system(size: 14, weight: .regular, design: .serif))
                    .italic()
                    .foregroundStyle(.primary)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)

                Text("— \(source)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.leading, 16)
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 36)
        .padding(.vertical, 16)
        .background(Color(red: 0.83, green: 0.66, blue: 0.13).opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 0))
    }
}
