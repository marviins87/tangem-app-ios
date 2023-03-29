//
//  SeedPhraseInputProcessor.swift
//  Tangem
//
//  Created by Andrew Son on 22/03/23.
//  Copyright © 2023 Tangem AG. All rights reserved.
//

import Combine
import TangemSdk

protocol SeedPhraseInputProcessor {
    var validatedSeedPhrase: String? { get }
    var isSeedPhraseValidPublisher: AnyPublisher<Bool, Never> { get }
    var inputErrorPublisher: Published<String?>.Publisher { get }
    var defaultTextColor: UIColor { get }
    var defaultTextFont: UIFont { get }

    func validate(newInput: String) -> NSAttributedString
    func prepare(copiedText: String) -> NSAttributedString
    func resetValidation()
}

class DefaultSeedPhraseInputProcessor: SeedPhraseInputProcessor {
    let defaultTextColor: UIColor = Colors.Text.primary1.uiColorFromRGB()
    let invalidTextColor: UIColor = Colors.Text.warning.uiColorFromRGB()
    let defaultTextFont: UIFont = UIFonts.Regular.body

    @Published private var inputError: String? = nil
    @Published private(set) var validatedSeedPhrase: String?

    private var dictionary: Set<String> = []

    var isSeedPhraseValidPublisher: AnyPublisher<Bool, Never> {
        $validatedSeedPhrase
            .map { $0 != nil }
            .eraseToAnyPublisher()
    }

    var inputErrorPublisher: Published<String?>.Publisher { $inputError }

    init() {
        dictionary = Set(BIP39.Wordlist.en.words)
    }

    func validate(newInput: String) -> NSAttributedString {
        if newInput.isEmpty {
            inputError = nil
            validatedSeedPhrase = nil
            return NSAttributedString(string: "")
        }
        let words = newInput.split(separator: " ").map { String($0) }
        let preparationResult = processInput(words: words)
        do {
            try BIP39().validate(mnemonicComponents: words)
            inputError = nil
            validatedSeedPhrase = newInput
        } catch {
            if preparationResult.invalidWords.isEmpty {
                processValidationError(error)
            } else {
                processValidationError(MnemonicError.invalidWords(words: preparationResult.invalidWords))
            }
            validatedSeedPhrase = nil
        }
        return preparationResult.attributedText
    }

    func prepare(copiedText: String) -> NSAttributedString {
        do {
            let mnemonic = try Mnemonic(with: copiedText)
            return processInput(words: mnemonic.mnemonicComponents).attributedText
        } catch {
            let parsed = parse(input: copiedText)
            return processInput(words: parsed).attributedText
        }
    }

    func resetValidation() {
        validatedSeedPhrase = nil
    }

    private func parse(input: String) -> [String] {
        input.split(separator: " ").map { String($0) }
    }

    private func processInput(words: [String]) -> ProcessedInput {
        let mutableStr = NSMutableAttributedString()
        let separator = " "
        var invalidWords = [String]()

        for i in 0 ..< words.count {
            let parsedWord = words[i]
            let isValidWord = dictionary.contains(parsedWord)
            if !isValidWord {
                invalidWords.append(parsedWord)
            }

            let wordColor = isValidWord ? defaultTextColor : invalidTextColor
            let string = NSMutableAttributedString()
            string.append(NSAttributedString(string: parsedWord, attributes: [.foregroundColor: wordColor, .font: defaultTextFont]))
            string.append(NSAttributedString(string: separator, attributes: [.foregroundColor: defaultTextColor, .font: defaultTextFont]))
            mutableStr.append(string)
        }

        return ProcessedInput(attributedText: mutableStr, invalidWords: invalidWords)
    }

    private func processValidationError(_ error: Error) {
        guard let mnemonicError = error as? MnemonicError else {
            inputError = error.localizedDescription
            return
        }

        switch mnemonicError {
        case .invalidEntropyLength, .invalidWordCount, .invalidWordsFile, .mnenmonicCreationFailed, .normalizationFailed, .wrongWordCount:
            inputError = nil
        case .invalidCheksum:
            inputError = "Invalid checksum. Please check words order"
        case .unsupportedLanguage, .invalidWords:
            inputError = "Invalid seed phrase, please check your spelling"
        @unknown default:
            break
        }
    }
}

extension DefaultSeedPhraseInputProcessor {
    private struct ProcessedInput {
        let attributedText: NSAttributedString
        let invalidWords: [String]
    }
}
