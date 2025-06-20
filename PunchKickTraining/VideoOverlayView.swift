//
//  VideoOverlayView.swift
//  TProAthlete
//
//  Created by Jecky Toledo on 20/06/2025.
//

import SwiftUI
import WebKit

struct VideoOverlayView: View {
    let url: URL
    var onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.85).ignoresSafeArea()

            VStack {
                WebView(url: url)
                    .frame(height: 300)
                    .cornerRadius(12)

                Button("Close") {
                    onClose()
                }
                .padding()
                .foregroundColor(.white)
            }
            .padding()
        }
    }
}

struct WebView: UIViewRepresentable {
    let url: URL

    func makeUIView(context: Context) -> WKWebView {
        return WKWebView()
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {
        let request = URLRequest(url: url)
        uiView.load(request)
    }
}
