import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export const Closing: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Icon animation
  const iconScale = spring({
    frame,
    fps,
    config: {
      damping: 12,
      stiffness: 100,
    },
  });

  const iconOpacity = interpolate(frame, [0, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Text animations
  const textOpacity = interpolate(frame, [15, 30], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const ctaOpacity = interpolate(frame, [30, 45], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const ctaScale = spring({
    frame: frame - 30,
    fps,
    config: {
      damping: 10,
      stiffness: 100,
    },
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(135deg, #0A1929 0%, #0D263D 100%)",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {/* Glow effect */}
      <div
        style={{
          position: "absolute",
          width: "100%",
          height: "100%",
          opacity: 0.2,
        }}
      >
        <div
          style={{
            position: "absolute",
            width: 1000,
            height: 1000,
            borderRadius: "50%",
            background: "radial-gradient(circle, #00D9FF 0%, transparent 70%)",
            top: "50%",
            left: "50%",
            transform: `translate(-50%, -50%) scale(${iconScale})`,
          }}
        />
      </div>

      {/* App Icon */}
      <div
        style={{
          opacity: iconOpacity,
          transform: `scale(${iconScale})`,
          marginBottom: 60,
        }}
      >
        <Img
          src={staticFile("assets/app_icon.png")}
          style={{
            width: 250,
            height: 250,
            borderRadius: 70,
            boxShadow: "0 20px 60px rgba(0, 217, 255, 0.5)",
          }}
        />
      </div>

      {/* Text */}
      <div
        style={{
          opacity: textOpacity,
        }}
      >
        <h1
          style={{
            fontSize: 75,
            fontWeight: "bold",
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
          }}
        >
          AutoDentifyr
        </h1>
        <h2
          style={{
            fontSize: 48,
            fontWeight: 300,
            color: "#00D9FF",
            margin: 0,
            marginTop: 15,
            textAlign: "center",
            fontStyle: "italic",
          }}
        >
          Damage Decoded
        </h2>
      </div>

      {/* CTA */}
      <div
        style={{
          opacity: ctaOpacity,
          transform: `scale(${ctaScale})`,
          marginTop: 80,
        }}
      >
        <div
          style={{
            background: "linear-gradient(90deg, #00D9FF 0%, #00A0CC 100%)",
            padding: "30px 80px",
            borderRadius: 50,
            boxShadow: "0 15px 40px rgba(0, 217, 255, 0.4)",
          }}
        >
          <p
            style={{
              fontSize: 42,
              fontWeight: "bold",
              color: "#0A1929",
              margin: 0,
              textAlign: "center",
            }}
          >
            Download Today
          </p>
        </div>
      </div>
    </AbsoluteFill>
  );
};
