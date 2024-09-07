import XCTest
@testable import GoogleDriveClient
#if os(Linux)
import FoundationNetworking
#endif

final class GetAboutTests: XCTestCase {
  func testGetAbout() async throws {
    let credentials = Credentials(
      accessToken: "access-token-1",
      expiresAt: Date(),
      refreshToken: "refresh-token-1",
      tokenType: "token-type-1"
    )
    let httpRequests = ActorIsolated<[URLRequest]>([])
    let didRefreshToken = ActorIsolated(0)
    let GetAbout = GetAbout.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {
          await didRefreshToken.withValue { $0 += 1 }
        }
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { credentials }
        return keychain
      }(),
      httpClient: .init { request in
        await httpRequests.withValue { $0.append(request) }
        return (
          """
          {
            "user": {
              "displayName": "Test User",
              "photoLink": "https://lh3.googleusercontent.com/a/fake_hash",
              "emailAddress": "user@test.com"
            },
            "storageQuota": {
              "limit": "1000000000000",
              "usage": "70000000000"
            },
            "maxUploadSize": "5242880000000",
            "appInstalled": true
          }
          """.data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 200,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      }
    )

    let about = try await GetAbout()

    await didRefreshToken.withValue {
      XCTAssertEqual($0, 1)
    }
    await httpRequests.withValue {
      let url = URL(string: "https://www.googleapis.com/drive/v3/about?fields=\(About.apiFields)")!
      var expectedRequest = URLRequest(url: url)
      expectedRequest.httpMethod = "GET"
      expectedRequest.allHTTPHeaderFields = [
        "Authorization": "\(credentials.tokenType) \(credentials.accessToken)"
      ]
      XCTAssertEqual($0, [expectedRequest])
      XCTAssertNil($0.first?.httpBody)
    }
    XCTAssertEqual(about, About(
      storageQuota: StorageQuota(
        limit: "1000000000000",
        usage: "70000000000"
      ),
      appInstalled: true,
      maxUploadSize: "5242880000000",
      user: User(
        displayName: "Test User",
        emailAddress: "user@test.com",
        photoLink: "https://lh3.googleusercontent.com/a/fake_hash"
      )
    ))
  }

  func testGetAboutErrorResponse() async {
    let GetAbout = GetAbout.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {}
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = {
          Credentials(
            accessToken: "",
            expiresAt: Date(),
            refreshToken: "",
            tokenType: ""
          )
        }
        return keychain
      }(),
      httpClient: .init { request in
        (
          "Error!!!".data(using: .utf8)!,
          HTTPURLResponse(
            url: URL(filePath: "/"),
            statusCode: 500,
            httpVersion: nil,
            headerFields: nil
          )!
        )
      }
    )

    do {
      _ = try await GetAbout()
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? GetAbout.Error,
        .response(
          statusCode: 500,
          data: "Error!!!".data(using: .utf8)!
        ),
        "Expected to throw response error, got \(error)"
      )
    }
  }

  func testGetAboutWhenNotAuthorized() async {
    let GetAbout = GetAbout.live(
      auth: {
        var auth = Auth.unimplemented()
        auth.refreshToken = {}
        return auth
      }(),
      keychain: {
        var keychain = Keychain.unimplemented()
        keychain.loadCredentials = { nil }
        return keychain
      }(),
      httpClient: .unimplemented()
    )

    do {
      _ = try await GetAbout()
      XCTFail("Expected to throw, but didn't")
    } catch {
      XCTAssertEqual(
        error as? GetAbout.Error, .notAuthorized,
        "Expected to throw .notAuthorized, got \(error)"
      )
    }
  }
}
