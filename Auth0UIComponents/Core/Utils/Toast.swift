/// Struct representing a toast notification with style, message, and duration.
struct Toast: Equatable {
  var style: ToastStyle
  var message: String
  var duration: Double = 3
}
