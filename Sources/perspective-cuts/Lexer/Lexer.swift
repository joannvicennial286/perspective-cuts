import Foundation

struct LexerError: Error, CustomStringConvertible {
    let message: String
    let location: SourceLocation

    var description: String { "Error at \(location): \(message)" }
}

struct Lexer: Sendable {
    private let source: String

    init(source: String) {
        self.source = source
    }

    func tokenize() throws -> [Token] {
        var tokens: [Token] = []
        var index = source.startIndex
        var line = 1
        var column = 1

        while index < source.endIndex {
            let char = source[index]

            // Skip whitespace (not newlines)
            if char == " " || char == "\t" || char == "\r" {
                advance(&index, &column)
                continue
            }

            // Newlines
            if char == "\n" {
                tokens.append(Token(kind: .newline, location: SourceLocation(line: line, column: column)))
                advance(&index, &column)
                line += 1
                column = 1
                continue
            }

            // Comments
            if char == "/" && peek(index) == "/" {
                let commentStart = SourceLocation(line: line, column: column)
                advance(&index, &column) // skip first /
                advance(&index, &column) // skip second /
                var text = ""
                while index < source.endIndex && source[index] != "\n" {
                    text.append(source[index])
                    advance(&index, &column)
                }
                tokens.append(Token(kind: .comment(text.trimmingCharacters(in: .whitespaces)), location: commentStart))
                continue
            }

            // Block comments
            if char == "/" && peek(index) == "*" {
                let commentStart = SourceLocation(line: line, column: column)
                advance(&index, &column) // skip /
                advance(&index, &column) // skip *
                var text = ""
                while index < source.endIndex {
                    if source[index] == "*" && peek(index) == "/" {
                        advance(&index, &column) // skip *
                        advance(&index, &column) // skip /
                        break
                    }
                    if source[index] == "\n" {
                        line += 1
                        column = 0
                    }
                    text.append(source[index])
                    advance(&index, &column)
                }
                tokens.append(Token(kind: .comment(text.trimmingCharacters(in: .whitespacesAndNewlines)), location: commentStart))
                continue
            }

            // String literals
            if char == "\"" {
                let strLoc = SourceLocation(line: line, column: column)
                advance(&index, &column) // skip opening quote
                var value = ""
                while index < source.endIndex && source[index] != "\"" {
                    if source[index] == "\\" && peek(index) != nil {
                        advance(&index, &column)
                        let escaped = source[index]
                        switch escaped {
                        case "n": value.append("\n")
                        case "t": value.append("\t")
                        case "\\": value.append("\\")
                        case "\"": value.append("\"")
                        case "(":
                            // String interpolation: \(expr)
                            value.append("\\(")
                        default:
                            value.append("\\")
                            value.append(escaped)
                        }
                    } else if source[index] == "\n" {
                        line += 1
                        column = 0
                        value.append(source[index])
                    } else {
                        value.append(source[index])
                    }
                    advance(&index, &column)
                }
                if index < source.endIndex {
                    advance(&index, &column) // skip closing quote
                }
                tokens.append(Token(kind: .stringLiteral(value), location: strLoc))
                continue
            }

            // Numbers
            if char.isNumber {
                let numLoc = SourceLocation(line: line, column: column)
                var numStr = String(char)
                advance(&index, &column)
                while index < source.endIndex && (source[index].isNumber || source[index] == ".") {
                    numStr.append(source[index])
                    advance(&index, &column)
                }
                guard let value = Double(numStr) else {
                    throw LexerError(message: "Invalid number: \(numStr)", location: numLoc)
                }
                tokens.append(Token(kind: .numberLiteral(value), location: numLoc))
                continue
            }

            // Identifiers and keywords
            if char.isLetter || char == "_" {
                let idLoc = SourceLocation(line: line, column: column)
                var word = String(char)
                advance(&index, &column)
                while index < source.endIndex && (source[index].isLetter || source[index].isNumber || source[index] == "_" || source[index] == "'") {
                    word.append(source[index])
                    advance(&index, &column)
                }
                let kind: TokenKind = switch word {
                case "import": .importKeyword
                case "let": .letKeyword
                case "var": .varKeyword
                case "if": .ifKeyword
                case "else": .elseKeyword
                case "repeat": .repeatKeyword
                case "for": .forKeyword
                case "in": .inKeyword
                case "menu": .menuKeyword
                case "case": .caseKeyword
                case "func": .funcKeyword
                case "return": .returnKeyword
                case "contains": .containsKeyword
                case "true": .boolLiteral(true)
                case "false": .boolLiteral(false)
                default: .identifier(word)
                }
                tokens.append(Token(kind: kind, location: idLoc))
                continue
            }

            // Operators and punctuation
            let loc = SourceLocation(line: line, column: column)
            switch char {
            case "(": tokens.append(Token(kind: .leftParen, location: loc))
            case ")": tokens.append(Token(kind: .rightParen, location: loc))
            case "{": tokens.append(Token(kind: .leftBrace, location: loc))
            case "}": tokens.append(Token(kind: .rightBrace, location: loc))
            case "[": tokens.append(Token(kind: .leftBracket, location: loc))
            case "]": tokens.append(Token(kind: .rightBracket, location: loc))
            case ",": tokens.append(Token(kind: .comma, location: loc))
            case ":": tokens.append(Token(kind: .colon, location: loc))
            case "#": tokens.append(Token(kind: .hash, location: loc))
            case ".": tokens.append(Token(kind: .dot, location: loc))
            case "-" where peek(index) == ">":
                tokens.append(Token(kind: .arrow, location: loc))
                advance(&index, &column) // skip >
            case "=" where peek(index) == "=":
                tokens.append(Token(kind: .doubleEquals, location: loc))
                advance(&index, &column)
            case "!" where peek(index) == "=":
                tokens.append(Token(kind: .notEquals, location: loc))
                advance(&index, &column)
            case "=": tokens.append(Token(kind: .equals, location: loc))
            case ">": tokens.append(Token(kind: .greaterThan, location: loc))
            case "<": tokens.append(Token(kind: .lessThan, location: loc))
            default:
                throw LexerError(message: "Unexpected character: '\(char)'", location: loc)
            }
            advance(&index, &column)
        }

        tokens.append(Token(kind: .eof, location: SourceLocation(line: line, column: column)))
        return tokens
    }

    // MARK: - Helpers

    private func peek(_ index: String.Index) -> Character? {
        let next = source.index(after: index)
        guard next < source.endIndex else { return nil }
        return source[next]
    }

    private func advance(_ index: inout String.Index, _ column: inout Int) {
        index = source.index(after: index)
        column += 1
    }
}
