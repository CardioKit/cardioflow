import Foundation
import SwiftUI

struct IndicatorView: View {
    let number: String
    let title: String

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Spacer()
                Text(number)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(height: 30)
                Spacer()
            }
            Text(title)
                .font(.custom("Arial", size: 14))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(10)
        .shadow(radius: 5)
    }
}
