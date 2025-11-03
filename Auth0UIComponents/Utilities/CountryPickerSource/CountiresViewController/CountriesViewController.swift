//
//  CountriesViewController.swift
//  CountryCode
//
//  Created by Created by WeblineIndia  on 01/07/23.
//  Copyright © 2023 WeblineIndia . All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif
import Foundation
import CoreData

#if !os(macOS)
/// Class to select countries
public final class CountriesViewController: UIViewController, UISearchBarDelegate, UITableViewDelegate, UITableViewDataSource {

    public var unfilteredCountries: [[Country]]! { didSet { filteredCountries = unfilteredCountries } }
    public var filteredCountries: [[Country]]!
    public var majorCountryLocaleIdentifiers: [String] = []
    public var delegate: CountriesViewControllerDelegate?
    public var allowMultipleSelection: Bool = true
    public var selectedCountries: [Country] = [Country]() {
        didSet {
            self.navigationItem.rightBarButtonItem?.isEnabled = self.selectedCountries.count > 0
        }
    }

    /// Lazy var for table view
    // Table View is created programatically
    public fileprivate(set) lazy var tableView: UITableView = {

        let tableView: UITableView = UITableView()
        tableView.backgroundColor = UIColor.white
        
        return tableView

    }()

    /// Lazy var for table view
    /// search bar is created programatically
    public fileprivate(set) lazy var searchBar: UISearchBar = {

        let searchBar: UISearchBar = UISearchBar()
        searchBar.translatesAutoresizingMaskIntoConstraints = false
        searchBar.isTranslucent = true
        if let textfield = searchBar.value(forKey: "searchField") as? UITextField {
            textfield.placeholder = "Search Country"

        }
        searchBar.barTintColor = UIColor(named: "statusBar")
        return searchBar

    }()

    /// Lazy var for global stackview container
    //Search bar and table view are added to stack View
    public fileprivate(set) lazy var stackView: UIStackView = {

        let stackView           = UIStackView(arrangedSubviews: [self.searchBar, self.tableView])
        stackView.axis          = .vertical
        stackView.distribution  = .fill
        stackView.alignment     = .fill
        stackView.spacing       = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView

    }()

    /// Calculate the nav bar height if present
    var cancelButton: UIBarButtonItem!
    var doneButton: UIBarButtonItem?

    private var searchString: String = ""
// viewDidLoad specify the design of country picker when it is loaded
    override public func viewDidLoad() {

        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
    
        self.navigationItem.title = allowMultipleSelection ? "Select Countries" : "Select Country"
        self.navigationController?.navigationBar.backgroundColor = .white
        cancelButton = UIBarButtonItem(barButtonSystemItem: UIBarButtonItem.SystemItem.cancel, target: self, action: #selector(CountriesViewController.cancel))
        self.navigationItem.leftBarButtonItem = cancelButton

        if allowMultipleSelection {
            doneButton = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(CountriesViewController.done))
            self.navigationItem.rightBarButtonItem = doneButton
            self.navigationItem.rightBarButtonItem?.isEnabled = selectedCountries.count > 0
        }

        /// Configure tableVieew
        #if !os(visionOS)
        tableView.keyboardDismissMode   = .onDrag
        #endif

        /// Add delegates
        searchBar.delegate      = self
        tableView.dataSource    = self
        tableView.delegate      = self

        /// Add stackview
        self.view.addSubview(stackView)

        //autolayout the stack view and elements
        let viewsDictionary = [
            "stackView": stackView
            ] as [String: Any]

        //constraint for stackview
        let stackViewH = NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-0-[stackView]-0-|",
            options: NSLayoutConstraint.FormatOptions(rawValue: 0),
            metrics: nil,
            views: viewsDictionary
        )
        //constraint for stackview
        let stackViewV = NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-[stackView]-0-|",
            options: NSLayoutConstraint.FormatOptions(rawValue: 0),
            metrics: nil,
            views: viewsDictionary
        )

        /// Searchbar constraint
        searchBar.topAnchor.constraint(equalTo: stackView.topAnchor, constant: 0).isActive  = true
        searchBar.leftAnchor.constraint(equalTo: view.leftAnchor, constant: 0).isActive     = true
        searchBar.rightAnchor.constraint(equalTo: view.rightAnchor, constant: 0).isActive   = true
        searchBar.heightAnchor.constraint(equalToConstant: CGFloat(60)).isActive            = true

        //Add all constraints to view
        view.addConstraints(stackViewH)
        view.addConstraints(stackViewV)

        /// Setup controller
        setupCountries()

        self.edgesForExtendedLayout = []

    }

    /// Function for done button
    @objc func done() {

        delegate?.countriesViewController(self, didSelectCountries: selectedCountries)
        self.dismiss(animated: true, completion: nil)

    }

    /// Function for cancel button
    @objc func cancel() {

        delegate?.countriesViewControllerDidCancel(self)
        self.dismiss(animated: true, completion: nil)

    }

    // MARK: - UISearchBarDelegate
