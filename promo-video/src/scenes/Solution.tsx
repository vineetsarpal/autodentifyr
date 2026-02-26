import React from "react";
import {
  AbsoluteFill,
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { PhoneMockup } from "../components/PhoneMockup";
import { ScanningBeam } from "../components/ScanningBeam";
import { Particles } from "../components/Particles";

interface BoundingBox {
  top: string;
  left: string;
  width: string;
  height: string;
  label: string;
  triggerFrame: number;
  color: string;
}

const boundingBoxes: BoundingBox[] = [
  {
    top: "42%",
    left: "12%",
    width: "76%",
    height: "10%",
    label: "Headlight Crack",
    triggerFrame: 42,
    color: "#FFD700",
  },
  {
    top: "55%",
    left: "15%",
    width: "70%",
    height: "9%",
    label: "Bumper Dent",
    triggerFrame: 55,
    color: "#00D9FF",
  },
];

export const Solution: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // Phone entrance
  const phoneSpring = spring({
    frame: frame - 5,
    fps,
    config: { damping: 14, stiffness: 80, mass: 0.8 },
  });

  const phoneY = interpolate(phoneSpring, [0, 1], [300, 0]);
  const phoneOpacity = interpolate(frame, [5, 15], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Title
  const titleOpacity = interpolate(frame, [0, 12], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const titleY = interpolate(frame, [0, 12], [30, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #050A12 0%, #0A1929 30%, #0D263D 100%)",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <Particles count={20} color="#00D9FF" />

      {/* Title */}
      <div
        style={{
          position: "absolute",
          top: 80,
          opacity: titleOpacity,
          transform: `translateY(${titleY}px)`,
          zIndex: 10,
        }}
      >
        <h1
          style={{
            fontSize: 56,
            fontWeight: 800,
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            letterSpacing: "-1px",
          }}
        >
          AI Does the{" "}
          <span style={{ color: "#00D9FF" }}>Scanning</span>
        </h1>
      </div>

      {/* Phone with overlays */}
      <div
        style={{
          opacity: phoneOpacity,
          transform: `translateY(${phoneY}px)`,
          marginTop: 60,
        }}
      >
        <PhoneMockup imageSrc="assets/app_image-detection-2.png">
          {/* Scanning Beam */}
          <ScanningBeam startFrame={20} duration={50} />

          {/* Bounding Boxes */}
          {boundingBoxes.map((box, i) => {
            const boxSpring = spring({
              frame: frame - box.triggerFrame,
              fps,
              config: { damping: 10, stiffness: 150, mass: 0.4 },
            });

            const boxOpacity = interpolate(
              frame,
              [box.triggerFrame, box.triggerFrame + 5],
              [0, 1],
              {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }
            );

            const boxScale = interpolate(boxSpring, [0, 1], [0.3, 1]);

            // Label slide-in
            const labelSpring = spring({
              frame: frame - box.triggerFrame - 8,
              fps,
              config: { damping: 12, stiffness: 120 },
            });

            const labelOpacity = interpolate(
              frame,
              [box.triggerFrame + 8, box.triggerFrame + 14],
              [0, 1],
              {
                extrapolateLeft: "clamp",
                extrapolateRight: "clamp",
              }
            );

            return (
              <React.Fragment key={i}>
                {/* Bounding box */}
                <div
                  style={{
                    position: "absolute",
                    top: box.top,
                    left: box.left,
                    width: box.width,
                    height: box.height,
                    border: `3px solid ${box.color}`,
                    borderRadius: 8,
                    opacity: boxOpacity,
                    transform: `scale(${boxScale})`,
                    boxShadow: `0 0 15px ${box.color}40, inset 0 0 15px ${box.color}10`,
                  }}
                >
                  {/* Corner markers */}
                  {[
                    { top: -2, left: -2, borderTop: `4px solid ${box.color}`, borderLeft: `4px solid ${box.color}` },
                    { top: -2, right: -2, borderTop: `4px solid ${box.color}`, borderRight: `4px solid ${box.color}` },
                    { bottom: -2, left: -2, borderBottom: `4px solid ${box.color}`, borderLeft: `4px solid ${box.color}` },
                    { bottom: -2, right: -2, borderBottom: `4px solid ${box.color}`, borderRight: `4px solid ${box.color}` },
                  ].map((cornerStyle, ci) => (
                    <div
                      key={ci}
                      style={{
                        position: "absolute",
                        width: 14,
                        height: 14,
                        ...cornerStyle,
                      }}
                    />
                  ))}
                </div>

                {/* Label tag */}
                <div
                  style={{
                    position: "absolute",
                    top: box.top,
                    right: "8%",
                    transform: `translateY(-110%) translateX(${interpolate(labelSpring, [0, 1], [30, 0])}px)`,
                    opacity: labelOpacity,
                    background: `${box.color}CC`,
                    padding: "6px 14px",
                    borderRadius: 6,
                    display: "flex",
                    alignItems: "center",
                    gap: 6,
                  }}
                >
                  <div
                    style={{
                      width: 8,
                      height: 8,
                      borderRadius: "50%",
                      background: "#0A1929",
                    }}
                  />
                  <span
                    style={{
                      fontSize: 14,
                      fontWeight: 700,
                      color: "#0A1929",
                      fontFamily: "Inter, Helvetica, Arial, sans-serif",
                      whiteSpace: "nowrap",
                    }}
                  >
                    {box.label}
                  </span>
                </div>
              </React.Fragment>
            );
          })}
        </PhoneMockup>
      </div>

      {/* Bottom status bar */}
      <div
        style={{
          position: "absolute",
          bottom: 80,
          display: "flex",
          alignItems: "center",
          gap: 16,
          opacity: interpolate(frame, [65, 75], [0, 1], {
            extrapolateLeft: "clamp",
            extrapolateRight: "clamp",
          }),
        }}
      >
        <div
          style={{
            width: 12,
            height: 12,
            borderRadius: "50%",
            background: "#00FF88",
            boxShadow: "0 0 10px #00FF88",
          }}
        />
        <span
          style={{
            fontSize: 28,
            fontWeight: 600,
            color: "#AABBCC",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
            letterSpacing: "1px",
          }}
        >
          2 DAMAGE AREAS DETECTED
        </span>
      </div>
    </AbsoluteFill>
  );
};
