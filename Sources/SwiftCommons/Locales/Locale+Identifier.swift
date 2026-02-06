//
//  Locale+Identifier.swift
//  SwiftCommons
//
//  Extension to create locale identifiers from Language and Country enums
//

import Foundation

extension Locale {
    /// Create a locale identifier from language and country
    ///
    /// - Parameters:
    ///   - language: The language code
    ///   - country: The country code (optional)
    /// - Returns: A locale identifier string (e.g., "en-US", "fr-FR")
    public static func identifier(
        language: SwiftCommons.Language,
        country: SwiftCommons.Country? = nil
    ) -> String {
        if let country {
            "\(language.code)-\(country.code)"
        } else {
            language.code
        }
    }

    /// Common locale identifiers for convenience.
    public enum Identifiers {
        // MARK: - English Variants

        /// English (United States).
        public static let englishUS = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.unitedStates
        )
        /// English (United Kingdom).
        public static let englishUK = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.unitedKingdom
        )
        /// English (Australia).
        public static let englishAU = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.australia
        )
        /// English (Canada).
        public static let englishCA = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.canada
        )
        /// English (New Zealand).
        public static let englishNZ = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.newZealand
        )
        /// English (Ireland).
        public static let englishIE = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.ireland
        )
        /// English (South Africa).
        public static let englishZA = Locale.identifier(
            language: SwiftCommons.Language.english,
            country: SwiftCommons.Country.southAfrica
        )

        // MARK: - Spanish Variants

        /// Spanish (Spain).
        public static let spanishES = Locale.identifier(
            language: SwiftCommons.Language.spanish,
            country: SwiftCommons.Country.spain
        )
        /// Spanish (Mexico).
        public static let spanishMX = Locale.identifier(
            language: SwiftCommons.Language.spanish,
            country: SwiftCommons.Country.mexico
        )
        /// Spanish (Argentina).
        public static let spanishAR = Locale.identifier(
            language: SwiftCommons.Language.spanish,
            country: SwiftCommons.Country.argentina
        )
        /// Spanish (Colombia).
        public static let spanishCO = Locale.identifier(
            language: SwiftCommons.Language.spanish,
            country: SwiftCommons.Country.colombia
        )

        // MARK: - French Variants

        /// French (France).
        public static let frenchFR = Locale.identifier(
            language: SwiftCommons.Language.french,
            country: SwiftCommons.Country.france
        )
        /// French (Canada).
        public static let frenchCA = Locale.identifier(
            language: SwiftCommons.Language.french,
            country: SwiftCommons.Country.canada
        )
        /// French (Belgium).
        public static let frenchBE = Locale.identifier(
            language: SwiftCommons.Language.french,
            country: SwiftCommons.Country.belgium
        )
        /// French (Switzerland).
        public static let frenchCH = Locale.identifier(
            language: SwiftCommons.Language.french,
            country: SwiftCommons.Country.switzerland
        )

        // MARK: - German Variants

        /// German (Germany).
        public static let germanDE = Locale.identifier(
            language: SwiftCommons.Language.german,
            country: SwiftCommons.Country.germany
        )
        /// German (Austria).
        public static let germanAT = Locale.identifier(
            language: SwiftCommons.Language.german,
            country: SwiftCommons.Country.austria
        )
        /// German (Switzerland).
        public static let germanCH = Locale.identifier(
            language: SwiftCommons.Language.german,
            country: SwiftCommons.Country.switzerland
        )

        // MARK: - Portuguese Variants

        /// Portuguese (Brazil).
        public static let portugueseBR = Locale.identifier(
            language: SwiftCommons.Language.portuguese,
            country: SwiftCommons.Country.brazil
        )
        /// Portuguese (Portugal).
        public static let portuguesePT = Locale.identifier(
            language: SwiftCommons.Language.portuguese,
            country: SwiftCommons.Country.portugal
        )

        // MARK: - Chinese Variants

        /// Chinese (China).
        public static let chineseCN = Locale.identifier(
            language: SwiftCommons.Language.chinese,
            country: SwiftCommons.Country.china
        )
        /// Chinese (Hong Kong).
        public static let chineseHK = Locale.identifier(
            language: SwiftCommons.Language.chinese,
            country: SwiftCommons.Country.hongKong
        )
        /// Chinese (Taiwan).
        public static let chineseTW = Locale.identifier(
            language: SwiftCommons.Language.chinese,
            country: SwiftCommons.Country.taiwan
        )

        // MARK: - Other Major Languages

        /// Italian (Italy).
        public static let italianIT = Locale.identifier(
            language: SwiftCommons.Language.italian,
            country: SwiftCommons.Country.italy
        )
        /// Russian (Russia).
        public static let russianRU = Locale.identifier(
            language: SwiftCommons.Language.russian,
            country: SwiftCommons.Country.russia
        )
        /// Japanese (Japan).
        public static let japaneseJP = Locale.identifier(
            language: SwiftCommons.Language.japanese,
            country: SwiftCommons.Country.japan
        )
        /// Korean (South Korea).
        public static let koreanKR = Locale.identifier(
            language: SwiftCommons.Language.korean,
            country: SwiftCommons.Country.southKorea
        )
        /// Arabic (Saudi Arabia).
        public static let arabicSA = Locale.identifier(
            language: SwiftCommons.Language.arabic,
            country: SwiftCommons.Country.saudiArabia
        )
        /// Hindi (India).
        public static let hindiIN = Locale.identifier(
            language: SwiftCommons.Language.hindi,
            country: SwiftCommons.Country.india
        )
        /// Dutch (Netherlands).
        public static let dutchNL = Locale.identifier(
            language: SwiftCommons.Language.dutch,
            country: SwiftCommons.Country.netherlands
        )
        /// Polish (Poland).
        public static let polishPL = Locale.identifier(
            language: SwiftCommons.Language.polish,
            country: SwiftCommons.Country.poland
        )
        /// Swedish (Sweden).
        public static let swedishSE = Locale.identifier(
            language: SwiftCommons.Language.swedish,
            country: SwiftCommons.Country.sweden
        )
        /// Norwegian (Norway).
        public static let norwegianNO = Locale.identifier(
            language: SwiftCommons.Language.norwegian,
            country: SwiftCommons.Country.norway
        )
        /// Danish (Denmark).
        public static let danishDK = Locale.identifier(
            language: SwiftCommons.Language.danish,
            country: SwiftCommons.Country.denmark
        )
        /// Finnish (Finland).
        public static let finnishFI = Locale.identifier(
            language: SwiftCommons.Language.finnish,
            country: SwiftCommons.Country.finland
        )
        /// Greek (Greece).
        public static let greekGR = Locale.identifier(
            language: SwiftCommons.Language.greek,
            country: SwiftCommons.Country.greece
        )
        /// Turkish (Turkey).
        public static let turkishTR = Locale.identifier(
            language: SwiftCommons.Language.turkish,
            country: SwiftCommons.Country.turkey
        )
        /// Thai (Thailand).
        public static let thaiTH = Locale.identifier(
            language: SwiftCommons.Language.thai,
            country: SwiftCommons.Country.thailand
        )
        /// Vietnamese (Vietnam).
        public static let vietnameseVN = Locale.identifier(
            language: SwiftCommons.Language.vietnamese,
            country: SwiftCommons.Country.vietnam
        )
        /// Indonesian (Indonesia).
        public static let indonesianID = Locale.identifier(
            language: SwiftCommons.Language.indonesian,
            country: SwiftCommons.Country.indonesia
        )

        // MARK: - Default

        /// Default locale identifier used by SwiftCommons.
        public static let `default` = englishUS
    }
}
