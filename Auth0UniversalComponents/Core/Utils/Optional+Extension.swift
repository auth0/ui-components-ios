extension Optional {
    
    /// Returns a Boolean value indicating whether the optional is NOT nil.
    public var isNotNil: Bool {
        return self != nil
    }
    
    /// Returns a Boolean value indicating whether the optional is nil.
    public var isNil: Bool {
        return self == nil
    }
}
