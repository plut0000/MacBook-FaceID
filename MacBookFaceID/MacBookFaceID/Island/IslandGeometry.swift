import AppKit

struct IslandGeometry: Equatable {
    var screenFrame: CGRect
    var menuBarHeight: CGFloat
    var notchFrame: CGRect
    var hasNotch: Bool

    var notchWidth: CGFloat { notchFrame.width }
    var notchHeight: CGFloat { notchFrame.height }

    static func current() -> IslandGeometry {
        guard let screen = preferredScreen() else {
            return IslandGeometry(
                screenFrame: CGRect(x: 0, y: 0, width: 1440, height: 900),
                menuBarHeight: 24,
                notchFrame: CGRect(x: 630, y: 868, width: 180, height: 32),
                hasNotch: false
            )
        }
        return geometry(on: screen)
    }

    static func preferredScreen() -> NSScreen? {
        if let notched = NSScreen.screens.first(where: { geometry(on: $0).hasNotch }) {
            return notched
        }
        return NSScreen.main ?? NSScreen.screens.first
    }

    static func geometry(on screen: NSScreen) -> IslandGeometry {
        let frame = screen.frame
        let menu = max(frame.maxY - screen.visibleFrame.maxY, 24)

        if let left = screen.auxiliaryTopLeftArea,
           let right = screen.auxiliaryTopRightArea {
            let gap = right.minX - left.maxX
            let hasNotch = left.width > 0 && right.width > 0 && gap > 48
            if hasNotch {
                let height = max(max(left.height, right.height), 32)
                let notch = CGRect(
                    x: left.maxX,
                    y: frame.maxY - height,
                    width: gap,
                    height: height
                )
                return IslandGeometry(screenFrame: frame, menuBarHeight: menu, notchFrame: notch, hasNotch: true)
            }
        }

        let fallbackWidth = AppConstants.floatingPillWidth
        let fallbackHeight: CGFloat = 32
        let notch = CGRect(
            x: frame.midX - fallbackWidth / 2,
            y: frame.maxY - fallbackHeight,
            width: fallbackWidth,
            height: fallbackHeight
        )
        return IslandGeometry(screenFrame: frame, menuBarHeight: menu, notchFrame: notch, hasNotch: false)
    }

    func collapsedWindowFrame() -> CGRect {
        if hasNotch {
            return notchFrame
        }
        let extra: CGFloat = AppConstants.collapsedFloatingExtraWidth
        let width = notchWidth + extra
        let height = notchHeight + AppConstants.collapsedChin
        return CGRect(
            x: notchFrame.midX - width / 2,
            y: notchFrame.maxY - height,
            width: width,
            height: height
        )
    }

    func expandedWindowFrame() -> CGRect {
        let width = AppConstants.expandedWidth
        let height = notchHeight + AppConstants.expandedBodyHeight
        return CGRect(
            x: notchFrame.midX - width / 2,
            y: notchFrame.maxY - height,
            width: width,
            height: height
        )
    }
}
