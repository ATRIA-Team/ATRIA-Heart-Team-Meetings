//
//  FolderOrganising.swift
//  DemoDICOMmac
//

import Foundation

protocol FolderOrganising: Sendable {
    func createFolder(named name: String, in parent: URL, files: [Category: [URL]]) async throws -> URL
    func moveToICloud(_ url: URL) async throws -> URL
}
