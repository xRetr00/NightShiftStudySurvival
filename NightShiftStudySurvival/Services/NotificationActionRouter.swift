import Foundation

struct NotificationActionDecision {
    let cause: AlarmTransitionCause
    let userAction: AlarmUserAction
}

struct NotificationActionRouter {
    func decision(for actionIdentifier: String) -> NotificationActionDecision {
        switch actionIdentifier {
        case "SNOOZE":
            return NotificationActionDecision(cause: .userActionValid, userAction: .snooze)
        case "DISMISS":
            return NotificationActionDecision(cause: .userActionValid, userAction: .dismiss)
        case "OPEN_MATH_LOCK":
            return NotificationActionDecision(cause: .userActionValid, userAction: .startMathLock)
        default:
            return NotificationActionDecision(cause: .userActionValid, userAction: .openApp)
        }
    }
}
