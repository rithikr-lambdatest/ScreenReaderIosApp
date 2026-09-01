import SwiftUI

// =====================================================================
// TE-22788 — iOS Screen Reader Automation QA fixture.
// One tappable card per test element. Each element intentionally satisfies
// (violation) or avoids (pass) a specific screen-reader rule so the
// auto-report / linear-navigation scan can be verified against ground truth.
//
// Rule map (RFC numbering; Rule 3 Reading Order is covered by the AI rule):
//   R1 Interactive Focus Order   (2.4.3, critical)
//   R2 Non-Interactive Focus Order (2.4.3, serious)
//   R4 Meaningless Spoken Output  (1.1.1, serious)
//   R5 Image Missing Spoken Output (1.1.1, serious)
//   R6 Duplicate State Info       (4.1.2, moderate)
//   R7 Duplicate Type Info        (4.1.2, moderate)
//   R8 Visible Label Mismatch     (2.5.3, serious)
//
// accessibilityIdentifier convention: sr_r<rule>_<v|p><nn>_<slug>
// so automation can target each element deterministically.
// =====================================================================

struct ScreenReaderTestView: View {
    @State private var toggleA = true
    @State private var toggleB = false
    @StateObject private var scrollHolder = ScrollArrowHolder()

    var body: some View {
        VStack(spacing: 0) {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                // ---------- R1/R2: Screen Reader Focus Missing ----------
                // ACTUAL agent logic (from dev, 2026-09-01): an element enters traversalOrder
                // when (isLeaf || label != "" || identifier != "") && hasValidFrame. It lands in
                // skippedInteractive / skippedNonInteractive — and R1/R2 fire — ONLY when it has
                // interactive traits (button/link/switch) or content traits (staticText/image/
                // header) but NO label, NO identifier and HAS CHILDREN (non-leaf).
                // Hiding (isAccessibilityElement=false / accessibilityElementsHidden) is NOT part
                // of the check — all previous hidden-element fixtures were unfirable.
                // Consequence: the violating element itself must carry NO accessibilityIdentifier;
                // ids for automation live on its CHILD views (children are separate elements and
                // do not affect the parent's isAccessible check).
                section("R1 — Focus Missing: Interactive (2.4.3, critical)",
                        "Container with .button / .link trait, empty label, no identifier, with children — a custom control built without an accessible name. Reported from skippedInteractive.")
                section("R2 — Focus Missing: Non-Interactive (2.4.3, serious)",
                        "Container with .image / .header trait, empty label, no identifier, with children. Reported from skippedNonInteractive. All four violations live in the UIKit block below; locate them in the report by trait + bounds.")
                FocusMissingFixturesBlock()
                    .frame(height: 320)

                card("R1 P-01: reachable Button (pass)",
                     "Leaf with a label — in traversalOrder", "sr_r1_p01_reachable_button") {
                    Button("Add to Cart") {}
                        .buttonStyle(.borderedProminent)
                }
                card("R2 P-01: reachable text (pass)",
                     "Normal announced text", "sr_r2_p01_labeled_text") {
                    Text("Section divider")
                }

                // ---------- R4: Meaningless Spoken Output ----------
                section("R4 — Meaningless Spoken Output (1.1.1, serious)",
                        "Accessible name is a generic word (button, image, view, cell, icon, container…).")
                card("R4 V-01: Label = \"button\"",
                     "Text labeled \"button\" — violation", "sr_r4_v01_generic_button") {
                    Text("Submit").accessibilityLabel("button")
                }
                card("R4 V-02: Label = \"icon\"",
                     "Control labeled \"icon\" — violation", "sr_r4_v02_generic_icon") {
                    Button("Menu") {}.accessibilityLabel("icon")
                }
                card("R4 P-01: Descriptive label (pass)",
                     "Label \"Submit order\"", "sr_r4_p01_descriptive") {
                    Text("Submit").accessibilityLabel("Submit order")
                }

                // ---------- R5: Image Missing Spoken Output ----------
                section("R5 — Image Missing Spoken Output (1.1.1, serious)",
                        "Image element with empty OR generic label (image, icon, picture, photo, img).")
                card("R5 V-01: Image label = \"image\"",
                     "Generic image label — violation", "sr_r5_v01_generic_image") {
                    Image("nike").resizable().scaledToFit().frame(height: 40)
                        .accessibilityLabel("image")
                }
                card("R5 V-02: Informative image, empty label",
                     "Brand logo with no label — violation", "sr_r5_v02_empty_logo") {
                    Image("pepsi").resizable().scaledToFit().frame(height: 40)
                        .accessibilityLabel("")
                }
                card("R5 P-01: Described image (pass)",
                     "Label \"Nike logo\"", "sr_r5_p01_described") {
                    Image("nike").resizable().scaledToFit().frame(height: 40)
                        .accessibilityLabel("Nike logo")
                }

                // ---------- R6: Duplicate State Info ----------
                section("R6 — Duplicate State Info (4.1.2, moderate)",
                        "Label bakes in state (selected/checked/disabled; on/off only on toggles) that VoiceOver already announces.")
                card("R6 V-01: Toggle labeled \"Wi-Fi on\"",
                     "Real switch, \"on\" in label (toggle-only keyword) — violation", "sr_r6_v01_toggle_on") {
                    Toggle("Wi-Fi on", isOn: $toggleA)
                }
                card("R6 V-02: Toggle labeled \"Bluetooth off\"",
                     "Real switch, \"off\" in label — violation", "sr_r6_v02_toggle_off") {
                    Toggle("Bluetooth off", isOn: $toggleB)
                }
                card("R6 V-03: Label contains \"selected\"",
                     "Button labeled \"Item selected\" — violation (any element)", "sr_r6_v03_selected") {
                    Button("Item selected") {}
                }
                card("R6 V-04: Label contains \"disabled\"",
                     "Button labeled \"Sound disabled\" — violation", "sr_r6_v04_disabled") {
                    Button("Sound disabled") {}
                }
                card("R6 V-05: Label contains \"checked\"",
                     "Button labeled \"Task checked\" — violation", "sr_r6_v05_checked") {
                    Button("Task checked") {}
                }
                card("R6 P-01: \"Sony\" must NOT match \"on\" (pass)",
                     "Word-boundary edge case — should NOT fire", "sr_r6_p01_sony") {
                    Button("Sony") {}.accessibilityLabel("Sony headphones")
                }
                card("R6 P-02: \"on\" on plain text (pass)",
                     "\"Free shipping on orders\" on non-toggle — should NOT fire", "sr_r6_p02_shipping") {
                    Text("Offer").accessibilityLabel("Free shipping on orders")
                }

                // ---------- R7: Duplicate Type Info ----------
                section("R7 — Duplicate Type Info (4.1.2, moderate)",
                        "Label repeats the control type (button, link, heading, switch…) VoiceOver already announces.")
                card("R7 V-01: Label ends with \"Button\"",
                     "\"Add to Cart Button\" — violation", "sr_r7_v01_button_word") {
                    Button("Add to Cart") {}.accessibilityLabel("Add to Cart Button")
                }
                card("R7 V-02: Label contains \"link\"",
                     "\"Home link\" — violation", "sr_r7_v02_link_word") {
                    Button("Home") {}.accessibilityLabel("Home link")
                }
                card("R7 P-01: \"Onboarding\" must NOT match \"on\" nor type (pass)",
                     "Word-boundary edge case", "sr_r7_p01_onboarding") {
                    Button("Start") {}.accessibilityLabel("Onboarding")
                }
                card("R7 P-02: Clean label (pass)",
                     "\"Add to Cart\" only", "sr_r7_p02_clean") {
                    Button("Add to Cart") {}.accessibilityLabel("Add to Cart")
                }

                // ---------- R8: Visible Label Mismatch ----------
                section("R8 — Visible Label Mismatch (2.5.3, serious)",
                        "Interactive element whose ON-SCREEN text (OCR) is not in the spoken output.")
                card("R8 V-01: Shows \"Buy Now\", speaks something else",
                     "Label \"Complete purchase immediately\" — violation", "sr_r8_v01_buy_now") {
                    Button("Buy Now") {}.accessibilityLabel("Complete purchase immediately")
                }
                card("R8 V-02: Shows \"Next\", speaks \"Continue\"",
                     "Visible ≠ spoken — violation", "sr_r8_v02_next") {
                    Button("Next") {}.accessibilityLabel("Continue")
                }
                card("R8 P-01: Visible text within spoken (pass)",
                     "Shows \"Send\", speaks \"Send message\"", "sr_r8_p01_send") {
                    Button("Send") {}.accessibilityLabel("Send message")
                }
                card("R8 P-02: Visible == label (pass)",
                     "Shows \"Save\", speaks \"Save\"", "sr_r8_p02_save") {
                    Button("Save") {}.accessibilityLabel("Save")
                }

                // ---------- OCR stress (multilingual) ----------
                section("OCR Stress — multilingual visible text",
                        "Rules 1/2/4/5/8 rely on Vision OCR matching visible text to element bounds. Non-Latin scripts stress that match.")
                card("OCR-01: Arabic (RTL) image, empty label",
                     "R2/R5 violation + RTL OCR", "sr_ocr01_arabic") {
                    Image("arabicText").resizable().scaledToFit().frame(height: 44)
                        .accessibilityLabel("")
                }
                card("OCR-02: Hindi (Devanagari) image, empty label",
                     "R2/R5 violation + Devanagari OCR", "sr_ocr02_hindi") {
                    Image("hindiText").resizable().scaledToFit().frame(height: 44)
                        .accessibilityLabel("")
                }
                card("OCR-03: CJK image, empty label",
                     "R2/R5 violation + CJK OCR", "sr_ocr03_cjk") {
                    Image("chineseText").resizable().scaledToFit().frame(height: 44)
                        .accessibilityLabel("")
                }

                Spacer(minLength: 24)
                NavigationLink(destination: ScreenReaderLinearNavView()) {
                    Text("Open Linear-Navigation Fixture →")
                        .font(.headline).foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 50)
                        .background(Color.blue).cornerRadius(10)
                }
                .accessibilityIdentifier("sr_open_linear_nav")
            }
            .padding()
            .background(ScrollViewFinder(holder: scrollHolder))
        }
        ScrollArrowBar(holder: scrollHolder)
        }
        .navigationTitle("")
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Screen Reader Automation — Test Fixture")
                .font(.title2).fontWeight(.bold)
            Text("TE-22788. Each card holds ONE element that intentionally passes or fails a specific screen-reader rule. Walk with VoiceOver (or run the auto-report scan) and compare against the labels here.")
                .font(.subheadline).foregroundColor(.secondary)
            Divider()
        }
    }

    private func section(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title).font(.headline).foregroundColor(.red)
            Text(subtitle).font(.caption).foregroundColor(.secondary)
        }
        .padding(.top, 6)
    }

    @ViewBuilder
    private func card(_ title: String, _ note: String, _ identifier: String,
                      @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).fontWeight(.semibold)
            Text(note).font(.caption2).foregroundColor(.secondary)
            content()
                .accessibilityIdentifier(identifier)
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }

    /// Same as `card`, but deliberately leaves the element WITHOUT an
    /// accessibilityIdentifier — used as a control when we suspect the scan is
    /// treating the identifier as a fallback accessible name.
    @ViewBuilder
    private func cardNoIdentifier(_ title: String, _ note: String,
                                  @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title).font(.subheadline).fontWeight(.semibold)
            Text(note).font(.caption2).foregroundColor(.secondary)
            content()
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .cornerRadius(8)
    }
}

