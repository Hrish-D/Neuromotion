//
//  FaceOverlayView.swift
//  Neuromotion
//
//  Created by Hrish Dave on 2025-12-30.
//

import Foundation
import SwiftUI

struct FaceOverlayView: View {
    let landmarks: [CGPoint]   // normalized ARKit points

    var body: some View {
        GeometryReader { geo in
            ZStack {
                // Midline
                Path { path in
                    path.move(to: CGPoint(x: geo.size.width / 2, y: 0))
                    path.addLine(to: CGPoint(x: geo.size.width / 2, y: geo.size.height))
                }
                .stroke(.blue, lineWidth: 2)

                // Landmarks
                ForEach(landmarks.indices, id: \.self) { i in
                    Circle()
                        .fill(Color.red)
                        .frame(width: 6, height: 6)
                        .position(
                            x: landmarks[i].x * geo.size.width,
                            y: landmarks[i].y * geo.size.height
                        )
                }
            }
        }
        .aspectRatio(1, contentMode: .fit)
    }
}
