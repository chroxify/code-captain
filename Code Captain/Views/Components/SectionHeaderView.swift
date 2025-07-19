import SwiftUI

struct SectionHeaderView: View {
    let title: String
    let count: Int
    
    var body: some View {
        HStack {
            Text(title)
                .foregroundColor(.secondary)
                .font(.system(size: 11, weight: .medium))
            Text("\(count)")
                .foregroundColor(.secondary)
                .font(.system(size: 11, weight: .medium))
                .opacity(0.5)
        }
    }
}
