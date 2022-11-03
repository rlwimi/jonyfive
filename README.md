# ⚠️ Archived
This tool is currently broken. For starters, the XPaths are hopelessly out of date.

This tool was originally very hastily slapped together to the point of working, in support of [`my fork`](https://github.com/rlwimi/wwdc-session-transcripts) of [`ASCIIwwdc/wwdc-session-transcripts`](https://github.com/ASCIIwwdc/wwdc-session-transcripts) while that repo seemed abandoned, both in support of [`rlwimi/major-input`](https://github.com/rlwimi/major-input). 

I still see value in a tool like this. If I revive the project, I imagine moving to [`apple/swift-argument-parser`](https://github.com/apple/swift-argument-parser) and [Foundation's XML/XPath support](https://developer.apple.com/documentation/foundation/archives_and_serialization/xml_processing_and_modeling).

---

# jonyfive

CLI tool for doing useful things after scraping WWDC session metadata

## Usage

Once you are up and running, use `-h`/`--help` flags for more information about the interface and functionality.

## Getting Started

1. Follow the installation instructions for dependency [Kanna](https://github.com/tid-kijyun/Kanna), specifically the instructions for Swift 4 via Swift Package Manager.
1. Run `swift package update`.
1. Optionally run `swift package generate-xcodeproj` if you're interested in working with the implementation in Xcode.
1. Run `swift build`.
1. Find executable at `.build/debug/jonyfive`.

## Warning

Web scraping is fragile by nature, and small changes to the page HTML naming or structure can break this tool. It may be you that finds this breakage first–please file an issue.

## Thanks

Based on [Guaka](https://github.com/nsomar/Guaka) and [Kanna](https://github.com/tid-kijyun/Kanna).

## License

This tool is provided under the terms of the [LICENSE](https://github.com/rlwimi/jonyfive/blob/master/LICENSE).

All content copyright © 2010 – 2017 Apple Inc. All rights reserved.
