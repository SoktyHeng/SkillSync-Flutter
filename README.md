[README (1).md](https://github.com/user-attachments/files/29374088/README.1.md)
# SkillSync

**SkillSync** is an academic collaboration platform built exclusively for ABAC students, connecting peers with complementary skills for academic project collaborations through skill-based profile discovery, project posting, and real-time messaging.

<!-- 
Add screenshots here once available, e.g.:
| Login | Profile | Project Feed |
|-------|---------|--------------|
| ![Login](docs/screenshots/login.png) | ![Profile](docs/screenshots/profile.png) | ![Feed](docs/screenshots/feed.png) |
-->

## ✨ Key Features

- **University-Exclusive Authentication** — Sign-in restricted to verified `@au.edu` accounts via Microsoft OAuth 2.0, ensuring a trusted, exclusive community of ABAC students.
- **Skill-Based Collaborator Discovery** — Browse and search student profiles by specific skills, academic year, and department to find the right teammates across majors.
- **Project Posting** — Create project listings with defined role requirements so other students can find and apply to collaborate.
- **Real-Time Messaging** — Built-in chat for coordinating projects, eliminating the need to juggle multiple messaging apps and email threads.
- **Collaboration Requests** — Send, receive, and manage requests to join projects or connect with other students.
- **Auto-Synced Profiles** — User name and profile photo sync automatically from Microsoft accounts, with students able to add skills, bio, and contact details.

## 🛠️ Tech Stack

| Layer | Technology |
|---|---|
| Mobile App | Flutter (Dart) |
| Authentication | Firebase Authentication + Microsoft OAuth 2.0 |
| Database | Firebase Firestore |
| File Storage | Firebase Storage |
| Business Logic | Cloud Functions for Firebase |
| Infrastructure | Google Cloud Platform (GCP) |

## 🏗️ Architecture

SkillSync uses a **Firebase Backend-as-a-Service (BaaS)** architecture rather than a traditional REST API, chosen to leverage Firestore's real-time sync capabilities and simplify development within academic timeline constraints.

- The **Flutter client** communicates directly with Firebase services (Auth, Firestore, Storage) using the official Firebase SDKs.
- **Microsoft OAuth** handles identity verification, restricted to `@au.edu` email domains, before a session is created via Firebase Authentication.
- **Cloud Functions** handle server-side business logic — such as enforcing domain restrictions, triggering notifications, and validating writes — that shouldn't run on the client.
- **Firestore Security Rules** are the primary access-control layer, protecting student data at the database level since Firebase apps aren't subject to the same backend audit as a traditional API.

```
Flutter App
   │
   ├── Firebase Authentication ── Microsoft OAuth (@au.edu only)
   │
   ├── Firestore ── profiles, projects, messages, collaboration requests
   │
   ├── Firebase Storage ── profile photos, project files
   │
   └── Cloud Functions ── business logic, validation, notifications
```

## 📦 Getting Started

```bash
# Clone the repo
git clone https://github.com/<your-org>/skillsync.git
cd skillsync

# Install Flutter dependencies
flutter pub get

# Add your Firebase config files
# (google-services.json for Android, GoogleService-Info.plist for iOS)

# Run the app
flutter run
```

## 🚧 Roadmap

- [ ] Push notifications
- [ ] In-app file sharing
- [ ] Advanced search filtering by academic year and department
- [ ] Content moderation system
- [ ] Multi-language support (incl. Thai localization)
- [ ] iOS platform support
- [ ] Google Play Store publication

## 📄 License

This project is developed for academic purposes at Abraham Baldwin Agricultural College (ABAC).
