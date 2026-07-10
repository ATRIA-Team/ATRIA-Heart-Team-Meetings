//
//  AtriaManifest.swift
//  ATRIAmac
//

import Foundation

struct AtriaManifest: Codable {
    var version: Int = 1
    var patientName: String
    var createdAt: Date
    /// Maps each category's rawValue to the filenames stored inside that subfolder.
    var categories: [String: [String]]
}
