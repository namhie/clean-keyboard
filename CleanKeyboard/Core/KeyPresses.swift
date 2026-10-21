import Foundation
import Observation
import Synchronization

/// Состояние одной клавиши на схеме. Отдельный объект на клавишу — при нажатии
/// перерисовывается только она, а не вся клавиатура.
@Observable
final class KeyVisual {
    var isDown = false
    var isCleaned = false
}

/// Собирает нажатия с потока тапа и отдаёт их в главный поток пачкой — один раз за проход
/// главного цикла, а не отдельным `async` на каждое событие. Когда ладонь задевает
/// десяток клавиш сразу, интерфейс обновляется одной транзакцией.
nonisolated final class PressBuffer: Sendable {
    struct Press: Sendable {
        let code: UInt16
        let isDown: Bool
    }

    private struct State {
        var pending: [Press] = []
        var flushScheduled = false
    }

    private let state = Mutex(State())
    private let deliver: @MainActor @Sendable ([Press]) -> Void

    init(deliver: @escaping @MainActor @Sendable ([Press]) -> Void) {
        self.deliver = deliver
    }

    func add(_ code: UInt16, isDown: Bool) {
        let needsFlush = state.withLock { state -> Bool in
            state.pending.append(Press(code: code, isDown: isDown))
            defer { state.flushScheduled = true }
            return !state.flushScheduled
        }
        guard needsFlush else { return }
        DispatchQueue.main.async { [self] in
            let presses = state.withLock { state -> [Press] in
                defer {
                    state.pending.removeAll(keepingCapacity: true)
                    state.flushScheduled = false
                }
                return state.pending
            }
            MainActor.assumeIsolated { deliver(presses) }
        }
    }
}
