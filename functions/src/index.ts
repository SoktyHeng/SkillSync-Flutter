import * as admin from "firebase-admin";

// Initialize Firebase Admin
admin.initializeApp();

// Export all functions
export {onNewChatMessage} from "./notifications/chatNotification";
export {onContributionRequest, onRequestStatusChange} from "./notifications/projectNotification";
