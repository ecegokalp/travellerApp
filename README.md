1-Requirements

To run this app on your computer, you need the tools below:

*Flutter SDK (Recommended: Version 3.24.3)
    Flutter is a tool for building mobile apps.
    You can download from this link : https://docs.flutter.dev/get-started/install

*Dart SDK (included with Flutter)
    Dart is the programming language used in Flutter. You don't need to install it separately. It comes with Flutter.

*Android Studio or Visual Studio Code

  You can open and run the app with one of these programs:
  -Android Studio : https://developer.android.com/studio
  -VS Code (Visual Studio Code) : https://code.visualstudio.com/

  After you install these programs you have to install Flutter and Dart extensions inside them.
  How to install Flutter and Dart Extensions in Android Studio?
  1) Open Android Studio
  2) Click on Plugins (on the welcome screen, look bottom right)
  3) Go to "Marketplace" and search for Flutter
  4) Click install. After that Android Studio will show a pop-up saying Flutter plugin requires Dart. Click install again.
  5) Restart Android Studio

  The steps are very similar in Visual Studio Code.

*Firebase Account
  Firebase is used to save data and manage user login/register in this app.

*Google Generative AI (Gemini) API Key
  Gemini is used for AI-powered features like itinerary generation, checklist creation and document extraction.
  You can get a free API key from : https://aistudio.google.com

---------------------------------------------------------------------------------

2-How to Run the App

Step 1: Download the .zip file that includes the project codes.
Right click on it and choose 'Extract' to get the project folder.

Step 2: Open one of the programs (Android Studio or VS Code).
Click open folder and select the extracted project folder.

Step 3: Open the terminal in your project folder.
First type:
    flutter pub get
This command installs all the needed packages.

Step 4: To see the app you should use an emulator.
  - Click Create Device
  - Choose a phone model
  - Click Next
  - Download a system image
  - Click Next to finish
  - Then click the green Run button to start the emulator

You can also use your physical phone with a proper USB cable.

-------------------------------------------------------------------------------------

3-Firebase Setup

This app uses Firebase to manage users and data.
You need a file called google-services.json in this path:
    android/app/google-services.json

You also need GoogleService-Info.plist for iOS:
    ios/Runner/GoogleService-Info.plist

These files are not included in the repository for security reasons.
To get them:
  1) Go to https://console.firebase.google.com
  2) Create a new project
  3) Add an Android app and an iOS app to your project
  4) Download the config files and place them in the paths above
  5) Enable Authentication (Email/Password and Google Sign-In)
  6) Enable Firestore Database and Firebase Storage

---------------------------------------------------------------------------------------

4-Flutter Version

*Flutter 3.24.3
*Dart 3.5.3

----------------------------------------------------------------------------------------

5-YouTube Video Link : https://www.youtube.com/watch?v=OH-QklAjjgo

------------------------------------------------------------------------------------------

6-User Manual

How to Register & Sign-In

Since our application is a travel planning app, it requires users to register to the system. When users open the application, they will see email, password, login and register fields. If users don't have an account, they can click 'Register Now' and fill in the email and password fields. If they already have an account, they just enter their email and password to log in. Users can also log in with Google Sign-In by clicking the button. Forgot Password option is also available on the login screen — a reset email will be sent.


Main Screen

After logging in, users will see the Home Page with a calendar showing upcoming trips and a bottom navigation bar with 5 tabs:

1 Home - Displays the trip calendar, active trip checklists and a welcome message with profile photo.

2 Discover (Wander Feed) - A swipe-based feed where users can discover nearby places.

3 Map - An interactive map for exploring places around any location.

4 Documents - A page for uploading and managing travel documents like flight tickets and hotel bookings.

5 Profile - Shows user bio, visited countries & cities, followers/following, and published travel stories.


How to Discover Places

Users should tap the Discover tab to open the Wander Feed.
Swipe through place cards to explore nearby destinations. Each card shows the place name, category, rating and photos. A live map above the card shows the location of the current place. Users can toggle satellite view on any card. If a place looks interesting, tap the save icon to add it to saved places.


How to Plan a Trip

Users should tap the Home tab and select an existing trip or create a new one.
Inside the trip users can:
  - Add day-by-day activities using the planner (AI can suggest a full itinerary)
  - Set hotel check-in and check-out dates manually
  - Track the trip budget with currency conversion
  - View an auto-generated checklist for the trip

All trip dates sync automatically to the calendar on the Home Page.


How to Manage Travel Documents

Users should tap the Documents tab.
Documents like flight tickets or hotel bookings can be uploaded from the device. The AI will automatically read the document and extract important dates, syncing them to the trip calendar. Manual entry is also supported.


How to Use the Blog Page

Users should tap the Blog tab to browse travel stories from all users.
Stories are shown in a card layout. Users can like, comment on, save and share posts.
To write a story, tap the + button, add photos, write the content and publish.
Users receive a notification when someone likes, comments on or saves their post.


Profile Page

Users should tap the Profile tab to view their profile.
From here users can:
  - Edit their bio by tapping the edit icon
  - View visited countries and cities — tap either section to see the list and add new entries manually
  - See followers and following by tapping the counts
  - Browse all published travel stories in a grid

Other Details

Tap Forgot Password on the login screen to receive a password reset email.
Tap Log Out in the settings page to exit your session.
Dark mode can be toggled from the settings page.
Users receive push notifications when someone likes, comments on or saves their blog post, or when a new user follows them.
A Help Center is available in settings with a full guide to all features of the app.
