//
//  ThemeViewModel.swift
//  AppUIComponents
//
//  Created by Sudhanshu Vohra on 06/03/26.
//

import SwiftUI
import Combine

@MainActor
class ThemeViewModel: ObservableObject {

    // MARK: - Published State
    @Published var selectedOption: ThemeOption = .automatic

    // MARK: - Data
    let options: [ThemeOption] = ThemeOption.allCases

    // MARK: - Init
    init(activeOption: ThemeOption = .automatic) {
        self.selectedOption = activeOption
    }
}
