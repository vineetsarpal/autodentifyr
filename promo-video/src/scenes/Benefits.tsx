import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

const benefits = [
  { icon: "🔒", title: "Privacy First", description: "On-device AI processing" },
  { icon: "⚡", title: "Instant Results", description: "Real-time cost estimation" },
  { icon: "📱", title: "Works Offline", description: "No internet required" },
];

export const Benefits: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Title animation
  const titleOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(135deg, #0A1929 0%, #0D263D 100%)",
        justifyContent: "center",
        alignItems: "center",
        padding: 80,
      }}
    >
      {/* Title */}
      <div
        style={{
          position: "absolute",
          top: 120,
          opacity: titleOpacity,
        }}
      >
        <h1
          style={{
            fontSize: 70,
            fontWeight: "bold",
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
          }}
        >
          Why AutoDentifyr?
        </h1>
      </div>

      {/* Benefits Grid */}
      <div
        style={{
          display: "flex",
          flexDirection: "column",
          gap: 60,
          marginTop: 100,
        }}
      >
        {benefits.map((benefit, index) => {
          const delay = 20 + index * 15;
          const scale = spring({
            frame: frame - delay,
            fps,
            config: {
              damping: 12,
              stiffness: 100,
            },
          });

          const opacity = interpolate(frame, [delay, delay + 15], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          });

          return (
            <div
              key={index}
              style={{
                opacity,
                transform: `scale(${scale})`,
                background: "rgba(0, 217, 255, 0.08)",
                border: "2px solid rgba(0, 217, 255, 0.3)",
                borderRadius: 30,
                padding: "50px 80px",
                display: "flex",
                alignItems: "center",
                gap: 40,
                width: 800,
              }}
            >
              <div
                style={{
                  fontSize: 80,
                  flexShrink: 0,
                }}
              >
                {benefit.icon}
              </div>
              <div>
                <h2
                  style={{
                    fontSize: 50,
                    fontWeight: "bold",
                    color: "#00D9FF",
                    margin: 0,
                  }}
                >
                  {benefit.title}
                </h2>
                <p
                  style={{
                    fontSize: 36,
                    color: "#AAAAAA",
                    margin: 0,
                    marginTop: 10,
                  }}
                >
                  {benefit.description}
                </p>
              </div>
            </div>
          );
        })}
      </div>
    </AbsoluteFill>
  );
};
