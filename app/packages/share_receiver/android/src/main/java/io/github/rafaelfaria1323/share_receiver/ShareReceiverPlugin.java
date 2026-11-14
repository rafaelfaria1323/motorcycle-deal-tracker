package io.github.rafaelfaria1323.share_receiver;

import android.content.Intent;

import androidx.annotation.NonNull;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Text shared to the app from another app's Share menu (ACTION_SEND,
 * text/plain): the one the app was started with ({@code initialText}) and
 * each one while it runs ({@code shared}). Each is handed over once.
 */
public class ShareReceiverPlugin implements FlutterPlugin, MethodChannel.MethodCallHandler,
        ActivityAware, PluginRegistry.NewIntentListener {
    private MethodChannel channel;
    private ActivityPluginBinding activity;

    @Override
    public void onAttachedToEngine(@NonNull FlutterPluginBinding binding) {
        channel = new MethodChannel(binding.getBinaryMessenger(), "deal_tracker/shared_text");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(@NonNull FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
    }

    @Override
    public void onMethodCall(@NonNull MethodCall call, @NonNull MethodChannel.Result result) {
        if ("initialText".equals(call.method)) {
            result.success(activity == null ? null : takeText(activity.getActivity().getIntent()));
        } else {
            result.notImplemented();
        }
    }

    @Override
    public boolean onNewIntent(@NonNull Intent intent) {
        String text = takeText(intent);
        if (text == null) return false;
        channel.invokeMethod("shared", text);
        return true;
    }

    /** The shared text, once: the intent then reads as a plain launch. */
    private static String takeText(Intent intent) {
        if (intent == null || !Intent.ACTION_SEND.equals(intent.getAction())) return null;
        String type = intent.getType();
        if (type == null || !type.startsWith("text/")) return null;
        CharSequence text = intent.getCharSequenceExtra(Intent.EXTRA_TEXT);
        intent.removeExtra(Intent.EXTRA_TEXT);
        intent.setAction(Intent.ACTION_MAIN);
        return text == null ? null : text.toString();
    }

    @Override
    public void onAttachedToActivity(@NonNull ActivityPluginBinding binding) {
        activity = binding;
        binding.addOnNewIntentListener(this);
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
        if (activity != null) activity.removeOnNewIntentListener(this);
        activity = null;
    }
}
