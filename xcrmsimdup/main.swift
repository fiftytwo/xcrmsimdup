//
//  main.swift
//  xcrmsimdup
//
//  Created by Dmitry Victorov on 09/08/15.
//  Copyright (c) 2015 fiftytwo. All rights reserved.
//

import Foundation


// MARK: Data types


struct Section
{
    var name: String
    var rangeTitle: Range<String.Index>
    var rangeData: Range<String.Index>
}


struct Device
{
    var name: String
    var id: String
    var status: String
}


// MARK: Functions


func printUsage()
{
    println(
        "Usage: xcrmsimdup [options]\n" +
        "\n" +
        "Find duplicated simulator records from the active developer directory listed\n" +
        "by command `xcrun simctl list` and remove duplicates using\n" +
        "`xcrun simctl delete`.\n" +
        "\n" +
        "The active developer directory can be set using `xcode-select`, or via the\n" +
        "DEVELOPER_DIR environment variable. See the xcrun and xcode-select manual\n" +
        "pages for more information.\n" +
        "\n" +
        "Options:\n" +
        "  -h, --help      show this help message and exit\n" +
        "  -d, --delete    delete duplicates\n" +
        "  -s, --show      just show duplicates, but don't touch them"
    );

}


func executeWithBash(command: String) -> (status: Int32, output: String)
{
    var task = NSTask()

    var outputPipe = NSPipe()
    var outputFileHandle = outputPipe.fileHandleForReading

    task.launchPath = "/bin/bash"
    task.arguments = ["-c", command]
    task.standardOutput = outputPipe
    task.standardError = outputPipe

    task.launch()

    var outputData = outputFileHandle.readDataToEndOfFile()

    task.waitUntilExit()

    var output = NSString(data: outputData, encoding: NSUTF8StringEncoding) as! String

    return (task.terminationStatus, output)
}


func sectionsFromString(string: String, prefix: String, suffix: String, range: Range<String.Index>? = nil) -> Array<Section>?
{
    var startIndex: String.Index
    var endIndex: String.Index

    if range == nil
    {
        startIndex = string.startIndex
        endIndex = string.endIndex
    }
    else
    {
        startIndex = range!.startIndex
        endIndex = range!.endIndex
    }

    var sections = [Section]()

    while let prefixFound = string.rangeOfString(prefix, range: startIndex..<endIndex)
    {
        if let suffixFound = string.rangeOfString(suffix, range: prefixFound.endIndex..<endIndex)
        {
            var section = Section(
                name: string.substringWithRange(prefixFound.endIndex..<suffixFound.startIndex),
                rangeTitle: prefixFound.startIndex..<suffixFound.endIndex,
                rangeData: suffixFound.endIndex..<endIndex
            )

            sections.append(section)

            startIndex = suffixFound.endIndex;
        }
        else
        {
            return nil;
        }
    }

    for var i = sections.count - 2; i >= 0; i--
    {
        sections[i].rangeData.endIndex = sections[i + 1].rangeTitle.startIndex
    }

    return sections
}


func intFromStringIndex(string: String, index: String.Index) -> Int
{
    let utf16 = string.utf16;

    let utf16Index = index.samePositionIn(utf16)

    return distance(utf16.startIndex, utf16Index)
}


func NSRangeFromStringRange(string: String, range: Range<String.Index>) -> NSRange
{
    let utf16Start = intFromStringIndex(string, range.startIndex)

    let utf16End = intFromStringIndex(string, range.endIndex)

    let utf16length = distance(utf16Start, utf16End)

    return NSRange(location: utf16Start, length: utf16length)
}


func stringIndexFromInt(string: String, index: Int) -> String.Index?
{
    let utf16 = string.utf16

    let utf16Index = advance(utf16.startIndex, index, utf16.endIndex)

    return utf16Index.samePositionIn(string)
}


