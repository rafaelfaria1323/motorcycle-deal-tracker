package io.github.rafaelfaria1323.calendar_event;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.provider.CalendarContract;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Opens the calendar app's new-event screen with a planned visit filled in
 * (N.73). The person saves it there, so the app needs no calendar
 * permission and writes nothing itself.
 */
public class CalendarEventPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "deal_tracker/calendar_event");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!"insert".equals(call.method)) {
            result.notImplemented();
            return;
        }
        Number begin = call.argument("begin");
        Number end = call.argument("end");
        if (begin == null || end == null) {
            result.error("arguments", "begin and end are needed", null);
            return;
        }
        Intent intent = new Intent(Intent.ACTION_INSERT)
                .setData(CalendarContract.Events.CONTENT_URI)
                .putExtra(CalendarContract.EXTRA_EVENT_BEGIN_TIME, begin.longValue())
                .putExtra(CalendarContract.EXTRA_EVENT_END_TIME, end.longValue())
                .putExtra(CalendarContract.Events.TITLE, (String) call.argument("title"))
                .putExtra(CalendarContract.Events.DESCRIPTION, (String) call.argument("description"))
                .putExtra(CalendarContract.Events.EVENT_LOCATION, (String) call.argument("location"))
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK);
        try {
            context.startActivity(intent);
            result.success(true);
        } catch (ActivityNotFoundException e) {
            // No calendar app on the phone.
            result.success(false);
        }
    }
}
