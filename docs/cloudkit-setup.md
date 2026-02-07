# Setting Up iCloud Team Collaboration

To enable real-time team collaboration in **ANAJ Agency OS**, you must enable CloudKit in the Xcode project.

## Steps to Enable

1.  Open `anaj.xcodeproj` in Xcode.
2.  Click on the **"anaj"** project icon in the left navigator.
3.  Select the **"anaj"** target in the main view.
4.  Go to the **"Signing & Capabilities"** tab.
5.  Click **"+ Capability"** in the top left.
6.  Search for **"iCloud"** and add it.
7.  In the iCloud section:
    *   Check **"CloudKit"**.
    *   Click **"+"** under Containers to create a new container (e.g., `iCloud.com.yourname.anaj`).
8.  Go to the **"Background Modes"** capability (add it if missing) and check **"Remote notifications"**.

## After Enabling

Once enabled:
1.  The app will automatically sync your `Clients`, `Projects`, and `Tasks` to your private iCloud database.
2.  To invite team members, use the **"Share"** button in the Team View (coming soon requires `CKShare` implementation in the Data Model).

## Current Status
The app is currently running in **Local Mode** to prevent crashes. The "Share" button in Team View serves as a placeholder for this functionality.
