import { AbsoluteFill, Sequence } from "remotion";
import { Hook } from "./scenes/Hook";
import { Solution } from "./scenes/Solution";
import { Value } from "./scenes/Value";
import { CallToAction } from "./scenes/CallToAction";

export const Video: React.FC = () => {
  return (
    <AbsoluteFill style={{ backgroundColor: "#050A12" }}>
      {/* Scene 1: The Hook — 0-90 frames (3s) */}
      <Sequence from={0} durationInFrames={90}>
        <Hook />
      </Sequence>

      {/* Scene 2: The Solution — 90-180 frames (3s) */}
      <Sequence from={90} durationInFrames={90}>
        <Solution />
      </Sequence>

      {/* Scene 3: The Value — 180-300 frames (4s) */}
      <Sequence from={180} durationInFrames={120}>
        <Value />
      </Sequence>

      {/* Scene 4: Call to Action — 300-390 frames (3s) */}
      <Sequence from={300} durationInFrames={90}>
        <CallToAction />
      </Sequence>
    </AbsoluteFill>
  );
};
