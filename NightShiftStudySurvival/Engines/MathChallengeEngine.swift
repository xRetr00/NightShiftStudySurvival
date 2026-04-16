import Foundation

struct MathChallenge {
    let prompt: String
    let answer: Int
}

struct MathChallengeEngine {
    func nextChallenge(difficulty: String) -> MathChallenge {
        switch difficulty.lowercased() {
        case "easy":
            return easyChallenge()
        case "brutal":
            return brutalChallenge()
        default:
            return mediumChallenge()
        }
    }

    private func easyChallenge() -> MathChallenge {
        let a = Int.random(in: 2...12)
        let b = Int.random(in: 2...12)
        if Bool.random() {
            return MathChallenge(prompt: "\(a) + \(b) = ?", answer: a + b)
        }
        return MathChallenge(prompt: "\(a + b) - \(a) = ?", answer: b)
    }

    private func mediumChallenge() -> MathChallenge {
        let a = Int.random(in: 8...25)
        let b = Int.random(in: 6...20)
        let op = Int.random(in: 0...2)

        switch op {
        case 0:
            return MathChallenge(prompt: "\(a) + \(b) = ?", answer: a + b)
        case 1:
            return MathChallenge(prompt: "\(a) - \(b) = ?", answer: a - b)
        default:
            let m = Int.random(in: 4...12)
            return MathChallenge(prompt: "\(m) x \(b) = ?", answer: m * b)
        }
    }

    private func brutalChallenge() -> MathChallenge {
        let form = Int.random(in: 0...2)

        switch form {
        case 0:
            let a = Int.random(in: 15...45)
            let b = Int.random(in: 12...35)
            let c = Int.random(in: 3...12)
            return MathChallenge(prompt: "(\(a) + \(b)) - \(c) = ?", answer: (a + b) - c)
        case 1:
            let a = Int.random(in: 11...24)
            let b = Int.random(in: 7...16)
            let c = Int.random(in: 2...8)
            return MathChallenge(prompt: "\(a) x \(b) - \(c) = ?", answer: (a * b) - c)
        default:
            let divisor = Int.random(in: 4...12)
            let quotient = Int.random(in: 6...14)
            let dividend = divisor * quotient
            return MathChallenge(prompt: "\(dividend) / \(divisor) = ?", answer: quotient)
        }
    }
}
