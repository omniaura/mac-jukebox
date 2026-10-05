cask "mac-jukebox" do
  version "0.0.0"
  sha256 "0000000000000000000000000000000000000000000000000000000000000000"

  url "https://github.com/omniaura/mac-jukebox/releases/download/v#{version}/Jukebox-#{version}.zip"
  name "Jukebox"
  desc "Menu bar music queue shared by agents and humans"
  homepage "https://github.com/omniaura/mac-jukebox"

  depends_on macos: :ventura

  app "Jukebox.app"
  binary "#{appdir}/Jukebox.app/Contents/MacOS/Jukebox", target: "jukebox"

  zap trash: [
    "~/.jukebox",
    "~/Library/Caches/com.omniaura.mac-jukebox",
    "~/Library/Preferences/com.omniaura.mac-jukebox.plist",
    "~/Library/Saved Application State/com.omniaura.mac-jukebox.savedState",
  ]

  caveats <<~EOS
    Try it:

      jukebox cue --shuffle --play ~/Music
      jukebox status

    The menu bar app starts itself on first use. To have it at login, add
    Jukebox in System Settings > General > Login Items.

    Help: https://github.com/omniaura/mac-jukebox
  EOS
end
