/// Which way leads when the tenant offers both a one-time code and a password for an email or phone number. The other
/// is still one tap away on the same screen.
public enum EmbeddedLoginPreference: Sendable, Equatable {
    /// Whichever the server lists first. The default.
    case server
    /// A code is sent at once; the password is the alternative.
    case code
    /// The password is asked for; the code is the alternative.
    case password
}
