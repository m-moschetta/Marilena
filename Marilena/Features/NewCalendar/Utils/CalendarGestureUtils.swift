//
//  CalendarGestureUtils.swift
//  Marilena
//
//  Created by AI Assistant
//  Copyright © 2024. All rights reserved.
//

import SwiftUI
import UIKit

/// Utilità per gesture e animazioni del calendario
public class CalendarGestureUtils {
    
    // MARK: - Animation Configurations
    
    public static let navigationAnimation = Animation.easeInOut(duration: 0.3)
    public static let pinchAnimation = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.8)
    public static let eventDragAnimation = Animation.easeInOut(duration: 0.2)
    public static let viewModeAnimation = Animation.easeInOut(duration: 0.25)
    public static let eventCreationAnimation = Animation.easeInOut(duration: 0.1)
    
    // MARK: - Haptic Feedback
    
    /// Feedback per navigazione tra periodi
    public static func navigationFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Feedback per cambio vista
    public static func viewChangeFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Feedback per inizio creazione evento
    public static func eventCreationStartFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Feedback per completamento evento
    public static func eventCreationCompleteFeedback(success: Bool) {
        let notification = UINotificationFeedbackGenerator()
        notification.notificationOccurred(success ? .success : .error)
    }
    
    /// Feedback per drag evento
    public static func eventDragFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    /// Feedback per pinch-to-zoom
    public static func pinchFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred(intensity: 0.3)
    }
    
    /// Feedback per double tap
    public static func doubleTapFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }
    
    /// Feedback per refresh
    public static func refreshFeedback() {
        let impact = UIImpactFeedbackGenerator(style: .light)
        impact.impactOccurred()
    }
    
    // MARK: - Gesture Recognition Utilities
    
    /// Verifica se un gesture è principalmente orizzontale
    public static func isHorizontalGesture(_ translation: CGSize, threshold: CGFloat = 50) -> Bool {
        return abs(translation.width) > abs(translation.height) && abs(translation.width) > threshold
    }
    
    /// Verifica se un gesture è principalmente verticale
    public static func isVerticalGesture(_ translation: CGSize, threshold: CGFloat = 50) -> Bool {
        return abs(translation.height) > abs(translation.width) && abs(translation.height) > threshold
    }
    
    /// Analizza un gesto per determinare se è un swipe orizzontale valido
    public static func isValidHorizontalSwipe(_ translation: CGSize, velocity: CGSize? = nil) -> Bool {
        let h = abs(translation.width)
        let v = abs(translation.height)
        
        return h >= HorizontalSwipeParams.minimumDistance &&
               h >= v * HorizontalSwipeParams.horizontalToVerticalRatio &&
               v <= HorizontalSwipeParams.maxVerticalMovement
    }
    
    /// Analizza un gesto per determinare se è uno scroll verticale valido
    public static func isValidVerticalScroll(_ translation: CGSize, velocity: CGSize? = nil) -> Bool {
        let h = abs(translation.width)
        let v = abs(translation.height)
        
        return v >= VerticalScrollParams.minimumDistance &&
               v >= h * VerticalScrollParams.verticalToHorizontalRatio &&
               h <= VerticalScrollParams.maxHorizontalMovement
    }
    
    /// Determina il tipo di gesto basandosi sui parametri
    public static func analyzeGesture(_ translation: CGSize, velocity: CGSize? = nil) -> GestureType {
        if isValidHorizontalSwipe(translation, velocity: velocity) {
            return .horizontalSwipe(translation.width > 0 ? .right : .left)
        } else if isValidVerticalScroll(translation, velocity: velocity) {
            return .verticalScroll(translation.height > 0 ? .down : .up)
        } else {
            return .ambiguous
        }
    }
}

// MARK: - Gesture Analysis Types

public enum GestureType {
    case horizontalSwipe(SwipeDirection)
    case verticalScroll(ScrollDirection)
    case ambiguous
}

public enum SwipeDirection {
    case left, right
}

public enum ScrollDirection {
    case up, down
}

// MARK: - Extensions continued

