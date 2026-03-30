# Finance_Wise

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Lab: Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Cookbook: Useful Flutter samples](https://docs.flutter.dev/cookbook)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

# FinanceWise 💸
**Personal Wealth Management Engine**

FinanceWise is a modern, high-performance financial tracking and wealth management application. It bridges the gap between daily expense tracking and long-term financial planning by automating the mathematical heavy lifting required to maintain a balanced budget.

## 🚀 Tech Stack
* **Frontend:** Flutter & Dart (Cross-platform Mobile UI)
* **Backend:** Node.js & Express.js (RESTful API)
* **Database:** MongoDB Atlas (NoSQL Cloud Database)
* **Security:** JSON Web Tokens (JWT Stateless Authentication)

## ✨ Key Features
* **Real-Time Dashboard:** Instantly calculates and displays "Net Wealth" and safe spending limits based on a dynamic 1% safety buffer logic.
* **Optimistic UI:** Lightning-fast rendering that updates the dashboard instantly (0.0s lag) while securely syncing with the MongoDB cloud in the background.
* **Financial Goals Engine:** Automatically calculates required monthly savings and mathematically flags long-term targets as Achievable or Unrealistic.
* **Stateless Security:** Fully protected backend routes utilizing JWT encryption, ensuring user data remains totally private.
* **Advanced Analytics:** Data visualization for monthly spending habits categorized by custom variables (Housing, Food, Entertainment, etc.).

## 📱 Project Architecture
This project utilizes a decoupled architecture where the Flutter mobile application communicates with the custom-built Node.js backend via secure HTTP REST endpoints.