// =====================================================================
// UIKit wrappers for the NEW R1/R2 logic — the rule is defined in UIKit terms
// (isAccessibilityElement = false / accessibilityElementsHidden = true), so the
// violations are real UIKit views matching the dev's reference exactly.
// =====================================================================

struct HiddenUIButton: UIViewRepresentable {
    let title: String
    var identifier: String = ""
    func makeUIView(context: Context) -> UIButton {
        let button = UIButton(type: .system)
        button.setTitle(title, for: .normal)
        if !identifier.isEmpty { button.accessibilityIdentifier = identifier }
        button.isAccessibilityElement = false  // VoiceOver skips it
        return button
    }
    func updateUIView(_ uiView: UIButton, context: Context) {}
}

/// R1/R2 violations matching the device-agent's ACTUAL skip logic (see the section
/// comment above): each violating element is an unlabeled, identifier-less CONTAINER
/// carrying accessibility traits, with child views inside. Child views get labels and
/// identifiers so they stay ordinary reachable elements and only the parent violates.
private struct FocusMissingFixturesBlock: UIViewRepresentable {

    private func traitContainer(_ traits: UIAccessibilityTraits, tint: UIColor,
                                children: [UIView]) -> UIStackView {
        let container = UIStackView(arrangedSubviews: children)
        container.axis = .horizontal
        container.spacing = 8
        container.alignment = .center
        container.isLayoutMarginsRelativeArrangement = true
        container.layoutMargins = UIEdgeInsets(top: 8, left: 12, bottom: 8, right: 12)
        container.backgroundColor = tint.withAlphaComponent(0.15)
        container.layer.cornerRadius = 8
        container.accessibilityTraits = traits  // trait, but NO label and NO identifier
        return container
    }

