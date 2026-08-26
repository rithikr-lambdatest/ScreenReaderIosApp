import SwiftUI
import UIKit

// Reusable up/down step-scroll controls for any SwiftUI ScrollView.
// Because SwiftUI has no "scroll by N points" API, we capture the UIScrollView
// backing the ScrollView and drive its contentOffset directly.

// Holds a weak reference to the backing UIScrollView.
final class ScrollArrowHolder: ObservableObject {
    weak var scrollView: UIScrollView?
}

// Invisible helper placed inside the scroll content; walks up the UIKit
// hierarchy to find the enclosing UIScrollView.
struct ScrollViewFinder: UIViewRepresentable {
    let holder: ScrollArrowHolder

    private static func find(from view: UIView?) -> UIScrollView? {
        var parent = view?.superview
        while let current = parent {
            if let scrollView = current as? UIScrollView { return scrollView }
            parent = current.superview
        }
        return nil
    }

    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.isUserInteractionEnabled = false
        DispatchQueue.main.async { [weak view, weak holder] in
            holder?.scrollView = Self.find(from: view)
        }
        return view
    }

    func updateUIView(_ uiView: UIView, context: Context) {
        DispatchQueue.main.async { [weak uiView, weak holder] in
            guard let holder, holder.scrollView == nil else { return }
            holder.scrollView = Self.find(from: uiView)
        }
    }
}

private func stepScroll(_ holder: ScrollArrowHolder, by delta: CGFloat, step: CGFloat) {
    guard let scrollView = holder.scrollView else { return }
    let minOffset = -scrollView.adjustedContentInset.top
    let maxOffset = max(
        minOffset,
        scrollView.contentSize.height
            + scrollView.adjustedContentInset.bottom
            - scrollView.bounds.height
    )
    let target = min(max(scrollView.contentOffset.y + delta * step, minOffset), maxOffset)
    scrollView.setContentOffset(CGPoint(x: 0, y: target), animated: true)
}

// Jump straight to the very bottom (or top) of the scroll content in one tap.
private func jumpToEdge(_ holder: ScrollArrowHolder, toBottom: Bool) {
    guard let scrollView = holder.scrollView else { return }
    let minOffset = -scrollView.adjustedContentInset.top
    let maxOffset = max(
        minOffset,
        scrollView.contentSize.height
            + scrollView.adjustedContentInset.bottom
            - scrollView.bounds.height
    )
    scrollView.setContentOffset(CGPoint(x: 0, y: toBottom ? maxOffset : minOffset), animated: true)
}

@ViewBuilder
private func arrowButton(_ system: String, label: String, id: String, action: @escaping () -> Void) -> some View {
    Button(action: action) {
        Image(systemName: system)
            .font(.title2)
            .frame(width: 56, height: 56)   // >= 48pt touch target
            .background(Color.accentColor)
            .foregroundColor(.white)
            .clipShape(Circle())
            .shadow(radius: 3)
    }
    .accessibilityLabel(label)
    .accessibilityIdentifier(id)
}

// Fixed bottom bar of up/down arrows (kept out of the scroll content so the
// clickable buttons don't overlap interactive elements).
struct ScrollArrowBar: View {
    @ObservedObject var holder: ScrollArrowHolder
    var step: CGFloat = 600
    // When true, adds a "jump to bottom" button (single tap → very bottom).
    var showJumpToBottom: Bool = false

    var body: some View {
        HStack(spacing: 16) {
            Spacer()
            arrowButton("chevron.up", label: "Scroll up", id: "scroll_up_button") {
                stepScroll(holder, by: -1, step: step)
            }
            arrowButton("chevron.down", label: "Scroll down", id: "scroll_down_button") {
                stepScroll(holder, by: 1, step: step)
            }
            if showJumpToBottom {
                arrowButton("chevron.down.to.line", label: "Scroll to bottom", id: "scroll_to_bottom_button") {
                    jumpToEdge(holder, toBottom: true)
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
    }
}
