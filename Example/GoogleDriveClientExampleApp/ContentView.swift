import Dependencies
import GoogleDriveClient
import SwiftUI

struct ContentView: View {
  @Dependency(\.googleDriveClientAuthService) var auth
  @State var isSignedIn = false

  var body: some View {
    NavigationStack {
      Form {
        authSection
      }
      .navigationTitle("Example")
    }
    .task {
      isSignedIn = await auth.isSignedIn()
    }
    .onOpenURL { url in
      Task {
        try await auth.handleRedirect(url)
        isSignedIn = await auth.isSignedIn()
      }
    }
  }

  var authSection: some View {
    Section("Auth") {
      if !isSignedIn {
        Text("You are signed out")

        Button {
          Task {
            await auth.signIn()
            isSignedIn = await auth.isSignedIn()
          }
        } label: {
          Text("Sign In")
        }
      } else {
        Text("You are signed in")

        Button(role: .destructive) {
          Task {
            await auth.signOut()
            isSignedIn = await auth.isSignedIn()
          }
        } label: {
          Text("Sign Out")
        }
      }
    }
  }
}

#if DEBUG
struct ContentView_Previews: PreviewProvider {
  static var previews: some View {
    ContentView()
  }
}
#endif

extension GoogleDriveClient.Config: DependencyKey {
  public static let liveValue = Config(
    clientID: "437442953929-vk9agcivr59cldl92jqaiqdvlncpuh2v.apps.googleusercontent.com",
    redirectURI: "com.googleusercontent.apps.437442953929-vk9agcivr59cldl92jqaiqdvlncpuh2v://"
  )
}
