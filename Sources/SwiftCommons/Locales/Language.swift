//
//  Language.swift
//  SwiftCommons
//
//  Language codes following ISO 639-1 standard
//

import Foundation

/// Language codes (ISO 639-1)
public enum Language: String, CaseIterable, Sendable, Codable {
    // MARK: - Major World Languages
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    case italian = "it"
    case portuguese = "pt"
    case russian = "ru"
    case chinese = "zh"
    case japanese = "ja"
    case korean = "ko"
    case arabic = "ar"
    case hindi = "hi"

    // MARK: - European Languages
    case dutch = "nl"
    case polish = "pl"
    case swedish = "sv"
    case norwegian = "no"
    case danish = "da"
    case finnish = "fi"
    case greek = "el"
    case turkish = "tr"
    case czech = "cs"
    case hungarian = "hu"
    case romanian = "ro"
    case ukrainian = "uk"
    case croatian = "hr"
    case serbian = "sr"
    case bulgarian = "bg"
    case slovak = "sk"

    // MARK: - Asian Languages
    case thai = "th"
    case vietnamese = "vi"
    case indonesian = "id"
    case malay = "ms"
    case tagalog = "tl"
    case bengali = "bn"
    case urdu = "ur"
    case persian = "fa"
    case hebrew = "he"

    // MARK: - Other Languages
    case swahili = "sw"
    case afrikaans = "af"
    case catalan = "ca"
    case basque = "eu"
    case galician = "gl"

    // MARK: Public

    /// The ISO 639-1 language code
    public var code: String { rawValue }

    /// Display name for the language
    public var displayName: String {
        switch self {
        // Major World Languages
        case .english: "English"
        case .spanish: "Spanish"
        case .french: "French"
        case .german: "German"
        case .italian: "Italian"
        case .portuguese: "Portuguese"
        case .russian: "Russian"
        case .chinese: "Chinese"
        case .japanese: "Japanese"
        case .korean: "Korean"
        case .arabic: "Arabic"
        case .hindi: "Hindi"

        // European Languages
        case .dutch: "Dutch"
        case .polish: "Polish"
        case .swedish: "Swedish"
        case .norwegian: "Norwegian"
        case .danish: "Danish"
        case .finnish: "Finnish"
        case .greek: "Greek"
        case .turkish: "Turkish"
        case .czech: "Czech"
        case .hungarian: "Hungarian"
        case .romanian: "Romanian"
        case .ukrainian: "Ukrainian"
        case .croatian: "Croatian"
        case .serbian: "Serbian"
        case .bulgarian: "Bulgarian"
        case .slovak: "Slovak"

        // Asian Languages
        case .thai: "Thai"
        case .vietnamese: "Vietnamese"
        case .indonesian: "Indonesian"
        case .malay: "Malay"
        case .tagalog: "Tagalog"
        case .bengali: "Bengali"
        case .urdu: "Urdu"
        case .persian: "Persian"
        case .hebrew: "Hebrew"

        // Other Languages
        case .swahili: "Swahili"
        case .afrikaans: "Afrikaans"
        case .catalan: "Catalan"
        case .basque: "Basque"
        case .galician: "Galician"
        }
    }
}
