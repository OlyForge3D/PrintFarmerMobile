# Decision: Default API URL Should Be localhost

**Date:** 2025-07  
**Author:** Ripley  
**Status:** Accepted  

## Context
AppConfig.swift hardcoded `http://10.0.0.20:5000` as the default API URL — a private LAN IP that would leak network topology in a public repo and wouldn't work for anyone else.

## Decision
Changed default to `http://localhost:5000`. The `PRINTFARMER_API_URL` environment variable override remains for real deployments.

## Rationale
- `localhost` is universally safe and expected for local dev
- Environment variable override keeps deployment flexibility
- No private network details exposed in source
