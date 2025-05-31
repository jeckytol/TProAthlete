//
//  LoadingView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 10/05/2025.
//

import SwiftUI

struct LoadingView: View {
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 20) {
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    .scaleEffect(2)

                Text("Loading Profile...")
                    .foregroundColor(.white)
                    .font(.headline)
            }
        }
    }
}
