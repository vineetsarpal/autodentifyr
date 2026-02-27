import React from "react";
import {
  interpolate,
  spring,
  useCurrentFrame,
  useVideoConfig,
} from "remotion";

type AnimationVariant = "slam" | "slideLeft" | "slideRight" | "fadeUp" | "scale";

interface AnimatedTextProps {
  text: string;
  startFrame: number;
  variant?: AnimationVariant;
  style?: React.CSSProperties;
}

export const AnimatedText: React.FC<AnimatedTextProps> = ({
  text,
  startFrame,
  variant = "fadeUp",
  style,
}) => {
  const frame = useCurrentFrame();
  const { fps } = useVideoConfig();

  const springVal = spring({
    frame: frame - startFrame,
    fps,
    config: {
      damping: variant === "slam" ? 8 : 12,
      stiffness: variant === "slam" ? 200 : 100,
      mass: variant === "slam" ? 0.4 : 0.5,
    },
  });

  const opacity = interpolate(
    frame,
    [startFrame, startFrame + 10],
    [0, 1],
    {
      extrapolateLeft: "clamp",
      extrapolateRight: "clamp",
    }
  );

  let transform = "";
  switch (variant) {
    case "slam":
      transform = `scale(${interpolate(springVal, [0, 1], [3, 1])})`;
      break;
    case "slideLeft":
      transform = `translateX(${interpolate(springVal, [0, 1], [-200, 0])}px)`;
      break;
    case "slideRight":
      transform = `translateX(${interpolate(springVal, [0, 1], [200, 0])}px)`;
      break;
    case "fadeUp":
      transform = `translateY(${interpolate(springVal, [0, 1], [60, 0])}px)`;
      break;
    case "scale":
      transform = `scale(${springVal})`;
      break;
  }

  return (
    <div
      style={{
        opacity,
        transform,
        ...style,
      }}
    >
      {text}
    </div>
  );
};
