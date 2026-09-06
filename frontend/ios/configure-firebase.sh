#!/usr/bin/env bash
# Wires an iOS Firebase app into the Xcode project.
#
# Run this AFTER dropping GoogleService-Info.plist into ios/Runner/
# (Firebase console -> Add app -> iOS -> bundle id com.avneesh.movaraApp).
#
# It adds the URL scheme Google Sign-In needs to hand control back to the app.
# The file itself is not a secret (it ships inside every copy of the app), but
# it is gitignored to keep GitHub's secret scanner quiet.
set -euo pipefail
cd "$(dirname "$0")"

PLIST=Runner/GoogleService-Info.plist
INFO=Runner/Info.plist
PB=/usr/libexec/PlistBuddy

if [ ! -f "$PLIST" ]; then
  echo "error: $PLIST not found."
  echo "Download it from the Firebase console and put it in ios/Runner/ first."
  exit 1
fi

SCHEME=$($PB -c "Print :REVERSED_CLIENT_ID" "$PLIST" 2>/dev/null || true)
if [ -z "$SCHEME" ]; then
  echo "error: no REVERSED_CLIENT_ID in $PLIST."
  echo "Enable Google as a sign-in provider in Firebase, then re-download it."
  exit 1
fi

# Replace any scheme block we added before, so re-running is safe.
$PB -c "Delete :CFBundleURLTypes" "$INFO" 2>/dev/null || true
$PB -c "Add :CFBundleURLTypes array" "$INFO"
$PB -c "Add :CFBundleURLTypes:0 dict" "$INFO"
$PB -c "Add :CFBundleURLTypes:0:CFBundleTypeRole string Editor" "$INFO"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes array" "$INFO"
$PB -c "Add :CFBundleURLTypes:0:CFBundleURLSchemes:0 string $SCHEME" "$INFO"

plutil -lint "$INFO"
echo "Added Google Sign-In URL scheme: $SCHEME"

# Adding the file to ios/Runner/ is not enough: Xcode only copies what is
# listed in the target's resources build phase, so without this step Firebase
# fails to initialise at launch and the app shows the setup screen.
RUBY=/opt/homebrew/opt/ruby/bin/ruby
GEM_HOME=$(ls -d /opt/homebrew/Cellar/cocoapods/*/libexec 2>/dev/null | head -1)

if [ -x "$RUBY" ] && [ -n "$GEM_HOME" ]; then
  GEM_HOME="$GEM_HOME" "$RUBY" - <<'RB'
require 'xcodeproj'

project = Xcodeproj::Project.open('Runner.xcodeproj')
target  = project.targets.find { |t| t.name == 'Runner' }
group   = project.main_group.find_subpath('Runner', true)
name    = 'GoogleService-Info.plist'

ref = group.files.find { |f| f.path == name } ||
      group.new_reference(name)

unless target.resources_build_phase.files_references.include?(ref)
  target.resources_build_phase.add_file_reference(ref)
  puts "Added #{name} to the Runner target's resources."
else
  puts "#{name} was already in the Runner target's resources."
end

project.save
RB
else
  echo
  echo "warning: could not find the ruby that ships with CocoaPods, so"
  echo "$PLIST was NOT added to the Xcode target."
  echo "Open ios/Runner.xcworkspace and drag the file into the Runner group,"
  echo "ticking 'Copy items if needed' and the Runner target."
fi

