import React from "react";
import { Img, staticFile } from "remotion";

interface PhoneMockupProps {
  imageSrc: string;
  style?: React.CSSProperties;
  children?: React.ReactNode;
}

export const PhoneMockup: React.FC<PhoneMockupProps> = ({
  imageSrc,
  style,
  children,
}) => {
  return (
    <div
      style={{
        position: "relative",
        width: 480,
        height: 980,
        ...style,
      }}
    >
      {/* Phone outer frame */}
      <div
        style={{
          position: "absolute",
          inset: 0,
          borderRadius: 60,
          background: "linear-gradient(145deg, #1A2A3A 0%, #0A1520 100%)",
          boxShadow: `
            0 0 0 3px #2A3A4A,
            0 40px 100px rgba(0, 0, 0, 0.8),
            0 0 80px rgba(0, 217, 255, 0.15),
            inset 0 1px 0 rgba(255,255,255,0.08)
          `,
          padding: 12,
        }}
      >
        {/* Screen area */}
        <div
          style={{
            position: "relative",
            width: "100%",
            height: "100%",
            borderRadius: 48,
            overflow: "hidden",
            background: "#000",
          }}
        >
          {/* Screenshot image */}
          <Img
            src={staticFile(imageSrc)}
            style={{
              width: "100%",
              height: "100%",
              objectFit: "cover",
            }}
          />

          {/* Children overlay (bounding boxes, scanning beam, etc.) */}
          {children}

          {/* Notch */}
          <div
            style={{
              position: "absolute",
              top: 0,
              left: "50%",
              transform: "translateX(-50%)",
              width: 180,
              height: 34,
              background: "#0A1520",
              borderRadius: "0 0 24px 24px",
            }}
          />

          {/* Screen reflection / gloss */}
          <div
            style={{
              position: "absolute",
              top: 0,
              left: 0,
              width: "100%",
              height: "100%",
              background:
                "linear-gradient(135deg, rgba(255,255,255,0.06) 0%, transparent 50%)",
              pointerEvents: "none",
            }}
          />
        </div>
      </div>

      {/* Side button (power) */}
      <div
        style={{
          position: "absolute",
          right: -5,
          top: 200,
          width: 4,
          height: 60,
          background: "#2A3A4A",
          borderRadius: "0 4px 4px 0",
        }}
      />
    </div>
  );
};
