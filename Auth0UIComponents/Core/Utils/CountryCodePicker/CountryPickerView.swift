import SwiftUI

/// A modal picker for selecting a country and its calling code.
///
/// This view displays a searchable list of countries with their flag emojis
/// and calling codes. Users can search by country name or code to quickly find
/// their country.
struct CountryPickerView: View {
    /// Binding to the selected country, updated when user makes a selection
    @Binding var selectedCountry: Country?
    /// Binding to control the visibility of the picker
    @Binding var isPickerVisible: Bool

    /// Store that loads and provides the list of countries
    @StateObject private var store = CountryStore()
    /// Search text entered by the user
    @State private var searchText = ""

    /// The list of countries filtered by the search text.
    ///
    /// Filters by country name or calling code, case-insensitive.
    var filteredCountries: [Country] {
        if searchText.isEmpty { return store.countries }
        return store.countries.filter {
            $0.name.lowercased().contains(searchText.lowercased()) ||
            $0.code.contains(searchText)
        }
    }
    
    var body: some View {
        NavigationStack {
            List(filteredCountries) { country in
                Button {
                    selectedCountry = country
                    isPickerVisible.toggle()
                } label: {
                    HStack {
                        Text(country.flag)
                            .font(.system(size: 28))
                        
                        Text(country.name)
                            .font(.body)
                        
                        Spacer()
                        
                        Text(country.code)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Select country code")
            .searchable(text: $searchText)
        }
    }
}
