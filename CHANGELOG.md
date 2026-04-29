# Changelog

All notable changes to this project will be documented in this file.

The format is based on Keep a Changelog, and this project follows Semantic Versioning.

## [Unreleased]

### Added
- Added BathingSite domain model with validations and text search support.
- Added migration to create bathing_sites with site name, region, description, latitude/longitude, and user_id.
- Added BathingSites JSON API endpoints for index, show, create, and update.
- Added TypeScript configuration for frontend type safety.
- Added npm scripts for frontend development, build, and type checking.
- Added idempotent seed data for sample BathingSite records.

### Changed
- Replaced placeholder React frontend with a typed React + TypeScript bathing-sites interface for create, list, and search.
- Updated routing to include bathing_sites JSON endpoints.
- Simplified page views to mount a single frontend root while loading Vite assets from the layout.
- Updated Vite layout include to use the application.tsx entrypoint explicitly.
- Updated controller tests to use valid route helpers for current routes.
- Simplified the Bathing Sites frontend to a read-only seeded-data experience (list + search, no create form).

### Removed
- Removed temporary Review, Favourite, and Report model placeholders.
- Removed BathingSite associations for reviews, favourites, and reports for now.
- Removed geocoder-dependent model hooks that were causing runtime 500 errors in the Bathing Sites endpoint.
