# Beach State - New Implementation Guide

## 🎯 Architecture Overview

### Two-Page Flow
1. **Home Page** (`/`)
   - Landing with full hero section
   - Search bar in hero
   - Navbar + Footer visible
   
2. **Results Page** (`/results?search=query`)
   - Search bar at top (for refining search)
   - Bathing sites list below
   - Navbar + Footer visible

### Key Changes
- **Replaced plain CSS** with **Tailwind CSS** for design system consistency
- **Persistent navbar & footer** across all pages (sticky header with scroll effect)
- **Multi-page routing** instead of single-page React app
- **Interactive search** with URL-based queries

## 🚀 Running the Project

```bash
# Start the dev server (from project root)
./bin/dev

# This runs both:
# - Rails dev server (port 3000)
# - Vite dev server (handles React + Tailwind)
```

## 📐 Design System

### Colors
- **Primary**: #001629 (dark navy)
- **Primary Container**: #002b49 (lighter navy for backgrounds)
- **Secondary**: #006a65 (teal)
- **Surface**: #f7f9fb (light background)
- **On-Surface**: #191c1e (dark text)

### Typography
- **Font**: Manrope (400, 500, 600, 700, 800 weights)
- **Display Large**: 64px, 800 weight
- **Headline Large**: 48px, 700 weight
- **Headline Medium**: 32px, 700 weight
- **Headline Small**: 24px, 600 weight
- **Body Large**: 18px, 400 weight
- **Body Medium**: 16px, 400 weight
- **Label Medium**: 14px, 600 weight (uppercase)

### Spacing System
- **base**: 8px
- **stack-sm**: 12px
- **stack-md**: 24px
- **stack-lg**: 48px
- **container-margin**: 24px
- **grid-gutter**: 24px

## 🔍 How Search Works

### Home Page → Results Page Flow
1. User types query in hero search bar
2. Form submits to `/results?search=<query>` (standard form submission)
3. Results page loads with search query preserved in URL
4. React component reads URL params with `new URLSearchParams(window.location.search)`
5. Auto-loads bathing sites matching the search query

### URL Parameters
- `?search=cornwall` → Searches for sites in/near Cornwall
- `?search=` or no param → Empty state (shows "No results")

## 📱 Responsive Design
- **Mobile**: 1 column layout, responsive hero
- **Tablet**: 2 columns for site cards
- **Desktop**: 3 columns, full width layouts
- Header adapts: shows "Beach State" text on desktop only

## 🎨 Component Structure

### Shared Components (in layout)
```
app/views/layouts/application.html.erb
  ├── Header (navbar with Beach State logo + scroll effects)
  ├── Main (yield - page content)
  └── Footer (copyright + links)
```

### Page Components
```
app/views/home/index.html.erb
  └── Hero section with search bar

app/views/results/index.html.erb
  ├── Search bar
  └── #app (React component renders here)
```

### React Component
```
app/frontend/entrypoints/application.tsx
  └── Renders bathing sites with:
      - Site info cards
      - Load weather button
      - Load location info button
      - Weather metrics display
      - Wikipedia content display
```

## 🔗 Routes
- `GET /` → home#index (landing page)
- `GET /results` → results#index (search results)
- `GET /bathing_sites` → API (returns sites as JSON)
- `GET /bathing_sites/weather` → API (weather data)
- `GET /bathing_sites/wiki` → API (Wikipedia data)

## ⚙️ Configuration Files

### tailwind.config.js
- Defines all colors, spacing, fonts, animations
- Synced with design tool specifications
- Extends Tailwind defaults with custom values

### postcss.config.js
- Processes Tailwind + Autoprefixer
- Runs during build/dev process

### app/assets/stylesheets/application.css
- Imports Tailwind directives
- Defines custom Tailwind components (glass-effect, search-input, etc.)
- Imports typography.css

## 🛠️ Development Tips

### Adding New Colors
Edit `tailwind.config.js` → `theme.extend.colors`

### Adding New Typography Styles
Edit `tailwind.config.js` → `theme.extend.fontSize`

### Custom CSS
Add to `app/assets/stylesheets/application.css` inside `@layer components { }`

### Search Form Issues?
If search doesn't navigate to results page:
1. Check form `action="/results"` in view
2. Verify `method="get"` in form
3. Ensure input `name="search"` matches controller params

## 📊 Testing the Setup

### Test Home Page
```
1. Visit http://localhost:3000
2. Should see hero section with search bar
3. Try searching for a beach (e.g., "cornwall")
4. Should navigate to /results?search=cornwall
```

### Test Results Page
```
1. Should see search bar at top
2. Results should load below
3. Can refine search with top search bar
4. Click "Load weather" / "Load location info" buttons
5. Data should populate in cards
```

### Test Navigation
```
1. Logo/title links back to home
2. Footer links should be clickable
3. Search works from both home and results pages
4. Navbar stays at top when scrolling
```

## 🚨 Known Limitations
- React component still has some inline styles (Tailwind conversion in progress)
- Weather/location buttons need styling updates
- Mobile responsive design needs testing
- Error handling needs better UI

## 📝 Next Steps
1. Test the full search flow
2. Verify all fonts load correctly
3. Test on mobile devices
4. Add more Tailwind styling to React components
5. Implement better loading states
6. Add error boundaries
