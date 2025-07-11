import SwiftUI

struct SplashView: View {
    @State private var scale = 0.3
    @State private var opacity = 0.0
    @State private var rotation = 0.0
    @State private var pulseScale = 1.0
    @State private var showingPulse = false
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.blue.opacity(0.8),
                    Color.purple.opacity(0.6),
                    Color.pink.opacity(0.4)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 30) {
                ZStack {
                    // Pulsing circles behind the icon
                    if showingPulse {
                        ForEach(0..<3) { index in
                            Circle()
                                .stroke(Color.white.opacity(0.3), lineWidth: 2)
                                .scaleEffect(pulseScale + Double(index) * 0.3)
                                .opacity(1.0 - (pulseScale - 1.0))
                        }
                    }
                    
                    // Splash photo
                    Image("Splash")
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(width: 220, height: 220)
                        .clipShape(RoundedRectangle(cornerRadius: 55))
                        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 5)
                        .scaleEffect(scale)
                        .opacity(opacity)
                        .rotationEffect(.degrees(rotation))
                }
                .frame(width: 200, height: 200)
                
                // App name
                Text("Creamie")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundColor(.white)
                    .opacity(opacity)
                    .scaleEffect(scale)
                
                // Loading indicator
                HStack(spacing: 8) {
                    ForEach(0..<3) { index in
                        Circle()
                            .fill(Color.white)
                            .frame(width: 8, height: 8)
                            .scaleEffect(showingPulse ? 1.0 : 0.5)
                            .animation(
                                Animation.easeInOut(duration: 0.6)
                                    .repeatForever()
                                    .delay(Double(index) * 0.2),
                                value: showingPulse
                            )
                    }
                }
                .opacity(opacity)
            }
        }
        .onAppear {
            startAnimations()
        }
    }
    
    private func startAnimations() {
        // Initial icon entrance
        withAnimation(.easeOut(duration: 0.8)) {
            scale = 1.0
            opacity = 1.0
        }
        
        // Rotation effect
        withAnimation(.easeInOut(duration: 1.0).delay(0.3)) {
            rotation = 360
        }
        
        // Start pulsing effect
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            showingPulse = true
            
            // Pulsing animation
            withAnimation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true)) {
                pulseScale = 1.8
            }
        }
    }
}

#Preview {
    SplashView()
} 
