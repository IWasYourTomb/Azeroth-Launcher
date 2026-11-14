Azeroth Launcher

A native macOS launcher for managing and running multiple World of Warcraft game clients.

Azeroth Launcher aims to provide a convenient way to manage different WoW expansions, configure compatibility environments, and launch game clients on macOS.

Features

Game Management

* Manage multiple World of Warcraft installations.
* Support for Wrath of the Lich King.
* Support for Cataclysm.
* Support for Mists of Pandaria.
* Installation directory management.
* Game environment validation.

Graphics

* DXVK renderer.
* Metal renderer (MTLd3D).
* Per-edition renderer configuration.

Wine Integration

* Wine Runtime management.
* Shared Wine Runtime between installations.
* Independent Wine Prefixes for each game.
* Wine environment configuration.

Launch Configuration

* Custom launch arguments.
* Environment variables.
* DLL overrides.
* DXVK Async configuration.
* Wine debugging options.
* Virtual desktop configuration.

Additional Features

* Game diagnostics.
* Realm list management.
* Addon management.
* English and Russian localization.
* Light and dark appearance modes.
* Automatic application updates (Sparkle integration in progress).

Technology Stack

* Swift
* SwiftUI
* macOS
* Wine
* DXVK
* MoltenVK
* Apple Metal
* Sparkle

Requirements

* macOS.
* Xcode with Swift support.
* A compatible World of Warcraft game client.
* Wine Runtime.

Building

1. Clone or download the repository.
2. Open Azeroth Launcher.xcodeproj in Xcode.
3. Allow Swift Package Manager to resolve dependencies.
4. Select the Azeroth Launcher scheme.
5. Build and run the application.

Project Status

Azeroth Launcher is currently under active development.

The project is not yet considered production-ready. Features, architecture, and compatibility may change.

Disclaimer

Azeroth Launcher is an independent community project and is not affiliated with, endorsed by, or associated with Blizzard Entertainment.

World of Warcraft and all related trademarks are the property of Blizzard Entertainment.

The project does not include proprietary World of Warcraft game data.

Users are responsible for obtaining and using game files in accordance with applicable terms and laws.

License

License information will be added before public distribution.
