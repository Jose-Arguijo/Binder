# Binder

Binder includes an installable, offline-capable Progressive Web App and the original SwiftUI iOS project.

## Run the PWA locally

Serve this folder from `localhost` or an HTTPS host, then open it in a browser. The service worker caches the app shell, while collections, cards, photos, and theme preferences stay in that browser's IndexedDB storage.

For example, from this folder run `python3 -m http.server 4173` and open `http://localhost:4173`.

Use the install button in Binder or your browser's install option to add it to the home screen. On iOS, use Safari's Share menu and choose **Add to Home Screen**.

The SwiftUI app remains in [Binder.xcodeproj](Binder.xcodeproj).
