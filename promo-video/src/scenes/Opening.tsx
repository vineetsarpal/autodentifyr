import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export const Opening: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Icon animation
  const iconScale = spring({
    frame: frame - 10,
    fps,
    config: {
      damping: 12,
      stiffness: 100,
      mass: 0.5,
    },
  });

  const iconRotate = interpolate(frame, [0, 30], [0, 360], {
    extrapolateRight: "clamp",
  });

  // Text animations
  const titleOpacity = interpolate(frame, [30, 50], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const titleY = interpolate(frame, [30, 50], [50, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subtitleOpacity = interpolate(frame, [50, 70], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const subtitleY = interpolate(frame, [50, 70], [30, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(135deg, #0A1929 0%, #0D263D 100%)",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {/* Animated background circles */}
      <div
        style={{
          position: "absolute",
          width: "150%",
          height: "150%",
          opacity: 0.1,
        }}
      >
        <div
          style={{
            position: "absolute",
            width: 800,
            height: 800,
            borderRadius: "50%",
            background: "radial-gradient(circle, #00D9FF 0%, transparent 70%)",
            top: "20%",
            left: "10%",
            transform: `scale(${iconScale})`,
          }}
        />
      </div>

      {/* App Icon */}
      <div
        style={{
          transform: `scale(${iconScale}) rotate(${iconRotate}deg)`,
          marginBottom: 60,
        }}
      >
        <Img
          src={staticFile("assets/app_icon.png")}
          style={{
            width: 300,
            height: 300,
            borderRadius: 80,
            boxShadow: "0 20px 60px rgba(0, 217, 255, 0.4)",
          }}
        />
      </div>

      {/* Title */}
      <div
        style={{
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
        }}
      >
        <h1
          style={{
            fontSize: 80,
            fontWeight: "bold",
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
            letterSpacing: "-1px",
          }}
        >
          AutoDentifyr
        </h1>
      </div>

      {/* Subtitle */}
      <div
        style={{
          opacity: subtitleOpacity,
          transform: `translateY(${subtitleY}px)`,
          marginTop: 20,
        }}
      >
        <h2
          style={{
            fontSize: 52,
            fontWeight: 300,
            color: "#00D9FF",
            margin: 0,
            textAlign: "center",
            fontStyle: "italic",
            letterSpacing: "2px",
          }}
        >
          Damage Decoded
        </h2>
      </div>
    </AbsoluteFill>
  );
};
