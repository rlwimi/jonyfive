# wwwww

CLI tool for doing useful things after scraping WWDC session metadata

## Status

This tool is roughly implemented as an MVP to support the needs of [MajorInput](http://github.com/rlwimi/major-input), an iPad app for WWDC session consumption.

Currently, two commands are supported:

- `meta` Scrape session information, write to a JSON file
- `webvtt` Download session caption files ([ASCIIwwdc](https://github.com/ASCIIwwdc/wwdc-session-transcripts)-compatible)

Unimplemented commands:

- `video` Download session videos
- `resources` Download sample code, presentations slides (PDF), etc.

## Getting Started

Here are some steps which may or may not work.

Depends on [Kanna](https://github.com/tid-kijyun/Kanna). See its [README](https://github.com/tid-kijyun/Kanna/blob/master/README.md). You'll need to follow its installation instructions for Swift 3 and Swift Package Manager.

Depends on Swift Package Manager. After prepping for Kanna, you'll want to run `swift package update`, and you'll probably want to `swift package generate-xcodeproj`.

Based on [Guaka](https://github.com/nsomar/Guaka).

## Usage

Once you are up and running, use `-h`/`--help` flags for more information about the interface and functionality.

## Name

Yes, that is [five dubs](http://www.theonion.com/blogpost/fuck-everything-were-doing-five-blades-11056). As in, _world wide web dub dub_. Maybe _dub dub world wide web_. _dub dub dub dub dub_ if you like. Or even _dubby dub bub bubby dub_. Maybe it just looks like a squiggly line.
