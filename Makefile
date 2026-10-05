VERSION ?= 0.0.0-dev
APP     := build/Jukebox.app
# Prefer the Developer ID certificate when it is in the keychain: a stable signing identity
# means macOS remembers the Removable Volumes permission across rebuilds. Falls back to ad-hoc.
SIGN_ID ?= $(shell security find-identity -v -p codesigning 2>/dev/null | grep "Developer ID Application" | head -1 | awk -F '"' '{print $$2}')

.PHONY: build test release app install uninstall clean

build:
	swift build

test:
	swift test

release:
	swift build -c release --arch arm64 --arch x86_64

# Assemble Jukebox.app (Developer ID signed if available, else ad-hoc; the release workflow also notarizes).
app: release
	rm -rf $(APP)
	mkdir -p $(APP)/Contents/MacOS $(APP)/Contents/Resources
	cp "$$(swift build -c release --arch arm64 --arch x86_64 --show-bin-path)/jukebox" $(APP)/Contents/MacOS/Jukebox
	VERSION=$(VERSION) ./scripts/generate-info-plist.sh > $(APP)/Contents/Info.plist
	codesign --force --sign "$(if $(SIGN_ID),$(SIGN_ID),-)" $(if $(SIGN_ID),--options runtime) $(APP)

install: app
	rm -rf /Applications/Jukebox.app
	cp -R $(APP) /Applications/
	ln -sf /Applications/Jukebox.app/Contents/MacOS/Jukebox /opt/homebrew/bin/jukebox

uninstall:
	-/Applications/Jukebox.app/Contents/MacOS/Jukebox quit
	rm -rf /Applications/Jukebox.app /opt/homebrew/bin/jukebox ~/.jukebox

clean:
	rm -rf .build build
