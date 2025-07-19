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
                    .opacity(0.7 + 0.3 * sin(Double(animationOffset)))
                    .frame(width: 16, height: 16)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            animationOffset = .pi * 2
                        }
                    }
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
                    .opacity(0.7 + 0.3 * sin(Double(animationOffset)))
                    .frame(width: 16, height: 16)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 1.0).repeatForever(autoreverses: true)) {
                            animationOffset = .pi * 2
                        }
                    }
                    
            case .readyForReview:
                Image(systemName: "checkmark.circle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .scaleEffect(1.0 + 0.1 * sin(Double(animationOffset)))
                    .frame(width: 16, height: 16)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 2.0).repeatForever(autoreverses: true)) {
                            animationOffset = .pi * 2
                        }
                    }
            case .queued:
                Image(systemName: "clock.badge.plus")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .frame(width: 16, height: 16)
            case .error:
                Image(systemName: "exclamationmark.cricle")
                    .font(.system(size: 14))
                    .foregroundColor(.secondary)
                    .opacity(0.7 + 0.3 * sin(Double(animationOffset)))
                    .frame(width: 16, height: 16)
                    .onAppear {
                        withAnimation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true)) {
                            animationOffset = .pi * 2
                        }
                    }
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
