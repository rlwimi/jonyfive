import PackageDescription
let package = Package(
  name: "jonyfive",
  dependencies: [
    .Package(url: "https://github.com/IBM-Swift/swift-html-entities.git", majorVersion: 3, minor: 0),
    .Package(url: "https://github.com/jpsim/Yams.git", majorVersion: 0),
    .Package(url: "https://github.com/oarrabi/FileUtils.git", majorVersion: 0),
    .Package(url: "https://github.com/oarrabi/Guaka.git", majorVersion: 0),
    .Package(url: "https://github.com/sharplet/Regex.git", majorVersion: 1),
    .Package(url: "https://github.com/tid-kijyun/Kanna.git", majorVersion: 2),
    ]
)
