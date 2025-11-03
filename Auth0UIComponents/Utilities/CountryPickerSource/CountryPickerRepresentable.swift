import SwiftUI

#if !os(macOS)
struct CountryPicker: UIViewControllerRepresentable {
    let countryPicker = CountriesViewController()
    @Binding var country: CountryModel?
    
    func makeUIViewController(context: Context) -> CountriesViewController {
        countryPicker.allowMultipleSelection = false
        countryPicker.delegate = context.coordinator
        return countryPicker
    }
    
    func updateUIViewController(_ uiViewController: CountriesViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, CountriesViewControllerDelegate {
        func countriesViewControllerDidCancel(_ countriesViewController: CountriesViewController) {
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didSelectCountry country: Country) {
            var cModel = CountryModel()
            if let info = getCountryAndName(country.countryCode) {
                cModel.countryCode  = info.countryCode!
                cModel.countryFlag  = info.countryFlag!
            }
            parent.country = cModel
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didUnselectCountry country: Country) {
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didSelectCountries countries: [Country]) {
        }
        
        var parent: CountryPicker
        init(_ parent: CountryPicker) {
            self.parent = parent
        }
    }
}
#else
struct CountryPicker: NSViewControllerRepresentable {
    
    let countryPicker = CountriesViewController()
    @Binding var country: CountryModel?
    
    func makeNSViewController(context: Context) -> CountriesViewController {
        countryPicker.allowMultipleSelection = false
        countryPicker.delegate = context.coordinator
        return countryPicker
    }
    
    func updateNSViewController(_ nsViewController: CountriesViewController, context: Context) {
    }
    
    func makeCoordinator() -> Coordinator {
        return Coordinator(self)
    }
    
    class Coordinator: NSObject, CountriesViewControllerDelegate {
        func countriesViewControllerDidCancel(_ countriesViewController: CountriesViewController) {
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didSelectCountry country: Country) {
            var cModel = CountryModel()
            if let info = getCountryAndName(country.countryCode) {
                cModel.countryCode  = info.countryCode!
                cModel.countryFlag  = info.countryFlag!
            }
            parent.country = cModel
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didUnselectCountry country: Country) {
        }
        
        func countriesViewController(_ countriesViewController: CountriesViewController, didSelectCountries countries: [Country]) {
        }
        
        var parent: CountryPicker
        init(_ parent: CountryPicker) {
            self.parent = parent
        }
    }
}
#endif
