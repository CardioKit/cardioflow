import Foundation
import SwiftUI

struct GradientIndicatorBarView: View {
    var title: String
    var points: [Float32] // Assuming these values are normalized between 0.0 and 1.0
    
    var body: some View {
        CardView {
            VStack {
                Text(title)
                    .font(.headline)
                    .padding()
                
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Rectangle()
                            .fill(LinearGradient(gradient: Gradient(colors: [.green, .red]), startPoint: .leading, endPoint: .trailing))
                        
                        ForEach(points, id: \.self) { point in
                            Circle()
                                .frame(width: 10, height: 10)
                                .offset(x: geometry.size.width * CGFloat(point) - 5, y: 0) // Adjusting circle's position based on the point value
                        }
                    }
                }
                .frame(height: 20)
            }
        }
        .padding()
    }
}

// A simple card view modifier
struct CardView<Content: View>: View {
    let content: Content
    
    init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }
    
    var body: some View {
        content
            .background(Color.white)
            .cornerRadius(10)
            .shadow(radius: 5)
    }
}
