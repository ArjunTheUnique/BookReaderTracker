# Install your app — Shelf (Reading Tracker)

Your app is built. It's an **Android app file (APK)**, sitting on GitHub, free, waiting for you.

## Get the file

1. Open the build page:
   **https://github.com/ArjunTheUnique/BookReaderTracker/actions**
2. Click the most recent **green** run of the workflow named **`build-apk`**.
3. Scroll to the bottom, to the **Artifacts** section.
4. Download **`shelf-app-apk`** (about 28 MB). It arrives as a `.zip`.
5. **Unzip it** — inside is **`app-release.apk`** (about 58 MB). That is your app.

## Put it on your phone

1. Copy `app-release.apk` to your phone (USB cable, Google Drive, or email it to yourself).
2. On the phone, tap the file to install.
3. Android will say *"For your security, your phone is not allowed to install unknown apps from this source."* Tap **Settings**, and allow it for the app you're installing from (Files, Chrome, Drive — whichever you used).
4. Tap **Install**. Done.

## What you'll see

- A home screen with **exactly 6 categories**, no scrolling.
- Each category holds up to **6 books**, each showing **% read today**.
- Add a book — an ebook from your phone (PDF/EPUB) or a paper book you log by hand.
- Tap a book to **log how far you've read**.
- Add the **home-screen widget** to see today's pages against your daily goal (long-press the home screen → Widgets → Shelf).

## Honest notes

- **Android only.** iOS was dropped (it needs a Mac and a paid Apple account).
- The APK is **self-signed**, which is fine for installing on your own phone. To publish on the Play Store later, it needs a proper signing key — a separate, optional step.
- All your data stays **on your phone**. No account, no server.
- One small, non-blocking item is still open: a hardening fix to the library module (finding F3). It does not affect normal use.

## If you ever want to rebuild it

Push any change to the repo and the same workflow rebuilds the APK automatically — you never touch a command line.
