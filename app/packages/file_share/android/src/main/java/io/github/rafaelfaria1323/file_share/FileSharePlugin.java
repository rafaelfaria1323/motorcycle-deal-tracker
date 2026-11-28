package io.github.rafaelfaria1323.file_share;

import android.content.ActivityNotFoundException;
import android.content.ClipData;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.OutputStream;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * Shares a file the app made (the ad's report as a PDF, N.127) through
 * Android's share sheet: written to the cache's shared/ folder (the only
 * one the provider exposes; each share replaces the last), then sent with
 * ACTION_SEND and a read-only grant to the app the person picks.
 */
public class FileSharePlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "deal_tracker/file_share");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!"share".equals(call.method)) {
            result.notImplemented();
            return;
        }
        byte[] bytes = call.argument("bytes");
        String name = call.argument("name");
        String type = call.argument("type");
        String title = call.argument("title");
        if (bytes == null || name == null || type == null
                || name.contains("/") || name.startsWith(".")) {
            result.error("arguments", "bytes, a plain file name and a type are needed", null);
            return;
        }
        Uri uri;
        try {
            File folder = new File(context.getCacheDir(), "shared");
            if (!folder.isDirectory() && !folder.mkdirs()) {
                throw new IOException("cannot make " + folder);
            }
            File[] earlier = folder.listFiles();
            if (earlier != null) {
                for (File file : earlier) {
                    // Only the file being shared stays; a failed delete is harmless.
                    //noinspection ResultOfMethodCallIgnored
                    file.delete();
                }
            }
            File file = new File(folder, name);
            try (OutputStream out = new FileOutputStream(file)) {
                out.write(bytes);
            }
            uri = FileProvider.getUriForFile(
                    context, context.getPackageName() + ".file_share", file);
        } catch (IOException | IllegalArgumentException e) {
            result.error("write", e.getMessage(), null);
            return;
        }
        Intent send = new Intent(Intent.ACTION_SEND)
                .setType(type)
                .putExtra(Intent.EXTRA_STREAM, uri)
                .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION);
        if (title != null) send.putExtra(Intent.EXTRA_SUBJECT, title);
        // The grant reaches the picked app through the clip (Android 10+).
        send.setClipData(ClipData.newRawUri(name, uri));
        Intent chooser = Intent.createChooser(send, title)
                .addFlags(Intent.FLAG_ACTIVITY_NEW_TASK
                        | Intent.FLAG_GRANT_READ_URI_PERMISSION);
        try {
            context.startActivity(chooser);
            result.success(true);
        } catch (ActivityNotFoundException e) {
            result.success(false);
        }
    }
}
