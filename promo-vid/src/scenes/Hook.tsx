import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

export const Hook: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // === Pulse Ripple ===
  const pulseScale = interpolate(frame, [0, 40], [0, 8], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const pulseOpacity = interpolate(frame, [0, 10, 35, 40], [0, 0.6, 0.1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Second ripple (delayed)
  const pulse2Scale = interpolate(frame, [10, 50], [0, 8], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const pulse2Opacity = interpolate(frame, [10, 20, 45, 50], [0, 0.4, 0.05, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === "SCRATCHED?" Text ===
  const scratchedSpring = spring({
    frame: frame - 15,
    fps,
    config: { damping: 6, stiffness: 250, mass: 0.3 },
  });

  const scratchedScale = interpolate(scratchedSpring, [0, 1], [4, 1]);
  const scratchedOpacity = interpolate(frame, [15, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glitch out SCRATCHED
  const scratchedExitOpacity = interpolate(frame, [42, 45], [1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Glitch offset
  const glitchX =
    frame >= 40 && frame < 45
      ? Math.sin(frame * 50) * 15
      : 0;
  const glitchY =
    frame >= 40 && frame < 45
      ? Math.cos(frame * 70) * 8
      : 0;

  // === "DENTED?" Text ===
  const dentedSpring = spring({
    frame: frame - 46,
    fps,
    config: { damping: 6, stiffness: 250, mass: 0.3 },
  });

  const dentedScale = interpolate(dentedSpring, [0, 1], [4, 1]);
  const dentedOpacity = interpolate(frame, [46, 50, 68, 72], [0, 1, 1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === "WHAT WILL IT COST?" ===
  const costOpacity = interpolate(frame, [72, 80], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const costY = interpolate(frame, [72, 85], [40, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === Background vignette pulse ===
  const bgPulse = interpolate(frame, [15, 20, 46, 51], [0, 0.15, 0, 0.15], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "#050A12",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      {/* Background radial pulse on text slam */}
      <div
        style={{
          position: "absolute",
          width: "100%",
          height: "100%",
          background: `radial-gradient(circle at center, rgba(0, 217, 255, ${bgPulse}) 0%, transparent 60%)`,
        }}
      />

      {/* Pulse Ripple 1 */}
      <div
        style={{
          position: "absolute",
          width: 120,
          height: 120,
          borderRadius: "50%",
          border: "2px solid #00D9FF",
          opacity: pulseOpacity,
          transform: `scale(${pulseScale})`,
        }}
      />

      {/* Pulse Ripple 2 */}
      <div
        style={{
          position: "absolute",
          width: 120,
          height: 120,
          borderRadius: "50%",
          border: "1.5px solid #00D9FF",
          opacity: pulse2Opacity,
          transform: `scale(${pulse2Scale})`,
        }}
      />

      {/* Glitch bars (during transition) */}
      {frame >= 40 && frame < 46 && (
        <>
          <div
            style={{
              position: "absolute",
              width: "100%",
              height: 4,
              background: "rgba(0, 217, 255, 0.3)",
              top: `${30 + Math.sin(frame * 30) * 20}%`,
            }}
          />
          <div
            style={{
              position: "absolute",
              width: "100%",
              height: 2,
              background: "rgba(255, 215, 0, 0.2)",
              top: `${60 + Math.cos(frame * 40) * 15}%`,
            }}
          />
          <div
            style={{
              position: "absolute",
              width: "100%",
              height: 3,
              background: "rgba(0, 217, 255, 0.15)",
              top: `${50 + Math.sin(frame * 55) * 25}%`,
            }}
          />
        </>
      )}

      {/* SCRATCHED? */}
      <div
        style={{
          position: "absolute",
          opacity: scratchedOpacity * scratchedExitOpacity,
          transform: `scale(${scratchedScale}) translate(${glitchX}px, ${glitchY}px)`,
        }}
      >
        <h1
          style={{
            fontSize: 120,
            fontWeight: 900,
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
            letterSpacing: "-3px",
            textShadow: `0 0 30px rgba(0, 217, 255, 0.6), 0 0 80px rgba(0, 217, 255, 0.2)`,
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          SCRATCHED?
        </h1>
      </div>

      {/* DENTED? */}
      <div
        style={{
          position: "absolute",
          opacity: dentedOpacity,
          transform: `scale(${dentedScale})`,
        }}
      >
        <h1
          style={{
            fontSize: 120,
            fontWeight: 900,
            color: "#FFD700",
            margin: 0,
            textAlign: "center",
            letterSpacing: "-3px",
            textShadow: `0 0 30px rgba(255, 215, 0, 0.6), 0 0 80px rgba(255, 215, 0, 0.2)`,
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          DENTED?
        </h1>
      </div>

      {/* WHAT WILL IT COST? */}
      <div
        style={{
          position: "absolute",
          opacity: costOpacity,
          transform: `translateY(${costY}px)`,
        }}
      >
        <h2
          style={{
            fontSize: 72,
            fontWeight: 300,
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
            letterSpacing: "4px",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          WHAT WILL IT
        </h2>
        <h2
          style={{
            fontSize: 90,
            fontWeight: 800,
            color: "#00D9FF",
            margin: 0,
            marginTop: 10,
            textAlign: "center",
            letterSpacing: "2px",
            textShadow: "0 0 40px rgba(0, 217, 255, 0.5)",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          COST?
        </h2>
      </div>
    </AbsoluteFill>
  );
};