    private func childLabel(_ text: String, id: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.accessibilityIdentifier = id
        return label
    }

    func makeUIView(context: Context) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .leading

        // R1 V-01: custom "button" — .button trait, no label/identifier, children inside.
        let icon = UIImageView(image: UIImage(named: "wooden_dice"))
        icon.accessibilityLabel = "Dice icon"
        icon.accessibilityIdentifier = "sr_r1_v01_child_icon"
        icon.translatesAutoresizingMaskIntoConstraints = false
        icon.heightAnchor.constraint(equalToConstant: 28).isActive = true
        icon.widthAnchor.constraint(equalToConstant: 28).isActive = true
        stack.addArrangedSubview(traitContainer(.button, tint: .systemBlue, children: [
            icon, childLabel("Buy now", id: "sr_r1_v01_child_label"),
        ]))

        // R1 V-02: custom "link" — .link trait, no label/identifier, children inside.
        stack.addArrangedSubview(traitContainer(.link, tint: .systemIndigo, children: [
            childLabel("View details", id: "sr_r1_v02_child_label"),
        ]))

        // R2 V-01: "image" container — .image trait, no label/identifier, children inside.
        let swatchA = UIImageView(image: UIImage(named: "nike"))
        swatchA.accessibilityLabel = "Nike swoosh"
        swatchA.accessibilityIdentifier = "sr_r2_v01_child_image"
        swatchA.translatesAutoresizingMaskIntoConstraints = false
        swatchA.heightAnchor.constraint(equalToConstant: 36).isActive = true
        swatchA.widthAnchor.constraint(equalToConstant: 36).isActive = true
        stack.addArrangedSubview(traitContainer(.image, tint: .systemGreen, children: [
            swatchA, childLabel("Product shot", id: "sr_r2_v01_child_caption"),
        ]))

        // R2 V-02: "header" container — .header trait, no label/identifier, children inside.
        stack.addArrangedSubview(traitContainer(.header, tint: .systemOrange, children: [
            childLabel("Todays deals", id: "sr_r2_v02_child_label"),
        ]))

        return stack
    }
    func updateUIView(_ uiView: UIStackView, context: Context) {}
}

#Preview {
    NavigationView { ScreenReaderTestView() }
}
