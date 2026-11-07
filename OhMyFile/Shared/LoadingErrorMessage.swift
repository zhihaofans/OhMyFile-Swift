//
//  LoadingErrorMessage.swift
//  OhMyFile
//
//  文本类预览的友好错误文案。
//

import Foundation

func textLoadingMessage(for error: Error) -> String {
    if let loadingError = error as? TextFileLoader.LoadingError {
        switch loadingError {
        case .tooLarge:
            return String(localized: "File is too large to preview.")
        case .unsupportedEncoding:
            return String(localized: "Text encoding is not supported.")
        case .readFailed:
            return String(localized: "Unable to read file.")
        }
    }

    if error is CloudFileError {
        return String(localized: "File download timed out. Please try again.")
    }

    return error.localizedDescription
}
