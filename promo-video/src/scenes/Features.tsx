import {
  AbsoluteFill,
  Img,
  interpolate,
  staticFile,
  useCurrentFrame,
} from "remotion";

export const Features: React.FC = () => {
  const frame = useCurrentFrame();

  // Screenshot animation
  const screenshotOpacity = interpolate(frame, [0, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const screenshotScale = interpolate(frame, [0, 20], [0.8, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Text animations
  const titleOpacity = interpolate(frame, [20, 35], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const feature1Opacity = interpolate(frame, [35, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const feature2Opacity = interpolate(frame, [50, 65], [0, 1], {
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
          top: 100,
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
          Choose Your Mode
        </h1>
      </div>

      {/* Home Screenshot */}
      <div
        style={{
          opacity: screenshotOpacity,
          transform: `scale(${screenshotScale})`,
          marginTop: 100,
        }}
      >
        <Img
          src={staticFile("assets/app_home.jpeg")}
          style={{
            width: 550,
            height: 1200,
            borderRadius: 40,
            boxShadow: "0 30px 80px rgba(0, 217, 255, 0.3)",
          }}
        />
      </div>

      {/* Feature Highlights */}
      <div
        style={{
          position: "absolute",
          bottom: 150,
          width: "100%",
          display: "flex",
          justifyContent: "space-around",
          padding: "0 100px",
        }}
      >
        <div
          style={{
            opacity: feature1Opacity,
            textAlign: "center",
          }}
        >
          <div
            style={{
              fontSize: 60,
              marginBottom: 10,
            }}
          >
            📹
          </div>
          <h3
            style={{
              fontSize: 40,
              fontWeight: "bold",
              color: "#00D9FF",
              margin: 0,
            }}
          >
            Live Camera
          </h3>
          <p
            style={{
              fontSize: 28,
              color: "#AAAAAA",
              margin: 0,
              marginTop: 10,
            }}
          >
            Real-time detection
          </p>
        </div>

        <div
          style={{
            opacity: feature2Opacity,
            textAlign: "center",
          }}
        >
          <div
            style={{
              fontSize: 60,
              marginBottom: 10,
            }}
          >
            🖼️
          </div>
          <h3
            style={{
              fontSize: 40,
              fontWeight: "bold",
              color: "#00D9FF",
              margin: 0,
            }}
          >
            Upload Image
          </h3>
          <p
            style={{
              fontSize: 28,
              color: "#AAAAAA",
              margin: 0,
              marginTop: 10,
            }}
          >
            Analyze photos
          </p>
        </div>
      </div>
    </AbsoluteFill>
  );
};
