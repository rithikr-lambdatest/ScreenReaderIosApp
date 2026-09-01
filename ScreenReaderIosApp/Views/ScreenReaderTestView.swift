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

                // ---------- R1: Screen Reader Focus Missing for Interactive Element ----------
                // NEW LOGIC (2026-08-20, from dev): the rule no longer tests for an empty accessible
                // name. It fires when an interactive element EXISTS in the view tree but is HIDDEN
                // from VoiceOver — isAccessibilityElement = false on the element, or
                // accessibilityElementsHidden = true on a parent. ios-device-agent sees it during
                // the tree walk and routes it to skippedInteractive (not traversalOrder); the rule
                // fires from that list. The old empty-name cases are obsolete (archived in the QA
                // test plan §1a) — an unlabelled-but-reachable control is no longer an R1 case.
                // Violations use real UIKit views so the constructions match the dev's reference
                // APIs exactly; V-02 covers the SwiftUI equivalent (.accessibilityHidden(true)).
                section("R1 — Focus Missing: Interactive (2.4.3, critical)",
                        "Interactive element exists and is tappable, but VoiceOver can never reach it: isAccessibilityElement = false, or a parent with accessibilityElementsHidden = true. Reported from skippedInteractive.")
                // ALL UIKit R1+R2 violations live in ONE plain UIKit subtree below, with
                // accessibilityIdentifiers set on the UIKit views THEMSELVES. Deliberately no
                // card()/.accessibilityIdentifier wrappers: a SwiftUI identifier modifier
                // creates a visible AX element around the hidden view, which can mask the
                // hidden element from the device-agent walker.
                section("UIKit hidden-elements block (R1 V-01, V-03 / R2 V-01, V-03, V-04)",
                        "Hidden Button · hidden container (Buy Now + label) · hidden labeled image · hidden shipping label — every one present, functional and skipped by VoiceOver.")
                HiddenFixturesUIKitBlock()
                    .frame(height: 240)

                card("R1 V-02: SwiftUI Button, .accessibilityHidden(true)",
                     "SwiftUI-flavor probe. NOTE: SwiftUI removes hidden elements from the AX tree entirely, so the walker may never see this one — if only the UIKit block fires, that is the reason", "sr_r1_v02_hidden_swiftui_button") {
                    Button("Checkout now") {}
                        .buttonStyle(.borderedProminent)
                        .accessibilityHidden(true)
                }
                card("R1 P-01: reachable Button (pass)",
                     "Ordinary button, in traversalOrder", "sr_r1_p01_reachable_button") {
                    Button("Add to Cart") {}
                        .buttonStyle(.borderedProminent)
                }
                card("R1 P-02: reachable text field (pass)",
                     "Named input, reachable", "sr_r1_p02_textfield_labeled") {
                    TextField("", text: .constant(""))
                        .textFieldStyle(.roundedBorder)
                        .accessibilityLabel("Email address")
                }

                // ---------- R2: Screen Reader Focus Missing for Non-Interactive Element ----------
                // Same new logic for content elements: image/text hidden from VoiceOver while
                // present on screen → skippedNonInteractive → rule fires.
                section("R2 — Focus Missing: Non-Interactive (2.4.3, serious)",
                        "Content element (image / text) hidden from VoiceOver the same two ways. Reported from skippedNonInteractive.")
                card("R2 V-02: SwiftUI Text, .accessibilityHidden(true)",
                     "SwiftUI-flavor probe — same caveat as R1 V-02: may be absent from the AX tree rather than skipped", "sr_r2_v02_hidden_text") {
                    Text("Limited stock — 3 left")
                        .accessibilityHidden(true)
                }
                card("R2 P-01: reachable text (pass)",
                     "Normal announced text", "sr_r2_p01_labeled_text") {
                    Text("Section divider")
                }
                card("R2 P-02: reachable described image (pass)",
                     "Described and reachable", "sr_r2_p02_reachable_image") {
                    Image("wooden_dice").resizable().scaledToFit().frame(height: 44)
                        .accessibilityLabel("Wooden dice")
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

/// All UIKit R1/R2 violations in one plain UIKit subtree, matching the dev's
/// reference snippets exactly. Identifiers are set on the UIKit views themselves;
/// no SwiftUI accessibility modifiers sit above them.
private struct HiddenFixturesUIKitBlock: UIViewRepresentable {
    func makeUIView(context: Context) -> UIStackView {
        let stack = UIStackView()
        stack.axis = .vertical
        stack.spacing = 10
        stack.alignment = .leading

        // R1 V-01: fully functional button VoiceOver skips.
        let hiddenButton = UIButton(type: .system)
        hiddenButton.setTitle("Hidden Button", for: .normal)
        hiddenButton.accessibilityIdentifier = "sr_r1_v01_hidden_uibutton"
        hiddenButton.isAccessibilityElement = false  // VoiceOver skips it
        stack.addArrangedSubview(hiddenButton)

        // R1 V-03 (button) + R2 V-04 (label): parent hides ALL children.
        let container = UIStackView()
        container.axis = .vertical
        container.spacing = 4
        container.accessibilityIdentifier = "sr_r1_v03_hidden_container"
        let containerButton = UIButton(type: .system)
        containerButton.setTitle("Buy Now", for: .normal)
        containerButton.accessibilityIdentifier = "sr_r1_v03_container_button"
        let containerLabel = UILabel()
        containerLabel.text = "Limited time offer"
        containerLabel.font = .preferredFont(forTextStyle: .footnote)
        containerLabel.accessibilityIdentifier = "sr_r2_v04_container_label"
        container.addArrangedSubview(containerButton)
        container.addArrangedSubview(containerLabel)
        container.accessibilityElementsHidden = true  // all children hidden
        stack.addArrangedSubview(container)

        // R2 V-01: image WITH an accessibilityLabel that VoiceOver skips.
        let hiddenImage = UIImageView(image: UIImage(named: "wooden_dice"))
        hiddenImage.contentMode = .scaleAspectFit
        hiddenImage.accessibilityLabel = "Product image"
        hiddenImage.accessibilityIdentifier = "sr_r2_v01_hidden_uiimage"
        hiddenImage.isAccessibilityElement = false  // VoiceOver skips it
        hiddenImage.translatesAutoresizingMaskIntoConstraints = false
        hiddenImage.heightAnchor.constraint(equalToConstant: 56).isActive = true
        hiddenImage.widthAnchor.constraint(equalToConstant: 56).isActive = true
        stack.addArrangedSubview(hiddenImage)

        // R2 V-03: informative text VoiceOver skips.
        let hiddenLabel = UILabel()
        hiddenLabel.text = "Free shipping on orders over $50"
        hiddenLabel.accessibilityIdentifier = "sr_r2_v03_hidden_uilabel"
        hiddenLabel.isAccessibilityElement = false  // VoiceOver skips it
        stack.addArrangedSubview(hiddenLabel)

        return stack
    }
    func updateUIView(_ uiView: UIStackView, context: Context) {}
}

#Preview {
    NavigationView { ScreenReaderTestView() }
}
