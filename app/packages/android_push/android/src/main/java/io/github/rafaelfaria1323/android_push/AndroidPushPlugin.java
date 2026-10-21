package io.github.rafaelfaria1323.android_push;

import android.Manifest;
import android.app.Activity;
import android.content.Context;
import android.content.Intent;
import android.content.pm.PackageManager;
import android.os.Build;

import androidx.annotation.NonNull;
import androidx.core.app.ActivityCompat;
import androidx.core.app.NotificationManagerCompat;
import androidx.core.content.ContextCompat;

import com.google.firebase.FirebaseApp;
import com.google.firebase.messaging.FirebaseMessaging;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * The app's side of its notifications: whether they are on, turning them
 * on (Android 13+ asks the person first) and off, the device's FCM
 * registration token (stored by the app as its device), and the page of a
 * tapped notification ({@link DealTrackerMessagingService} shows them).
 */
public class AndroidPushPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler,
        ActivityAware, PluginRegistry.NewIntentListener,
        PluginRegistry.RequestPermissionsResultListener {
    private static final int PERMISSION_REQUEST = 8030;

    private MethodChannel channel;
    private Context context;
    private ActivityPluginBinding activity;
    private MethodChannel.Result waitingForPermission;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "deal_tracker/android_push");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        switch (call.method) {
            case "state":
                result.success(state());
                break;
            case "enable":
                enable(result);
                break;
            case "disable":
                PushSettings.setEnabled(context, false);
                token(result);
                break;
            case "initialUrl":
                result.success(activity == null ? null : takeUrl(activity.getActivity().getIntent()));
                break;
            default:
                result.notImplemented();
        }
    }

    /** "unavailable" (this build has no Firebase), "denied", "on" or "off". */
    private String state() {
        if (!firebaseReady()) return "unavailable";
        boolean allowed = NotificationManagerCompat.from(context).areNotificationsEnabled();
        boolean enabled = PushSettings.enabled(context);
        if (!allowed && (enabled || (PushSettings.asked(context) && !canAskAgain()))) {
            return "denied";
        }
        return enabled ? "on" : "off";
    }

    /** Android 13+ lets the app ask again after a first refusal. */
    private boolean canAskAgain() {
        return Build.VERSION.SDK_INT >= 33 && activity != null
                && ActivityCompat.shouldShowRequestPermissionRationale(
                        activity.getActivity(), Manifest.permission.POST_NOTIFICATIONS);
    }

    private void enable(MethodChannel.Result result) {
        if (!firebaseReady()) {
            result.error("unavailable", "Firebase is not configured in this build", null);
            return;
        }
        if (Build.VERSION.SDK_INT >= 33
                && ContextCompat.checkSelfPermission(context, Manifest.permission.POST_NOTIFICATIONS)
                != PackageManager.PERMISSION_GRANTED) {
            if (activity == null || waitingForPermission != null) {
                result.error("denied", "the permission can't be asked now", null);
                return;
            }
            waitingForPermission = result;
            PushSettings.setAsked(context);
            ActivityCompat.requestPermissions(activity.getActivity(),
                    new String[] {Manifest.permission.POST_NOTIFICATIONS}, PERMISSION_REQUEST);
            return;
        }
        afterPermission(result);
    }

    private void afterPermission(MethodChannel.Result result) {
        if (!NotificationManagerCompat.from(context).areNotificationsEnabled()) {
            PushSettings.setAsked(context);
            result.error("denied", "notifications are blocked for the app", null);
            return;
        }
        PushSettings.setEnabled(context, true);
        token(result);
    }

    /** The registration token (FCM answers on the main thread). */
    private void token(MethodChannel.Result result) {
        if (!firebaseReady()) {
            result.success(null);
            return;
        }
        FirebaseMessaging.getInstance().getToken().addOnCompleteListener(task -> {
            if (task.isSuccessful()) {
                result.success(task.getResult());
            } else {
                Exception e = task.getException();
                result.error("token", e == null ? "no token" : e.getMessage(), null);
            }
        });
    }

    private boolean firebaseReady() {
        return !FirebaseApp.getApps(context).isEmpty();
    }

    @Override
    public boolean onRequestPermissionsResult(int requestCode, @NonNull String[] permissions,
                                              @NonNull int[] grantResults) {
        if (requestCode != PERMISSION_REQUEST || waitingForPermission == null) return false;
        MethodChannel.Result result = waitingForPermission;
        waitingForPermission = null;
        if (grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED) {
            afterPermission(result);
        } else {
            result.error("denied", "the person refused notifications", null);
        }
        return true;
    }

    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        String url = takeUrl(intent);
        if (url == null) return false;
        channel.invokeMethod("open", url);
        return true;
    }

    /** The page of a tapped notification, once (not again on a restart). */
    private static String takeUrl(Intent intent) {
        if (intent == null) return null;
        String url = intent.getStringExtra(DealTrackerMessagingService.EXTRA_URL);
        intent.removeExtra(DealTrackerMessagingService.EXTRA_URL);
        return url;
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addOnNewIntentListener(this);
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        onDetachedFromActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(@NonNull ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        if (activity != null) {
            activity.removeOnNewIntentListener(this);
            activity.removeRequestPermissionsResultListener(this);
        }
        activity = null;
    }

    /** Kept for the app's whole life, also read by the messaging service. */
    static final class PushSettings {
        private static final String FILE = "deal_tracker_push";

        static boolean enabled(Context context) {
            return context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean("enabled", false);
        }

        static void setEnabled(Context context, boolean on) {
            context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean("enabled", on).apply();
        }

        static boolean asked(Context context) {
            return context.getSharedPreferences(FILE, Context.MODE_PRIVATE).getBoolean("asked", false);
        }

        static void setAsked(Context context) {
            context.getSharedPreferences(FILE, Context.MODE_PRIVATE).edit().putBoolean("asked", true).apply();
        }
    }
}
