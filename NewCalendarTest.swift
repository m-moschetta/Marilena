//
//  NewCalendarTest.swift
//  Test file for New Calendar compilation
//

import Foundation
import SwiftUI

// Test basic compilation of new calendar types
let testEvent = NewCalendarEvent(title: "Test Event", startDate: Date(), endDate: Date().addingTimeInterval(3600))
let testViewMode = NewCalendarViewMode.month
let testAttendeeStatus = NewAttendeeStatus.pending
let testPriority = NewPriority.none
let testEventStatus = NewEventStatus.confirmed
let testColor = CodableColor(.blue)

print("✅ New Calendar types compile successfully!")
print("✅ CodableColor works correctly!")
print("✅ Event created: \(testEvent.title)")
print("✅ Color: \(testColor.color)")