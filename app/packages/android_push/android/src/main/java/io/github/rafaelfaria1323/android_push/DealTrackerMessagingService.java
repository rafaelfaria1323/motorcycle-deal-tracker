package io.github.rafaelfaria1323.android_push;

import android.app.NotificationChannel;
import android.app.NotificationManager;
import android.app.PendingIntent;
import android.content.Intent;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.NotificationCompat;
import androidx.core.app.NotificationManagerCompat;

import com.google.firebase.messaging.FirebaseMessagingService;
import com.google.firebase.messaging.RemoteMessage;

import java.util.Map;

/**
 * Shows what the collector sends (FCM data messages: title, body, url,
 * tag, language) as a notification on the account's "Alertas"/"Alerts"
 * channel, also with the app closed. A tap opens the app on the message's page. Nothing is shown
 * while the person has them off in the app (or after signing out).
 */
public class DealTrackerMessagingService extends FirebaseMessagingService {
    static final String EXTRA_URL = "deal_tracker_url";
    private static final String CHANNEL = "alerts";

    @Override
    public void onMessageReceived(@NonNull RemoteMessage message) {
        if (!AndroidPushPlugin.PushSettings.enabled(this)) return;
        Map<String, String> data = message.getData();
        String title = data.get("title");
        String body = data.get("body");
        String url = data.get("url");
        String tag = data.get("tag");

        NotificationManagerCompat manager = NotificationManagerCompat.from(this);
        if (Build.VERSION.SDK_INT >= 26) {
            manager.createNotificationChannel(new NotificationChannel(
                    CHANNEL, "en".equals(data.get("language")) ? "Alerts" : "Alertas",
                    NotificationManager.IMPORTANCE_HIGH));
        }
        NotificationCompat.Builder notification = new NotificationCompat.Builder(this, CHANNEL)
                .setSmallIcon(R.drawable.android_push_notification)
                .setContentTitle(title == null || title.isEmpty() ? "Deal Tracker" : title)
                .setPriority(NotificationCompat.PRIORITY_HIGH)
                .setAutoCancel(true);
        if (body != null) {
            notification.setContentText(body)
                    .setStyle(new NotificationCompat.BigTextStyle().bigText(body));
        }
        PendingIntent open = openIntent(url);
        if (open != null) notification.setContentIntent(open);
        try {
            // Same tag: the newer message replaces the older one.
            manager.notify(tag, 0, notification.build());
        } catch (SecurityException e) {
            // The person took the permission away: nothing to show.
        }
    }

    /** The app, brought forward (or started) with [url] to open. */
    private PendingIntent openIntent(String url) {
        Intent launch = getPackageManager().getLaunchIntentForPackage(getPackageName());
        if (launch == null) return null;
        Intent intent = new Intent()
                .setComponent(launch.getComponent())
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK | Intent.FLAG_ACTIVITY_CLEAR_TOP
                        | Intent.FLAG_ACTIVITY_SINGLE_TOP);
        if (url != null) intent.putExtra(EXTRA_URL, url);
        int flags = PendingIntent.FLAG_UPDATE_CURRENT;
        if (Build.VERSION.SDK_INT >= 23) flags |= PendingIntent.FLAG_IMMUTABLE;
        // One per page, so a newer notification doesn't change an older one's.
        return PendingIntent.getActivity(this, url == null ? 0 : url.hashCode(), intent, flags);
    }
}
