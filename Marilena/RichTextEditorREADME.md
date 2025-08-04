# 📝 Rich Text Editor

## 🎯 **Panoramica**

RichTextEditor è un editor di testo avanzato per la composizione email che offre funzionalità di formattazione complete, simili all'app Mail standard di iOS.

## ✨ **Caratteristiche Principali**

### **🎨 Formattazione Testo**
- **Grassetto** - `Bold` (`⌘B`)
- **Corsivo** - `Italic` (`⌘I`) 
- **Sottolineato** - `Underline` (`⌘U`)
- **Colore testo** - Picker colori integrato
- **Dimensioni** - Sistema font scale automatico

### **📐 Allineamento**
- **Sinistra** - Allineamento standard
- **Centro** - Centratura testo
- **Destra** - Allineamento destro

### **🔗 Elementi Avanzati**
- **Link** - Inserimento URL con dialog
- **Liste** - Liste puntate automatiche
- **Rilevamento automatico** - Link e numeri di telefono

### **🛠 Toolbar Integrata**
- **Toolbar accessoria** - Sempre visibile quando si digita
- **Pulsanti rapidi** - Formattazione con un tap
- **Design iOS nativo** - Stile coerente con l'ecosistema

## 🔧 **Implementazione Tecnica**

### **Architettura**
```swift
struct RichTextEditor: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFirstResponder: Bool
    let placeholder: String
}
```

### **UITextView Sottostante**
- **Editing attributi** - `allowsEditingTextAttributes = true`
- **Data detection** - Link e telefoni automatici
- **Input accessory** - Toolbar personalizzata
- **Delegate pattern** - Gestione cambiamenti in tempo reale

### **Coordinator Pattern**
```swift
class Coordinator: NSObject, UITextViewDelegate {
    // Gestione formattazione
    @objc func toggleBold(_ sender: UIBarButtonItem)
    @objc func toggleItalic(_ sender: UIBarButtonItem)
    @objc func changeTextColor(_ sender: UIBarButtonItem)
    @objc func insertLink(_ sender: UIBarButtonItem)
}
```

## 🎨 **UI/UX Features**

### **Interfaccia Utente**
- **Toolbar scorrevole** - 9 pulsanti di formattazione
- **Feedback visivo** - Stati attivi/inattivi
- **Placeholder** - Supporto nativo con styling
- **Auto-focus** - Gestione focus programmatico

### **Formattazione Intelligente**
- **Selezione testo** - Applica formattazione al testo selezionato
- **Typing attributes** - Formattazione per testo nuovo
- **Persistent styling** - Mantiene formattazione tra sessioni
- **Mix formatting** - Supporto formattazione mista

### **Gestione Colori**
- **UIColorPickerViewController** - Picker nativo iOS 14+
- **Popover presentation** - Su iPad e landscape
- **Alpha support** - Trasparenza disabilitata per testo
- **System colors** - Supporto colori dinamici

## 📱 **Integrazione ComposeEmailView**

### **State Management**
```swift
@State private var richTextEditorFocused = false
```

### **Layout Integration**
```swift
RichTextEditor(
    text: $emailBody,
    isFirstResponder: $richTextEditorFocused,
    placeholder: "Componi il tuo messaggio..."
)
.frame(minHeight: 200)
```

### **Toolbar Actions**
- **Bold/Italic/Underline** - Pulsanti rapidi in nav bar
- **Sync con toolbar** - Doppi controlli per UX ottimale
- **Conditional visibility** - Appaiono solo quando editor è attivo

## 🔄 **Flusso Utilizzatore**

```
1. 📱 Utente tocca area email body
   ↓
2. ⌨️ Keyboard appare con toolbar
   ↓  
3. 🎨 Utente seleziona testo o posiziona cursore
   ↓
4. 🔧 Tap su pulsante formattazione
   ↓
5. ✅ Formattazione applicata istantaneamente
   ↓
6. 💾 Stato salvato automaticamente
```

## 🎯 **Benefici UX**

| Feature | Prima | Dopo | Miglioramento |
|---------|-------|------|---------------|
| Editor | TextEditor base | RichTextEditor | **Formattazione completa** |
| Toolbar | Nessuna | 9 strumenti | **Professional editing** |
| Link | Manuale | Auto-detection + inserimento | **Intelligente** |
| Colori | Nessun supporto | Color picker | **Personalizzazione** |
| Mobile UX | Base | Toolbar accessoria | **Ottimizzato mobile** |

## 🚀 **Performance**

- **Rendering** - UITextView nativo (performance ottimale)
- **Memory** - Gestione automatica attributed strings
- **Smooth scrolling** - Nessun lag con testi lunghi
- **Battery** - Ottimizzato per efficienza energetica

## 🔧 **Personalizzazione**

### **Estendibilità**
```swift
// Aggiungere nuovi pulsanti toolbar
let newButton = UIBarButtonItem(
    image: UIImage(systemName: "custom.icon"),
    style: .plain,
    target: coordinator,
    action: #selector(Coordinator.customAction)
)
```

### **Styling**
```swift
// Personalizzare font e colori
textView.font = .systemFont(ofSize: 16)
textView.textColor = .label
textView.backgroundColor = .clear
```

## 📋 **Compatibilità**

- **iOS 14.0+** - UIColorPickerViewController
- **SwiftUI 2.0+** - UIViewRepresentable
- **iPad** - Supporto popover completo
- **iPhone** - Keyboard toolbar ottimizzata
- **Accessibility** - VoiceOver ready

## 🎉 **Risultato**

L'app ora offre un'esperienza di composizione email **professionale e ricca** con tutti gli strumenti di formattazione necessari, mantenendo la semplicità e l'efficienza dell'interfaccia nativa iOS.