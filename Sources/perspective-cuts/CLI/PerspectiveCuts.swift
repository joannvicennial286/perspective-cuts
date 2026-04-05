import ArgumentParser
import Foundation

@main
struct PerspectiveCuts: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "perspective",
        abstract: "Perspective Cuts — A text-based Apple Shortcuts compiler",
        version: "0.1.0",
        subcommands: [Compile.self, Validate.self, Actions.self, Discover.self]
    )
}

// MARK: - Compile

struct Compile: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Compile a .perspective file to a .shortcut file"
    )

    @Argument(help: "The .perspective file to compile")
    var file: String

    @Option(name: .shortAndLong, help: "Output path for the compiled .shortcut file")
    var output: String?

    @Flag(name: .long, help: "Sign the shortcut for import")
    var sign: Bool = false

    @Flag(name: .long, help: "Install directly to Shortcuts app (bypasses import, preserves all enum values)")
    var install: Bool = false

    func run() throws {
        let source = try readSource(file)
        let tokens = try Lexer(source: source).tokenize()
        let nodes = try Parser(tokens: tokens).parse()
        let registry = try ActionRegistry.load()
        let plist = try Compiler(registry: registry).compile(nodes: nodes)

        // Determine output path
        let inputURL = URL(fileURLWithPath: file)
        let baseName = inputURL.deletingPathExtension().lastPathComponent
        let outputPath = output ?? "\(baseName).shortcut"
        let outputURL = URL(fileURLWithPath: outputPath)

        // Extract actions and name for install mode
        let actions = plist["WFWorkflowActions"] as? [[String: Any]] ?? []
        let shortcutName = plist["WFWorkflowName"] as? String ?? baseName

        // Serialize to binary plist
        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .binary,
            options: 0
        )
        try data.write(to: outputURL)

        if install {
            try installToShortcuts(name: shortcutName, actions: actions)
        } else if sign {
            let signedPath = outputURL.deletingPathExtension().path + "-signed.shortcut"
            let signedURL = URL(fileURLWithPath: signedPath)
            try Signer.sign(input: outputURL, output: signedURL)
            // Replace unsigned with signed
            try FileManager.default.removeItem(at: outputURL)
            try FileManager.default.moveItem(at: signedURL, to: outputURL)
            FileHandle.standardError.write(Data("Compiled and signed: \(outputURL.path)\n".utf8))
        } else {
            FileHandle.standardError.write(Data("Compiled: \(outputURL.path)\n".utf8))
            FileHandle.standardError.write(Data("Note: Run with --sign to create an importable shortcut.\n".utf8))
        }
    }

    private func installToShortcuts(name: String, actions: [[String: Any]]) throws {
        let dbPath = NSHomeDirectory() + "/Library/Shortcuts/Shortcuts.sqlite"
        guard FileManager.default.fileExists(atPath: dbPath) else {
            throw ValidationError("Shortcuts database not found at \(dbPath)")
        }

        var db: OpaquePointer?
        guard sqlite3_open(dbPath, &db) == SQLITE_OK, let db else {
            throw ValidationError("Cannot open Shortcuts database")
        }
        defer { sqlite3_close(db) }

        // Serialize actions array to binary plist
        let actionsData = try PropertyListSerialization.data(
            fromPropertyList: actions,
            format: .binary,
            options: 0
        )

        // Check if shortcut with this name already exists
        var checkStmt: OpaquePointer?
        sqlite3_prepare_v2(db, "SELECT Z_PK FROM ZSHORTCUT WHERE ZNAME = ?", -1, &checkStmt, nil)
        sqlite3_bind_text(checkStmt, 1, name, -1, nil)

        if sqlite3_step(checkStmt) == SQLITE_ROW {
            // Update existing shortcut's actions
            let existingPK = sqlite3_column_int64(checkStmt, 0)
            sqlite3_finalize(checkStmt)

            var updateStmt: OpaquePointer?
            sqlite3_prepare_v2(db, "UPDATE ZSHORTCUTACTIONS SET ZDATA = ? WHERE ZSHORTCUT = ?", -1, &updateStmt, nil)
            sqlite3_bind_blob(updateStmt, 1, (actionsData as NSData).bytes, Int32(actionsData.count), nil)
            sqlite3_bind_int64(updateStmt, 2, existingPK)

            guard sqlite3_step(updateStmt) == SQLITE_DONE else {
                sqlite3_finalize(updateStmt)
                throw ValidationError("Failed to update shortcut actions")
            }
            sqlite3_finalize(updateStmt)
            FileHandle.standardError.write(Data("Updated '\(name)' in Shortcuts app (PK=\(existingPK)). Restart Shortcuts to see changes.\n".utf8))
        } else {
            sqlite3_finalize(checkStmt)
            FileHandle.standardError.write(Data("Shortcut '\(name)' not found. Import with --sign first, then use --install to update.\n".utf8))
        }
    }

    private func readSource(_ path: String) throws -> String {
        let url = URL(fileURLWithPath: path)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(path)")
        }
        return try String(contentsOf: url, encoding: .utf8)
    }
}

