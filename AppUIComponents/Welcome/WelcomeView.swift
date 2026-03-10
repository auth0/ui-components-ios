import SwiftUI
import Auth0UniversalComponents

struct WelcomeView: View {
    
    // MARK: - Properties
    @StateObject private var viewModel: WelcomeViewModel
    
    // MARK: - Router
    @EnvironmentObject var router: Router<SampleAppRoute>
    
    // MARK: - Init
    init(viewModel: WelcomeViewModel) {
        _viewModel = StateObject(wrappedValue: viewModel)
    }
    
    // MARK: - Main body
    var body: some View {
        VStack(alignment: .center, spacing: 24) {
            VStack(spacing: 8) {
                Text("Hi,")
                    .font(.system(size: 28, weight: .semibold))
                    .foregroundStyle(Color.black)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                
                Text("Discover how to utilize auth0’s powerful native SDK and account API in this app.")
                    .font(.system(size: 17, weight: .regular))
                    .foregroundStyle(Color("606060", bundle: .main))
                    .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            
            makeAvailableOptionsList()
            
            logoutButton()
        }
        .padding(24)
        #if !os(macOS)
        .navigationBarBackButtonHidden()
        #endif
        .background(Color("FAF9F9", bundle: .main))
    }
    
    @ViewBuilder
    private func makeAvailableOptionsList() -> some View {
        // 1. Define two flexible columns
        let columns = [
            GridItem(.flexible()),
            GridItem(.flexible())
        ]
        
        ScrollView {
            // 2. Pass columns to the LazyVGrid
            LazyVGrid(columns: columns, spacing: 16) {
                ForEach($viewModel.options) { item in
                    VStack(alignment: .leading, spacing: 24) {
                        Image(item.icon.wrappedValue, bundle: .main)
                            .frame(width: 24, height: 24)
                        
                        Text(item.title.wrappedValue)
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundStyle(Color("191919", bundle: .main))
                            .frame(maxWidth: .infinity, alignment: .topLeading)
                    }
                    .padding(.all, 20)
                    .contentShape(Rectangle())
                    .background(Color.white)
                    .cornerRadius(20)
                    .overlay {
                        RoundedRectangle(cornerRadius: 20)
                            .inset(by: 0.5)
                            .stroke(Color("E8E8E8", bundle: .main), lineWidth: 1)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 6, x: 0, y: 2)
                    .onTapGesture {
                        guard let route = item.route.wrappedValue else {
                            return
                        }
                        router.navigate(to: route)
                    }
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private func logoutButton() -> some View {
        Button {
            viewModel.performLogout {
                router.pop()
            }
        } label: {
            Text("Log out")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color("262420", bundle: .main))
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.vertical, 14)
        }
    }
}