func stringRangeFromNSRange(string: String, nsRange: NSRange) -> Range<String.Index>?
{
    if nsRange.location == NSNotFound
    {
        return nil
    }

    if let start = stringIndexFromInt(string, nsRange.location),
        end = stringIndexFromInt(string, nsRange.location + nsRange.length)
    {
        return start..<end
    }

    return nil
}


func devicesFromRuntimeSection(string: String, runtimeSection: Section) -> Dictionary< String, Array<Device> >
{
    var devices = [String: Array<Device>]();

    let regexPattern = "^ +(.+?) \\(([0-9a-fA-F\\-]{36})\\) \\((.+?)\\)$"
    var regex = NSRegularExpression(pattern: regexPattern, options: .AnchorsMatchLines, error: nil)!

    var nsRange = NSRangeFromStringRange(string, runtimeSection.rangeData)

    var matches = regex.matchesInString(string, options: nil, range: nsRange)

    for match in matches
    {
        if let nameRange = stringRangeFromNSRange(string, match.rangeAtIndex(1)),
            idRange = stringRangeFromNSRange(string, match.rangeAtIndex(2)),
            statusRange = stringRangeFromNSRange(string, match.rangeAtIndex(3))
        {
            let device = Device(
                name: string.substringWithRange(nameRange),
                id: string.substringWithRange(idRange),
                status: string.substringWithRange(statusRange))

            if var devicesList = devices[device.name]
            {
                devicesList.append(device);
                devices[device.name] = devicesList;
            }
            else
            {
                devices[device.name] = [device];
            }
        }
    }

    return devices;
}


func processDuplicatesInSection(string: String, section: Section, isShowOnly: Bool) -> Bool
{
    if let runtimes = sectionsFromString(string, "-- ", " --\n", range: section.rangeData)
    {
        for runtime in runtimes
        {
            let devices = devicesFromRuntimeSection(string, runtime)

            println("Processing environment \(runtime.name)")

            for device in devices
            {
                if device.1.count < 1
                {
                    println("    No device records found for \(device.0), probably bug in parser")
                }
                else if device.1.count == 1
                {
                    println("    No duplicats found for \(device.1[0].name) (\(device.1[0].id))")
                }
                else
                {
                    println("    Duplicates found for \(device.1[0].name) (\(device.1[0].id))")

                    for var i = 1; i < device.1.count; i++
                    {
                        if isShowOnly
                        {
                            println("        \(device.1[i].id)")
                        }
                        else
                        {
                            let deleteStatus = executeWithBash("xcrun simctl delete " + device.1[i].id)

                            if deleteStatus.status == 0
                            {
                                println("        \(device.1[i].id) DELETED")
                            }
                            else
                            {
                                println("        \(device.1[i].id) NOT DELETED, error code \(deleteStatus.status)")
                            }
                        }
                    }
                }
            }
        }
    }
    else
    {
        println("Can't enumerate runtimes in section \(section.name)")

        return false;
    }

    return true
}


// MARK: Execution starts here


if Process.argc != 2
{
    println("Invalid options count")
    printUsage();
    exit(1)
}


var isShowOnlyMode: Bool;


switch Process.arguments[1]
{
case "-h", "--help":
    printUsage()
    exit(1)

case "-d", "--delete":
    isShowOnlyMode = false;

case "-s", "--show":
    isShowOnlyMode = true;

default:
    println("Unknown option \(Process.arguments[1])")
    printUsage()
    exit(1)
}


var simulatorsList = executeWithBash("xcrun simctl list")

if simulatorsList.status != 0
{
    println("'xcrun simctl list' execution failed with code \(simulatorsList.status)")
    exit(1)
}


var sections = sectionsFromString(simulatorsList.output, "== ", " ==\n")

if sections == nil
{
    println("Can't parse output of 'xcrun simctl list'")
    exit(1);
}


for section in sections!
{
    if section.name == "Devices"
    {
        if processDuplicatesInSection(simulatorsList.output, section, isShowOnlyMode)
        {
            break
        }

        exit(1);
    }
}