extension CalendarGestureUtils {
    /// Calcola l'ora basandosi sulla posizione Y
    public static func hourFromYPosition(_ yPosition: CGFloat, hourHeight: CGFloat) -> (hour: Int, minute: Int) {
        let hourFloat = max(0, min(23.999, yPosition / hourHeight))
        let hour = Int(hourFloat)
        let minute = Int((hourFloat - CGFloat(hour)) * 60)
        return (hour, minute)
    }
    
    /// Snappa i minuti alla griglia più vicina (default 5 minuti)
    public static func snapToMinuteGrid(_ minute: Int, gridSize: Int = 5) -> Int {
        return (minute / gridSize) * gridSize
    }
    
    /// Calcola la durata minima per un evento
    public static func minimumEventDuration() -> TimeInterval {
        return 30 * 60 // 30 minuti
    }
    
    // MARK: - Visual Effects
    
    /// Colore per l'overlay di creazione evento
    public static var eventCreationOverlayColor: Color {
        return Color.blue.opacity(0.7)
    }
    
    /// Colore per il bordo durante il drag
    public static var dragBorderColor: Color {
        return Color.white.opacity(0.5)
    }
    
    /// Ombra per eventi durante il drag
    public static func dragShadow() -> some View {
        return Color.black.opacity(0.3)
    }
    
    /// Scala per eventi durante il drag
    public static let dragScale: CGFloat = 1.05
    
    // MARK: - Gesture Recognition Constants
    
    /// Parametri per il riconoscimento dei gesti orizzontali (swipe)
    public struct HorizontalSwipeParams {
        public static let minimumDistance: CGFloat = 80
        public static let minimumSpeed: CGFloat = 100
        public static let horizontalToVerticalRatio: CGFloat = 3.0 // h/v deve essere >= 3
        public static let maxVerticalMovement: CGFloat = 30
    }
    
    /// Parametri per il riconoscimento dei gesti verticali (scroll)
    public struct VerticalScrollParams {
        public static let minimumDistance: CGFloat = 10
        public static let verticalToHorizontalRatio: CGFloat = 2.0 // v/h deve essere >= 2
        public static let maxHorizontalMovement: CGFloat = 20
    }
    
    /// Parametri per long press e drag
    public struct EventCreationParams {
        public static let longPressMinimumDuration: TimeInterval = 0.7
        public static let dragMinimumDistance: CGFloat = 0
        public static let snapToMinutes: Int = 5
    }
    
    // MARK: - Timing Constants
    
    public static let longPressMinimumDuration: TimeInterval = EventCreationParams.longPressMinimumDuration
    public static let doubleTapMaxInterval: TimeInterval = 0.3
    public static let refreshSimulationDelay: UInt64 = 500_000_000 // 0.5 secondi in nanoseconds
    
    // MARK: - Layout Constants
    
    public static let hourLabelWidth: CGFloat = 45
    public static let hourLabelPadding: CGFloat = 8
    public static let eventPadding: CGFloat = 4
    public static let eventCornerRadius: CGFloat = 8
    public static let minEventHeight: CGFloat = 30
    
    // MARK: - Zoom Constants
    
    public static let minHourHeight: CGFloat = 30.0
    public static let maxHourHeight: CGFloat = 120.0
    public static let defaultHourHeight: CGFloat = 60.0
    public static let pinchZoomThreshold: CGFloat = 0.1
}

// MARK: - Extensions

extension Animation {
    /// Animazione standard per le gesture del calendario
    static let calendarGesture = Animation.easeInOut(duration: 0.2)
    
    /// Animazione per il pinch-to-zoom fluido
    static let smoothPinch = Animation.interactiveSpring(
        response: 0.3,
        dampingFraction: 0.8,
        blendDuration: 0.1
    )
    
    /// Animazione per la navigazione tra viste
    static let viewTransition = Animation.easeInOut(duration: 0.3)
}

extension Color {
    /// Colore per gli indicatori di gesture
    static let gestureIndicator = Color.blue.opacity(0.6)
    
    /// Colore per gli overlay temporanei
    static let temporaryOverlay = Color.black.opacity(0.1)
}