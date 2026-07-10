//
//  Category.swift
//  ATRIAmac
//

import Foundation

enum Category: String, CaseIterable, Identifiable {
    case medicalHistory = "Medical History"
    case vitals         = "Vitals"
    case bloodTests     = "Blood Tests"
    case echo           = "Echo"
    case ct             = "CT"
    case coro           = "Coro"
    case other          = "Other"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .medicalHistory: return "list.bullet.clipboard.fill"
        case .vitals:         return "stethoscope"
        case .bloodTests:     return "drop.fill"
        case .echo:           return "waveform.path.ecg.text.clipboard.fill"
        case .ct:             return "waveform.path.ecg.rectangle.fill"
        case .coro:           return "heart.fill"
        case .other:          return "heart.text.clipboard.fill"
        }
    }
}
