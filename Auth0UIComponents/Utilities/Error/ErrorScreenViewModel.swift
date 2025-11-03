import Foundation
struct ErrorScreenViewModel {
    let title: String
    let subTitle: AttributedString
    let textTap: () -> Void
    let buttonTitle: String

    let buttonClick: () -> Void
    
    init(title: String,
         subTitle: AttributedString,
         buttonTitle: String,
         textTap: @escaping () -> Void,
         buttonClick: @escaping () -> Void) {
        self.title = title
        self.subTitle = subTitle
        self.buttonTitle = buttonTitle
        self.buttonClick = buttonClick
        self.textTap = textTap
    }
    
    func handleTextTap() {
       textTap()
    }

    func handleButtonClick() {
        buttonClick()
    }
}

