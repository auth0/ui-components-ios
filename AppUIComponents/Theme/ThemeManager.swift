//
//  ThemeManager.swift
//  AppUIComponents
//
//  Created by Sudhanshu Vohra on 09/03/26.
//

import SwiftUI
import Auth0UniversalComponents
import Combine

@MainActor
final class ThemeManager: ObservableObject {

    // MARK: - Published State
    @Published private(set) var currentTheme: Auth0Theme = Auth0Theme()
    @Published private(set) var activeOption: ThemeOption = .automatic

    // MARK: - Apply
    func apply(_ option: ThemeOption) {
        activeOption = option
        currentTheme = option.theme
    }
}
