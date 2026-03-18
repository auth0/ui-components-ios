import Foundation

struct ProfileSection: Identifiable {
    let id: String
    let title: String
    let description: String?
    let rows: [ProfileOptionRow]
}
