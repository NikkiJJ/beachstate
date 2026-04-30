import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";

type BathingSite = {
  id: string;
  site_name: string;
  region: string;
  description: string | null;
  latitude: number | null;
  longitude: number | null;
  location_label: string;
  quality_classification: string | null;
  quality_classification_uri: string | null;
  official_uri: string | null;
  eubwid_notation: string;
  heavy_rain_affected: boolean | null;
  created_at: string | null;
  updated_at: string | null;
};

function App() {
  const [sites, setSites] = useState<BathingSite[]>([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);

  async function loadSites(query = "") {
    setLoading(true);
    setError(null);

    try {
      const params = new URLSearchParams();
      if (query.trim()) params.set("q", query.trim());

      const path = `/bathing_sites${params.toString() ? `?${params.toString()}` : ""}`;
      const response = await fetch(path);

      if (!response.ok) {
        throw new Error(`Could not load bathing sites (status ${response.status}).`);
      }

      const data: BathingSite[] = await response.json();
      setSites(data);
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unexpected error.");
    } finally {
      setLoading(false);
    }
  }

  useEffect(() => {
    void loadSites();
  }, []);

  const hasData = useMemo(() => sites.length > 0, [sites]);

  return (
    <main style={{ maxWidth: 900, margin: "2rem auto", padding: "0 1rem", fontFamily: "sans-serif" }}>
      <h1>Bathing Sites</h1>

      <div style={{ display: "flex", gap: "0.5rem", marginBottom: "1rem" }}>
        <input
          value={search}
          onChange={(e) => setSearch(e.target.value)}
          placeholder="Search by site or region"
          style={{ flex: 1 }}
        />
        <button type="button" onClick={() => void loadSites(search)} disabled={loading}>
          Search
        </button>
      </div>

      {error && <p style={{ color: "crimson" }}>{error}</p>}
      {loading && <p>Loading...</p>}
      {!loading && !hasData && <p>No bathing sites found.</p>}

      {!loading && hasData && (
        <ul style={{ display: "grid", gap: "0.75rem", listStyle: "none", padding: 0 }}>
          {sites.map((site) => (
            <li key={site.id} style={{ border: "1px solid #ddd", borderRadius: 8, padding: "0.75rem" }}>
              <h2 style={{ margin: "0 0 0.35rem" }}>{site.site_name}</h2>
              <p style={{ margin: "0 0 0.35rem", color: "#555" }}>{site.region}</p>
              {site.quality_classification && (
                <p style={{ margin: "0 0 0.35rem" }}>
                  <strong>Water quality:</strong> {site.quality_classification}
                </p>
              )}
              {site.eubwid_notation && (
                <p style={{ margin: "0 0 0.35rem", color: "#555" }}>
                  <strong>EA code:</strong> {site.eubwid_notation}
                </p>
              )}
              {site.description && <p style={{ margin: 0 }}>{site.description}</p>}
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

const el = document.getElementById("app");
if (el) createRoot(el).render(<App />);