// MARK: - Validate

struct Validate: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Check a .perspective file for syntax errors without compiling"
    )

    @Argument(help: "The .perspective file to validate")
    var file: String

    func run() throws {
        let url = URL(fileURLWithPath: file)
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ValidationError("File not found: \(file)")
        }
        let source = try String(contentsOf: url, encoding: .utf8)
        let tokens = try Lexer(source: source).tokenize()
        let nodes = try Parser(tokens: tokens).parse()

        // Validate action names against registry
        let registry = try ActionRegistry.load()
        for node in nodes {
            try validateNode(node, registry: registry)
        }

        print("Valid. \(nodes.count) statements parsed.")
    }

    private func validateNode(_ node: ASTNode, registry: ActionRegistry) throws {
        switch node {
        case .actionCall(let name, _, _, let location):
            // Dotted names are raw 3rd party identifiers — always valid
            if registry.actions[name] == nil && !name.contains(".") {
                var msg = "Unknown action: '\(name)'"
                if let suggestion = registry.findClosestAction(to: name) {
                    msg += ". Did you mean '\(suggestion)'?"
                }
                throw ValidationError("\(location): \(msg)")
            }
        case .ifStatement(_, let thenBody, let elseBody, _):
            for child in thenBody { try validateNode(child, registry: registry) }
            if let elseBody { for child in elseBody { try validateNode(child, registry: registry) } }
        case .repeatLoop(_, let body, _), .forEachLoop(_, _, let body, _):
            for child in body { try validateNode(child, registry: registry) }
        case .menu(_, let cases, _):
            for c in cases { for child in c.body { try validateNode(child, registry: registry) } }
        case .functionDeclaration(_, let body, _):
            for child in body { try validateNode(child, registry: registry) }
        default: break
        }
    }
}

// MARK: - Actions

struct Actions: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "List available actions"
    )

    @Argument(help: "Optional search term to filter actions")
    var search: String?

    func run() throws {
        let registry = try ActionRegistry.load()
        var results = registry.actions.sorted(by: { $0.key < $1.key })

        if let search = search?.lowercased() {
            results = results.filter {
                $0.key.lowercased().contains(search) ||
                $0.value.description.lowercased().contains(search)
            }
        }

        if results.isEmpty {
            print("No actions found.")
            return
        }

        print("\(results.count) actions:")
        print("")
        for (name, def) in results {
            print("  \(name)")
            print("    \(def.description)")
            print("    Identifier: \(def.identifier)")
            if !def.parameters.isEmpty {
                let paramNames = def.parameters.keys.sorted().joined(separator: ", ")
                print("    Parameters: \(paramNames)")
            }
            print("")
        }
    }
}

// MARK: - Discover

struct Discover: ParsableCommand {
    static let configuration = CommandConfiguration(
        abstract: "Discover actions from installed apps via the Shortcuts ToolKit database"
    )

    @Argument(help: "Search term to filter by app name or action identifier")
    var search: String?

    @Flag(name: .long, help: "Show only 3rd party apps (exclude Apple and built-in actions)")
    var thirdParty: Bool = false

