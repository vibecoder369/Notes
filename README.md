# Notepad Messenger (Android)

A minimal AMOLED-dark notes-style front end with a secret search-word entry and a one-to-one text messenger backed by Supabase.

## Backend setup (Supabase)

1. Create a project at https://supabase.com/.
2. In **Authentication -> Providers -> Anonymous**, enable **Anonymous sign-ins**.
3. Open **SQL Editor** and run all of `supabase/schema.sql`.
4. In **Project Settings -> API**, copy the **Project URL** and **`anon` public key**.

## Automatic APK build with GitHub Actions

1. Push this repository to GitHub (make sure `.github/workflows/android.yml` is at the root of the repo).
2. On GitHub, go to **Settings -> Secrets and variables -> Actions -> New repository secret** and add:
   - `SUPABASE_URL`: your Supabase Project URL
   - `SUPABASE_ANON_KEY`: your Supabase `anon` public key
3. Push to `main` (or go to **Actions -> Build Android APK -> Run workflow**).
4. Once finished, download **`notepad-messenger-release-apk`** from the workflow run's **Artifacts** section and install `app-release.apk` on Android.
