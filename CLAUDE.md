# Claude Configuration

## Build Settings
- Always use iPhone 16 simulator for iOS builds instead of iPhone 15
- Default build command: `xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" build`

## Test Settings  
- Use iPhone 16 simulator for running tests
- Test command: `xcodebuild -workspace Marilena.xcworkspace -scheme Marilena-iOS -destination "platform=iOS Simulator,name=iPhone 16" test`

## Development Notes
- Project uses SwiftUI and requires iOS 26.0 deployment target
- Main workspace file: Marilena.xcworkspace (not .xcodeproj)
- Scheme name: Marilena-iOS