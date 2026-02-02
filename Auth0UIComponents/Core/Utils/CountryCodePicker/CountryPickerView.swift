import SwiftUI

struct CountryPickerView: View {
    @Binding var selectedCountry: Country?
    @Binding var isPickerVisible: Bool

    @StateObject private var store = CountryStore()
    @State private var searchText = ""
    
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
