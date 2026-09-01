import SwiftUI

// TE-22788 — Linear-Navigation fixture.
// Content extends well beyond the viewport (long vertical scroll) AND includes a
// horizontal carousel, so linear-navigation mode must scroll through everything
// to find the off-screen violations. Also links to pHash edge-case screens.
struct ScreenReaderLinearNavView: View {
    @StateObject private var scrollHolder = ScrollArrowHolder()

    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Text("Linear Navigation Fixture")
                    .font(.title2).fontWeight(.bold)
                Text("Off-screen violations here should only be found in linear-navigation mode (which scrolls the whole page). Auto-report mode should find the top ones plus whatever a customer scroll reveals.")
                    .font(.subheadline).foregroundColor(.secondary)

                // Top-of-page violation (visible without scrolling)
                // NEW R1 logic: hidden-but-tappable interactive element, on screen from the
                // start — must land in skippedInteractive in BOTH modes.
                // UIKit construction with the identifier on the UIButton itself — a SwiftUI
                // .accessibilityIdentifier wrapper would mask the hidden element from the walker.
                VStack(alignment: .leading, spacing: 6) {
                    Text("TOP: hidden Button (R1) — visible without scrolling")
                        .font(.caption).fontWeight(.semibold)
                    HiddenUIButton(title: "Flash Sale", identifier: "sr_lin_top_r1")
                        .frame(height: 44)
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .cornerRadius(8)

                // Horizontal carousel — linear mode must swipe left through it
                Text("Horizontal carousel (swipe →)").font(.headline).padding(.top, 8)
                ScrollView(.horizontal, showsIndicators: true) {
                    HStack(spacing: 12) {
                        ForEach(0..<10, id: \.self) { i in
                            VStack {
                                Image(systemName: "photo").font(.largeTitle)
                                    .accessibilityHidden(true)
                                Text("Card \(i + 1)")
                            }
                            .frame(width: 120, height: 100)
                            .background(Color(.tertiarySystemBackground))
                            .cornerRadius(8)
                            // Card 8 (off-screen in the carousel) is a generic-label violation
                            .accessibilityLabel(i == 7 ? "image" : "Card \(i + 1)")
                            .accessibilityIdentifier(i == 7 ? "sr_lin_carousel_r5" : "sr_lin_carousel_\(i + 1)")
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Long filler so the bottom violations are far off-screen
                ForEach(0..<18, id: \.self) { i in
                    Text("Filler row \(i + 1) — scroll down for more")
                        .font(.body).foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground))
                        .cornerRadius(6)
                        .accessibilityIdentifier("sr_lin_filler_\(i + 1)")
                }

                // Bottom-of-page violations (only reachable after vertical scroll)
                labeledRow("BOTTOM: \"Add to Cart Button\" (R7) — far off-screen",
                           "sr_lin_bottom_r7") {
                    Button("Add to Cart") {}.accessibilityLabel("Add to Cart Button")
                }
                labeledRow("BOTTOM: Buy Now speaks otherwise (R8) — far off-screen",
                           "sr_lin_bottom_r8") {
                    Button("Buy Now") {}.accessibilityLabel("Complete purchase immediately")
                }

                Divider().padding(.vertical, 8)
                Text("pHash edge cases").font(.headline)
                NavigationLink(destination: PHashSimilarView()) {
                    Text("Visually-similar-but-different screen (false-skip risk)")
                }.accessibilityIdentifier("sr_phash_similar_link")
                NavigationLink(destination: PHashAnimatedView()) {
                    Text("Animated screen (false-scan risk)")
                }.accessibilityIdentifier("sr_phash_animated_link")
            }
            .padding()
            .background(ScrollViewFinder(holder: scrollHolder))
        }
        ScrollArrowBar(holder: scrollHolder)
        }
        .navigationTitle("")
    }

    @ViewBuilder
    private func labeledRow(_ title: String, _ id: String,
                            @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).fontWeight(.semibold)
            content().accessibilityIdentifier(id)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// pHash false-SKIP risk: two states that look ~identical but differ meaningfully.
// Toggling reveals an error label / flips a switch without changing overall layout.
struct PHashSimilarView: View {
    @State private var showError = false
    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("pHash — Similar Screens").font(.title3).fontWeight(.bold)
            Text("Tap the button: the screen changes meaningfully (an error appears) but looks ~95% the same. A pHash that over-skips would MISS the new element.")
                .font(.caption).foregroundColor(.secondary)

