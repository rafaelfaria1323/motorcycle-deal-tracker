package io.github.rafaelfaria1323.apk_installer;

import android.content.ActivityNotFoundException;
import android.content.Context;
import android.content.Intent;
import android.net.Uri;
import android.os.Handler;
import android.os.Looper;

import androidx.annotation.NonNull;
import androidx.core.content.FileProvider;

import java.io.ByteArrayOutputStream;
import java.io.File;
import java.io.FileOutputStream;
import java.io.IOException;
import java.io.InputStream;
import java.io.OutputStream;
import java.net.HttpURLConnection;
import java.net.URL;
import java.nio.charset.StandardCharsets;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;

/**
 * The app's own updater: reads the release's version file and downloads
 * the latest APK, then opens Android's installer with it (the person
 * confirms; nothing installs silently). Downloads run one at a time, off
 * the main thread.
 */
public class ApkInstallerPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler {
    private static final String APK_TYPE = "application/vnd.android.package-archive";

    private final ExecutorService worker = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());
    private MethodChannel channel;
    private Context context;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "deal_tracker/apk_installer");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if (!(call.arguments instanceof String)) {
            result.error("arguments", "a URL is needed", null);
            return;
        }
        String url = (String) call.arguments;
        switch (call.method) {
            case "readText":
                worker.execute(() -> readText(url, result));
                break;
            case "install":
                worker.execute(() -> install(url, result));
                break;
            default:
                result.notImplemented();
        }
    }

    private void readText(String url, MethodChannel.Result result) {
        try {
            ByteArrayOutputStream text = new ByteArrayOutputStream();
            download(url, text);
            String body = new String(text.toByteArray(), StandardCharsets.UTF_8);
            main.post(() -> result.success(body));
        } catch (IOException e) {
            fail(result, "download", e);
        }
    }

    private void install(String url, MethodChannel.Result result) {
        Intent intent;
        try {
            File folder = new File(context.getCacheDir(), "apk");
            if (!folder.isDirectory() && !folder.mkdirs()) {
                throw new IOException("cannot make " + folder);
            }
            // Written aside first, so a broken download never replaces a
            // whole APK.
            File part = new File(folder, "download.part");
            try (OutputStream out = new FileOutputStream(part)) {
                download(url, out);
            }
            File apk = new File(folder, "motorcycle-deal-tracker.apk");
            if (!part.renameTo(apk)) {
                throw new IOException("cannot keep " + apk);
            }
            Uri uri = FileProvider.getUriForFile(
                    context, context.getPackageName() + ".apk_installer", apk);
            intent = new Intent(Intent.ACTION_VIEW)
                    .setDataAndType(uri, APK_TYPE)
                    .addFlags(Intent.FLAG_GRANT_READ_URI_PERMISSION
                            | Intent.FLAG_ACTIVITY_NEW_TASK);
        } catch (IOException | IllegalArgumentException e) {
            fail(result, "download", e);
            return;
        }
        main.post(() -> {
            try {
                context.startActivity(intent);
                result.success(null);
            } catch (ActivityNotFoundException e) {
                result.error("install", e.getMessage(), null);
            }
        });
    }

    /** Copies what [url] answers into [out]; anything but 200 fails. */
    private static void download(String url, OutputStream out) throws IOException {
        HttpURLConnection connection = (HttpURLConnection) new URL(url).openConnection();
        try {
            connection.setConnectTimeout(15000);
            connection.setReadTimeout(60000);
            connection.setUseCaches(false);
            connection.setInstanceFollowRedirects(true);
            int status = connection.getResponseCode();
            if (status != HttpURLConnection.HTTP_OK) {
                throw new IOException("HTTP " + status + " from " + url);
            }
            try (InputStream in = connection.getInputStream()) {
                byte[] buffer = new byte[64 * 1024];
                int read;
                while ((read = in.read(buffer)) != -1) {
                    out.write(buffer, 0, read);
                }
            }
        } finally {
            connection.disconnect();
        }
    }

    private void fail(MethodChannel.Result result, String code, Exception e) {
        main.post(() -> result.error(code, e.getMessage(), null));
    }
}
