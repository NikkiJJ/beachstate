import React from "react";
import { createRoot } from "react-dom/client";

function App() {
  return <h1>Beachstate</h1>;
}

const el = document.getElementById("app");
if (el) createRoot(el).render(<App />);
