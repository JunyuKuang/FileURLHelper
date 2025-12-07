//
//  FileURLHelper.swift
//  JonnyUtility
//
//  Created by Jonny Kuang on 6/3/22.
//  Copyright © 2022 Jonny Kuang. All rights reserved.
//

import Foundation

public enum FileURLHelper {
    
    case directoryURL(URL)
    
    case folderNames([String], directory: FileManager.SearchPathDirectory = .cachesDirectory)
    
    /// Saved content will be deleted next time the app is launched.
    ///
    /// Client is responsible for calling `notifyAppLaunch` for deleting on launch to work.
    case deletesOnLaunch(folderNames: [String])
    
    /// Supported directories: cachesDirectory, libraryDirectory, and applicationSupportDirectory
    case appGroupFolder(folderNames: [String], appGroupID: String, directory: FileManager.SearchPathDirectory = .cachesDirectory)
    
    public static func folderName(_ name: String, directory: FileManager.SearchPathDirectory = .cachesDirectory) -> Self {
        folderNames([name], directory: directory)
    }
    
    public static func deletesOnLaunch(folderName: String) -> Self {
        deletesOnLaunch(folderNames: [folderName])
    }
    
    public static func appGroupFolder(folderName: String, appGroupID: String, directory: FileManager.SearchPathDirectory = .cachesDirectory) -> Self {
        appGroupFolder(folderNames: [folderName], appGroupID: appGroupID, directory: directory)
    }
}

public extension FileURLHelper {
    
    private func directoryURL(for directory: FileManager.SearchPathDirectory) throws -> URL {
        if directory == .itemReplacementDirectory {
            return FileManager.default.temporaryDirectory // workaround a nil URL error
        }
        return try FileManager.default.url(for: directory, in: .userDomainMask, appropriateFor: nil, create: true)
    }
    
    /// You can delete folder with the returned URL.
    /// Accessing this method does NOT create any directory.
    func resolvedDirectoryURL() throws -> URL {
        switch self {
        case let .directoryURL(url):
            return url
            
        case let .folderNames(folderNames, directory):
            var url = try directoryURL(for: directory)
            folderNames.forEach {
                url.appendPathComponent($0, isDirectory: true)
            }
            return url
            
        case let .deletesOnLaunch(folderNames):
            var url = FileManager.default.temporaryDirectory
            ([Self.mainDirectoryNameForDeletingOnLaunch, Self.subdirectoryNameForDeletingOnLaunch] + folderNames).forEach {
                url.appendPathComponent($0, isDirectory: true)
            }
            return url
            
        case let .appGroupFolder(folderNames, appGroupID, directory):
            guard [.cachesDirectory, .libraryDirectory, .applicationSupportDirectory].contains(directory) else {
                throw Error.unsupportedDirectory(directory)
            }
            guard var url = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
                throw Error.invalidAppGroupID(appGroupID)
            }
            url.appendPathComponent("Library", isDirectory: true)
            if directory != .libraryDirectory {
                url.appendPathComponent(directory == .cachesDirectory ? "Caches" : "Application Support", isDirectory: true)
            }
            folderNames.forEach {
                url.appendPathComponent($0, isDirectory: true)
            }
            return url
        }
    }
    
    enum Error : LocalizedError {
        case unsupportedDirectory(FileManager.SearchPathDirectory)
        case invalidAppGroupID(String)
        
        public var errorDescription: String? {
            switch self {
            case .unsupportedDirectory:
                "Unsupported directory for app group folder."
            case let .invalidAppGroupID(appGroupID):
                "Failed to create container URL for App Group \(appGroupID)."
            }
        }
    }
    
    /// The helper will create a folder at `resolvedDirectoryURL()` for you if it doesn't exist.
    ///
    /// Will never throw error if self is `directoryURL` or `deletesOnLaunch`.
    func fileURL(withFilename filename: String, fileExtension: String = "") throws -> URL {
        let directoryURL = try resolvedDirectoryURL()
        let manager = FileManager.default
        
        var isDirectory: ObjCBool = false
        if !manager.fileExists(atPath: directoryURL.path, isDirectory: &isDirectory) || !isDirectory.boolValue {
            try? manager.removeItem(at: directoryURL)
            try manager.createDirectory(at: directoryURL, withIntermediateDirectories: true, attributes: nil)
        }
        var fileURL = directoryURL.appendingPathComponent(filename, isDirectory: false)
        if !fileExtension.isEmpty {
            fileURL.appendPathExtension(fileExtension)
        }
        return fileURL
    }
    
    private static let mainDirectoryNameForDeletingOnLaunch = "KJYDeleteOnLaunch"
    
    private static let subdirectoryNameForDeletingOnLaunch = UUID().uuidString
    
    /// Delete content marked with `deletesOnLaunch`.
    static let notifyAppLaunch: Void = {
        DispatchQueue.global(qos: .background).async {
            let urls = try? FileManager.default.contentsOfDirectory(
                at: FileManager.default.temporaryDirectory.appendingPathComponent(mainDirectoryNameForDeletingOnLaunch, isDirectory: true),
                includingPropertiesForKeys: [],
                options: [.skipsHiddenFiles, .skipsSubdirectoryDescendants]
            )
            urls?.forEach { url in
                if url.lastPathComponent != subdirectoryNameForDeletingOnLaunch {
                    try? FileManager.default.removeItem(at: url)
                }
            }
        }
    }()
}
