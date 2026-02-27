import React, { useMemo } from "react";
import { interpolate, useCurrentFrame } from "remotion";

interface ParticlesProps {
  count?: number;
  color?: string;
}

interface Particle {
  x: number;
  size: number;
  speed: number;
  opacity: number;
  delay: number;
}

export const Particles: React.FC<ParticlesProps> = ({
  count = 30,
  color = "#00D9FF",
}) => {
  const frame = useCurrentFrame();

  // Generate stable particle positions using useMemo
  const particles: Particle[] = useMemo(() => {
    return Array.from({ length: count }, (_, i) => ({
      x: (i * 37 + 13) % 100, // pseudo-random distribution
      size: 2 + ((i * 7) % 6),
      speed: 0.3 + ((i * 13) % 10) / 15,
      opacity: 0.1 + ((i * 11) % 5) / 10,
      delay: (i * 23) % 60,
    }));
  }, [count]);

  return (
    <div
      style={{
        position: "absolute",
        inset: 0,
        overflow: "hidden",
        pointerEvents: "none",
      }}
    >
      {particles.map((p, i) => {
        const adjustedFrame = frame + p.delay;
        const yPos = interpolate(
          adjustedFrame * p.speed,
          [0, 200],
          [110, -10],
          {
            extrapolateLeft: "clamp",
            extrapolateRight: "extend",
          }
        );

        // Wrap y position to create continuous flow
        const wrappedY = ((yPos % 120) + 120) % 120;

        const fadeOpacity = interpolate(
          frame,
          [0, 15],
          [0, p.opacity],
          {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }
        );

        return (
          <div
            key={i}
            style={{
              position: "absolute",
              left: `${p.x}%`,
              top: `${wrappedY}%`,
              width: p.size,
              height: p.size,
              borderRadius: "50%",
              background: color,
              opacity: fadeOpacity,
              boxShadow: `0 0 ${p.size * 2}px ${color}`,
            }}
          />
        );
      })}
    </div>
  );
};
