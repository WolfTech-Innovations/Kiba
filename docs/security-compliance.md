
# Security & Compliance

<p align="center">
  <img src="../branding/kibaos_banner.png" alt="KibaOS Banner" width="100%">
</p>

<p align="center">
  <img src="`https://img.shields.io/badge/Privacy-First-green?style=for-the-badge`" alt="Privacy First">
  <img src="`https://img.shields.io/badge/Compliance-AB`%202273-blue?style=for-the-badge" alt="AB 2273">
  <img src="`https://img.shields.io/badge/Security-Hardened-red?style=for-the-badge`" alt="Hardened">
</p>

---

KibaOS is built with a "Privacy by Design" philosophy. We go beyond standard security practices to ensure compliance with modern digital safety laws and to minimize the system's attack surface.

---

\n## California Age-Appropriate Design Code (AB 2273)

To comply with the California Age-Appropriate Design Code Act, KibaOS features a custom **Age Verification** module within the **Calamares** installer.

#\n## Implementation

- **Module:** A custom Python-based view module located at `/usr/lib/calamares/modules/ageverify/`.
- **User Interface:** During installation, users are presented with a screen to select their age group (e.g., Under 13, 13-15, 16-17, 18+, or "Prefer not to say").
- **Transparency:** The screen clearly explains why this information is being collected and how it is stored.

#\n## Privacy and Data Storage

In accordance with KibaOS's privacy-first philosophy:

- **Local Storage Only:** The selected age group is stored exclusively on the user's local machine at `/etc/kibaos/age-verify`.
- **No Transmission:** This data is **never** transmitted to WolfTech Innovations or any other external servers.
- **Purpose:** This local record ensures the system can provide an age-appropriate experience as mandated by law without compromising user anonymity.

- **Technical Stack:** A custom Python view module using the `pythonqt` interface.
- **User Choice:** During installation, users are prompted to select their age group (Under 13, 13-15, 16-17, 18+, or Decline to state).
- **Purpose:** This allows the system to potentially apply age-appropriate safety defaults without requiring a central account or online tracking.

#\n## Privacy Policy: Local Storage Only

In strict adherence to our privacy goals:

- **No Transmission:** Your age selection is **never** sent to WolfTech Innovations or any third party.
- **Local Record:** Data is stored exclusively at **`/etc/kibaos/age-verify`**.
- **User Control:** You can delete or modify this file at any time after installation.

---

\n## System Hardening

KibaOS implements several strategies to keep your data safe and your system resilient.

#\n## Minimal Attack Surface

By following our **Extreme Minimization** strategy, we remove hundreds of non-essential packages, documentation, and services.

- **Result:** Fewer installed binaries means fewer potential vulnerabilities (CVEs) on your system.

#\n## Kernel Security

The **CachyOS Kernel** isn't just for performance; it includes modern security patches and is regularly updated to mitigate emerging hardware and software threats.

#\n## Account Security

- **Live Session:** The `user` account has passwordless sudo for ease of testing.
- **Installed System:** The installer forces the creation of a secure root and user password, and the passwordless sudo privilege is automatically revoked.

---

\n## Privacy by Design

We believe your operating system should be a tool, not a tracker.

- **No Telemetry:** KibaOS does not include any built-in telemetry or data collection services.
- **Ungoogled Chromium:** Our default browser is stripped of Google-specific tracking and background services.
- **Flatpak Sandboxing:** We encourage the use of Flatpaks via **KibaStore**, which provides an additional layer of isolation between your applications and your private data.

---

\n## Related Reading

- [**Architecture**](./architecture.md)
- [**Software Management**](./software-management.md)
- [**WIKI**](../WIKI.md)
