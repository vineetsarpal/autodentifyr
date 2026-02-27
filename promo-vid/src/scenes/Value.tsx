import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Particles } from "../components/Particles";
import { AnimatedText } from "../components/AnimatedText";

export const Value: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // === Dollar counter animation ===
  const counterStart = 30;
  const counterEnd = 80;
  const counterValue = Math.round(
    interpolate(frame, [counterStart, counterEnd], [0, 750], {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    })
  );

  const counterOpacity = interpolate(frame, [counterStart - 5, counterStart + 5], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const counterScale = spring({
    frame: frame - counterStart,
    fps,
    config: { damping: 15, stiffness: 80 },
  });

  // === Features data ===
  const features = [
    { icon: "⚡", text: "INSTANT ESTIMATES", startFrame: 10, variant: "slideLeft" as const },
    { icon: "🔒", text: "ON-DEVICE AI", startFrame: 22, variant: "slideRight" as const },
    { icon: "📱", text: "WORKS OFFLINE", startFrame: 34, variant: "slideLeft" as const },
  ];

  // === Central ring animation ===
  const ringScale = spring({
    frame: frame - 25,
    fps,
    config: { damping: 20, stiffness: 60 },
  });

  const ringRotation = interpolate(frame, [0, 150], [0, 360], {
    extrapolateRight: "extend",
  });

  // === Bottom tagline ===
  const taglineOpacity = interpolate(frame, [95, 110], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const taglineY = interpolate(frame, [95, 110], [30, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #0A1929 0%, #061220 50%, #0A1929 100%)",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <Particles count={40} color="#00D9FF" />

      {/* Rotating dashed ring behind dollar amount */}
      <div
        style={{
          position: "absolute",
          width: 500,
          height: 500,
          borderRadius: "50%",
          border: "2px dashed rgba(0, 217, 255, 0.15)",
          transform: `scale(${ringScale}) rotate(${ringRotation}deg)`,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 380,
          height: 380,
          borderRadius: "50%",
          border: "1px dashed rgba(255, 215, 0, 0.1)",
          transform: `scale(${ringScale}) rotate(${-ringRotation * 0.7}deg)`,
        }}
      />

      {/* Feature lines */}
      <div
        style={{
          position: "absolute",
          top: 120,
          width: "100%",
          display: "flex",
          flexDirection: "column",
          gap: 30,
          padding: "0 60px",
        }}
      >
        {features.map((feat, i) => (
          <div
            key={i}
            style={{
              display: "flex",
              alignItems: "center",
              gap: 20,
              justifyContent: feat.variant === "slideLeft" ? "flex-start" : "flex-end",
            }}
          >
            <AnimatedText
              text={`${feat.icon}  ${feat.text}`}
              startFrame={feat.startFrame}
              variant={feat.variant}
              style={{
                fontSize: 44,
                fontWeight: 800,
                color: "#FFFFFF",
                fontFamily: "Inter, Helvetica, Arial, sans-serif",
                letterSpacing: "2px",
                textShadow: "0 0 20px rgba(0, 217, 255, 0.3)",
                background: "rgba(0, 217, 255, 0.06)",
                padding: "18px 36px",
                borderRadius: 16,
                border: "1px solid rgba(0, 217, 255, 0.15)",
              }}
            />
          </div>
        ))}
      </div>

      {/* Central cost counter */}
      <div
        style={{
          opacity: counterOpacity,
          transform: `scale(${counterScale})`,
          marginTop: 180,
          textAlign: "center",
        }}
      >
        <div
          style={{
            fontSize: 32,
            fontWeight: 600,
            color: "#AABBCC",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            letterSpacing: "3px",
            marginBottom: 10,
          }}
        >
          ESTIMATED REPAIR COST
        </div>
        <div
          style={{
            fontSize: 140,
            fontWeight: 900,
            color: "#FFD700",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            letterSpacing: "-4px",
            textShadow: `
              0 0 40px rgba(255, 215, 0, 0.5),
              0 0 100px rgba(255, 215, 0, 0.2)
            `,
            lineHeight: 1,
          }}
        >
          ${counterValue}
        </div>

        {/* Progress bar under cost */}
        <div
          style={{
            width: 500,
            height: 6,
            background: "rgba(255, 255, 255, 0.08)",
            borderRadius: 3,
            marginTop: 30,
            margin: "30px auto 0",
            overflow: "hidden",
          }}
        >
          <div
            style={{
              width: `${interpolate(frame, [counterStart, counterEnd], [0, 100], {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              })}%`,
              height: "100%",
              background: "linear-gradient(90deg, #00D9FF, #FFD700)",
              borderRadius: 3,
              boxShadow: "0 0 10px #FFD700",
            }}
          />
        </div>
      </div>

      {/* Bottom tagline */}
      <div
        style={{
          position: "absolute",
          bottom: 120,
          opacity: taglineOpacity,
          transform: `translateY(${taglineY}px)`,
          textAlign: "center",
        }}
      >
        <p
          style={{
            fontSize: 36,
            fontWeight: 600,
            color: "#00D9FF",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            letterSpacing: "2px",
            margin: 0,
          }}
        >
          Know Before You Go
        </p>
        <p
          style={{
            fontSize: 26,
            fontWeight: 400,
            color: "#667788",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            margin: 0,
            marginTop: 10,
          }}
        >
          No internet required · 100% on-device
        </p>
      </div>
    </AbsoluteFill>
  );
};
