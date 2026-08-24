//
//  AuthFlow.swift
//  Seans
//
//  Created by Claude on 23.08.2026.
//

import SwiftUI

struct AuthFlow: View {
    var body: some View {
        NavigationStack {
            SignInScreen()
        }
    }
}

#Preview {
    AuthFlow()
        .environment(UserRepository())
}