//Serach bar method to search countries
    public func searchBar(_ searchBar: UISearchBar, textDidChange searchText: String) {
        searchString = searchText
        searchForText(searchText)
        tableView.reloadData()
    }

    fileprivate func searchForText(_ text: String) {
        if text.isEmpty {
            filteredCountries = unfilteredCountries
        } else {
            let allCountries: [Country] = Countries.countries.filter { $0.name.lowercased().range(of: text.lowercased()) != nil }
            filteredCountries = partionedArray(allCountries, usingSelector: #selector(getter: NSFetchedResultsSectionInfo.name))
            filteredCountries.insert([], at: 0) //Empty section for our favorites
        }
        tableView.reloadData()
    }

    // MARK: Viewing Countries
    fileprivate func setupCountries() {

        unfilteredCountries = partionedArray(Countries.countries, usingSelector: #selector(getter: NSFetchedResultsSectionInfo.name))
        unfilteredCountries.insert(Countries.countriesFromCountryCodes(majorCountryLocaleIdentifiers), at: 0)
        tableView.reloadData()

        /// If some countries are selected, scroll to the first
        if let selectedCountry = selectedCountries.first {
            for (index, countries) in unfilteredCountries.enumerated() {
                if let countryIndex = countries.firstIndex(of: selectedCountry) {
                    let indexPath = IndexPath(row: countryIndex, section: index)
                    tableView.scrollToRow(at: indexPath, at: .top, animated: true)
                    break
                }
            }
        }
    }

    //  UItableViewDelegate,UItableViewDataSource

    public func numberOfSections(in tableView: UITableView) -> Int {
        return filteredCountries.count
    }

    public func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredCountries[section].count
    }


    public  func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        /// Obtain a cell
        let cell: UITableViewCell = {
            guard let cell = tableView.dequeueReusableCell(withIdentifier: "Cell") else {
                
                return UITableViewCell(style: UITableViewCell.CellStyle.value1, reuseIdentifier: "Cell")
            }
            cell.contentView.backgroundColor = UIColor(named:"contactListingColor")
            return cell
        }()

        /// Configure cell
        let country                 = filteredCountries[indexPath.section][indexPath.row]
        cell.textLabel?.text        = country.flag + " " + country.name
        cell.detailTextLabel?.text  = "+" + country.phoneExtension
        cell.accessoryType          = (selectedCountries.firstIndex(of: country) != nil) ? .checkmark : .none
        cell.contentView.backgroundColor = UIColor(named:"contactListingColor")
        return cell
    }

    public func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {

        let countries = filteredCountries[section]
        if countries.isEmpty {
            return nil
        }
        if section == 0 {
            return ""
        }
        return UILocalizedIndexedCollation.current().sectionTitles[section - 1]

    }
