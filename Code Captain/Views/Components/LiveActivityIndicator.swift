import SwiftUI

struct LiveActivityIndicator: View {
    let state: SessionState
    @State private var animationOffset: CGFloat = 0
    @State private var rotationAngle: Double = 0
    
    var body: some View {
        Group {
            switch state {
            case .idle:
                Image(systemName: "circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .processing:
                // Native spinning progress indicator
                ProgressView()
                    .progressViewStyle(CircularProgressViewStyle(tint: .secondary))
                    .controlSize(.mini)
                    .scaleEffect(1.4)
                    .frame(width: 16, height: 16)
            case .waitingForInput:
                Image(systemName: "hand.raised.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
                    
            case .readyForReview:
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .queued:
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .error:
                Image(systemName: "exclamationmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .failed:
                Image(systemName: "xmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .archived:
                Image(systemName: "archivebox.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            }
        }
    }
}
