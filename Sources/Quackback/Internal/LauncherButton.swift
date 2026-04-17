#if canImport(UIKit)
import UIKit

final class LauncherButton: UIButton {
    private let position: QuackbackPosition
    private var isOpen = false
    private let size: CGFloat = 48
    private let inset: CGFloat = 24
    private let iconSize: CGFloat = 28

    private let chatIcon = UIImageView()
    private let closeIcon = UIImageView()

    init(position: QuackbackPosition, color: UIColor, foreground: UIColor) {
        self.position = position; super.init(frame: .zero)
        backgroundColor = color; layer.cornerRadius = size / 2
        layer.shadowColor = UIColor.black.cgColor; layer.shadowOffset = CGSize(width: 0, height: 4)
        layer.shadowOpacity = 0.15; layer.shadowRadius = 6
        // Hidden until the server theme is applied (or a fallback timer elapses),
        // to avoid a flash of the default color before the brand color lands.
        alpha = 0
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([widthAnchor.constraint(equalToConstant: size), heightAnchor.constraint(equalToConstant: size)])

        let chatImage = UIImage(systemName: "bubble.left.fill")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .medium))
            .withTintColor(foreground, renderingMode: .alwaysOriginal)
        chatIcon.image = chatImage
        chatIcon.contentMode = .scaleAspectFit
        chatIcon.translatesAutoresizingMaskIntoConstraints = false
        chatIcon.alpha = 1
        addSubview(chatIcon)

        let closeImage = UIImage(systemName: "xmark")?
            .withConfiguration(UIImage.SymbolConfiguration(pointSize: 20, weight: .bold))
            .withTintColor(foreground, renderingMode: .alwaysOriginal)
        closeIcon.image = closeImage
        closeIcon.contentMode = .scaleAspectFit
        closeIcon.translatesAutoresizingMaskIntoConstraints = false
        closeIcon.alpha = 0
        closeIcon.transform = CGAffineTransform(rotationAngle: -.pi / 2)
        addSubview(closeIcon)

        for icon in [chatIcon, closeIcon] {
            NSLayoutConstraint.activate([
                icon.centerXAnchor.constraint(equalTo: centerXAnchor),
                icon.centerYAnchor.constraint(equalTo: centerYAnchor),
                icon.widthAnchor.constraint(equalToConstant: iconSize),
                icon.heightAnchor.constraint(equalToConstant: iconSize),
            ])
        }
    }
    @available(*, unavailable) required init?(coder: NSCoder) { fatalError() }

    private var isRevealed = false
    /// Fade the launcher in. Safe to call multiple times; only the first call animates.
    func reveal() {
        guard !isRevealed else { return }
        isRevealed = true
        UIView.animate(withDuration: 0.2) { self.alpha = 1 }
    }

    func install(in window: UIWindow) {
        window.addSubview(self)
        let guide = window.safeAreaLayoutGuide
        var constraints = [bottomAnchor.constraint(equalTo: guide.bottomAnchor, constant: -inset)]
        switch position {
        case .bottomRight: constraints.append(trailingAnchor.constraint(equalTo: guide.trailingAnchor, constant: -inset))
        case .bottomLeft: constraints.append(leadingAnchor.constraint(equalTo: guide.leadingAnchor, constant: inset))
        }
        NSLayoutConstraint.activate(constraints)
    }

    func setOpen(_ open: Bool) {
        guard open != isOpen else { return }; isOpen = open
        let duration: TimeInterval = 0.22
        let damping: CGFloat = 0.65

        UIView.animate(withDuration: duration, delay: 0, usingSpringWithDamping: damping, initialSpringVelocity: 0, options: []) {
            if open {
                self.chatIcon.alpha = 0
                self.chatIcon.transform = CGAffineTransform(rotationAngle: .pi / 2)
                self.closeIcon.alpha = 1
                self.closeIcon.transform = .identity
            } else {
                self.chatIcon.alpha = 1
                self.chatIcon.transform = .identity
                self.closeIcon.alpha = 0
                self.closeIcon.transform = CGAffineTransform(rotationAngle: -.pi / 2)
            }
        }
    }

    // MARK: - Touch feedback

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesBegan(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.transform = CGAffineTransform(scaleX: 1.1, y: 1.1) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesEnded(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.transform = .identity }
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
        super.touchesCancelled(touches, with: event)
        UIView.animate(withDuration: 0.1) { self.transform = .identity }
    }
}
#endif