//section are prepared as per localization of countries
    public func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return searchString != "" ? nil : UILocalizedIndexedCollation.current().sectionTitles
    }

    public func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        return UILocalizedIndexedCollation.current().section(forSectionIndexTitle: index + 1)
    }

    public func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        if allowMultipleSelection {
            if let cell = tableView.cellForRow(at: indexPath) {
                if cell.accessoryType == .checkmark {
                    cell.accessoryType = .none
                    let co = filteredCountries[indexPath.section][indexPath.row]
                    selectedCountries = selectedCountries.filter({
                        $0 != co
                    })
                    /// Comunicate to delegate
                    delegate?.countriesViewController(self, didUnselectCountry: co)

                } else {
                    /// Comunicate to delegate
                    delegate?.countriesViewController(self, didSelectCountry: filteredCountries[indexPath.section][indexPath.row])

                    selectedCountries.append(filteredCountries[indexPath.section][indexPath.row])
                    cell.accessoryType = .checkmark
                }
            }
        } else {

            /// Comunicate to delegate
            delegate?.countriesViewController(self, didSelectCountry: filteredCountries[indexPath.section][indexPath.row])

            self.dismiss(animated: true) { () -> Void in }

        }

    }

    /// Function to present a selector in a UIViewContoller claass
    ///
    /// - Parameter to: UIViewController current visibile
    public class func show(countriesViewController coVar: CountriesViewController, toVar: UIViewController) {

        let navController  = UINavigationController(rootViewController: coVar)

        toVar.present(navController, animated: true) { () -> Void in }

    }

}

/// Return partionated array
///
/// - Parameters:
///   - array: source array
///   - selector: selector
/// - Returns: Partionaed array
private func partionedArray<T: AnyObject>(_ array: [T], usingSelector selector: Selector) -> [[T]] {

    let collation = UILocalizedIndexedCollation.current()
    let numberOfSectionTitles = collation.sectionTitles.count
    var unsortedSections: [[T]] = Array(repeating: [], count: numberOfSectionTitles)

    for object in array {
        let sectionIndex = collation.section(for: object, collationStringSelector: selector)
        unsortedSections[sectionIndex].append(object)
    }

    var sortedSections: [[T]] = []

    for section in unsortedSections {
        let sortedSection = collation.sortedArray(from: section, collationStringSelector: selector) as! [T]
        sortedSections.append(sortedSection)
    }

    return sortedSections

}

#else


/// Class to select countries
// Change to NSViewController for AppKit
public final class CountriesViewController: NSViewController, NSSearchFieldDelegate, NSTableViewDelegate, NSTableViewDataSource {

    // filteredCountries is now a dictionary for section headers in AppKit
    // Key: Section Title (String, e.g., "A", "B", or "Favorites")
    // Value: Array of Countries
    public var unfilteredCountries: [String: [Country]]! { didSet { filteredCountries = unfilteredCountries } }
    public var filteredCountries: [String: [Country]]!
    // Store ordered keys for section display in the table view
    public var sectionTitles: [String] = []
    
    public var majorCountryLocaleIdentifiers: [String] = []
    public var delegate: CountriesViewControllerDelegate?
    public var allowMultipleSelection: Bool = true
    
    // NSViewController properties (no rightBarButtonItem like UIKit)
    // We'll use a custom Done/Cancel button setup if needed.
    
    public var selectedCountries: [Country] = [Country]() {
        didSet {
            // macOS UI typically handles "Done" differently. We'll skip enabling/disabling a button for now.
            // A separate 'Done' button or a 'Close' window button would handle this.
            // For simplicity, we'll keep the logic if a custom button is added later.
        }
    }

