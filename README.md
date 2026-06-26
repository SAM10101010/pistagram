<div align="center">

<img src="assets/logo_app.png" alt="Pistagram Logo" width="100" />

# 📸 Pistagram

**A full-featured Instagram-clone built with Flutter & Firebase — with a Watch-to-Earn reward system**

[![Flutter](https://img.shields.io/badge/Flutter-3.x-02569B?logo=flutter&logoColor=white)](https://flutter.dev)
[![Dart](https://img.shields.io/badge/Dart-89.6%25-0175C2?logo=dart&logoColor=white)](https://dart.dev)
[![Firebase](https://img.shields.io/badge/Firebase-Backend-FFCA28?logo=firebase&logoColor=black)](https://firebase.google.com)
[![License](https://img.shields.io/badge/License-MIT-green.svg)](LICENSE)
[![Platform](https://img.shields.io/badge/Platform-Android%20%7C%20iOS%20%7C%20Web-blue)](https://flutter.dev/multi-platform)

</div>

---

## 📖 Overview

**Pistagram** is a feature-rich social media application that mirrors the core Instagram experience — photos, reels, stories, direct messages, comments, and more — while adding a unique **Watch-to-Earn** gamification layer. Users earn points and rewards simply by engaging with content, redeeming them for prizes, climbing weekly and monthly leaderboards, and participating in challenges and campaigns.

The app is built entirely with **Flutter** for cross-platform support (Android, iOS, Web, macOS, Linux, Windows) and powered by a **Firebase** backend (Firestore, Auth, Storage, Functions, and Messaging).

---

## ✨ Features

### 📱 Core Social Features
- **Photo & Video Posts** — Upload, caption, and share posts with your followers
- **Reels** — Short-form video feed with likes, comments, and sharing
- **Stories** — 24-hour ephemeral content with reactions and comment threads
- **Follow / Unfollow** — Discover and follow other users
- **Comments & Likes** — Engage with posts, reels, and stories
- **Saved Posts / Bookmarks** — Save content to revisit later
- **User Profiles** — Customisable profiles with posts grid, followers, and following counts
- **Search & Discovery** — Find users and explore content
- **Share** — Share posts externally via `share_plus`

### 🎬 Reels & Series
- **Series** — Creators can bundle reels into episodic series
- **Series Progress** — Users track watch progress across episodes
- **Boosted Reels** — Creators can boost their reels for greater visibility
- **Reel Ratings** — Viewers rate reels to surface quality content
- **Reel Engagements** — Detailed per-user engagement tracking

### 💬 Messaging
- **Direct Messages (DMs)** — One-to-one real-time chat
- **Group Chats** — Multi-user conversations with invite system
- **Group Invitations** — Invite links and in-app invitations to groups

### 🏆 Watch-to-Earn & Gamification
- **Watch-to-Earn** — Earn points for watching reels (deduplicated per reel per user via `reelWatchRewards`)
- **Points & Transactions** — Full ledger of point earnings and spending
- **Point Transfers** — Send points to other users
- **Rewards & Redemptions** — Redeem accumulated points for rewards
- **Leaderboards** — Weekly and monthly rankings across all users
- **Achievements** — Unlock badges and milestones
- **Campaigns** — Time-limited earning campaigns with progress tracking
- **Challenges** — Admin-created community challenges
- **Predictions** — Predict outcomes and win points
- **Mystery Box** — Surprise reward drops for engagement
- **Vault Reels** — Locked premium content unlocked with points

### 📊 Analytics & Charts
- **fl_chart** integration — In-app charts and analytics dashboards
- **Health History** — Per-user history tracking subcollection

### 🔔 Notifications
- **Push Notifications** — Firebase Cloud Messaging (FCM) for real-time alerts
- **Local Notifications** — `flutter_local_notifications` for foreground alerts
- **In-app Notification Feed** — Persistent notification history

### 🛡️ Moderation & Safety
- **Block Users** — Block/unblock other accounts
- **Report Content** — Report posts, reels, and users
- **Warnings & Appeals** — Admin-issued warnings with user appeal flow
- **Fraud Detection** — `fraud_flags` collection to surface suspicious activity
- **Manipulation Alerts** — Admin-side alerts for engagement manipulation
- **Moderation Queue** — Admin review queue for reported content
- **Collab Invites** — Controlled collaboration requests between creators

### 🔐 Authentication & Security
- **Email & Password Auth** — Firebase Authentication
- **Google Sign-In** — One-tap Google login
- **Secure Storage** — `flutter_secure_storage` for sensitive token storage
- **Firestore Security Rules** — 437-line rule set enforcing per-user and admin-only access across every collection

### 🛠️ Admin Panel
- **Admin Role System** — Dedicated `admins` collection with privilege checks
- **Admin Activity Logs** — Immutable audit trail of admin actions
- **Support Tickets** — User-submitted tickets with internal admin notes
- **Ranking Audit Logs** — Audit trail for leaderboard changes
- **Report Votes** — Admin voting on reported content decisions
- **App Settings** — Runtime feature flags controlled by admins

---

## 🏗️ Tech Stack

| Layer | Technology |
|---|---|
| **Framework** | Flutter (Dart SDK ^3.8.1) |
| **Authentication** | Firebase Auth, Google Sign-In |
| **Database** | Cloud Firestore |
| **Storage** | Firebase Storage |
| **Serverless Functions** | Cloud Functions (TypeScript) |
| **Push Notifications** | Firebase Cloud Messaging |
| **Video Playback** | `video_player` |
| **Audio** | `just_audio`, `on_audio_query` |
| **Image Handling** | `image_picker`, `cached_network_image` |
| **File Handling** | `file_picker` |
| **Charting** | `fl_chart` |
| **Networking** | `dio` |
| **Fonts** | `google_fonts` |
| **Sharing** | `share_plus` |
| **Local Storage** | `shared_preferences`, `flutter_secure_storage` |
| **Email** | `mailer` |
| **Internationalization** | `intl` |
| **Time Display** | `timeago` |
| **Platform** | Android, iOS, Web, macOS, Linux, Windows |

---

## 📁 Project Structure

```
pistagram/
├── lib/                    # Main Dart source code
├── functions/              # Firebase Cloud Functions (TypeScript)
├── assets/                 # Images, icons, and static assets
├── android/                # Android-specific config
├── ios/                    # iOS-specific config
├── web/                    # Web-specific config
├── macos/                  # macOS-specific config
├── linux/                  # Linux-specific config
├── windows/                # Windows-specific config
├── stitch_screens/         # UI screen mockups / screenshots
├── firestore.rules         # Firestore security rules
├── firestore.indexes.json  # Firestore composite indexes
├── firebase.json           # Firebase project config
├── pubspec.yaml            # Flutter dependencies
└── README.md
```

---

## 🗄️ Firestore Collections

Pistagram uses a rich Firestore schema to power every feature:

**Social Core:** `users` · `posts` · `reels` · `stories` · `follows` · `likes` · `comments` · `saves` · `savedPosts`

**Messaging:** `chats` · `groupChats` · `groupInvitations`

**Gamification:** `reelEngagements` · `reelRatings` · `reelWatchRewards` · `series` · `seriesProgress` · `leaderboardWeekly` · `leaderboardMonthly` · `userAchievements` · `campaigns` · `campaignProgress` · `challenges` · `predictions` · `mysteryBoxResults` · `pointTransfers` · `boostedReels` · `vaultReels`

**Economy:** `transactions` · `rewards` · `redemptions`

**Safety:** `blocks` · `reports` · `warnings` · `appeals` · `fraud_flags` · `collabInvites`

**Admin:** `admins` · `adminLogs` · `supportTickets` · `moderationQueue` · `manipulationAlerts` · `reportVotes` · `rankingAuditLogs` · `appSettings`

---

## 🚀 Getting Started

### Prerequisites

- [Flutter SDK](https://docs.flutter.dev/get-started/install) (Dart SDK ^3.8.1)
- [Firebase CLI](https://firebase.google.com/docs/cli)
- A Firebase project with Firestore, Auth, Storage, Functions, and Messaging enabled
- Node.js (for Cloud Functions)

### Installation

1. **Clone the repository**
   ```bash
   git clone https://github.com/SAM10101010/pistagram.git
   cd pistagram
   ```

2. **Install Flutter dependencies**
   ```bash
   flutter pub get
   ```

3. **Set up Firebase**
   - Create a Firebase project at [console.firebase.google.com](https://console.firebase.google.com)
   - Add Android and iOS apps and download the `google-services.json` / `GoogleService-Info.plist` files into the respective platform folders
   - Enable **Authentication** (Email/Password + Google), **Firestore**, **Storage**, and **Cloud Messaging**

4. **Deploy Firestore rules and indexes**
   ```bash
   firebase deploy --only firestore
   ```

5. **Deploy Cloud Functions**
   ```bash
   cd functions
   npm install
   firebase deploy --only functions
   ```

6. **Run the app**
   ```bash
   flutter run
   ```

---

## 📸 Screenshots

> Place your app screenshots in `stitch_screens/images/` and reference them here.

| Feed | Reels | Profile | Leaderboard |
|------|-------|---------|-------------|
| ![Feed](stitch_screens/images/feed.png) | ![Reels](stitch_screens/images/reels.png) | ![Profile](stitch_screens/images/profile.png) | ![Leaderboard](stitch_screens/images/leaderboard.png) |

---

## 🤝 Contributing

Contributions, issues, and feature requests are welcome!

1. Fork the project
2. Create your feature branch (`git checkout -b feature/amazing-feature`)
3. Commit your changes (`git commit -m 'Add some amazing feature'`)
4. Push to the branch (`git push origin feature/amazing-feature`)
5. Open a Pull Request

---

## 📄 License

This project is licensed under the MIT License — see the [LICENSE](LICENSE) file for details.

---

<div align="center">

Made with ❤️ using Flutter & Firebase

</div>
