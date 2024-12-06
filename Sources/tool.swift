import Foundation
import ArgumentParser

// https://id.atlassian.com/manage-profile/security/api-tokens

struct Config {
    let user: String
    let token: String
    let url: String

    static let mine = Config(
        user: "**USERNAME** @**DOMAIN**",
        token: "** TOKEN **",
        url: "https://**JIRA_SERVER**"
    )
}

struct CreateIssueRequest: Codable {
    struct Project: Codable {
        let key: String
    }

    struct IssueType: Codable {
        let name: String
    }

    struct Fields: Codable {
        let project: Project
        let summary: String
        let description: String
        let issuetype: IssueType
        let labels: [String]
    }

    let fields: Fields
}

struct CreateIssueResponse: Codable {
    let id: String
    let key: String
    let `self`: String
}

struct Jira {
    let config: Config

    func jira(url: String) -> URLRequest {
        let auth = "\(config.user):\(config.token)".data(using: .utf8)!.base64EncodedString()
        var req = URLRequest(url: URL(string: url)!)
        req.addValue("Basic \(auth)", forHTTPHeaderField: "Authorization")
        req.addValue("application/json", forHTTPHeaderField: "Content-Type")
        return req
    }

    func createIssue(issue: CreateIssueRequest) async throws -> CreateIssueResponse {
        var req = jira(url: "\(config.url)/rest/api/2/issue")
        req.httpMethod = "POST"
        req.httpBody = try JSONEncoder().encode(issue)
        let data = try await URLSession.shared.data(for: req).0
        return try JSONDecoder().decode(CreateIssueResponse.self, from: data)
    }
}

@main
struct Tool: AsyncParsableCommand {
    @Argument(help: "The title or summary of the ticket")
    var title: String

    @Argument(help: "The content of the ticket")
    var descr: String

    @Flag(name: [.customShort("r"), .long], help: "Actually perform the request")
    var doit = false

    func run() async throws {
        let request = CreateIssueRequest(
            fields: .init(
                project: .init(key: "STX"),
                summary: title,
                description: descr,
                issuetype: .init(name: "Bug"),
                labels: ["iOS"]
            )
        )

        guard doit else {
            print(self)
            print(" - ")
            print(request)
            return
        }

        print("Creating ticket...")
        let J = Jira(config: Config.mine)
        let respose = try await J.createIssue(issue: request)
        print(respose)
    }
}