    /// Lazy var for table view
    public fileprivate(set) lazy var tableView: NSTableView = {
        let tableView = NSTableView()
        // Define a single column for country display
        let column = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("CountryColumn"))
        column.title = "Country"
        tableView.addTableColumn(column)
        tableView.headerView = nil // Hide the header for a list-style view
        tableView.allowsMultipleSelection = self.allowMultipleSelection // Enable/disable multiple selection
        tableView.usesAlternatingRowBackgroundColors = true
        return tableView
    }()

    /// Lazy var for scroll view to contain the table view
    public fileprivate(set) lazy var scrollView: NSScrollView = {
        let scrollView = NSScrollView()
        scrollView.documentView = self.tableView
        scrollView.hasVerticalScroller = true
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        return scrollView
    }()

    /// Lazy var for search bar (NSSearchField in AppKit)
    public fileprivate(set) lazy var searchField: NSSearchField = {
        let searchField = NSSearchField()
        searchField.placeholderString = "Search Country"
        searchField.translatesAutoresizingMaskIntoConstraints = false
        searchField.isBezeled = true
        // Set a delegate later
        return searchField
    }()

    /// Lazy var for main stack view container
    public fileprivate(set) lazy var stackView: NSStackView = {
        // AppKit's NSStackView is more flexible than UIStackView but used similarly here
        let stackView = NSStackView(views: [self.searchField, self.scrollView])
        stackView.orientation = .vertical
        stackView.alignment = .width
        stackView.spacing = 0
        stackView.translatesAutoresizingMaskIntoConstraints = false
        return stackView
    }()

    private var searchString: String = ""
    
    override public func loadView() {
        // Use a simple NSView as the main view
        self.view = NSView()
    }

    // viewDidLoad is now just viewDidLoad in AppKit, though viewWillAppear/viewDidAppear are common for setup
    override public func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.wantsLayer = true
        self.view.layer?.backgroundColor = NSColor.white.cgColor // Set background color
        
        // NSViewController doesn't have a navigationItem directly, but we can set the title
        self.title = allowMultipleSelection ? "Select Countries" : "Select Country"

        // For macOS, we'll rely on the window's close/miniaturize buttons.
        // If this VC is presented in a popover or sheet, the presenting VC handles dismissal.
        // A custom Cancel/Done button *can* be added to the view's layout if needed,
        // but it's not a standard 'navigationItem' element.

        /// Configure tableView and searchField
        searchField.delegate = self
        tableView.dataSource = self
        tableView.delegate = self
        
        // Register the assumed CountryCell or use a basic view-based cell (macOS standard)
        // For simplicity, we'll use basic NSTextField in the cell.
        
        /// Add stackview
        self.view.addSubview(stackView)

        // AutoLayout constraints for stack view
        let viewsDictionary = ["stackView": stackView]
        
        // Horizontal constraints
        self.view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "H:|-0-[stackView]-0-|",
            options: [],
            metrics: nil,
            views: viewsDictionary
        ))
        
        // Vertical constraints - macOS VCs often fill the entire view from top to bottom
        self.view.addConstraints(NSLayoutConstraint.constraints(
            withVisualFormat: "V:|-0-[stackView]-0-|",
            options: [],
            metrics: nil,
            views: viewsDictionary
        ))

        // Search field height constraint
        searchField.heightAnchor.constraint(equalToConstant: CGFloat(30)).isActive = true // Standard search field height
        
        /// Setup controller
        setupCountries()
    }

    // MARK: - Actions (Done/Cancel)

    // Example of how done/cancel actions would be wired to custom NSButtons
    @objc func done() {
        delegate?.countriesViewController(self, didSelectCountries: selectedCountries)
        // Dismiss the view/window/sheet
        self.view.window?.close()
    }

    @objc func cancel() {
        delegate?.countriesViewControllerDidCancel(self)
        self.view.window?.close()
    }

    // MARK: - NSSearchFieldDelegate (AppKit Search)

    public func controlTextDidChange(_ obj: Notification) {
        if let searchField = obj.object as? NSSearchField {
            let searchText = searchField.stringValue
            searchString = searchText
            searchForText(searchText)
        }
    }

    // MARK: - Filtering Logic (Modified for AppKit)
    
    fileprivate func searchForText(_ text: String) {
        if text.isEmpty {
            filteredCountries = unfilteredCountries
            sectionTitles = filteredCountries.keys.sorted() // Re-sort all sections
        } else {
            let allCountries: [Country] = Countries.countries.filter { $0.name.lowercased().range(of: text.lowercased()) != nil }
            // Use the macOS grouping logic
            filteredCountries = groupCountriesByFirstLetter(allCountries)
        }
        
        // Special section for major countries (if they are not part of the standard A-Z list)
        if !text.isEmpty {
            filteredCountries[""] = [] // Empty section for major countries not shown during search
        }
        
        // Ensure "Favorites" (empty string key) is always first if present
        sectionTitles = filteredCountries.keys.filter { !$0.isEmpty }.sorted()
        if filteredCountries[""] != nil {
             sectionTitles.insert("", at: 0)
        }
        
        tableView.reloadData()
    }

    // MARK: Viewing Countries (Modified for AppKit)
    
    fileprivate func setupCountries() {
        // Group all countries by their first letter
        let allGrouped = groupCountriesByFirstLetter(Countries.countries)
        
        // Get major countries and put them in a special "Favorites" section (empty string key)
        var groupedCountries: [String: [Country]] = allGrouped
        groupedCountries[""] = Countries.countriesFromCountryCodes(majorCountryLocaleIdentifiers) // First section for 'favorites'

        unfilteredCountries = groupedCountries
        filteredCountries = unfilteredCountries
        
        // Set the initial section titles order
        sectionTitles = filteredCountries.keys.filter { !$0.isEmpty }.sorted()
        if filteredCountries[""] != nil {
             sectionTitles.insert("", at: 0)
        }
        
        tableView.reloadData()

        // Scrolling to selected country logic is more complex in an NSTableView and will be omitted for simplicity,
        // as it often involves finding the row index within the full list of rows (including sections).
    }

    // MARK: - NSTableViewDataSource (AppKit Table View)

    // The number of rows is the sum of all countries in all sections (since NSTableView doesn't natively group)
    public func numberOfRows(in tableView: NSTableView) -> Int {
        // We will treat the section headers as rows themselves, so we need a calculated total
        return sectionTitles.reduce(0) { total, title in
            // +1 for the section header row itself
            return total + (filteredCountries[title]?.count ?? 0) + 1
        }
    }

    // MARK: - NSTableViewDelegate (AppKit Table View)

    // This is the core difference: NSTableView doesn't have sections like UITableView.
    // We use view-based cells and check if a row is a "Section Header" or a "Content Row".

    public func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        // Get the country for the given row index (a bit more complex with custom section logic)
        guard let (country, isHeader) = item(at: row) else {
            return nil
        }

        if isHeader {
            // This is a Section Header Row
            let identifier = NSUserInterfaceItemIdentifier("HeaderCell")
            let view = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTextField ?? {
                let header = NSTextField(labelWithString: "")
                header.identifier = identifier
                header.font = NSFont.boldSystemFont(ofSize: 12)
                header.isEditable = false
                header.drawsBackground = true
                header.backgroundColor = NSColor.windowBackgroundColor // A lighter shade for a header
                return header
            }()
            
            view.stringValue = country.name // The 'country' here is actually a placeholder with the section title
            return view
            
        } else {
            // This is a regular Country Row
            let identifier = NSUserInterfaceItemIdentifier("CountryCell")
            let view = tableView.makeView(withIdentifier: identifier, owner: self) as? NSTableCellView ?? {
                let cellView = NSTableCellView()
                cellView.identifier = identifier
                
                // Text label for country name and flag
                let textField = NSTextField(labelWithString: "")
                textField.translatesAutoresizingMaskIntoConstraints = false
                cellView.addSubview(textField)
                cellView.textField = textField
                
                // Detail label for phone extension (right aligned)
                let detailText = NSTextField(labelWithString: "")
                detailText.translatesAutoresizingMaskIntoConstraints = false
                detailText.alignment = .right
                detailText.textColor = NSColor.secondaryLabelColor
                cellView.addSubview(detailText)
                
                // Layout constraints
                NSLayoutConstraint.activate([
                    cellView.textField!.leadingAnchor.constraint(equalTo: cellView.leadingAnchor, constant: 8),
                    cellView.textField!.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    
                    detailText.trailingAnchor.constraint(equalTo: cellView.trailingAnchor, constant: -8),
                    detailText.centerYAnchor.constraint(equalTo: cellView.centerYAnchor),
                    detailText.widthAnchor.constraint(lessThanOrEqualToConstant: 80), // Limit width for extension
                    cellView.textField!.trailingAnchor.constraint(lessThanOrEqualTo: detailText.leadingAnchor, constant: -8)
                ])
                
                return cellView
            }()

            // Configure cell view
            view.textField?.stringValue = country.flag + " " + country.name
            
            // Assuming the detailText is the second text field we added
            if let detailText = view.subviews.first(where: { ($0 as? NSTextField)?.alignment == .right }) as? NSTextField {
                 detailText.stringValue = "+" + country.phoneExtension
            }
            
            // No accessoryType checkmark in AppKit, usually done by custom cell or an image view.
            // For a simple view, we'll skip the checkmark for brevity.
            
            return view
        }
    }

    public func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool {
        // Prevent selection of section header rows
        return !item(at: row)!.isHeader
    }

    public func tableViewSelectionDidChange(_ notification: Notification) {
        
        let selectedRows = tableView.selectedRowIndexes
        var currentSelection: [Country] = []
        
        selectedRows.forEach { row in
            if let (country, isHeader) = item(at: row), !isHeader {
                currentSelection.append(country)
            }
        }
        
        // Manual delegate calls for selection/unselection are tricky with AppKit's `selectionDidChange`
        // We will only report the final list of selected countries to match the `done()` behavior.
        // If single selection is allowed, we just pick the first one.
        
        if allowMultipleSelection {
            selectedCountries = currentSelection
            // The delegate calls for individual selection/unselection are omitted here
            // as the logic is difficult to map one-to-one with NSTableView's bulk selection update.
            // The final selection is reported via the `done()` method.
        } else if let row = tableView.selectedRowIndexes.first, let (country, isHeader) = item(at: row), !isHeader {
            // Single selection mode
            delegate?.countriesViewController(self, didSelectCountry: country)
            self.view.window?.close()
        }
    }
    
    // MARK: - Helper Methods

    /// Maps a global row index to a (Country, isHeader) tuple.
    private func item(at rowIndex: Int) -> (country: Country, isHeader: Bool)? {
        var runningRow = 0
        
        for sectionTitle in sectionTitles {
            let countries = filteredCountries[sectionTitle] ?? []
            
            // 1. Check for Header Row
            if runningRow == rowIndex {
                // Create a dummy Country object just to hold the section title
                let headerCountry = Country(countryCode: "", phoneExtension: "", isMain: false, flag: "")
//                headerCountry.name = sectionTitle.isEmpty ? "Major Countries" : sectionTitle // Use a proper title for the empty key
                return (headerCountry, true)
            }
            runningRow += 1
            
            // 2. Check for Content Rows
            for country in countries {
                if runningRow == rowIndex {
                    return (country, false)
                }
                runningRow += 1
            }
        }
        return nil
    }
    
    // Replacement for UILocalizedIndexedCollation on macOS
    private func groupCountriesByFirstLetter(_ array: [Country]) -> [String: [Country]] {
        let grouped = Dictionary(grouping: array) { country -> String in
            guard let firstLetter = country.name.uppercased().first else { return "#" }
            return String(firstLetter)
        }
        // Ensure countries within each group are sorted by name
        return grouped.mapValues { countries in
            countries.sorted { $0.name.localizedStandardCompare($1.name) == .orderedAscending }
        }
    }
}
#endif
