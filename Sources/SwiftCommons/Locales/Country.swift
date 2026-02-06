//
//  Country.swift
//  SwiftCommons
//
//  Country codes following ISO 3166-1 alpha-2 standard
//

import Foundation

/// Country codes (ISO 3166-1 alpha-2)
public enum Country: String, CaseIterable, Sendable, Codable {
    // MARK: - North America
    case unitedStates = "US"
    case canada = "CA"
    case mexico = "MX"

    // MARK: - Europe
    case unitedKingdom = "GB"
    case ireland = "IE"
    case france = "FR"
    case germany = "DE"
    case italy = "IT"
    case spain = "ES"
    case portugal = "PT"
    case netherlands = "NL"
    case belgium = "BE"
    case switzerland = "CH"
    case austria = "AT"
    case sweden = "SE"
    case norway = "NO"
    case denmark = "DK"
    case finland = "FI"
    case poland = "PL"
    case czechRepublic = "CZ"
    case greece = "GR"
    case russia = "RU"
    case ukraine = "UA"
    case romania = "RO"
    case hungary = "HU"

    // MARK: - Asia
    case china = "CN"
    case japan = "JP"
    case southKorea = "KR"
    case india = "IN"
    case indonesia = "ID"
    case thailand = "TH"
    case vietnam = "VN"
    case philippines = "PH"
    case malaysia = "MY"
    case singapore = "SG"
    case hongKong = "HK"
    case taiwan = "TW"
    case pakistan = "PK"
    case bangladesh = "BD"
    case saudiArabia = "SA"
    case unitedArabEmirates = "AE"
    case israel = "IL"
    case turkey = "TR"

    // MARK: - Oceania
    case australia = "AU"
    case newZealand = "NZ"

    // MARK: - South America
    case brazil = "BR"
    case argentina = "AR"
    case chile = "CL"
    case colombia = "CO"
    case peru = "PE"
    case venezuela = "VE"

    // MARK: - Africa
    case southAfrica = "ZA"
    case nigeria = "NG"
    case egypt = "EG"
    case kenya = "KE"
    case morocco = "MA"

    // MARK: Public

    /// The ISO 3166-1 alpha-2 country code
    public var code: String { rawValue }

    /// Display name for the country
    public var displayName: String {
        switch self {
        // North America
        case .unitedStates: "United States"
        case .canada: "Canada"
        case .mexico: "Mexico"

        // Europe
        case .unitedKingdom: "United Kingdom"
        case .ireland: "Ireland"
        case .france: "France"
        case .germany: "Germany"
        case .italy: "Italy"
        case .spain: "Spain"
        case .portugal: "Portugal"
        case .netherlands: "Netherlands"
        case .belgium: "Belgium"
        case .switzerland: "Switzerland"
        case .austria: "Austria"
        case .sweden: "Sweden"
        case .norway: "Norway"
        case .denmark: "Denmark"
        case .finland: "Finland"
        case .poland: "Poland"
        case .czechRepublic: "Czech Republic"
        case .greece: "Greece"
        case .russia: "Russia"
        case .ukraine: "Ukraine"
        case .romania: "Romania"
        case .hungary: "Hungary"

        // Asia
        case .china: "China"
        case .japan: "Japan"
        case .southKorea: "South Korea"
        case .india: "India"
        case .indonesia: "Indonesia"
        case .thailand: "Thailand"
        case .vietnam: "Vietnam"
        case .philippines: "Philippines"
        case .malaysia: "Malaysia"
        case .singapore: "Singapore"
        case .hongKong: "Hong Kong"
        case .taiwan: "Taiwan"
        case .pakistan: "Pakistan"
        case .bangladesh: "Bangladesh"
        case .saudiArabia: "Saudi Arabia"
        case .unitedArabEmirates: "United Arab Emirates"
        case .israel: "Israel"
        case .turkey: "Turkey"

        // Oceania
        case .australia: "Australia"
        case .newZealand: "New Zealand"

        // South America
        case .brazil: "Brazil"
        case .argentina: "Argentina"
        case .chile: "Chile"
        case .colombia: "Colombia"
        case .peru: "Peru"
        case .venezuela: "Venezuela"

        // Africa
        case .southAfrica: "South Africa"
        case .nigeria: "Nigeria"
        case .egypt: "Egypt"
        case .kenya: "Kenya"
        case .morocco: "Morocco"
        }
    }
}
