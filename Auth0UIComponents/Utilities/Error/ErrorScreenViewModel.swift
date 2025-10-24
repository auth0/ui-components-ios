struct ErrorScreenViewModel {
    let title: String
    let subTitle: String
    let buttonTitle: String

    let buttonClick: () -> Void
    
    init(title: String,
         subTitle: String,
         buttonTitle: String,
         buttonClick: @escaping () -> Void) {
        self.title = title
        self.subTitle = subTitle
        self.buttonTitle = buttonTitle
        self.buttonClick = buttonClick
    }
    
    func handleButtonClick() {
        buttonClick()
    }
}

