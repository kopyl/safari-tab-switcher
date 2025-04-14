import Cocoa

private final class Favicons {
    private(set) var icons: [String: NSImage] = [:]
    private var cache: Set<String> = []
    private var observers: [String: [NSView]] = [:]
    
    static let shared = Favicons()
    
    func fetchFavicon(for host: String, view: NSView? = nil) {
        // Register observer if provided
        if let view = view {
            if observers[host] == nil {
                observers[host] = []
            }
            observers[host]?.append(view)
        }
        
        // Return if already in cache
        if icons[host] != nil {
            view?.needsDisplay = true
            return
        }
        
        // Return if already fetching
        if cache.contains(host) {
            return
        }
        cache.insert(host)
        
        let primaryURL = "https://icons.duckduckgo.com/ip3/\(host).ico"
        let fallbackURL = "https://www.google.com/s2/favicons?sz=32&domain=\(host)"
        
        fetchImage(from: primaryURL, for: host, fallbackURL: fallbackURL)
    }
    
    private func fetchImage(from urlString: String, for host: String, fallbackURL: String? = nil) {
        guard let url = URL(string: urlString) else { return }
        
        URLSession.shared.dataTask(with: url) { [weak self] data, response, error in
            guard let self = self else { return }
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 404 {
                if let fallbackURL = fallbackURL {
                    self.fetchImage(from: fallbackURL, for: host)
                }
                return
            }
            
            guard let data = data, let image = NSImage(data: data), error == nil else {
                return
            }
            
            DispatchQueue.main.async {
                self.icons[host] = image
                
                // Notify all observers
                if let views = self.observers[host] {
                    for view in views {
                        view.needsDisplay = true
                    }
                }
            }
        }.resume()
    }
}

final class FaviconView: NSView {
    let tab: Tab
    private let textLayer = CATextLayer()
    private var imageLayer: CALayer?
    
    public let width: CGFloat = 16
    public let height: CGFloat = 16
    public let fontSize: CGFloat = 10
    
    init(tab: Tab) {
        self.tab = tab
        super.init(frame: NSRect(x: 0, y: 0, width: width, height: height))
        
        setupView()
    }
    
    private func setupView() {
        wantsLayer = true
        layer?.backgroundColor = NSColor.lightGrey.cgColorAppearanceFix
        layer?.cornerRadius = 3
        
        textLayer.string = tab.host.first?.uppercased() ?? "N"
        textLayer.alignmentMode = .center
        textLayer.foregroundColor = NSColor.nearBlack.cgColorAppearanceFix
        textLayer.font = NSFont.systemFont(ofSize: fontSize)
        textLayer.fontSize = fontSize
        textLayer.contentsScale = NSScreen.main?.backingScaleFactor ?? 2
        layer?.addSublayer(textLayer)
        
        self.translatesAutoresizingMaskIntoConstraints = false
        
        // Request favicon if host is available
        if !tab.host.isEmpty {
            Favicons.shared.fetchFavicon(for: tab.host, view: self)
        }
    }
    
    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)
        
        // Check if we have an icon for this host
        if !tab.host.isEmpty, let image = Favicons.shared.icons[tab.host] {
            displayImage(image)
        } else {
            displayPlaceholder()
        }
    }
    
    private func displayImage(_ image: NSImage) {
        // Remove text layer
        textLayer.removeFromSuperlayer()
        
        // Remove previous image layer if it exists
        imageLayer?.removeFromSuperlayer()
        
        // Create new image layer
        let imgLayer = CALayer()
        imgLayer.frame = bounds
        imgLayer.contentsGravity = .resizeAspect
        imgLayer.contents = image
        layer?.addSublayer(imgLayer)
        imageLayer = imgLayer
        
        // Reset background
        layer?.backgroundColor = NSColor.clear.cgColorAppearanceFix
    }
    
    private func displayPlaceholder() {
        // Make sure text layer is visible
        if textLayer.superlayer == nil {
            layer?.addSublayer(textLayer)
        }
        
        // Remove image layer if it exists
        imageLayer?.removeFromSuperlayer()
        imageLayer = nil
        
        // Set background color
        layer?.backgroundColor = NSColor.lightGrey.cgColorAppearanceFix
        
        // Update text layout
        if let font = textLayer.font as? NSFont {
            let textHeight = font.ascender + abs(font.descender)
            let yOffset = (bounds.height - textHeight) / 2 + abs(font.descender) - 2
            
            textLayer.frame = CGRect(x: 0, y: yOffset, width: bounds.width, height: textHeight)
        }
    }
    
    override func layout() {
        super.layout()
        
        // Check if we're showing the placeholder or image
        if imageLayer != nil {
            imageLayer?.frame = bounds
        } else {
            guard let font = textLayer.font as? NSFont else { return }
            
            let textHeight = font.ascender + abs(font.descender)
            let yOffset = (bounds.height - textHeight) / 2 + abs(font.descender) - 2
            
            textLayer.frame = CGRect(x: 0, y: yOffset, width: bounds.width, height: textHeight)
        }
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

