import UIKit
import SwiftUI

/// Rich Text Editor per la composizione email con formattazione completa
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    
    let placeholder: String
    
    func makeUIView(context: Context) -> UITextView {
        let textView = UITextView()
        textView.delegate = context.coordinator
        textView.isEditable = true
        textView.isScrollEnabled = true
        textView.font = .systemFont(ofSize: 16)
        textView.backgroundColor = .clear
        textView.textColor = .label
        textView.returnKeyType = .default
        textView.allowsEditingTextAttributes = true
        textView.dataDetectorTypes = [.link, .phoneNumber]
        
        // Configura toolbar con opzioni formattazione
        textView.inputAccessoryView = createToolbar(for: textView, coordinator: context.coordinator)
        
        // Placeholder styling
        updatePlaceholder(textView)
        
        return textView
    }
    
    func updateUIView(_ uiView: UITextView, context: Context) {
        if uiView.text != text {
            let selectedRange = uiView.selectedRange
            uiView.text = text
            uiView.selectedRange = selectedRange
        }
        
        updatePlaceholder(uiView)
        
        if isFirstResponder && !uiView.isFirstResponder {
            uiView.becomeFirstResponder()
        } else if !isFirstResponder && uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    class Coordinator: NSObject, UITextViewDelegate {
        let parent: RichTextEditor
        
        init(_ parent: RichTextEditor) {
            self.parent = parent
        }
        
        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
            parent.updatePlaceholder(textView)
        }
        
        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFirstResponder = true
        }
        
        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFirstResponder = false
        }
        
        // MARK: - Formatting Actions
        
        @objc func toggleBold(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyTextAttribute(.font, value: UIFont.boldSystemFont(ofSize: 16), textView: textView)
        }
        
        @objc func toggleItalic(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyTextAttribute(.font, value: UIFont.italicSystemFont(ofSize: 16), textView: textView)
        }
        
        @objc func toggleUnderline(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyTextAttribute(.underlineStyle, value: NSUnderlineStyle.single.rawValue, textView: textView)
        }
        
        @objc func changeTextColor(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            
            let colorPicker = UIColorPickerViewController()
            colorPicker.supportsAlpha = false
            colorPicker.delegate = self
            colorPicker.modalPresentationStyle = .popover
            colorPicker.popoverPresentationController?.barButtonItem = sender
            
            if let scene = textView.window?.windowScene,
               let rootViewController = scene.windows.first?.rootViewController {
                rootViewController.present(colorPicker, animated: true)
            }
        }
        
        @objc func insertLink(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            
            let alert = UIAlertController(title: "Inserisci Link", message: "Inserisci l'URL del link", preferredStyle: .alert)
            
            alert.addTextField { textField in
                textField.placeholder = "https://esempio.com"
                textField.keyboardType = .URL
            }
            
            let insertAction = UIAlertAction(title: "Inserisci", style: .default) { _ in
                guard let urlText = alert.textFields?.first?.text,
                      let url = URL(string: urlText) else { return }
                
                let selectedRange = textView.selectedRange
                let linkText = urlText
                let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
                
                if selectedRange.length > 0 {
                    attributedString.addAttribute(.link, value: url, range: selectedRange)
                } else {
                    let linkAttributedString = NSAttributedString(
                        string: linkText,
                        attributes: [.link: url, .font: UIFont.systemFont(ofSize: 16)]
                    )
                    attributedString.insert(linkAttributedString, at: selectedRange.location)
                }
                
                textView.attributedText = attributedString
                self.parent.text = textView.text
            }
            
            alert.addAction(insertAction)
            alert.addAction(UIAlertAction(title: "Annulla", style: .cancel))
            
            if let scene = textView.window?.windowScene,
               let rootViewController = scene.windows.first?.rootViewController {
                rootViewController.present(alert, animated: true)
            }
        }
        
        @objc func createList(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            
            let selectedRange = textView.selectedRange
            let text = textView.text ?? ""
            let lineStart = (text as NSString).lineRange(for: selectedRange).location
            
            let newText = "• "
            let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            attributedString.insert(NSAttributedString(string: newText), at: lineStart)
            
            textView.attributedText = attributedString
            self.parent.text = textView.text
        }
        
        @objc func alignLeft(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyParagraphAlignment(.left, textView: textView)
        }
        
        @objc func alignCenter(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyParagraphAlignment(.center, textView: textView)
        }
        
        @objc func alignRight(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            applyParagraphAlignment(.right, textView: textView)
        }
        
        // MARK: - Helper Methods
        
        private func applyTextAttribute(_ attribute: NSAttributedString.Key, value: Any, textView: UITextView) {
            let selectedRange = textView.selectedRange
            let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            if selectedRange.length > 0 {
                attributedString.addAttribute(attribute, value: value, range: selectedRange)
            } else {
                textView.typingAttributes[attribute] = value
            }
            
            textView.attributedText = attributedString
            parent.text = textView.text
        }
        
        private func applyParagraphAlignment(_ alignment: NSTextAlignment, textView: UITextView) {
            let selectedRange = textView.selectedRange
            let attributedString = NSMutableAttributedString(attributedString: textView.attributedText)
            
            let paragraphStyle = NSMutableParagraphStyle()
            paragraphStyle.alignment = alignment
            
            attributedString.addAttribute(.paragraphStyle, value: paragraphStyle, range: selectedRange)
            textView.attributedText = attributedString
            parent.text = textView.text
        }
        
        @objc func showFormattingMenu(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView,
                  let scene = textView.window?.windowScene,
                  let rootViewController = scene.windows.first?.rootViewController else { return }
            
            let alert = UIAlertController(title: "✨ Formattazione", message: "Scegli un'opzione", preferredStyle: .actionSheet)
            
            alert.addAction(UIAlertAction(title: "🎨 Colore Testo", style: .default) { _ in
                self.changeTextColor(sender)
            })
            
            alert.addAction(UIAlertAction(title: "🔗 Inserisci Link", style: .default) { _ in
                self.insertLink(sender)
            })
            
            alert.addAction(UIAlertAction(title: "• Lista", style: .default) { _ in
                self.createList(sender)
            })
            
            alert.addAction(UIAlertAction(title: "← Allinea Sinistra", style: .default) { _ in
                self.alignLeft(sender)
            })
            
            alert.addAction(UIAlertAction(title: "↔ Allinea Centro", style: .default) { _ in
                self.alignCenter(sender)
            })
            
            alert.addAction(UIAlertAction(title: "→ Allinea Destra", style: .default) { _ in
                self.alignRight(sender)
            })
            
            alert.addAction(UIAlertAction(title: "❌ Annulla", style: .cancel))
            
            if let popover = alert.popoverPresentationController {
                popover.barButtonItem = sender
            }
            
            rootViewController.present(alert, animated: true)
        }
        
        @objc func dismissKeyboard(_ sender: UIBarButtonItem) {
            guard let textView = sender.target as? UITextView else { return }
            textView.resignFirstResponder()
        }
    }
    
    // MARK: - Helper Functions
    
    private func updatePlaceholder(_ textView: UITextView) {
        if text.isEmpty {
            textView.text = placeholder
            textView.textColor = .placeholderText
        } else if textView.textColor == .placeholderText {
            textView.text = text
            textView.textColor = .label
        }
    }
    
    private func createToolbar(for textView: UITextView, coordinator: Coordinator) -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        
        // Pulsanti formattazione
        let boldButton = UIBarButtonItem(
            image: UIImage(systemName: "bold"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.toggleBold)
        )
        boldButton.target = textView
        
        let italicButton = UIBarButtonItem(
            image: UIImage(systemName: "italic"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.toggleItalic)
        )
        italicButton.target = textView
        
        let underlineButton = UIBarButtonItem(
            image: UIImage(systemName: "underline"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.toggleUnderline)
        )
        underlineButton.target = textView
        
        let colorButton = UIBarButtonItem(
            image: UIImage(systemName: "textformat.alt"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.changeTextColor)
        )
        colorButton.target = textView
        
        let linkButton = UIBarButtonItem(
            image: UIImage(systemName: "link"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.insertLink)
        )
        linkButton.target = textView
        
        let listButton = UIBarButtonItem(
            image: UIImage(systemName: "list.bullet"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.createList)
        )
        listButton.target = textView
        
        let alignLeftButton = UIBarButtonItem(
            image: UIImage(systemName: "text.alignleft"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.alignLeft)
        )
        alignLeftButton.target = textView
        
        let alignCenterButton = UIBarButtonItem(
            image: UIImage(systemName: "text.aligncenter"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.alignCenter)
        )
        alignCenterButton.target = textView
        
        let alignRightButton = UIBarButtonItem(
            image: UIImage(systemName: "text.alignright"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.alignRight)
        )
        alignRightButton.target = textView
        
        let flexSpace = UIBarButtonItem(barButtonSystemItem: .flexibleSpace, target: nil, action: nil)
        
        // Crea un menu compatto per opzioni avanzate
        let moreButton = UIBarButtonItem(
            image: UIImage(systemName: "ellipsis.circle"),
            style: .plain,
            target: coordinator,
            action: #selector(Coordinator.showFormattingMenu)
        )
        moreButton.target = textView
        
        let doneButton = UIBarButtonItem(
            barButtonSystemItem: .done,
            target: coordinator,
            action: #selector(Coordinator.dismissKeyboard)
        )
        doneButton.target = textView
        
        toolbar.items = [
            boldButton, italicButton, underlineButton,
            flexSpace,
            moreButton,
            flexSpace,
            doneButton
        ]
        
        return toolbar
    }
}

// MARK: - UIColorPickerViewControllerDelegate

extension RichTextEditor.Coordinator: UIColorPickerViewControllerDelegate {
    func colorPickerViewControllerDidSelectColor(_ viewController: UIColorPickerViewController) {
        guard let textView = viewController.popoverPresentationController?.barButtonItem?.target as? UITextView else { return }
        
        let selectedColor = viewController.selectedColor
        applyTextAttribute(.foregroundColor, value: selectedColor, textView: textView)
    }
}

// MARK: - Preview Provider

struct RichTextEditor_Previews: PreviewProvider {
    static var previews: some View {
        VStack {
            RichTextEditor(
                text: .constant("Testo di esempio con **formattazione**"),
                isFirstResponder: .constant(false),
                placeholder: "Scrivi il tuo messaggio..."
            )
            .frame(height: 300)
            .border(Color.gray, width: 1)
        }
        .padding()
    }
}