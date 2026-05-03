import React, { useEffect, useMemo, useState } from "react";
import { createRoot } from "react-dom/client";

type BathingSite = {
  id: string;
  site_name: string;
  region: string;
  country: string | null;
  description: string | null;
  latitude: number | null;
  longitude: number | null;
  location_label: string;
  quality_classification: string | null;
  quality_classification_uri: string | null;
  latest_sample_at: string | null;
  latest_risk_prediction_at: string | null;
  source_updated_at: string | null;
  risk_level: string | null;
  risk_prediction_expires_at: string | null;
  year_designated: number | null;
  cache_refreshed_at: string | null;
  official_uri: string | null;
  eubwid_notation: string;
  heavy_rain_affected: boolean | null;
  created_at: string | null;
  updated_at: string | null;
};

type WeatherMetric = {
  status: "available" | "unavailable";
  value: string | number | null;
  observed_at: string | null;
  unavailable_reason: string | null;
};

type SiteWeather = {
  source: string;
  fetched_at: string | null;
  location: {
    latitude: number;
    longitude: number;
  };
  metrics: {
    air_temperature_c: WeatherMetric;
    wind_speed_m_s: WeatherMetric;
    water_temperature_c: WeatherMetric;
    wave_height_m: WeatherMetric;
    weather_condition: WeatherMetric;
    next_high_tide_at: WeatherMetric;
    next_low_tide_at: WeatherMetric;
  };
};

type SiteWiki = {
  description: string | null;
  image_url: string | null;
  wikipedia_url: string | null;
  unavailable_reason: string | null;
};

