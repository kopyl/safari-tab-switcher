import Cocoa

extension NSColor {

    public var cgColorAppearanceFix: CGColor {
        var color = CGColor(gray: 0, alpha: 0)
        
        app.effectiveAppearance.performAsCurrentDrawingAppearance {
            color = self.cgColor
        }

        return color
    }
}