            TextField("Email", text: .constant(""))
                .textFieldStyle(.roundedBorder)
                .accessibilityIdentifier("sr_phash_email_field")

            if showError {
                Text("Error: enter a valid email")
                    .foregroundColor(.red).font(.footnote)
                    .accessibilityIdentifier("sr_phash_error_label")
            }

            Button(showError ? "Hide error" : "Show error") { showError.toggle() }
                .accessibilityIdentifier("sr_phash_toggle_error")
            Spacer()
        }
        .padding()
        .navigationTitle("")
    }
}

// pHash false-SCAN risk: continuous animation changes pixels without changing content.
//
// The hash is an 8x8 average hash with a >95% similarity skip threshold, so a small
// symmetric spinner barely moves it — rotating a radially-symmetric glyph inside one
// or two of the 64 cells is close to a no-op. To actually stress the threshold the
// animation has to shift large blocks of luminance ACROSS the grid, which is what the
// two elements below do:
//   A-01 sweeping band  — a wide dark block translates across the full width, changing
//                         whole columns of the hash grid as it travels.
//   A-02 flashing tiles — a 4x3 checkerboard inverts light/dark, flipping many of the
//                         64 cells at once. This is the maximally adversarial case.
// The accessibility content never changes while all of this runs, so any repeated scan
// is provably a duplicate of identical content.
struct PHashAnimatedView: View {
    @State private var spin = false
    @State private var sweep = false
    @State private var flip = false

    var body: some View {
        ScrollView {
            VStack(spacing: 14) {
                Text("pHash — Animated Screen").font(.title3).fontWeight(.bold)
                Text("The content is static but a large share of the pixels change every frame. A pHash that under-skips would re-scan this same screen repeatedly — burning linear-navigation budget and re-reporting the same elements.")
                    .font(.caption).foregroundColor(.secondary)

                // A-01: wide band sweeping across the full width.
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.tertiarySystemBackground))
                    GeometryReader { geo in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.primary.opacity(0.85))
                            .frame(width: geo.size.width * 0.35)
                            .offset(x: sweep ? geo.size.width * 0.65 : 0)
                            .animation(.linear(duration: 1.2).repeatForever(autoreverses: true),
                                       value: sweep)
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 150)
                .clipped()
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Loading banner")
                .accessibilityIdentifier("sr_phash_anim_sweep")

                // A-02: checkerboard inverting light/dark — flips many hash cells at once.
                VStack(spacing: 6) {
                    ForEach(0..<3, id: \.self) { row in
                        HStack(spacing: 6) {
                            ForEach(0..<4, id: \.self) { col in
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(tileIsDark(row: row, col: col) ? Color.black : Color.white)
                                    .frame(height: 44)
                            }
                        }
                    }
                }
                .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: flip)
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Activity grid")
                .accessibilityIdentifier("sr_phash_anim_tiles")

                // Original spinner, enlarged. Kept as the low-delta control: a symmetric
                // rotation should NOT move the hash much even at this size.
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.system(size: 120))
                    .rotationEffect(.degrees(spin ? 360 : 0))
                    .animation(.linear(duration: 1).repeatForever(autoreverses: false), value: spin)
                    .accessibilityLabel("Loading")
                    .accessibilityIdentifier("sr_phash_spinner")

                // Static content — must be reported exactly ONCE no matter how many times
                // the animation tempts the engine into re-scanning.
                Button("Confirm order") {}.accessibilityIdentifier("sr_phash_static_button")

                // Dedup probe: a stable R7 violation (label repeats the element type) on an
                // animated screen. R7 is confirmed-firing, so it will be reported. In linear
                // mode dedupId = SHA256(element_id + "_" + ruleID), so it must appear exactly
                // once — more than one occurrence means a re-scan slipped past dedup.
                Button("Submit") {}
                    .accessibilityLabel("Submit Button")
                    .accessibilityIdentifier("sr_phash_anim_r7_button")

                Spacer(minLength: 20)
            }
            .padding()
        }
        .onAppear {
            spin = true
            sweep = true
            flip = true
        }
        .navigationTitle("")
    }

    private func tileIsDark(row: Int, col: Int) -> Bool {
        (row + col).isMultiple(of: 2) ? flip : !flip
    }
}

#Preview {
    NavigationView { ScreenReaderLinearNavView() }
}