function App() {
  const [sites, setSites] = useState<BathingSite[]>([]);
  const [search, setSearch] = useState("");
  const [error, setError] = useState<string | null>(null);
  const [loading, setLoading] = useState(false);
  const [weatherBySite, setWeatherBySite] = useState<Record<string, SiteWeather>>({});
  const [weatherLoadingBySite, setWeatherLoadingBySite] = useState<Record<string, boolean>>({});
  const [wikiBySite, setWikiBySite] = useState<Record<string, SiteWiki>>({});
  const [wikiLoadingBySite, setWikiLoadingBySite] = useState<Record<string, boolean>>({});

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

  const formatDateTime = (iso: string | null) => {
    if (!iso) return null;

    const date = new Date(iso);
    if (Number.isNaN(date.getTime())) return null;

    return date.toLocaleString("en-GB", {
      day: "2-digit",
      month: "short",
      year: "numeric",
      hour: "2-digit",
      minute: "2-digit"
    });
  };

  async function loadWeather(site: BathingSite) {
    if (site.latitude == null || site.longitude == null) {
      return;
    }

    setWeatherLoadingBySite((prev) => ({ ...prev, [site.id]: true }));

    try {
      const params = new URLSearchParams({
        lat: String(site.latitude),
        lng: String(site.longitude)
      });

      const response = await fetch(`/bathing_sites/weather?${params.toString()}`);
      if (!response.ok) {
        throw new Error(`Could not load weather (status ${response.status}).`);
      }

      const payload: SiteWeather = await response.json();
      setWeatherBySite((prev) => ({ ...prev, [site.id]: payload }));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unexpected weather load error.");
    } finally {
      setWeatherLoadingBySite((prev) => ({ ...prev, [site.id]: false }));
    }
  }

  async function loadWiki(site: BathingSite) {
    setWikiLoadingBySite((prev) => ({ ...prev, [site.id]: true }));

    try {
      const params = new URLSearchParams({ site_name: site.site_name });
      const response = await fetch(`/bathing_sites/wiki?${params.toString()}`);
      if (!response.ok) {
        throw new Error(`Could not load location info (status ${response.status}).`);
      }

      const payload: SiteWiki = await response.json();
      setWikiBySite((prev) => ({ ...prev, [site.id]: payload }));
    } catch (err) {
      setError(err instanceof Error ? err.message : "Unexpected wiki load error.");
    } finally {
      setWikiLoadingBySite((prev) => ({ ...prev, [site.id]: false }));
    }
  }

  const metricDisplay = (metric: WeatherMetric, unit = "") => {
    if (metric.status !== "available" || metric.value == null || metric.value === "") {
      return "Unavailable";
    }

    return `${metric.value}${unit}`;
  };

  const tideStatus = (weather: SiteWeather) => {
    const highMetric = weather.metrics.next_high_tide_at;
    const lowMetric = weather.metrics.next_low_tide_at;

    const highTime = highMetric.status === "available" && highMetric.value ? new Date(highMetric.value as string) : null;
    const lowTime = lowMetric.status === "available" && lowMetric.value ? new Date(lowMetric.value as string) : null;

    if (!highTime && !lowTime) return null;

    if (highTime && lowTime) {
      if (highTime < lowTime) {
        return `The tide is coming in. Next high tide at ${formatDateTime(highMetric.value as string) ?? "unknown"}.`;
      } else {
        return `The tide is going out. Next low tide at ${formatDateTime(lowMetric.value as string) ?? "unknown"}.`;
      }
    }

    if (highTime) {
      return `Next high tide at ${formatDateTime(highMetric.value as string) ?? "unknown"}.`;
    }

    return `Next low tide at ${formatDateTime(lowMetric.value as string) ?? "unknown"}.`;
  };

  const weatherUnavailableReason = (weather: SiteWeather) => {
    const metrics = weather.metrics;

    return (
      metrics.air_temperature_c.unavailable_reason ||
      metrics.wind_speed_m_s.unavailable_reason ||
      metrics.water_temperature_c.unavailable_reason ||
      metrics.wave_height_m.unavailable_reason ||
      metrics.next_high_tide_at.unavailable_reason ||
      metrics.next_low_tide_at.unavailable_reason ||
      null
    );
  };

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

              {/* Wikipedia info */}
              <div style={{ marginBottom: "0.5rem" }}>
                <button
                  type="button"
                  onClick={() => void loadWiki(site)}
                  disabled={Boolean(wikiLoadingBySite[site.id])}
                >
                  {wikiLoadingBySite[site.id] ? "Loading info..." : "Load location info"}
                </button>

                {wikiBySite[site.id] && (
                  <div style={{ marginTop: "0.5rem" }}>
                    {wikiBySite[site.id].image_url && (
                      <img
                        src={wikiBySite[site.id].image_url!}
                        alt={site.site_name}
                        style={{ width: "100%", maxHeight: 220, objectFit: "cover", borderRadius: 6, marginBottom: "0.5rem" }}
                      />
                    )}
                    {wikiBySite[site.id].description && (
                      <p style={{ margin: "0 0 0.35rem", color: "#333" }}>{wikiBySite[site.id].description}</p>
                    )}
                    {!wikiBySite[site.id].description && wikiBySite[site.id].unavailable_reason && (
                      <p style={{ margin: "0 0 0.35rem", color: "#888" }}>{wikiBySite[site.id].unavailable_reason}</p>
                    )}
                    {wikiBySite[site.id].wikipedia_url && (
                      <a href={wikiBySite[site.id].wikipedia_url!} target="_blank" rel="noopener noreferrer" style={{ fontSize: "0.85rem" }}>
                        Read more on Wikipedia
                      </a>
                    )}
                  </div>
                )}
              </div>
              {site.source_updated_at && (
                <p style={{ margin: "0 0 0.35rem", color: "#555" }}>
                  <strong>Latest update:</strong> {formatDateTime(site.source_updated_at) ?? "Unavailable"}
                </p>
              )}
              {site.quality_classification && (
                <p style={{ margin: "0 0 0.35rem" }}>
                  <strong>Water quality:</strong> {site.quality_classification}
                </p>
              )}

              <div style={{ marginTop: "0.5rem", borderTop: "1px solid #eee", paddingTop: "0.5rem" }}>
                <button
                  type="button"
                  onClick={() => void loadWeather(site)}
                  disabled={Boolean(weatherLoadingBySite[site.id]) || site.latitude == null || site.longitude == null}
                >
                  {weatherLoadingBySite[site.id] ? "Loading conditions..." : "Load conditions"}
                </button>

                {weatherBySite[site.id] && (
                  <div style={{ marginTop: "0.5rem", color: "#444" }}>
                    <p style={{ margin: "0 0 0.5rem", fontSize: "1.05rem", fontWeight: 500 }}>
                      {metricDisplay(weatherBySite[site.id].metrics.weather_condition)}
                    </p>
                    <p style={{ margin: "0 0 0.35rem" }}>
                      <strong>Air temp:</strong> {metricDisplay(weatherBySite[site.id].metrics.air_temperature_c, " C")}
                    </p>
                    <p style={{ margin: "0 0 0.35rem" }}>
                      <strong>Wind speed:</strong> {metricDisplay(weatherBySite[site.id].metrics.wind_speed_m_s, " m/s")}
                    </p>
                    <p style={{ margin: "0 0 0.35rem" }}>
                      <strong>Water temp:</strong> {metricDisplay(weatherBySite[site.id].metrics.water_temperature_c, " C")}
                    </p>
                    <p style={{ margin: "0 0 0.35rem" }}>
                      <strong>Wave height:</strong> {metricDisplay(weatherBySite[site.id].metrics.wave_height_m, " m")}
                    </p>
                    {tideStatus(weatherBySite[site.id]) ? (
                      <p style={{ margin: "0 0 0.35rem" }}>
                        {tideStatus(weatherBySite[site.id])}
                      </p>
                    ) : (
                      <p style={{ margin: "0 0 0.35rem" }}>Tide information unavailable.</p>
                    )}
                    <p style={{ margin: 0, color: "#666" }}>
                      <strong>Observed:</strong>{" "}
                      {formatDateTime(weatherBySite[site.id].metrics.air_temperature_c.observed_at) ??
                        formatDateTime(weatherBySite[site.id].fetched_at) ??
                        "Unavailable"}
                    </p>
                    {weatherUnavailableReason(weatherBySite[site.id]) && (
                      <p style={{ margin: "0.35rem 0 0", color: "#8a4b00" }}>
                        <strong>Why unavailable:</strong> {weatherUnavailableReason(weatherBySite[site.id])}
                      </p>
                    )}
                  </div>
                )}
              </div>
            </li>
          ))}
        </ul>
      )}
    </main>
  );
}

const el = document.getElementById("app");
if (el) createRoot(el).render(<App />);
