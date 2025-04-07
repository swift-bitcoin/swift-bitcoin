enum Token: Equatable {
    case fragment(String)
    case wrapper(String)
    case argument(String)
    case parenOpen // (
    case parenClose // )
    case comma // ,
    case colon // :

    static func tokenize(_ source: String) -> [Token] {
        var strings = [String]()
        for char in source {
            let current = char.description
            let punctuation = ["(", ")", ",", ":"]
            if punctuation.contains(current) {
                strings.append(current)
            } else if let last = strings.last, !punctuation.contains(last) {
                strings[strings.endIndex - 1].append(char)
            } else {
                strings.append(current)
            }
        }
        var tokens = [Token]()
        for i in strings.indices {
            let current = strings[i]
            switch current {
            case "(": tokens.append(.parenOpen)
            case ")": tokens.append(.parenClose)
            case ",": tokens.append(.comma)
            case ":": tokens.append(.colon)
            default:
                let next = i + 1
                if next == strings.endIndex {
                    tokens.append(.argument(current))
                } else if strings[next] == "," || strings[next] == ")" {
                    tokens.append(.argument(current))
                } else if strings[next] == "(" {
                    tokens.append(.fragment(current))
                } else if strings[next] == ":" {
                    for c in current {
                        tokens.append(.wrapper(c.description))
                    }
                }
            }
        }
        return tokens
    }
}
