import Foundation
import SwiftUI

// MARK: https://stackoverflow.com/questions/74224127/how-to-create-a-battery-badge-that-shows-current-battery-level-in-swiftui
struct HalfCircleShape : Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        
        path.move(to: CGPoint(x: rect.minX, y: rect.midY))
        path.addArc(center: CGPoint(x: rect.minX, y: rect.midY), radius: rect.height , startAngle: .degrees(90), endAngle: .degrees(270), clockwise: true)
        return path
    }
}

struct BatteryView : View {
    let batteryLevel: CGFloat
    var body: some View {
        GeometryReader { geo in
            HStack(spacing: 5) {
                GeometryReader { rectangle in
                    RoundedRectangle(cornerRadius: 15)
                        .stroke(lineWidth: 1)
                    RoundedRectangle(cornerRadius: 15)
                        .padding(5)
                        .frame(width: rectangle.size.width - (rectangle.size.width * (1 - batteryLevel)))
                        .foregroundColor(Color.BatteryLevel)
                }
                HalfCircleShape()
                .frame(width: geo.size.width / 7, height: geo.size.height / 7)
                
            }
            .padding(.leading)
        }
    }
}

extension Color {
    static var BatteryLevel : Color {
        let batteryLevel = 0.4
        switch batteryLevel {
            // returns red color for range %0 to %20
            case 0...0.2:
                return Color.red
            // returns yellow color for range %20 to %50
            case 0.2...0.5:
                return Color.yellow
            // returns green color for range %50 to %100
            case 0.5...1.0:
                return Color.green
            default:
                return Color.clear
        }
    }
}