    func run() throws {
        let toolkitPath = try findToolKitDB()
        let db = try ToolKitReader(path: toolkitPath)
        let actions = try db.discoverActions(search: search, thirdPartyOnly: thirdParty)

        if actions.isEmpty {
            print("No actions found.")
            return
        }

        // Group by app
        var grouped: [(String, [(id: String, name: String, params: [String])])] = []
        var currentApp = ""
        var currentActions: [(id: String, name: String, params: [String])] = []

        for action in actions {
            let app = appName(from: action.id)
            if app != currentApp {
                if !currentActions.isEmpty {
                    grouped.append((currentApp, currentActions))
                }
                currentApp = app
                currentActions = []
            }
            currentActions.append(action)
        }
        if !currentActions.isEmpty {
            grouped.append((currentApp, currentActions))
        }

        print("\(actions.count) actions from \(grouped.count) apps:\n")
        for (app, appActions) in grouped {
            print("  \(app)")
            for action in appActions {
                let paramStr = action.params.isEmpty ? "" : "(\(action.params.joined(separator: ", ")))"
                print("    \(action.id)\(paramStr)")
                if !action.name.isEmpty && action.name != action.id.split(separator: ".").last.map(String.init) ?? "" {
                    print("      \"\(action.name)\"")
                }
            }
            print("")
        }

        print("Use any identifier directly in .perspective files:")
        print("  \(actions.first?.id ?? "com.example.app.Action")(param: \"value\") -> result")
    }

    private func findToolKitDB() throws -> String {
        let base = NSHomeDirectory() + "/Library/Shortcuts/ToolKit"
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: base) else {
            throw ValidationError("ToolKit directory not found at \(base)")
        }
        guard let db = contents.first(where: { $0.hasPrefix("Tools-prod") && $0.hasSuffix(".sqlite") }) else {
            throw ValidationError("No ToolKit database found in \(base)")
        }
        return base + "/" + db
    }

    private func appName(from identifier: String) -> String {
        let parts = identifier.split(separator: ".")
        if parts.count >= 3 {
            return parts.prefix(3).joined(separator: ".")
        }
        return identifier
    }
}

// MARK: - ToolKit Database Reader

import SQLite3

struct ToolKitReader {
    let db: OpaquePointer

    init(path: String) throws {
        var dbPointer: OpaquePointer?
        guard sqlite3_open_v2(path, &dbPointer, SQLITE_OPEN_READONLY, nil) == SQLITE_OK,
              let db = dbPointer else {
            throw ValidationError("Cannot open ToolKit database at \(path)")
        }
        self.db = db
    }

    func discoverActions(search: String?, thirdPartyOnly: Bool) throws -> [(id: String, name: String, params: [String])] {
        var results: [(id: String, name: String, params: [String])] = []

        // Get all tools
        var query = "SELECT t.rowId, t.id FROM Tools t"
        if thirdPartyOnly {
            query += " WHERE t.id NOT LIKE 'is.workflow.actions.%' AND t.id NOT LIKE 'com.apple.%'"
        }
        query += " ORDER BY t.id"

        var stmt: OpaquePointer?
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return results }
        defer { sqlite3_finalize(stmt) }

        while sqlite3_step(stmt) == SQLITE_ROW {
            let rowId = sqlite3_column_int64(stmt, 0)
            guard let idCStr = sqlite3_column_text(stmt, 1) else { continue }
            let toolId = String(cString: idCStr)

            // Filter by search
            if let search = search?.lowercased() {
                guard toolId.lowercased().contains(search) else { continue }
            }

            // Get display name
            let name = getLocalization(toolId: Int(rowId))

            // Get parameters
            let params = getParameters(toolId: Int(rowId))

            results.append((id: toolId, name: name, params: params))
        }

        return results
    }

    private func getLocalization(toolId: Int) -> String {
        var stmt: OpaquePointer?
        let query = "SELECT name FROM ToolLocalizations WHERE toolId = ? AND locale = 'en' LIMIT 1"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return "" }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(toolId))
        if sqlite3_step(stmt) == SQLITE_ROW, let cstr = sqlite3_column_text(stmt, 0) {
            return String(cString: cstr)
        }
        return ""
    }

    private func getParameters(toolId: Int) -> [String] {
        var params: [String] = []
        var stmt: OpaquePointer?
        let query = "SELECT key FROM Parameters WHERE toolId = ? ORDER BY sortOrder"
        guard sqlite3_prepare_v2(db, query, -1, &stmt, nil) == SQLITE_OK else { return params }
        defer { sqlite3_finalize(stmt) }
        sqlite3_bind_int64(stmt, 1, Int64(toolId))
        while sqlite3_step(stmt) == SQLITE_ROW {
            if let cstr = sqlite3_column_text(stmt, 0) {
                params.append(String(cString: cstr))
            }
        }
        return params
    }
}
