# Security & Compliance

KibaOS is committed to user privacy and complies with modern digital safety standards.

## California Age-Appropriate Design Code (AB 2273)

To comply with the California Age-Appropriate Design Code Act, KibaOS includes a custom **Age Verification** module within the **Calamares** graphical installer.

### Implementation
- **Module:** A custom Python-based view module located at `/usr/lib/calamares/modules/ageverify/`.
- **User Interface:** During installation, users are presented with a screen to select their age group (e.g., Under 13, 13-15, 16-17, 18+, or "Prefer not to say").
- **Transparency:** The screen clearly explains why this information is being collected and how it is stored.

### Privacy and Data Storage
In accordance with KibaOS's privacy-first philosophy:
- **Local Storage Only:** The selected age group is stored exclusively on the user's local machine at `/etc/kibaos/age-verify`.
- **No Transmission:** This data is **never** transmitted to WolfTech Innovations or any other external servers.
- **Purpose:** This local record ensures the system can provide an age-appropriate experience as mandated by law without compromising user anonymity.

## System Security

- **Sudo Access:** In the live session, the `user` account has passwordless sudo access for convenience. However, this is automatically revoked during installation, and the user is prompted to set a secure root and user password.
- **Kernel Security:** The **CachyOS Kernel** includes modern security patches and is regularly updated to mitigate emerging threats.
- **Minimal Surface Area:** By following the "Extreme Minimization" strategy, KibaOS reduces the number of installed packages and services, thereby shrinking the potential attack surface.
