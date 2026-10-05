VERSION ?= 0.0.0-dev
APP     := build/Jukebox.app

.PHONY: build test release app install uninstall clean

build:
	swift build

test:
	swift test

release:
	swift build -c release --arch arm64 --arch x86_64

# Assemble Jukebox.app (ad-hoc signed; the release workflow signs with Developer ID).
app: release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/jukebox" $(APP)/Contents/MacOS/Jukebox
	VERSION=$(VERSION) ./scripts/generate-info-plist.sh > $(APP)/Contents/Info.plist
	codesign --force --sign - $(APP)

install: app
	rm -rf /Applications/Jukebox.app
	cp -R $(APP) /Applications/
	ln -sf /Applications/Jukebox.app/Contents/MacOS/Jukebox /opt/homebrew/bin/jukebox

uninstall:
	-/Applications/Jukebox.app/Contents/MacOS/Jukebox quit
	rm -rf /Applications/Jukebox.app /opt/homebrew/bin/jukebox ~/.jukebox

clean:
	rm -rf .build build
