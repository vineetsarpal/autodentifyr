import {
  AbsoluteFill,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

export const Detection: React.FC = () => {
  const frame = useCurrentFrame();

  // Screenshot animation
  const screenshotOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const screenshotScale = interpolate(frame, [0, 25], [1.2, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Highlight boxes animation
  const highlight1 = interpolate(frame, [30, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const highlight2 = interpolate(frame, [45, 65], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Stats animation
  const statsOpacity = interpolate(frame, [70, 90], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const statsScale = interpolate(frame, [70, 90], [0.8, 1], {
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
          top: 80,
          opacity: screenshotOpacity,
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
          AI-Powered Detection
        </h1>
      </div>

      {/* Detection Screenshot */}
      <div
        style={{
          opacity: screenshotOpacity,
          transform: `scale(${screenshotScale})`,
          marginTop: 50,
          position: "relative",
        }}
      >
        <Img
          src={staticFile("assets/app_image-detection-2.png")}
          style={{
            width: 550,
            height: 1200,
            borderRadius: 40,
            boxShadow: "0 30px 80px rgba(0, 217, 255, 0.4)",
          }}
        />

        {/* Animated highlight boxes */}
        <div
          style={{
            position: "absolute",
            top: 0,
            left: 0,
            width: "100%",
            height: "100%",
            borderRadius: 40,
            overflow: "hidden",
          }}
        >
          {/* Highlight 1 - Headlight damage */}
          <div
            style={{
              position: "absolute",
              top: "45%",
              left: "20%",
              width: "60%",
              height: "8%",
              border: `4px solid rgba(0, 217, 255, ${highlight1})`,
              borderRadius: 10,
              animation: `pulse 1s ease-in-out infinite`,
            }}
          />

          {/* Highlight 2 - Bumper dent */}
          <div
            style={{
              position: "absolute",
              top: "56%",
              left: "20%",
              width: "60%",
              height: "8%",
              border: `4px solid rgba(0, 217, 255, ${highlight2})`,
              borderRadius: 10,
              animation: `pulse 1s ease-in-out infinite`,
              animationDelay: "0.3s",
            }}
          />
        </div>
      </div>

      {/* Stats Box */}
      <div
        style={{
          position: "absolute",
          bottom: 120,
          opacity: statsOpacity,
          transform: `scale(${statsScale})`,
          background: "rgba(0, 217, 255, 0.1)",
          border: "2px solid #00D9FF",
          borderRadius: 30,
          padding: "40px 80px",
          display: "flex",
          gap: 100,
        }}
      >
        <div style={{ textAlign: "center" }}>
          <div
            style={{
              fontSize: 60,
              fontWeight: "bold",
              color: "#00D9FF",
            }}
          >
            2
          </div>
          <div
            style={{
              fontSize: 32,
              color: "#FFFFFF",
              marginTop: 10,
            }}
          >
            Detections
          </div>
        </div>

        <div
          style={{
            width: 2,
            background: "#00D9FF",
            opacity: 0.3,
          }}
        />

        <div style={{ textAlign: "center" }}>
          <div
            style={{
              fontSize: 60,
              fontWeight: "bold",
              color: "#FFD700",
            }}
          >
            $750
          </div>
          <div
            style={{
              fontSize: 32,
              color: "#FFFFFF",
              marginTop: 10,
            }}
          >
            Estimated Cost
          </div>
        </div>
      </div>
    </AbsoluteFill>
  );
};
