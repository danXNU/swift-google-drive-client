import Foundation
#if os(Linux)
import FoundationNetworking
#endif

public struct GetAbout: Sendable {
  public enum Error: Swift.Error, Sendable, Equatable {
    case notAuthorized
    case response(statusCode: Int?, data: Data)
  }

  public typealias Run = @Sendable () async throws -> About

  public init(run: @escaping Run) {
    self.run = run
  }

  public var run: Run

  public func callAsFunction() async throws -> About {
    try await run()
  }
}

extension GetAbout {
  public static func live(
    auth: Auth,
    keychain: Keychain,
    httpClient: HTTPClient
  ) -> GetAbout {
    GetAbout {
      try await auth.refreshToken()

      guard let credentials = await keychain.loadCredentials() else {
        throw Error.notAuthorized
      }

      let request: URLRequest = {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.googleapis.com"
        components.path = "/drive/v3/about"
        components.queryItems = [
          URLQueryItem(name: "fields", value: About.apiFields),
        ]

        var request = URLRequest(url: components.url!)
        request.httpMethod = "GET"
        request.setValue(
          "\(credentials.tokenType) \(credentials.accessToken)",
          forHTTPHeaderField: "Authorization"
        )

        return request
      }()

      let (responseData, response) = try await httpClient.data(for: request)
      let statusCode = (response as? HTTPURLResponse)?.statusCode

      guard let statusCode, (200..<300).contains(statusCode) else {
        throw Error.response(statusCode: statusCode, data: responseData)
      }

      return try JSONDecoder.api.decode(About.self, from: responseData)
    }
  }
}
