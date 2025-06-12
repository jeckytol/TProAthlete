//
//  LoadingView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 10/05/2025.
//

import SwiftUI

struct LoadingView: View {
    @State private var isAnimating = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 30) {
                // App Icon Image (Dopamineo)
                Image("DopaIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 100, height: 100)
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(radius: 10)

                // Custom Circular Loader
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 6)
                        .frame(width: 70, height: 70)

                    Circle()
                        .trim(from: 0, to: 0.7)
                        .stroke(Color.white, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .frame(width: 70, height: 70)
                        .rotationEffect(Angle(degrees: isAnimating ? 360 : 0))
                        .animation(Animation.linear(duration: 1).repeatForever(autoreverses: false), value: isAnimating)
                }
                .onAppear {
                    isAnimating = true
                }

                // Loading Text
                Text("Loading Profile...")
                    .foregroundColor(.white)
                    .font(.title2)
                    .fontWeight(.medium)

                // Welcome Message
                Text("Welcome to the Dopa world")
                    .foregroundColor(.gray)
                    .font(.caption)
            }
            .padding()
        }
    }
}
