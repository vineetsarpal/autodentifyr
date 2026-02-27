import React from "react";
import { interpolate, useCurrentFrame } from "remotion";

interface ScanningBeamProps {
  startFrame: number;
  duration: number;
}

export const ScanningBeam: React.FC<ScanningBeamProps> = ({
  startFrame,
  duration,
}) => {
  const frame = useCurrentFrame();

  const progress = interpolate(
    frame,
    [startFrame, startFrame + duration],
    [0, 100],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }
  );

  const opacity = interpolate(
    frame,
    [startFrame, startFrame + 5, startFrame + duration - 10, startFrame + duration],
    [0, 1, 1, 0],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }
  );

  return (
    <div
      style={{
        position: "absolute",
        top: 0,
        left: 0,
        width: "100%",
        height: "100%",
        pointerEvents: "none",
        opacity,
      }}
    >
      {/* Main beam line */}
      <div
        style={{
          position: "absolute",
          top: `${progress}%`,
          left: 0,
          width: "100%",
          height: 3,
          background: "linear-gradient(90deg, transparent 0%, #00D9FF 20%, #00D9FF 80%, transparent 100%)",
          boxShadow: "0 0 20px #00D9FF, 0 0 60px rgba(0, 217, 255, 0.4)",
          transform: "translateY(-50%)",
        }}
      />

      {/* Glow area above beam */}
      <div
        style={{
          position: "absolute",
          top: 0,
          left: 0,
          width: "100%",
          height: `${progress}%`,
          background: "linear-gradient(180deg, transparent 70%, rgba(0, 217, 255, 0.08) 100%)",
          pointerEvents: "none",
        }}
      />

      {/* Scan line dots */}
      {[15, 35, 55, 75].map((pos, i) => (
        <div
          key={i}
          style={{
            position: "absolute",
            top: `${progress}%`,
            left: `${pos}%`,
            width: 6,
            height: 6,
            borderRadius: "50%",
            background: "#00D9FF",
            boxShadow: "0 0 10px #00D9FF",
            transform: "translate(-50%, -50%)",
            opacity: progress > 5 ? 1 : 0,
          }}
        />
      ))}
    </div>
  );
};
