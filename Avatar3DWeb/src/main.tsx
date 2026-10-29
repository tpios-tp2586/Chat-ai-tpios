import React, { useRef, useState } from "react";
import { createRoot } from "react-dom/client";
import { AvatarStage, AvatarSpeechScene, getExpressionById } from "../../xlunar-source/src/lib/avatar";
import "./style.css";

function App() {
  const audioRef = useRef<HTMLAudioElement>(null);
  const [expression, setExpression] = useState("neutral");
  const [loadError, setLoadError] = useState("");
  const [ready, setReady] = useState(false);
  const expressionLabels: Record<string, string> = { neutral: "Bình thường", happy: "Vui", thinking: "Suy nghĩ", surprised: "Ngạc nhiên", shy: "Ngại" };

  return (
    <main className="screen">
      <header><span className="orb">✦</span><div><strong>ChatAI 3D</strong><small>Avatar riêng · chạy cục bộ</small></div></header>
      <section className="stage">
        <AvatarStage stage={{ backgroundColor: "#151820", ambientLightIntensity: 0.8, directionalLightIntensity: 1 }} camera={{ position: [0, 1.35, 2.8], fov: 35, controlsTarget: [0, 1.05, 0], enableZoom: false, enablePan: false, enableRotate: true }}>
          <AvatarSpeechScene
            appearance={{ modelUrl: "./models/Aisa.vrm" }}
            audioRef={audioRef}
            expression={getExpressionById(expression)}
            onLoad={() => { setReady(true); setLoadError(""); }}
          />
        </AvatarStage>
        {!ready && !loadError && <div className="status">Đang tải mô hình 3D…</div>}
        {loadError && <div className="error">{loadError}</div>}
      </section>
      <nav className="expressions">
        {["neutral", "happy", "thinking", "surprised", "shy"].map((id) =>
          <button className={expression === id ? "selected" : ""} key={id} onClick={() => setExpression(id)}>
            {expressionLabels[id]}
          </button>
        )}
      </nav>
      <section className="chat"><p>Khung chat 3D đang được tách riêng để phát triển. Chatbot hiện tại chưa bị thay đổi.</p><div className="composer"><input placeholder="Nhắn tin (bước kết nối chatbot tiếp theo)" disabled /><button disabled>➤</button></div></section>
      <audio ref={audioRef} />
      <footer>XLunar Avatar Engine · VRM · biểu cảm khuôn mặt</footer>
    </main>
  );
}

createRoot(document.getElementById("root")!).render(<App />);
