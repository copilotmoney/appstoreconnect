import ArgumentParser

@main
struct AppStoreConnect: AsyncParsableCommand {
  static let configuration = CommandConfiguration(
    abstract: "AppStoreConnect API utility.",
    subcommands: [RegenerateProfilesCommand.self, RegisterDeviceCommand.self],
    defaultSubcommand: RegenerateProfilesCommand.self
  )
}

