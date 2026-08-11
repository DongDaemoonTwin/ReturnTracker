import Foundation

struct GmailAPIClient {
    func fetchRecentPurchaseEmails(accessToken: String) async throws -> [EmailMessageSnapshot] {
        var components = URLComponents(string: "https://gmail.googleapis.com/gmail/v1/users/me/messages")!
        components.queryItems = [
            URLQueryItem(name: "maxResults", value: "30"),
            URLQueryItem(
                name: "q",
                value: "newer_than:90d {subject:주문 subject:결제 subject:구매 subject:order subject:receipt} -subject:취소"
            )
        ]
        let list: GmailMessageList = try await request(components.url!, accessToken: accessToken)

        var snapshots: [EmailMessageSnapshot] = []
        for message in list.messages ?? [] {
            let url = URL(
                string: "https://gmail.googleapis.com/gmail/v1/users/me/messages/\(message.id)?format=full"
            )!
            let detail: GmailMessage = try await request(url, accessToken: accessToken)
            if let snapshot = detail.snapshot {
                snapshots.append(snapshot)
            }
        }
        return snapshots
    }

    private func request<Response: Decodable>(
        _ url: URL,
        accessToken: String
    ) async throws -> Response {
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse,
              (200...299).contains(httpResponse.statusCode) else {
            let status = (response as? HTTPURLResponse)?.statusCode ?? -1
            let message = String(data: data, encoding: .utf8)?.prefix(160) ?? ""
            throw GmailAPIError.requestFailed(status: status, message: String(message))
        }
        return try JSONDecoder().decode(Response.self, from: data)
    }
}

enum GmailAPIError: LocalizedError {
    case requestFailed(status: Int, message: String)

    var errorDescription: String? {
        switch self {
        case let .requestFailed(status, _):
            status == 401
                ? "Gmail 권한이 만료되었습니다. 다시 동기화해 주세요."
                : "Gmail 요청에 실패했습니다. (\(status))"
        }
    }
}

private struct GmailMessageList: Decodable {
    let messages: [GmailMessageReference]?
}

private struct GmailMessageReference: Decodable {
    let id: String
}

private struct GmailMessage: Decodable {
    let id: String
    let internalDate: String?
    let payload: GmailPayload?

    var snapshot: EmailMessageSnapshot? {
        guard let payload else { return nil }
        var headers: [String: String] = [:]
        for header in payload.headers ?? [] where headers[header.name.lowercased()] == nil {
            headers[header.name.lowercased()] = header.value
        }
        var plainBodies: [String] = []
        var htmlBodies: [String] = []
        payload.collectBodies(plain: &plainBodies, html: &htmlBodies)
        let body = plainBodies.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
        let resolvedBody = body.isEmpty
            ? htmlBodies.joined(separator: "\n").strippingHTML
            : body

        return EmailMessageSnapshot(
            id: id,
            subject: headers["subject"] ?? "",
            from: headers["from"] ?? "",
            receivedAt: internalDate.flatMap(Double.init).map { Date(timeIntervalSince1970: $0 / 1000) } ?? .now,
            body: resolvedBody
        )
    }
}

private struct GmailPayload: Decodable {
    let mimeType: String?
    let headers: [GmailHeader]?
    let body: GmailBody?
    let parts: [GmailPayload]?

    func collectBodies(plain: inout [String], html: inout [String]) {
        if let encoded = body?.data,
           let decoded = encoded.base64URLDecodedString,
           !decoded.isEmpty {
            if mimeType?.hasPrefix("text/plain") == true {
                plain.append(decoded)
            } else if mimeType?.hasPrefix("text/html") == true {
                html.append(decoded)
            }
        }
        for part in parts ?? [] {
            part.collectBodies(plain: &plain, html: &html)
        }
    }
}

private struct GmailHeader: Decodable {
    let name: String
    let value: String
}

private struct GmailBody: Decodable {
    let data: String?
}

private extension String {
    var base64URLDecodedString: String? {
        var value = replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        value += String(repeating: "=", count: (4 - value.count % 4) % 4)
        guard let data = Data(base64Encoded: value) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    var strippingHTML: String {
        replacingMatches("<style[^>]*>.*?</style>", with: " ", dotMatchesLineSeparators: true)
            .replacingMatches("<script[^>]*>.*?</script>", with: " ", dotMatchesLineSeparators: true)
            .replacingMatches("<br\\s*/?>|</p>|</div>|</tr>", with: "\n")
            .replacingMatches("<[^>]+>", with: " ")
            .replacingOccurrences(of: "&nbsp;", with: " ")
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
            .replacingMatches("[ \\t]+", with: " ")
            .replacingMatches("\\n{3,}", with: "\n\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    func replacingMatches(
        _ pattern: String,
        with replacement: String,
        dotMatchesLineSeparators: Bool = false
    ) -> String {
        var options: NSRegularExpression.Options = .caseInsensitive
        if dotMatchesLineSeparators {
            options.insert(.dotMatchesLineSeparators)
        }
        guard let expression = try? NSRegularExpression(pattern: pattern, options: options) else {
            return self
        }
        return expression.stringByReplacingMatches(
            in: self,
            range: NSRange(startIndex..., in: self),
            withTemplate: replacement
        )
    }
}
