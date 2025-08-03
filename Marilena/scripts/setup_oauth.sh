#!/bin/bash

# 🔧 Script di Configurazione OAuth per Marilena
# Questo script aiuta a configurare e testare OAuth

echo "🚀 Configurazione OAuth per Marilena"
echo "======================================"

# Colori per output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Funzione per stampare messaggi colorati
print_status() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

print_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Verifica se siamo nella directory corretta
if [ ! -f "Marilena.xcodeproj/project.pbxproj" ]; then
    print_error "Script deve essere eseguito dalla directory root del progetto Marilena"
    exit 1
fi

print_status "Verifica ambiente di sviluppo..."

# Verifica Xcode
if ! command -v xcodebuild &> /dev/null; then
    print_error "Xcode non trovato. Installa Xcode Command Line Tools"
    exit 1
fi

# Verifica simulatore iPhone 16
if ! xcrun simctl list devices | grep -q "iPhone 16"; then
    print_warning "Simulatore iPhone 16 non trovato. Verifica che sia installato in Xcode"
fi

print_success "Ambiente di sviluppo verificato"

# Compila il progetto
print_status "Compilazione progetto..."
if xcodebuild -project Marilena.xcodeproj -scheme Marilena -destination 'platform=iOS Simulator,name=iPhone 16' build; then
    print_success "Progetto compilato con successo"
else
    print_error "Errore durante la compilazione"
    exit 1
fi

# Avvia simulatore
print_status "Avvio simulatore iPhone 16..."
xcrun simctl boot "iPhone 16" 2>/dev/null || true
open -a Simulator

print_success "Simulatore avviato"

# Mostra istruzioni per OAuth
echo ""
echo "🔧 CONFIGURAZIONE OAUTH RICHIESTA"
echo "================================"
echo ""
echo "Per risolvere l'errore 'OAuth access is restricted to the test users':"
echo ""
echo "1. Vai su Google Cloud Console:"
echo "   https://console.cloud.google.com/"
echo ""
echo "2. Seleziona il progetto: 774947872067-h5edpv1rgirar19mn240dnhd0sr3ml7o"
echo ""
echo "3. Vai su 'APIs & Services' > 'OAuth consent screen'"
echo ""
echo "4. Clicca 'EDIT APP'"
echo ""
echo "5. Nella sezione 'Test users', clicca 'ADD USERS'"
echo ""
echo "6. Aggiungi il tuo indirizzo email Gmail"
echo ""
echo "7. Clicca 'SAVE'"
echo ""
echo "8. Attendi fino a 24 ore per la sincronizzazione"
echo ""

# Test dell'app
print_status "Per testare l'app:"
echo "1. Apri Xcode"
echo "2. Apri il progetto Marilena.xcodeproj"
echo "3. Seleziona 'iPhone 16' come dispositivo"
echo "4. Clicca 'Run' (⌘+R)"
echo ""

print_success "Setup completato! Segui le istruzioni sopra per configurare OAuth" 