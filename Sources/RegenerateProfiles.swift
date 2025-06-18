import Foundation
@preconcurrency import AppStoreConnect_Swift_SDK
import ArgumentParser

enum ProfileType: String, EnumerableFlag {
  case development, production
}

struct RegenerateProfilesCommand: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    commandName: "regenerate",
    abstract: "Regenerates development and distribution provisioning profiles."
  )

  @Option(
    name: [.customLong("out-dir")],
    help: "Directory where to save the generated profiles."
  )
  var outputDirectory: String

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

  @Option(
    name: [.customLong("profile-prefix")],
    help: "Prefix for profiles to regenerate"
  )
  var profilePrefix: String

  @Flag(
    help: "Profile type platform."
  )
  var profileType: ProfileType = .development

  mutating func run() async throws {
    let configuration = try APIConfiguration(
      issuerID: issuerID,
      privateKeyID: keyID,
      privateKeyURL: URL(fileURLWithPath: authKey)
    )

    let provider = APIProvider(configuration: configuration)

    let allDevicesRequest = APIEndpoint.v1.devices.get(
      parameters: .init(
        filterPlatform: [.macOs, .ios],
        filterStatus: [.enabled],
        limit: 200
      )
    )

    let allDevices: [Device]

    if profileType == .development {
      allDevices = try await provider.request(allDevicesRequest).data.filter {
        $0.attributes?.status == .enabled
      }
    } else {
      allDevices = []
    }

    let certificatesRequest = APIEndpoint.v1.certificates.get(
      parameters: .init(
        limit: 200
      )
    )

    let provisioningProfilesRequest = APIEndpoint.v1.profiles.get(
      parameters: .init(
        limit: 200,
        include: [.certificates, .bundleID]
      )
    )

    let profiles = try await provider.request(provisioningProfilesRequest).data

    let outputURL = URL(fileURLWithPath: outputDirectory)

    let fileURLs = try FileManager.default.contentsOfDirectory(
      at: outputURL,
      includingPropertiesForKeys: nil,
      options: .skipsHiddenFiles
    )

    for fileURL in fileURLs {
      if ["mobileprovision", "provisionprofile"].contains(fileURL.pathExtension) {
        try FileManager.default.removeItem(at: fileURL)
      }
    }

    for profile in profiles {
      guard let profileName = profile.attributes?.name else { continue }
      guard profileName.starts(with: profilePrefix) else { continue }
      guard let bundleIDID = profile.relationships?.bundleID?.data?.id else { continue }
      guard let certificateID = profile.relationships?.certificates?.data?.first?.id else { continue }
      guard let currentProfileType = profile.attributes?.profileType else { continue }

      let newProfileType: ProfileCreateRequest.Data.Attributes.ProfileType
      let devicesToLink: [Device]
      let profileExtension: String

      switch (profileType, currentProfileType) {
      case (.development, .iosAppDevelopment):
        newProfileType = .iosAppDevelopment
        devicesToLink = allDevices
        profileExtension = "mobileprovision"
      case (.development, .macCatalystAppDevelopment):
        newProfileType = .macCatalystAppDevelopment
        devicesToLink = allDevices.filter { $0.attributes?.platform == .macOs }
        profileExtension = "provisionprofile"
      case (.production, .iosAppStore):
        newProfileType = .iosAppStore
        devicesToLink = []
        profileExtension = "mobileprovision"
      case (.production, .macCatalystAppStore):
        newProfileType = .macCatalystAppStore
        devicesToLink = []
        profileExtension = "provisionprofile"
      case (.production, .macCatalystAppDirect):
        newProfileType = .macCatalystAppDirect
        devicesToLink = []
        profileExtension = "provisionprofile"
      default:
        continue
      }

      let deleteRequest = APIEndpoint.v1.profiles.id(profile.id).delete
      try await provider.request(deleteRequest)

      let createRequest = APIEndpoint.v1.profiles.post(
        ProfileCreateRequest(
          data: .init(
            type: .profiles,
            attributes: .init(
              name: profileName,
              profileType: newProfileType
            ),
            relationships: .init(
              bundleID: .init(
                data: .init(type: .bundleIDs, id: bundleIDID)
              ),
              devices: .init(
                data: devicesToLink.map {
                  .init(type: .devices, id: $0.id)
                }
              ),
              certificates: .init(
                data: [
                  .init(type: .certificates, id: certificateID)
                ]
              )
            )
          )
        )
      )

      print("Deleting \(profileName)...")

      let newProfile = try await provider.request(createRequest).data

      guard
        let newProfileContent = newProfile.attributes?.profileContent,
        let decodedData = Data(base64Encoded: newProfileContent)
      else {
        continue
      }

      try decodedData.write(
        to: outputURL.appending(path: "\(profileName).\(profileExtension)")
      )
    }
  }
}
