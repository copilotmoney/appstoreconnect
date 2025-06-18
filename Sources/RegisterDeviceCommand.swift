import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK
import ArgumentParser

enum DevicePlatform: String, EnumerableFlag {
  case macos, ios
}

struct RegisterDeviceCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "register",
    abstract: "Register development device"
  )

  @Flag(
    help: "Device platform."
  )
  var platform: DevicePlatform

  @Option(
    name: [.customLong("name")],
    help: "Device name."
  )
  var name: String

  @Option(
    name: [.customLong("device-id")],
    help: "Device identifier."
  )
  var deviceID: String

  @Option(
    name: [.customLong("issuer-id")],
    help: "Issuer ID for API auth key."
  )
  var issuerID: String

  @Option(
    name: [.customLong("key-id")],
    help: "Key ID for API auth key."
  )
  var keyID: String

  @Option(
    name: [.customLong("auth-key")],
    help: "Path for API auth key."
  )
  var authKey: String

  mutating func run() async throws {
    let configuration = try APIConfiguration(
      issuerID: issuerID,
      privateKeyID: keyID,
      privateKeyURL: URL(fileURLWithPath: authKey)
    )

    let provider = APIProvider(configuration: configuration)

    let devicePlatform: BundleIDPlatform
    switch platform {
    case .macos:
      devicePlatform = .macOs
    case .ios:
      devicePlatform = .ios
    }

    let deviceRegisterRequest = APIEndpoint.v1.devices.post(
      DeviceCreateRequest(
        data: .init(
          type: .devices,
          attributes: .init(
            name: name,
            platform: devicePlatform,
            udid: deviceID
          )
        )
      )
    )

    _ = try await provider.request(deviceRegisterRequest)
    print("Device \(name) [\(deviceID)] registered successfully.")
  }
}
