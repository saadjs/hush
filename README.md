# Hush

An ultra-minimal native Safari content blocker for iPhone, iPad, and Mac. Its only purpose is to block ads.

## Privacy

Hush collects, stores, and transmits no data. It contains no analytics, accounts, advertising, networking code, or JavaScript page injection. Safari compiles and applies the bundled declarative rules.

Rules are bundled into each release. The installed app never downloads rules or makes network requests.

## Build

Requirements: Xcode 26 and [XcodeGen](https://github.com/yonaskolb/XcodeGen).

```sh
xcodegen generate
open Hush.xcodeproj
```

The generated project provides `Hush-iOS` and `Hush-macOS` schemes. Simulator builds require no signing configuration. To run on a device or create an archive, create a local signing configuration and set it to your Apple Developer Team ID:

```sh
cp Config/Signing.local.xcconfig.example Config/Signing.local.xcconfig
```

`Config/Signing.local.xcconfig` is ignored by Git. You may also need to use bundle identifiers registered to your developer account.

Command-line checks:

```sh
xcodebuild -project Hush.xcodeproj -scheme Hush-iOS \
  -sdk iphonesimulator CODE_SIGNING_ALLOWED=NO build
xcodebuild -project Hush.xcodeproj -scheme Hush-macOS \
  CODE_SIGNING_ALLOWED=NO build
```

## Rules

The bundled rules are generated from EasyList and uBlock Origin's ad filters:

```sh
./scripts/update-rules
```

Third-party filter data retains its own license; see `THIRD_PARTY_NOTICES.md`. Hush's original source code is MIT-licensed.

## Principles

- Block ads only—not cookie notices, social widgets, or unrelated content.
- No runtime network access.
- No browsing or page-content access.
- No third-party runtime dependencies.
- Deterministic, reviewable rule generation.
- Conservative exceptions when a rule breaks a site.
