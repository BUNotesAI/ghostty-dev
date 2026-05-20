#!/usr/bin/env nu

# Build the macOS Ghostty app using xcodebuild with a clean environment
# to avoid Nix shell interference (NIX_LDFLAGS, NIX_CFLAGS_COMPILE, etc.).

def main [
    --scheme: string = "Ghostty Dev"   # Xcode scheme (Ghostty Dev, Ghostty-iOS, DockTilePlugin)
    --configuration: string = "Release" # Build configuration (Debug, Release, ReleaseLocal)
    --action: string = "build"         # xcodebuild action (build, test, clean, etc.)
] {
    let project = ($env.FILE_PWD | path join "Ghostty Dev.xcodeproj")
    let build_dir = ($env.FILE_PWD | path join "build")

    # Skip UI tests for CLI-based invocations because it requires
    # special permissions.
    let skip_testing = if $action == "test" {
        [-skip-testing GhosttyUITests]
    } else {
        []
    }

    (^env -i
        $"HOME=($env.HOME)"
        "PATH=/usr/bin:/bin:/usr/sbin:/sbin"
        xcodebuild
        -project $project
        -scheme $scheme
        -configuration $configuration
        $"SYMROOT=($build_dir)"
        ...$skip_testing
        $action)
}
