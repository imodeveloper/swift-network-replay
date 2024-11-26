# Swift Network Replay

**SwiftNetworkReplay** is a Swift package for recording and replaying network requests. It simplifies debugging and testing of network-dependent features in iOS apps by intercepting HTTP/HTTPS traffic, recording API responses, and replaying them later.

## Features

- Intercept and record network requests during runtime.
- Replay recorded responses without live API calls.
- Easy configuration for switching between recording and replay modes.
- Fully asynchronous with modern Swift concurrency (`async/await`).
- Customizable file naming and directory management for recorded sessions.

## Installation

Add **SwiftNetworkReplay** to your project using Swift Package Manager (SPM):

1. In Xcode, go to **File > Add Packages...**.
2. Enter the repository URL for this package.
3. Select your target and add the package.

## Usage

### Start Interception and Recording/Replaying

Initialize the interceptor in either replay or recording mode using `start`:

```swift
import SwiftNetworkReplay

// Start in replay mode
SwiftNetworkReplay.start(
    record: false // Set to true to enable recording
)
```

- `record`: Set to `true` for recording mode or `false` for replay mode.

### Stop Interception

To stop intercepting requests, call `stop`:

```swift
SwiftNetworkReplay.stop()
```

### Remove Recording Directory

Clean up all recorded sessions with `removeRecordingDirectory`:

```swift
do {
    try SwiftNetworkReplay.removeRecordingDirectory()
} catch {
    print("Failed to remove directory: \(error.localizedDescription)")
}
```

## Example Workflow

1. **Record Network Requests**:
   ```swift
   SwiftNetworkReplay.start(
       record: true
   )
   ```

2. Perform actions in your app to generate network requests.

3. **Stop Recording**:
   ```swift
   SwiftNetworkReplay.stop()
   ```

4. **Replay Recorded Responses**:
   ```swift
   SwiftNetworkReplay.start(
       record: false
   )
   ```

## Requirements

- **iOS**: 16.0+
- **Swift**: 5.8+
