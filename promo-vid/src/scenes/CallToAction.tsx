import React from "react";
import {
  AbsoluteFill,
  Img,
  interpolate,
  spring,
  staticFile,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";
import { Particles } from "../components/Particles";

export const CallToAction: React.FC = () => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  // === Shockwave ring ===
  const shockwaveScale = interpolate(frame, [5, 30], [0, 6], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const shockwaveOpacity = interpolate(frame, [5, 12, 25, 30], [0, 0.6, 0.1, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // Second shockwave
  const shock2Scale = interpolate(frame, [12, 40], [0, 7], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const shock2Opacity = interpolate(frame, [12, 18, 35, 40], [0, 0.3, 0.05, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === Logo entrance ===
  const logoSpring = spring({
    frame,
    fps,
    config: { damping: 10, stiffness: 100, mass: 0.5 },
  });

  const logoScale = interpolate(logoSpring, [0, 1], [0, 1]);
  const logoOpacity = interpolate(frame, [0, 8], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === Glow behind logo ===
  const glowPulse = interpolate(
    Math.sin(frame * 0.15),
    [-1, 1],
    [0.3, 0.6]
  );

  // === Title ===
  const titleSpring = spring({
    frame: frame - 12,
    fps,
    config: { damping: 14, stiffness: 100 },
  });

  const titleOpacity = interpolate(frame, [12, 20], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const titleY = interpolate(titleSpring, [0, 1], [40, 0]);

  // === Tagline ===
  const taglineOpacity = interpolate(frame, [22, 32], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // === CTA Button ===
  const ctaSpring = spring({
    frame: frame - 30,
    fps,
    config: { damping: 8, stiffness: 120, mass: 0.4 },
  });

  const ctaScale = interpolate(ctaSpring, [0, 1], [0, 1]);
  const ctaOpacity = interpolate(frame, [30, 38], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  // CTA pulse
  const ctaPulse = interpolate(
    Math.sin((frame - 35) * 0.2),
    [-1, 1],
    [1, 1.05]
  );
  const showPulse = frame > 40;

  // === Store badges ===
  const badgesOpacity = interpolate(frame, [42, 52], [0, 1], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  const badgesY = interpolate(frame, [42, 52], [20, 0], {
    extrapolateLeft: "clamp",
    extrapolateRight: "clamp",
  });

  return (
    <AbsoluteFill
      style={{
        background: "linear-gradient(180deg, #050A12 0%, #0A1929 50%, #050A12 100%)",
        justifyContent: "center",
        alignItems: "center",
      }}
    >
      <Particles count={25} color="#00D9FF" />

      {/* Shockwave rings */}
      <div
        style={{
          position: "absolute",
          width: 100,
          height: 100,
          borderRadius: "50%",
          border: "3px solid #00D9FF",
          opacity: shockwaveOpacity,
          transform: `scale(${shockwaveScale})`,
        }}
      />
      <div
        style={{
          position: "absolute",
          width: 100,
          height: 100,
          borderRadius: "50%",
          border: "2px solid #00D9FF",
          opacity: shock2Opacity,
          transform: `scale(${shock2Scale})`,
        }}
      />

      {/* Glow behind logo */}
      <div
        style={{
          position: "absolute",
          width: 400,
          height: 400,
          borderRadius: "50%",
          background: `radial-gradient(circle, rgba(0, 217, 255, ${glowPulse}) 0%, transparent 70%)`,
          transform: `scale(${logoScale})`,
          marginTop: -160,
        }}
      />

      {/* Logo */}
      <div
        style={{
          opacity: logoOpacity,
          transform: `scale(${logoScale})`,
          marginBottom: 30,
        }}
      >
        <Img
          src={staticFile("assets/app_icon.png")}
          style={{
            width: 220,
            height: 220,
            borderRadius: 60,
            boxShadow: `
              0 20px 60px rgba(0, 0, 0, 0.6),
              0 0 50px rgba(0, 217, 255, 0.3),
              0 0 100px rgba(0, 217, 255, 0.1)
            `,
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
            fontWeight: 900,
            color: "#FFFFFF",
            margin: 0,
            textAlign: "center",
            letterSpacing: "-2px",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          AutoDentifyr
        </h1>
      </div>

      {/* Tagline */}
      <div
        style={{
          opacity: taglineOpacity,
          marginTop: 8,
        }}
      >
        <h2
          style={{
            fontSize: 42,
            fontWeight: 300,
            color: "#00D9FF",
            margin: 0,
            textAlign: "center",
            fontStyle: "italic",
            letterSpacing: "3px",
            fontFamily: "Inter, Helvetica, Arial, sans-serif",
          }}
        >
          Damage Decoded
        </h2>
      </div>

      {/* CTA Button */}
      <div
        style={{
          opacity: ctaOpacity,
          transform: `scale(${ctaScale * (showPulse ? ctaPulse : 1)})`,
          marginTop: 60,
        }}
      >
        <div
          style={{
            background: "linear-gradient(135deg, #00D9FF 0%, #0098CC 100%)",
            padding: "28px 80px",
            borderRadius: 50,
            boxShadow: `
              0 15px 50px rgba(0, 217, 255, 0.4),
              0 0 30px rgba(0, 217, 255, 0.2),
              inset 0 1px 0 rgba(255,255,255,0.2)
            `,
          }}
        >
          <p
            style={{
              fontSize: 40,
              fontWeight: 800,
              color: "#0A1929",
              margin: 0,
              textAlign: "center",
              letterSpacing: "2px",
              fontFamily: "Inter, Helvetica, Arial, sans-serif",
            }}
          >
            DOWNLOAD NOW
          </p>
        </div>
      </div>

      {/* Store badges */}
      <div
        style={{
          position: "absolute",
          bottom: 120,
          width: "100%",
          display: "flex",
          justifyContent: "center",
          gap: 40,
          opacity: badgesOpacity,
          transform: `translateY(${badgesY}px)`,
          alignItems: "center",
        }}
      >
        {/* Apple App Store badge - Commented out for now
        <Img
          src="https://tools.applemediaservices.com/api/badges/download-on-the-app-store/black/en-us"
          style={{
            height: 100,
            width: "auto",
            filter: "drop-shadow(0 10px 30px rgba(0,0,0,0.5))",
          }}
        />
        */}

        {/* Google Play Store badge */}
        <Img
          src="https://play.google.com/intl/en_us/badges/static/images/badges/en_badge_web_generic.png"
          style={{
            height: 145, // Play Store badge usually has more padding in the raw image
            width: "auto",
            filter: "drop-shadow(0 10px 30px rgba(0,0,0,0.5))",
          }}
        />
      </div>
    </AbsoluteFill>
  );
};
